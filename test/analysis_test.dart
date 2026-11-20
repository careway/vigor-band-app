import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/analysis.dart';

void main() {
  test('Tanaka: 208 - 0.7*edad', () {
    expect(hrMaxTanaka(30), 187);
    expect(hrMaxTanaka(50), 173);
  });
  test('zonas por % de FCmax', () {
    expect(hrZone(80, 200), 0); expect(hrZone(110, 200), 1); expect(hrZone(130, 200), 2);
    expect(hrZone(150, 200), 3); expect(hrZone(170, 200), 4); expect(hrZone(190, 200), 5);
  });
  test('TRIMP de Edwards = suma minutos*zona', () {
    // 10 min zona 2 + 5 min zona 4 = 20 + 20
    final z = [0, 0, 10, 0, 5, 0];
    expect(edwardsTrimp(z), 40);
  });
  test('RMSSD con valores conocidos', () {
    // diferencias: 10, -10, 10, -10 -> RMSSD = 10
    expect(rmssd([800, 810, 800, 810, 800])!, closeTo(10, 1e-9));
    expect(rmssd([800, 810]), isNull);
    expect(rmssd([2550, 2550, 2550, 2550, 2550]), isNull); // centinela 255*10 = sin dato
  });
  test('mediana', () {
    expect(median([3, 1, 2]), 2); expect(median([1, 2, 3, 4]), 2.5); expect(median([]), isNull);
  });
  test('Haversine ~111 km por grado de latitud', () {
    expect(haversine(0, 0, 1, 0), closeTo(111195, 300));
  });
  test('FC reposo aprox: pocas muestras -> null', () {
    expect(restingHrApprox(List.filled(5, 60)), isNull);
    expect(restingHrApprox([...List.filled(50, 60), ...List.filled(50, 100)]), closeTo(60, 1e-9));
  });
}
