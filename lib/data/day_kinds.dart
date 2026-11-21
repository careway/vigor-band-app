import 'repo.dart';
import 'sports.dart';

/// Qué hacía el usuario en cada franja de 30 min del reloj de Hoy. Lógica pura (sin Flutter) para poder probarla.
/// El reloj NO pinta categorías sueltas: pinta una MEZCLA continua ([BinMix]) y estos nombres solo sirven para la leyenda y la lectura.
enum DayKind { none, sleep, activity, walk, rest }

String dayKindLabel(DayKind k) => switch (k) {
      DayKind.sleep => 'Dormir', DayKind.activity => 'Actividad deportiva', DayKind.walk => 'Actividad leve', DayKind.rest => 'Reposo', DayKind.none => 'Sin datos' };

/// Mezcla de una franja: [sleep] 0..1 (cuánto pesa el sueño), [effort] 0..1 (0 reposo · ≈0,5 actividad leve · 1 deportiva) y si hay datos.
class BinMix {
  final double sleep, effort; final bool hasData;
  const BinMix({this.sleep = 0, this.effort = 0, this.hasData = false});
  /// Nombre dominante de la franja (leyenda, lectura y resumen hablado).
  DayKind get kind => sleep >= kSleepDominates ? DayKind.sleep : !hasData ? DayKind.none : effort >= kSportFrom ? DayKind.activity : effort >= kLightFrom ? DayKind.walk : DayKind.rest;
}

/// Minutos de sueño en la franja a partir de los cuales el sueño manda por completo; por debajo se mezcla (peso = min / este valor).
const int kSleepFullMin = 15;
/// Peso de sueño a partir del cual la franja se nombra «Dormir».
const double kSleepDominates = 0.5;
/// Esfuerzo a partir del cual la franja es «actividad leve» / «actividad deportiva» (solo para nombrarla; el color es continuo).
const double kLightFrom = 0.18, kSportFrom = 0.62;
/// Esfuerzo por pasos en 30 min: puntos (pasos, esfuerzo) de una curva lineal a trozos. ~1500 pasos = marcha ligera; ~4000 = carrera.
const List<(double, double)> kStepsCurve = [(0, 0), (150, .2), (1500, .5), (4000, 1)];
/// Esfuerzo por pulso: fracción de la FCmáx → esfuerzo. 45 % o menos = reposo; 60 % ≈ ligera; 80 % o más = intenso.
const List<(double, double)> kHrCurve = [(.45, 0), (.60, .5), (.80, 1)];

double _curve(List<(double, double)> pts, double x) {
  if (x <= pts.first.$1) return pts.first.$2;
  for (var i = 1; i < pts.length; i++) {
    if (x <= pts[i].$1) { final a = pts[i - 1], b = pts[i]; return a.$2 + (b.$2 - a.$2) * (x - a.$1) / (b.$1 - a.$1); }
  }
  return pts.last.$2;
}
double effortFromSteps(double stepsIn30) => _curve(kStepsCurve, stepsIn30);
double effortFromHr(double meanHr, int hrMax) => hrMax <= 0 ? 0 : _curve(kHrCurve, meanHr / hrMax);

int _overlapMin(DateTime a0, DateTime a1, DateTime b0, DateTime b1) {
  final s = a0.isAfter(b0) ? a0 : b0, e = a1.isBefore(b1) ? a1 : b1;
  return e.isAfter(s) ? e.difference(s).inMinutes : 0;
}

/// Intervalo que cubre una noche o siesta: del inicio al despertar; si falta, inicio + duración.
(DateTime, DateTime)? sleepSpan(Night n) {
  final s = n.start; if (s == null) return null;
  final e = n.up ?? (n.stages != null ? s.add(Duration(minutes: n.stages!.length)) : s.add(Duration(minutes: n.total)));
  return e.isAfter(s) ? (s, e) : null;
}

/// Las 48 franjas de 30 min del día [day] como mezcla. Esfuerzo = el MAYOR de: pasos, pulso (respecto a [hrMax]) y ejercicio registrado
/// (deportivo: 0,5 + 0,5·fracción de la franja; caminata/senderismo: 0,3 + 0,3·fracción). El sueño, si lo hay en la franja, predomina:
/// peso = minutos de sueño / [kSleepFullMin] (con 15 min o más, la franja es del todo de sueño). Heurística, no validada.
List<BinMix> mixDay({required Day day, required List<Night> nights, required List<Session> sessions, int hrMax = 185}) {
  final d0 = DateTime.tryParse(day.date); if (d0 == null) return List.filled(48, const BinMix());
  final spans = [for (final n in nights) if (sleepSpan(n) != null) sleepSpan(n)!];
  final steps = List<double>.filled(48, 0); final has = List<bool>.filled(48, false);
  final hrSum = List<double>.filled(48, 0); final hrN = List<int>.filled(48, 0);
  int bin(DateTime t) => (t.hour * 2 + t.minute ~/ 30).clamp(0, 47);
  bool same(DateTime t) => t.year == d0.year && t.month == d0.month && t.day == d0.day;
  for (final s in day.steps5) { if (same(s.t)) { steps[bin(s.t)] += s.v; has[bin(s.t)] = true; } }
  for (final s in day.hr) { if (same(s.t) && s.v > 0) { hrSum[bin(s.t)] += s.v; hrN[bin(s.t)]++; has[bin(s.t)] = true; } }
  final out = <BinMix>[];
  for (var i = 0; i < 48; i++) {
    final b0 = DateTime(d0.year, d0.month, d0.day, 0, i * 30), b1 = b0.add(const Duration(minutes: 30));
    final sleepMin = spans.fold<int>(0, (a, s) => a + _overlapMin(s.$1, s.$2, b0, b1));
    var effort = effortFromSteps(steps[i]);
    if (hrN[i] > 0) { final e = effortFromHr(hrSum[i] / hrN[i], hrMax); if (e > effort) effort = e; }
    var sessionSeen = false;
    for (final s in sessions) {
      final m = _overlapMin(s.start, s.start.add(Duration(seconds: s.seconds)), b0, b1);
      if (m < 10) continue; // menos de 10 min dentro de la franja no la define
      sessionSeen = true; final f = (m / 30).clamp(0.0, 1.0);
      final e = sportById(s.sportType)?.group == SportGroup.walk ? .3 + .3 * f : .5 + .5 * f;
      if (e > effort) effort = e;
    }
    out.add(BinMix(sleep: (sleepMin / kSleepFullMin).clamp(0.0, 1.0), effort: effort.clamp(0.0, 1.0), hasData: has[i] || sessionSeen || sleepMin > 0));
  }
  return out;
}

/// Atajo: el nombre dominante de cada franja.
List<DayKind> classifyDay({required Day day, required List<Night> nights, required List<Session> sessions, int hrMax = 185}) =>
    [for (final m in mixDay(day: day, nights: nights, sessions: sessions, hrMax: hrMax)) m.kind];

/// Franjas por nombre (para la leyenda y el resumen hablado).
Map<DayKind, int> countKinds(List<DayKind> k) { final m = <DayKind, int>{}; for (final x in k) { m[x] = (m[x] ?? 0) + 1; } return m; }
