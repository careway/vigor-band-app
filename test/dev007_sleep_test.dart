import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'package:vigor_app/data/repo.dart';
import 'dev007_test.dart' show Env;

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  test('muestra de sueño: el repositorio saca down/up/total y la sincronización escribe 00:25-07:00', () async {
    final sample = File('test/fixtures_sleep_real.json').readAsStringSync();
    bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'getData' ? (c.arguments['kind'] == 'sleep' ? sample : '[]') : null);
    final repo = VigorRepo(); await repo.reload();
    expect(repo.nights.length, 1);
    final n = repo.nights.first;
    expect(n.total, 395); expect(n.down, DateTime(2026, 11, 20, 0, 25)); expect(n.up, DateTime(2026, 11, 20, 7, 0));
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = HealthSource(const {}, repo.nights, const [], const {});
    await e.h.run();
    final w = e.g.items.where((i) => i.type == HType.sleep).toList();
    expect(w.length, 1); expect(w.first.start, DateTime(2026, 11, 20, 0, 25)); expect(w.first.end, DateTime(2026, 11, 20, 7, 0));
    expect(e.h.catStatus(HealthCat.sleep), contains('00:25–07:00'));
  });

  test('noche sin hora de fin (en curso) o inválida: no se envía y el estado lo explica', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = HealthSource(const {}, [Night('2026-11-20', 100, 10, 80, 0, DateTime(2026, 11, 20, 1), null)], const [], const {});
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.sleep), isEmpty);
    expect(e.h.catStatus(HealthCat.sleep), contains('ninguna con hora'));
    e.src = HealthSource(const {}, const [], const [], const {}); await e.h.run();
    expect(e.h.catStatus(HealthCat.sleep), contains('No hay noches'));
  });

  test('sin permiso de sueño: estado «Sin permiso» y no escribe; con fallo de escritura muestra la causa y el reintento reenvía', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.g.granted.remove(HType.sleep); await e.h.run();
    expect(e.h.catStatus(HealthCat.sleep), contains('Sin permiso')); expect(e.g.items.where((i) => i.type == HType.sleep), isEmpty);
    e.g.granted.add(HType.sleep); e.g.failWrites = true; await e.h.run();
    expect(e.h.catStatus(HealthCat.sleep), contains('Error al escribir: PlatformException: simulado'));
    e.g.failWrites = false; await e.h.retryCat(HealthCat.sleep);
    expect(e.g.items.where((i) => i.type == HType.sleep).length, 1); expect(e.h.catStatus(HealthCat.sleep), contains('Última noche enviada'));
    await e.h.retryCat(HealthCat.sleep); // reenvío explícito: mismo clientRecordId (HC actualiza, no duplica)
    expect(e.g.items.where((i) => i.type == HType.sleep).map((i) => i.id).toSet().length, 1);
  });

  test('un fallo en pasos o en sesiones no impide enviar el sueño', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.g.failTypes.addAll({HType.steps, HType.workout});
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.steps), isEmpty);
    expect(e.g.items.where((i) => i.type == HType.sleep).length, 1);
    expect(e.h.catStatus(HealthCat.activity), contains('Error al escribir'));
  });
}
