import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/gps_filter.dart';

// Rutas sintéticas inventadas (no son recorridos reales). Un punto cada 5 s.
const _lat0 = 40.0, _lng0 = -3.0; const _mPerDeg = 111320.0;
double _kx() => math.cos(_lat0 * math.pi / 180) * _mPerDeg;
GpsFix _fix(double xMeters, double yMeters, int i, {int signal = 2}) => GpsFix(_lat0 + yMeters / _mPerDeg, _lng0 + xMeters / _kx(), i * 5, signal);
/// Recta a 3 m/s hacia el este.
List<GpsFix> _line(int n) => [for (var i = 0; i < n; i++) _fix(i * 15.0, 0, i)];

double _maxOffAxisM(TrackReport r) { var m = 0.0; for (final s in r.segments) { for (final p in s) { m = math.max(m, (p.$1 - _lat0).abs() * _mPerDeg); } } return m; }

void main() {
  test('una recta limpia sale casi igual y sin correcciones', () {
    final r = filterTrack(_line(40));
    expect(r.segments.length, 1); expect(r.corrected, 0); expect(r.noSignal, 0); expect(r.kept, 40);
    expect(r.filteredMeters, closeTo(r.rawMeters, r.rawMeters * .03));
  });
  test('puntos sin señal (0) o en 0,0 se descartan y no se unen: no se inventa el tramo', () {
    final f = _line(30); f[10] = GpsFix(f[10].lat, f[10].lng, f[10].t, 0); f[11] = const GpsFix(0, 0, 55, 2);
    final r = filterTrack(f); expect(r.noSignal, 2); expect(r.kept, lessThanOrEqualTo(28));
  });
  test('un hueco largo corta la ruta en dos tramos', () {
    final f = [..._line(15), for (var i = 40; i < 55; i++) _fix(i * 15.0, 0, i)];
    final r = filterTrack(f); expect(r.segments.length, 2);
  });
  test('un salto imposible de 2 km se descarta; con una sola vez no cambia el resto de la ruta', () {
    final f = _line(40); f[20] = _fix(2000, 1500, 20);
    final r = filterTrack(f); expect(r.jumps, 1); expect(r.kept, 39); expect(_maxOffAxisM(r), lessThan(20));
  });
  test('si el salto es en realidad un cambio de posición (varios puntos seguidos), se acepta la nueva posición', () {
    final f = [..._line(15), for (var i = 15; i < 40; i++) _fix(5000 + i * 15.0, 0, i)];
    final r = filterTrack(f); expect(r.segments.length, 2, reason: 'la nueva posición abre un tramo, no se une al anterior'); expect(r.kept, greaterThan(30), reason: 'no se queda esperando para siempre la posición vieja');
  });
  test('un punto aislado a 40 m (velocidad posible) lo detecta el filtro de atípicos', () {
    final f = _line(40); f[20] = _fix(20 * 15.0, 40, 20);
    final r = filterTrack(f, cfg: const GpsFilterConfig(maxSpeed: 30)); expect(r.outliers, greaterThanOrEqualTo(1)); expect(_maxOffAxisM(r), lessThan(10));
  });
  test('el alisado reduce el zigzag del ruido pero conserva la forma', () {
    final rnd = math.Random(7); final noisy = [for (var i = 0; i < 60; i++) _fix(i * 15.0 + rnd.nextDouble() * 6 - 3, rnd.nextDouble() * 8 - 4, i)];
    final r = filterTrack(noisy);
    expect(r.filteredMeters, lessThan(r.rawMeters), reason: 'menos ruido = menos camino de más');
    expect(r.filteredMeters, greaterThan(60 * 15 * .9)); expect(_maxOffAxisM(r), lessThan(4));
  });
  test('un giro de 90 grados no se corta por dentro más de unos metros', () {
    final f = [for (var i = 0; i < 20; i++) _fix(i * 15.0, 0, i), for (var i = 1; i <= 20; i++) _fix(19 * 15.0, i * 15.0, 19 + i)];
    final r = filterTrack(f); final corner = r.segments.first[19]; final cx = (corner.$2 - _lng0) * _kx(), cy = (corner.$1 - _lat0) * _mPerDeg;
    expect(math.sqrt(math.pow(cx - 19 * 15.0, 2) + math.pow(cy, 2)), lessThan(12));
  });
  test('entradas desordenadas, vacías o con un solo punto no rompen', () {
    expect(filterTrack(const []).isEmpty, true); expect(filterTrack([_fix(0, 0, 0)]).isEmpty, true);
    final f = _line(20).reversed.toList(); expect(filterTrack(f).kept, 20);
  });
  test('valores absurdos (NaN, fuera de rango) se descartan', () {
    final f = [..._line(10), const GpsFix(double.nan, 1, 100, 2), const GpsFix(95, 1, 105, 2), const GpsFix(1, 200, 110, 2)];
    expect(filterTrack(f).noSignal, 3);
  });
  test('la velocidad máxima depende del modo: andar es más estricto que ir en bici', () {
    expect(GpsFilterConfig.forSport(2).maxSpeed, lessThan(GpsFilterConfig.forSport(3).maxSpeed));
    expect(GpsFilterConfig.forSport(null).maxSpeed, 15); expect(GpsFilterConfig.forSport(99999).maxSpeed, 15);
  });
  test('haversine: ~111 km por grado de latitud', () { expect(haversineM(0, 0, 1, 0), closeTo(111195, 300)); expect(haversineM(10, 10, 10, 10), 0); });
}
