// C2: estados limite de reload(). Datos sinteticos.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';

const _mc = MethodChannel('vigor/methods');
Map<String, Object?> _data = {};

Map _t(int y, int mo, int d, int h, int mi) => {'year': y, 'month': mo, 'day': d, 'hour': h, 'minute': mi};

Future<VigorRepo> _load(Map<String, Object?> data) async {
  _data = data;
  final r = VigorRepo();
  await r.reload();
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() { _data = {}; bm.setMockMethodCallHandler(_mc, (c) async {
    if (c.method != 'getData') return null;
    final v = _data[(c.arguments as Map)['kind']];
    return v is String ? v : jsonEncode(v ?? []);
  }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  const kinds = ['origin5', 'spo2', 'hrv', 'sleep', 'sports', 'sportItems', 'live'];
  for (final k in kinds) {
    test('JSON corrupto en $k: no lanza, carga el resto', () async {
      final r = await _load({
        'origin5': [{'mTime': _t(2026, 3, 5, 8, 0), 'stepValue': 10}],
        'sleep': [{'Date': '2026-03-05', 'allSleepTime': 400}],
        k: '{{no es json',
      });
      expect(r.loaded, true);
      if (k != 'origin5') expect(r.days['2026-03-05']?.steps, 10);
      if (k != 'sleep') expect(r.nights.length, 1);
    });
    test('$k con tipo equivocado (objeto, cadena, numeros): se ignora', () async {
      for (final bad in [{'a': 1}, 'x', 5, [1, 'a', null, [2]]]) {
        final r = await _load({k: bad});
        expect(r.loaded, true);
        expect(r.sessions, isEmpty);
      }
    });
  }

  test('sin ningun dato: listas vacias y loaded', () async {
    final r = await _load({});
    expect(r.loaded, true); expect(r.days, isEmpty); expect(r.nights, isEmpty); expect(r.sessions, isEmpty); expect(r.liveSteps, 0);
  });

  test('registros con campos nulos, de tipo erroneo o sin hora no rompen y se descartan', () async {
    final r = await _load({
      'origin5': [{}, {'mTime': null}, {'mTime': 'x'}, {'mTime': _t(2026, 3, 5, 8, 0), 'stepValue': 'abc', 'ppgs': 'no lista', 'bloodComponent': 5}],
      'spo2': [{'mTime': _t(2026, 3, 5, 8, 0), 'oxygenValue': null}],
      'hrv': [{'mTime': _t(2026, 3, 5, 8, 0), 'rrValue': 'zz'}],
    });
    expect(r.loaded, true);
    expect(r.days['2026-03-05']?.steps ?? 0, 0);
  });

  test('dia sin muestras validas (todo fuera de rango) no inventa lecturas', () async {
    final r = await _load({'origin5': [{'mTime': _t(2026, 3, 5, 8, 0), 'stepValue': 5, 'ppgs': [0, 255, 10, 300], 'temperature': 99, 'pressure': 500}]});
    final d = r.days['2026-03-05']!;
    expect(d.hr, isEmpty); expect(d.temp, isEmpty); expect(d.stress, isEmpty); expect(d.steps, 5);
  });

  test('noche sin sleepLine: se conserva sin fases; sleepLine no-cadena no rompe; total 0 se descarta', () async {
    final r = await _load({'sleep': [
      {'Date': '2026-03-05', 'allSleepTime': 420, 'deepSleepTime': 60, 'lowSleepTime': 300},
      {'Date': '2026-03-06', 'allSleepTime': 400, 'sleepLine': 12345},
      {'Date': '2026-03-07', 'allSleepTime': 0},
      {'allSleepTime': 300},
    ]});
    expect(r.nights.map((n) => n.date), containsAll(['2026-03-05', '2026-03-06']));
    expect(r.nights.any((n) => n.date == '2026-03-07'), false);
    for (final n in r.nights.where((n) => n.date.isNotEmpty)) { expect(n.stages == null || n.stages!.isEmpty, true); }
  });

  test('sesion sin GPS (arrays vacios o ceros): sin ruta, FC por minuto valida', () async {
    final r = await _load({
      'sports': [{'_key': 'a', 'startTime': _t(2026, 3, 5, 9, 0), 'sportTime': 1800, 'sportType': 1, 'distance': 3000}],
      'sportItems': [{'_key': 'a', 'items': [
        {'minute': 1, 'rate': 120, 'latArray': [0, 0], 'lngArray': [0, 0]},
        {'minute': 2, 'rate': 500},
        {'minute': 3, 'rate': 130, 'latArray': 'x'},
        'basura',
      ]}],
    });
    expect(r.sessions.length, 1);
    final s = r.sessions.first;
    expect(s.route, isEmpty); expect(s.fixes, isEmpty); expect(s.hrPerMinute, [120, 130]);
  });

  test('sesion sin items, sin hora o con duracion 0 se descarta/maneja sin lanzar', () async {
    final r = await _load({'sports': [
      {'_key': 'a', 'startTime': _t(2026, 3, 5, 9, 0), 'sportTime': 600},
      {'_key': 'b', 'sportTime': 600},
      {'_key': 'c', 'startTime': _t(2026, 3, 5, 9, 0), 'sportTime': 0},
      {'startTime': _t(2026, 3, 5, 9, 0), 'sportTime': 600},
    ]});
    expect(r.sessions.map((s) => s.key), ['a']);
  });

  test('fechas fuera de orden: dias con series ordenadas, noches y sesiones de mas reciente a mas antigua', () async {
    final r = await _load({
      'origin5': [
        {'mTime': _t(2026, 3, 7, 10, 0), 'stepValue': 1, 'ppgs': [90]},
        {'mTime': _t(2026, 3, 5, 12, 0), 'stepValue': 2, 'ppgs': [80]},
        {'mTime': _t(2026, 3, 5, 6, 0), 'stepValue': 3, 'ppgs': [70]},
      ],
      'sleep': [{'Date': '2026-03-05', 'allSleepTime': 100}, {'Date': '2026-03-09', 'allSleepTime': 100}, {'Date': '2026-03-07', 'allSleepTime': 100}],
      'sports': [
        {'_key': 'x', 'startTime': _t(2026, 3, 5, 9, 0), 'sportTime': 60},
        {'_key': 'y', 'startTime': _t(2026, 3, 8, 9, 0), 'sportTime': 60},
        {'_key': 'z', 'startTime': _t(2026, 3, 6, 9, 0), 'sportTime': 60},
      ],
    });
    final d5 = r.days['2026-03-05']!;
    expect(d5.steps, 5);
    expect(d5.hr.map((s) => s.v), [70, 80]);
    expect(r.nights.map((n) => n.date), ['2026-03-09', '2026-03-07', '2026-03-05']);
    expect(r.sessions.map((s) => s.key), ['y', 'z', 'x']);
  });

  test('ppgs que cruzan medianoche van al dia siguiente', () async {
    final r = await _load({'origin5': [{'mTime': _t(2026, 3, 5, 23, 59), 'ppgs': [60, 61, 62]}]});
    expect(r.days['2026-03-05']!.hr.length, 1);
    expect(r.days['2026-03-06']!.hr.length, 2);
  });

  test('recargar dos veces no duplica datos', () async {
    _data = {'origin5': [{'mTime': _t(2026, 3, 5, 8, 0), 'stepValue': 7}]};
    final r = VigorRepo(); await r.reload(); await r.reload();
    expect(r.days['2026-03-05']!.steps, 7);
  });

  test('liveSteps: lectura de otro dia se ignora; de hoy cuenta', () async {
    var r = await _load({'live': [{'at': DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch, 'step': 500}]});
    expect(r.liveSteps, 0);
    r = await _load({'live': [{'at': DateTime.now().millisecondsSinceEpoch, 'step': 500}]});
    expect(r.liveSteps, 500);
  });
}
