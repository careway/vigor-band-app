// Pruebas de VigorRepo.reload() con JSON inventado (sin datos reales).
// Los defectos documentados en QA_001 ya estan corregidos y estos casos prueban el comportamiento correcto.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';

Map<String, int> _t(int y, int mo, int d, int h, int mi) => {'year': y, 'month': mo, 'day': d, 'hour': h, 'minute': mi};

Future<VigorRepo> _load(Map<String, List> data) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'), (call) async {
    if (call.method == 'getData') return jsonEncode(data[call.arguments['kind']] ?? []);
    return null;
  });
  final r = VigorRepo();
  await r.reload();
  return r;
}

void main() {
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'), null));

  test('datos vacios: no revienta y marca loaded', () async {
    final r = await _load({});
    expect(r.loaded, isTrue);
    expect(r.days, isEmpty); expect(r.nights, isEmpty); expect(r.sessions, isEmpty);
    expect(r.liveSteps, 0); expect(r.dayKeys, isEmpty);
  });

  test('origin5: suma pasos/kcal/km, filtra rangos y ordena', () async {
    final r = await _load({'origin5': [
      {'mTime': _t(2026, 3, 5, 10, 5), 'stepValue': 20, 'calValue': 1.5, 'disValue': 0.01, 'ppgs': [70, 72, 0, 300, 29, 220], 'pressure': 40, 'temperature': 36.4, 'baseTemperature': 32.1, 'met': 1.2, 'bloodGlucose': 5.0},
      {'mTime': _t(2026, 3, 5, 10, 0), 'stepValue': 10, 'calValue': 0.5, 'disValue': 0.02, 'ppgs': [], 'pressure': 0, 'temperature': 0, 'baseTemperature': 0, 'met': 0, 'bloodGlucose': 0},
      {'mTime': _t(2026, 3, 6, 0, 0), 'stepValue': 5},
    ]});
    expect(r.dayKeys, ['2026-03-05', '2026-03-06']);
    final d = r.days['2026-03-05']!;
    expect(d.steps, 30); expect(d.kcal, closeTo(2.0, 1e-9)); expect(d.km, closeTo(0.03, 1e-9));
    expect(d.hr.map((s) => s.v), [70, 72, 220]); // 0, 300 y 29 descartados
    expect(d.hr.first.t, DateTime(2026, 3, 5, 10, 5)); expect(d.hr[1].t, DateTime(2026, 3, 5, 10, 6)); // un valor por minuto (supuesto, no verificado con la pulsera)
    expect(d.stress.length, 1); expect(d.temp.length, 1); expect(d.skin.length, 1); expect(d.met.length, 1); expect(d.glucose.length, 1);
    expect(d.steps5.first.t, DateTime(2026, 3, 5, 10, 0)); // ordenado
  });

  test('temperatura fuera de rango fisiologico se descarta (35.9 y 43.1 limites)', () async {
    final r = await _load({'origin5': [
      {'mTime': _t(2026, 3, 5, 1, 0), 'temperature': 29.9, 'baseTemperature': 14.9},
      {'mTime': _t(2026, 3, 5, 1, 5), 'temperature': 30.0, 'baseTemperature': 15.0},
      {'mTime': _t(2026, 3, 5, 1, 10), 'temperature': 43.0, 'baseTemperature': 43.0},
      {'mTime': _t(2026, 3, 5, 1, 15), 'temperature': 43.1, 'baseTemperature': 43.1},
    ]});
    final d = r.days['2026-03-05']!;
    expect(d.temp.map((s) => s.v), [30.0, 43.0]); expect(d.skin.map((s) => s.v), [15.0, 43.0]);
  });

  test('tipos inesperados (strings, null) en campos numericos -> 0, sin excepcion', () async {
    final r = await _load({'origin5': [
      {'mTime': _t(2026, 3, 5, 9, 0), 'stepValue': '12', 'calValue': null, 'disValue': 'x', 'ppgs': [], 'bloodComponent': 'x'},
    ]});
    expect(r.days['2026-03-05']!.steps, 0);
  });

  test('ppgs que no es lista se ignora sin abortar reload; el resto del registro se conserva', () async {
    final r = await _load({'origin5': [{'mTime': _t(2026, 3, 5, 9, 0), 'ppgs': 'no-lista', 'stepValue': 7}, {'mTime': _t(2026, 3, 5, 9, 5), 'ppgs': [null, 'x', 80]}]});
    expect(r.loaded, isTrue);
    final d = r.days['2026-03-05']!;
    expect(d.steps, 7); expect(d.hr.length, 1);
  });

  // Ronda 3 (E3): los no numericos ya no se eliminan uniendo vecinos; ocupan su sitio como invalidos y la diferencia no cruza el hueco.
  test('rrValue con null/no numericos no aborta reload y no une latidos vecinos', () async {
    final r = await _load({'hrv': [
      {'mTime': _t(2026, 3, 5, 9, 0), 'rrValue': [800, null, 810, 800, 790, 800, 'x']}, // solo 3 diferencias validas -> minuto invalido
      {'mTime': _t(2026, 3, 5, 9, 30), 'rrValue': 'mal'},
      {'mTime': _t(2026, 3, 5, 9, 45), 'rrValue': [800, 810, 800, 810, 800, 810, 800]}]});
    expect(r.loaded, isTrue);
    expect(r.days['2026-03-05']!.hrv.length, 1);
    expect(r.days['2026-03-05']!.qOf('hrv').raw, 3);
  });

  test('un registro malo no impide cargar los demas', () async {
    final r = await _load({'origin5': ['basura', 5, {'mTime': _t(2026, 3, 5, 9, 0), 'stepValue': 3}]});
    expect(r.days['2026-03-05']!.steps, 3);
  });

  test('mTime presente pero vacio se descarta (sin dia basura)', () async {
    final r = await _load({'origin5': [{'mTime': <String, int>{}, 'stepValue': 99}]});
    expect(r.days, isEmpty);
  });

  test('mTime ausente o no-mapa: fila ignorada', () async {
    final r = await _load({'origin5': [{'stepValue': 5}, {'mTime': '2026-03-05', 'stepValue': 5}]});
    expect(r.days, isEmpty);
  });

  test('SpO2 70..100, HRV robusta (>=5 diferencias validas = 6 RR)', () async {
    final r = await _load({
      'spo2': [{'mTime': _t(2026, 3, 5, 3, 0), 'oxygenValue': 96}, {'mTime': _t(2026, 3, 5, 3, 5), 'oxygenValue': 69}, {'mTime': _t(2026, 3, 5, 3, 10), 'oxygenValue': 101}],
      'hrv': [{'mTime': _t(2026, 3, 5, 3, 0), 'rrValue': [800, 810, 800, 810, 800, 810]}, {'mTime': _t(2026, 3, 5, 3, 30), 'rrValue': [800, 810]}],
    });
    final d = r.days['2026-03-05']!;
    expect(d.spo2.map((s) => s.v), [96]);
    expect(d.hrv.length, 1); expect(d.hrv.first.v, closeTo(10, 1e-9));
  });

  test('sueno: descarta noches con total 0, ordena de mas reciente a mas antigua, admite Date/date', () async {
    final r = await _load({'sleep': [
      {'Date': '2026-03-04', 'allSleepTime': 400, 'deepSleepTime': 80, 'lowSleepTime': 300, 'wakeCount': 2},
      {'date': '2026-03-05', 'allSleepTime': 0},
      {'Date': '2026-03-06', 'allSleepTime': 420, 'sleepDown': _t(2026, 3, 5, 23, 10), 'sleepUp': _t(2026, 3, 6, 6, 10)},
    ]});
    expect(r.nights.map((n) => n.date), ['2026-03-06', '2026-03-04']);
    expect(r.nights.first.down, DateTime(2026, 3, 5, 23, 10)); // cruza medianoche: se conserva
  });

  test('sesiones: ruta con cortes sin fix, pulso filtrado y orden', () async {
    final r = await _load({
      'sports': [
        {'_key': 'a', 'sportTime': 600, 'startTime': _t(2026, 3, 5, 8, 0), 'sportType': 1, 'distance': 1500, 'calories': 90000, 'stepCount': 1800, 'avgHeartRate': 140, 'avgPace': 400, 'hasGpsInfo': true},
        {'_key': 'b', 'sportTime': 0, 'startTime': _t(2026, 3, 5, 9, 0)},
        {'_key': 'c', 'sportTime': 60, 'startTime': _t(2026, 3, 6, 9, 0), 'sportType': 99},
      ],
      'sportItems': [{'_key': 'a', 'items': [
        {'latArray': [10.0, 10.0001, 0, 0, 10.0002], 'lngArray': [20.0, 20.0001, 0, 0, 20.0002], 'rate': 120},
        {'latArray': [0, 0], 'lngArray': [0, 0], 'rate': 20},
        {'latArray': [10.0003], 'lngArray': [], 'rate': 225},
      ]}],
    });
    expect(r.sessions.map((s) => s.key), ['c', 'a']); // b (0 s) descartada
    final a = r.sessions.last;
    expect(a.route.length, 5); // 2 puntos, corte, 1 punto, y un corte final espurio (item 2 todo ceros) que no se duplica con otro
    expect(a.route[2].$1.isNaN, isTrue); expect(a.route.last.$1.isNaN, isTrue);
    expect(a.hrPerMinute, [120]); // 20 y 225 fuera de 30..220
    expect(a.kcal, 90); // calories/1000: supuesto de unidad NO verificado
    expect(sportName(999), 'Actividad (999)');
  });

  test('sesion sin startTime se descarta (no se inventa la hora)', () async {
    final r = await _load({'sports': [{'_key': 'z', 'sportTime': 10}]});
    expect(r.sessions, isEmpty);
  });

  test('live: solo cuenta si la lectura es de hoy (campo at)', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect((await _load({'live': [{'step': 1234, 'at': now}]})).liveSteps, 1234);
    expect((await _load({'live': [{'step': 1234, 'at': now - 3 * 86400000}]})).liveSteps, 0);
    expect((await _load({'live': [{'step': 1234}]})).liveSteps, 0);
  });

  test('getData que falla o devuelve JSON roto no impide init/reload', () async {
    final repo = VigorRepo();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'), (call) async {
      if (call.method == 'getData') return '{no json';
      return null;
    });
    await repo.reload();
    expect(repo.loaded, isTrue); expect(repo.days, isEmpty);
  });

  test('maskMac muestra solo los ultimos 2 bytes', () {
    expect(maskMac('AA:BB:CC:DD:EE:FF'), endsWith('EE:FF'));
    expect(maskMac('AA:BB:CC:DD:EE:FF'), isNot(contains('AA:BB')));
    expect(maskMac(null), '');
  });

  test('reload es idempotente (no duplica al recargar)', () async {
    final data = {'origin5': [{'mTime': _t(2026, 3, 5, 10, 0), 'stepValue': 10}]};
    final r = await _load(data); await r.reload();
    expect(r.days['2026-03-05']!.steps, 10);
  });
}
