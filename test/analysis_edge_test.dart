import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/analysis.dart';

void main() {
  group('hrZone limites exactos', () {
    test('50 %, 60 %, 70 %, 80 %, 90 % pertenecen a la zona superior', () {
      expect(hrZone(99, 200), 0); expect(hrZone(100, 200), 1); expect(hrZone(120, 200), 2);
      expect(hrZone(140, 200), 3); expect(hrZone(160, 200), 4); expect(hrZone(180, 200), 5);
    });
    test('por encima de FCmax sigue en zona 5', () => expect(hrZone(250, 200), 5));
    test('hrMax 0 o negativo no lanza (devuelve algo definido)', () {
      expect(() => hrZone(100, 0), returnsNormally);
      expect(() => hrZone(100, -5), returnsNormally);
    });
  });

  group('Tanaka', () {
    test('edades extremas (el Perfil no limita la edad: QA_001)', () {
      expect(hrMaxTanaka(0), 208); expect(hrMaxTanaka(100), 138);
      expect(hrMaxTanaka(300), lessThan(0)); // sin clamp en la UI se llega a FCmax negativa
    });
    test('redondeo .5 hacia arriba (Dart round)', () { expect(hrMaxTanaka(35), 184); /* 183.5 */ });
  });

  group('zoneMinutes / TRIMP', () {
    test('lista vacia', () { expect(zoneMinutes([], 190), List.filled(6, 0)); expect(edwardsTrimp(zoneMinutes([], 190)), 0); });
    test('zona 0 no suma TRIMP', () { expect(edwardsTrimp(zoneMinutes(List.filled(60, 80), 190)), 0); });
    test('todo en zona 5', () { expect(edwardsTrimp(zoneMinutes(List.filled(10, 185), 190)), 50); });
    test('suma de zonas == numero de muestras', () {
      final z = zoneMinutes([60, 100, 120, 140, 160, 180, 200], 190); expect(z.reduce((a, b) => a + b), 7);
    });
  });

  group('RMSSD', () {
    test('exactamente 5 validos -> calcula; 4 -> null', () {
      expect(rmssd([800, 800, 800, 800, 800]), 0);
      expect(rmssd([800, 810, 800, 810]), isNull);
    });
    test('descarta <=0 y >=2500 pero NO artefactos (QA_001): un RR de 300 ms entre latidos de 800 infla el RMSSD', () {
      final clean = rmssd([800, 800, 800, 800, 800, 800])!;
      final noisy = rmssd([800, 800, 300, 800, 800, 800])!;
      expect(clean, 0); expect(noisy, greaterThan(200));
    });
    test('el filtrado crea "falsos sucesivos": dif. entre latidos no adyacentes (QA_001)', () {
      // 800, [0 descartado], 900 -> se calcula 900-800 como si fueran consecutivos
      expect(rmssd([800, 0, 900, 900, 900, 900])!, greaterThan(0));
    });
    test('valores decimales y enteros mezclados', () { expect(rmssd([800, 810.0, 800, 810, 800])!, closeTo(10, 1e-9)); });
  });

  group('median / restingHrApprox / haversine', () {
    test('mediana con un elemento y con duplicados', () { expect(median([4]), 4); expect(median([2, 2, 2, 9]), 2); });
    test('mediana no modifica la lista de entrada', () { final x = [3.0, 1.0, 2.0]; median(x); expect(x, [3.0, 1.0, 2.0]); });
    test('reposo: ignora fuera de rango y exige 20 validas', () {
      expect(restingHrApprox([...List.filled(19, 60), 0, 250]), isNull);
      expect(restingHrApprox(List.filled(20, 60)), 60);
    });
    test('reposo: minimo 3 muestras en el decil', () {
      final v = [50, 51, 52, ...List.filled(27, 90)]; // 10 % de 30 = 3
      expect(restingHrApprox(v), closeTo(51, 1e-9));
    });
    test('haversine: mismo punto = 0, simetrica, un grado de longitud en el ecuador', () {
      expect(haversine(10, 20, 10, 20), 0);
      expect(haversine(0, 0, 0, 1), closeTo(111195, 300));
      expect(haversine(10, 20, 11, 22), closeTo(haversine(11, 22, 10, 20), 1e-6));
    });
    test('haversine con antimeridiano no da NaN', () { expect(haversine(0, 179.9, 0, -179.9).isNaN, isFalse); });
  });
}
