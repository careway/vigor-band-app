import 'package:flutter/foundation.dart';
import 'analysis.dart';
import 'gps_filter.dart';
import 'sports.dart';

/// Datos que puede mostrar la pantalla de entreno (el tiempo siempre se muestra aparte, grande).
enum WorkoutField { distance, pace, speed, heartRate, calories, gps }

/// Qué datos importan en cada tipo de actividad, en orden. Carrera y caminata: distancia, ritmo, pulso; ciclismo y nieve: distancia y velocidad;
/// agua: distancia y pulso; gimnasio, mente y cuerpo, baile, combate, pelota y raqueta: pulso y calorías. La señal GPS solo en los de recorrido.
List<WorkoutField> workoutFields(SportMode? m) {
  final g = m?.group; final route = m?.tracksRoute ?? false;
  return [
    ...switch (g) {
      SportGroup.run || SportGroup.walk => [WorkoutField.distance, WorkoutField.pace, WorkoutField.heartRate, WorkoutField.calories],
      SportGroup.bike || SportGroup.snow => [WorkoutField.distance, WorkoutField.speed, WorkoutField.heartRate, WorkoutField.calories],
      SportGroup.water => [WorkoutField.distance, WorkoutField.heartRate, WorkoutField.calories],
      _ => [WorkoutField.heartRate, WorkoutField.calories],
    },
    if (route) WorkoutField.gps,
  ];
}

// Unidades del informe en vivo de la pulsera, según la documentación china del SDK («设置运动控制», SportControlDataInfo): duración en segundos,
// distancia en metros, pulso en lpm, ritmo en segundos por km, calorías en CALORÍAS (no kcal: se dividen entre 1000) y velocidad en METROS POR HORA
// (se divide entre 1000 para km/h). Documentadas, pero sin comprobar todavía con la pulsera; si no cuadran, se corrigen aquí.
const double kLiveDistanceToMeters = 1, kLiveCaloriesToKcal = 0.001, kLiveSpeedToKmh = 0.001;

double? _num(Object? v) { if (v is num) return v.isFinite ? v.toDouble() : null; if (v is String) return double.tryParse(v); return null; }

/// Lo que dice un informe de la pulsera, ya saneado: un dato absurdo o ausente es null (nunca se inventa).
class WorkoutReport {
  final int? sportType, heartRate, gpsSignal, durationSec; final double? distanceM, paceSecKm, speedKmh, kcal; final String runState;
  const WorkoutReport({this.sportType, this.heartRate, this.gpsSignal, this.durationSec, this.distanceM, this.paceSecKm, this.speedKmh, this.kcal, this.runState = ''});
  bool get isPaused => runState.toLowerCase().contains('pause');
  bool get isEnded { final s = runState.toLowerCase(); return s.contains('stop') || s.contains('end') || s.contains('finish'); }

  static WorkoutReport parse(Map<dynamic, dynamic> d) {
    int? hr; final h = _num(d['heartRate']); if (h != null && h >= 30 && h <= 230) hr = h.round();
    final dur = _num(d['sportDuration']); final dist = _num(d['distance']); final pace = _num(d['pace']); final sp = _num(d['speed']); final kc = _num(d['calories']); final gps = _num(d['gpsSignal']); final ty = _num(d['sportType']);
    return WorkoutReport(
      sportType: ty?.round(), heartRate: hr, gpsSignal: gps?.round(),
      durationSec: dur != null && dur >= 0 && dur < 86400 * 2 ? dur.round() : null,
      distanceM: dist != null && dist >= 0 && dist < 1e7 ? dist * kLiveDistanceToMeters : null,
      paceSecKm: pace != null && pace >= 60 && pace <= 3600 ? pace : null,
      speedKmh: sp != null && sp >= 0 && sp * kLiveSpeedToKmh < 120 ? sp * kLiveSpeedToKmh : null,
      kcal: kc != null && kc >= 0 && kc * kLiveCaloriesToKcal < 20000 ? kc * kLiveCaloriesToKcal : null,
      runState: '${d['runState'] ?? ''}');
  }
}

/// Actividad en curso: la inicia el usuario desde la app o la pulsera, y se alimenta de los informes en vivo de la pulsera. El reloj corre en
/// el móvil (anclado a la duración que informa la pulsera si la da), de modo que sigue contando aunque la pulsera esté un rato sin avisar.
class LiveWorkout extends ChangeNotifier {
  LiveWorkout({DateTime Function()? clock, this.staleAfter = const Duration(seconds: 25), this.giveUpAfter = const Duration(minutes: 45)}) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock; final Duration staleAfter, giveUpAfter;

  bool active = false, paused = false; SportMode? mode; DateTime? startedAt, lastReport;
  int? heartRate, gpsSignal; double? distanceM, paceSecKm, speedKmh, kcal;
  /// Pulso de cada informe, para la gráfica (como mucho [maxSamples]).
  final hrSamples = <int>[]; static const maxSamples = 600;
  int maxHr = 0;
  /// Recorrido que la pulsera ha devuelto de esta actividad (solo llega al sincronizar, no en directo) y la última posición con su incertidumbre aprox.
  List<GpsFix> track = const []; (double, double)? position; double? uncertaintyM; int? positionAgeSec;

  /// Actualiza el recorrido con los puntos que devolvió la pulsera (instantes en segundos desde el inicio). Sin puntos con señal, no hay posición.
  void setTrack(List<GpsFix> fixes) {
    track = fixes; final rep = filterTrack(fixes);
    final last = rep.segments.isEmpty ? null : rep.segments.last.last;
    position = last; final now = elapsed().inSeconds;
    uncertaintyM = last == null ? null : estimateUncertaintyM(fixes, nowT: now);
    final lastT = [for (final f in fixes) if (f.signal > 0 && !(f.lat == 0 && f.lng == 0)) f.t]; positionAgeSec = lastT.isEmpty ? null : (now - lastT.reduce((a, b) => a > b ? a : b)).clamp(0, 1 << 30);
    notifyListeners();
  }

  void begin(SportMode? m) { _reset(); active = true; mode = m; startedAt = _clock(); notifyListeners(); }
  void _reset() { track = const []; position = null; uncertaintyM = null; positionAgeSec = null; paused = false; heartRate = gpsSignal = null; distanceM = paceSecKm = speedKmh = kcal = null; hrSamples.clear(); maxHr = 0; lastReport = null; }

  void onReport(Map<dynamic, dynamic> d) {
    final r = WorkoutReport.parse(d); final now = _clock();
    if (r.isEnded) { end(); return; }
    if (!active) { _reset(); active = true; startedAt = now; } // iniciada desde la pulsera
    mode ??= r.sportType == null ? null : sportById(r.sportType!);
    if (r.durationSec != null) { final a = now.subtract(Duration(seconds: r.durationSec!)); if (startedAt == null || (startedAt!.difference(a)).inSeconds.abs() > 3) startedAt = a; }
    paused = r.isPaused; lastReport = now;
    if (r.heartRate != null) { heartRate = r.heartRate; hrSamples.add(r.heartRate!); if (hrSamples.length > maxSamples) hrSamples.removeAt(0); if (r.heartRate! > maxHr) maxHr = r.heartRate!; }
    gpsSignal = r.gpsSignal ?? gpsSignal; distanceM = r.distanceM ?? distanceM; paceSecKm = r.paceSecKm ?? paceSecKm; speedKmh = r.speedKmh ?? speedKmh; kcal = r.kcal ?? kcal;
    notifyListeners();
  }

  void end() { if (!active) return; active = false; paused = false; notifyListeners(); }

  /// Tiempo transcurrido desde el inicio (nunca negativo). No se detiene al pausar: la pulsera no informa de cuánto tiempo estuvo en pausa.
  Duration elapsed() { final s = startedAt; if (s == null) return Duration.zero; final d = _clock().difference(s); return d.isNegative ? Duration.zero : d; }
  /// ¿Hace rato que la pulsera no avisa? (sin conexión o fuera de alcance)
  bool get stale { final l = lastReport; return active && (l == null ? elapsed() > staleAfter : _clock().difference(l) > staleAfter); }
  /// Si lleva mucho sin avisar y sin conexión, la actividad se da por terminada en pantalla (ya aparecerá en el historial al sincronizar).
  bool get abandoned { final l = lastReport ?? startedAt; return active && l != null && _clock().difference(l) > giveUpAfter; }
  /// Llamar cada segundo desde la pantalla: da por terminada la actividad si lleva demasiado sin noticias de la pulsera.
  void tick() { if (abandoned) end(); }
  /// Zona de pulso 0..5 (0 = por debajo de la zona 1) según la FCmáx; null sin lectura.
  int? zone(int hrMax) => heartRate == null ? null : hrZone(heartRate!, hrMax);
}

/// «1:05:09» o «05:09».
String clockText(Duration d) { final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60; String two(int n) => n.toString().padLeft(2, '0'); return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}'; }
/// Ritmo en min:seg por km, o «—».
String paceText(double? secKm) { if (secKm == null || secKm <= 0) return '—'; final m = secKm ~/ 60, s = (secKm % 60).round(); return s == 60 ? '${m + 1}:00' : '$m:${s.toString().padLeft(2, '0')}'; }
