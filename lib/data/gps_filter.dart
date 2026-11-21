import 'dart:math' as math;
import 'sports.dart';

/// Un punto GPS de la pulsera: un punto cada 5 s dentro de cada minuto de la sesión, con una señal por punto
/// (0 = sin posición, 2 = con posición; la pulsera no da HDOP ni VDOP, solo esto). [t] = segundos desde el inicio de la sesión.
class GpsFix {
  final double lat, lng; final int t, signal;
  const GpsFix(this.lat, this.lng, this.t, this.signal);
}

/// Resultado del filtrado: la ruta en tramos continuos (sin unir lo que no se midió) y qué se corrigió.
class TrackReport {
  final List<List<(double, double)>> segments;
  final int total, noSignal, jumps, outliers; final double rawMeters, filteredMeters;
  const TrackReport(this.segments, {required this.total, required this.noSignal, required this.jumps, required this.outliers, required this.rawMeters, required this.filteredMeters});
  int get kept => segments.fold(0, (a, s) => a + s.length);
  int get corrected => jumps + outliers;
  bool get isEmpty => kept < 2;
}

/// Ajustes del filtro. Valores por defecto razonables para una pulsera de muñeca; heurísticas propias, no validadas.
class GpsFilterConfig {
  /// Hueco máximo entre puntos válidos de un mismo tramo (s). Más allá se corta (la pulsera no midió).
  final int maxGapSec;
  /// Velocidad máxima creíble (m/s). Más rápido entre dos puntos = salto.
  final double maxSpeed;
  /// Saltos rechazados seguidos tras los que se acepta el punto nuevo (la posición real cambió de verdad).
  final int reanchorAfter;
  /// Radio de la ventana (en puntos) del filtro de valores atípicos y mínimo de desvío (m) para descartar.
  final int outlierWindow; final double outlierMinMeters, outlierMadFactor;
  /// Desviación típica (en puntos) del alisado gaussiano; 0 = sin alisado.
  final double smoothSigma;
  const GpsFilterConfig({this.maxGapSec = 30, this.maxSpeed = 15, this.reanchorAfter = 4, this.outlierWindow = 3, this.outlierMinMeters = 15, this.outlierMadFactor = 4, this.smoothSigma = 1.2});

  /// Velocidad máxima creíble según el modo deportivo (m/s): lo que un humano o su vehículo aguanta, con margen para el ruido.
  static GpsFilterConfig forSport(int? sportType) {
    final g = sportType == null ? null : sportById(sportType)?.group;
    final v = switch (g) { SportGroup.run => 11.0, SportGroup.walk => 6.0, SportGroup.bike => 22.0, SportGroup.water => 8.0, SportGroup.snow => 35.0, _ => 15.0 };
    return GpsFilterConfig(maxSpeed: v);
  }
}

const double _mPerDeg = 111320;

double haversineM(double la1, double lo1, double la2, double lo2) {
  const r = 6371000.0; double rad(double d) => d * math.pi / 180;
  final dLa = rad(la2 - la1), dLo = rad(lo2 - lo1);
  final a = math.pow(math.sin(dLa / 2), 2) + math.cos(rad(la1)) * math.cos(rad(la2)) * math.pow(math.sin(dLo / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

bool _validFix(GpsFix f) => f.signal > 0 && f.lat.isFinite && f.lng.isFinite && f.lat.abs() <= 90 && f.lng.abs() <= 180 && !(f.lat == 0 && f.lng == 0);

double _median(List<double> v) { final s = [...v]..sort(); final n = s.length; return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2; }

/// Filtra y alisa una ruta GPS:
/// 1. descarta los puntos sin señal o imposibles; 2. corta en tramos si hay un hueco largo; 3. descarta saltos (velocidad imposible entre
/// puntos consecutivos; si se repiten, se acepta la nueva posición); 4. descarta valores atípicos aislados (mediana y MAD sobre una ventana);
/// 5. alisa con un promedio gaussiano dentro de cada tramo. Nunca inventa puntos ni une tramos separados.
TrackReport filterTrack(List<GpsFix> fixes, {GpsFilterConfig cfg = const GpsFilterConfig()}) {
  final sorted = [...fixes]..sort((a, b) => a.t.compareTo(b.t));
  final valid = [for (final f in sorted) if (_validFix(f)) f];
  final noSignal = sorted.length - valid.length;
  if (valid.length < 2) return TrackReport(const [], total: fixes.length, noSignal: noSignal, jumps: 0, outliers: 0, rawMeters: 0, filteredMeters: 0);
  final lat0 = valid.first.lat, lng0 = valid.first.lng; final kx = math.cos(lat0 * math.pi / 180) * _mPerDeg;
  (double, double) xy(GpsFix f) => ((f.lng - lng0) * kx, (f.lat - lat0) * _mPerDeg);
  (double, double) ll((double, double) p) => (lat0 + p.$2 / _mPerDeg, lng0 + p.$1 / kx);

  // 2) tramos por huecos de tiempo
  final segs = <List<GpsFix>>[]; var cur = <GpsFix>[valid.first];
  var raw = 0.0;
  for (var i = 1; i < valid.length; i++) {
    if (valid[i].t - valid[i - 1].t > cfg.maxGapSec) { segs.add(cur); cur = <GpsFix>[]; } else { raw += haversineM(valid[i - 1].lat, valid[i - 1].lng, valid[i].lat, valid[i].lng); }
    cur.add(valid[i]);
  }
  segs.add(cur);

  var jumps = 0, outliers = 0; final out = <List<(double, double)>>[]; var filtered = 0.0;
  // 3) saltos por velocidad. Si se repiten, la posición cambió de verdad: se abre un tramo nuevo en ese punto (no se une al anterior).
  final subs = <List<GpsFix>>[];
  for (final seg in segs) {
    var kept = <GpsFix>[seg.first]; var rejectedRun = 0;
    for (var i = 1; i < seg.length; i++) {
      final a = kept.last, b = seg[i]; final dt = math.max(1, b.t - a.t);
      final v = haversineM(a.lat, a.lng, b.lat, b.lng) / dt;
      if (v > cfg.maxSpeed) { rejectedRun++; if (rejectedRun >= cfg.reanchorAfter) { subs.add(kept); kept = <GpsFix>[b]; rejectedRun = 0; } else { jumps++; } } else { kept.add(b); rejectedRun = 0; }
    }
    subs.add(kept);
  }
  for (final kept in subs) {
    // 4) atípicos (en metros locales): se compara cada punto con la posición esperada entre sus vecinos (el punto medio de anterior y siguiente);
    //    se quita el peor y se repite, para que un solo pico no marque también a sus vecinos.
    var pts = [for (final f in kept) xy(f)]; var ts = [for (final f in kept) f.t];
    for (var guard = 0; guard < pts.length ~/ 4 + 1 && pts.length >= 5; guard++) {
      final res = List<double>.filled(pts.length, 0);
      for (var i = 1; i < pts.length - 1; i++) {
        final w = (ts[i + 1] - ts[i]) / math.max(1, ts[i + 1] - ts[i - 1]); // posición esperada por interpolación en el tiempo
        final ex = pts[i - 1].$1 + (pts[i + 1].$1 - pts[i - 1].$1) * (1 - w), ey = pts[i - 1].$2 + (pts[i + 1].$2 - pts[i - 1].$2) * (1 - w);
        res[i] = math.sqrt(math.pow(pts[i].$1 - ex, 2) + math.pow(pts[i].$2 - ey, 2));
      }
      final mad = 1.4826 * _median(res.sublist(1, res.length - 1));
      final thr = math.max(cfg.outlierMinMeters, cfg.outlierMadFactor * mad);
      var worst = -1; var wv = thr;
      for (var i = 1; i < pts.length - 1; i++) { if (res[i] > wv) { wv = res[i]; worst = i; } }
      if (worst < 0) break;
      pts = [for (var i = 0; i < pts.length; i++) if (i != worst) pts[i]]; ts = [for (var i = 0; i < ts.length; i++) if (i != worst) ts[i]]; outliers++;
    }
    if (pts.length < 2) continue;
    // 5) alisado: regresión lineal local ponderada (gaussiana en el tiempo). Sigue una recta sin acortar los extremos ni los giros suaves.
    var sm = pts;
    if (cfg.smoothSigma > 0) {
      final sig = cfg.smoothSigma * 5.0; // en segundos (un punto cada 5 s)
      sm = [for (var i = 0; i < pts.length; i++) () {
        double sw = 0, st = 0, stt = 0, sx = 0, sy = 0, stx = 0, sty = 0;
        for (var k = math.max(0, i - 4); k <= math.min(pts.length - 1, i + 4); k++) {
          final dt = (ts[k] - ts[i]).toDouble(); final w = math.exp(-(dt * dt) / (2 * sig * sig));
          sw += w; st += w * dt; stt += w * dt * dt; sx += w * pts[k].$1; sy += w * pts[k].$2; stx += w * dt * pts[k].$1; sty += w * dt * pts[k].$2;
        }
        final den = sw * stt - st * st; if (den.abs() < 1e-9) return (sx / sw, sy / sw);
        return ((sx * stt - st * stx) / den, (sy * stt - st * sty) / den); // valor de la recta ajustada en dt = 0
      }()];
    }
    final ls = [for (final p in sm) ll(p)];
    for (var i = 1; i < ls.length; i++) { filtered += haversineM(ls[i - 1].$1, ls[i - 1].$2, ls[i].$1, ls[i].$2); }
    out.add(ls);
  }
  return TrackReport(out, total: fixes.length, noSignal: noSignal, jumps: jumps, outliers: outliers, rawMeters: raw, filteredMeters: filtered);
}
