// DEV-029: wipeData y _exportThenClear a nivel de VigorRepo con pasarela falsa. Datos sinteticos.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'package:vigor_app/data/repo.dart';
import 'dev007_test.dart' show FakeGateway, source;

class Gate extends FakeGateway {
  Completer<void>? gate; int writes = 0;
  @override Future<BatchOut> writeBatch(List<HealthItem> its) async { if (gate != null) await gate!.future; writes++; return super.writeBatch(its); }
  @override Future<bool> write(HealthItem it) async { if (gate != null) await gate!.future; writes++; return super.write(it); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('vigor/methods');
  late List<String> calls; late String? ledger; late Gate g; late VigorRepo r;

  setUp(() async {
    calls = []; ledger = null; g = Gate();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
      calls.add(c.method);
      switch (c.method) {
        case 'healthLoad': return ledger;
        case 'healthSave': ledger = (c.arguments as Map)['json'] as String; return true;
        case 'agpsStatus': return <dynamic, dynamic>{};
        default: return null;
      }
    });
    r = VigorRepo(healthGateway: g);
    r.health.source = () => source();
    await r.health.init({}); await r.health.setMaster(true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
    r.dispose();
  });

  Future<void> tick() async { for (var i = 0; i < 5; i++) { await Future<void>.delayed(Duration.zero); } }

  test('wipeData espera a un run() en vuelo y no vuelve a guardar datos', () async {
    g.gate = Completer();
    final run = r.health.run(); await tick();
    expect(r.health.running, true);
    final w = r.wipeData(); await tick();
    expect(calls.contains('wipeData'), false, reason: 'no borra hasta que el envio en vuelo termine');
    g.gate!.complete(); g.gate = null;
    expect(await w, true); await run;
    expect(r.health.running, false);
    expect(calls.indexOf('wipeData'), greaterThanOrEqualTo(0));
    expect(r.health.totalSent, 0); expect(r.health.last, isNull);
    expect(r.privacyBusy, false);
  });

  test('fin de sync ok:true con master exporta y limpia dirty si run() da true', () async {
    r.debugHandle({'type': 'sync', 'value': 'end', 'ok': true}); await tick(); await tick();
    expect(g.writes, greaterThan(0));
    expect(calls.contains('clearExportDirty'), true);
  });

  test('_exportThenClear no limpia dirty si run() devuelve false', () async {
    g.failWrites = true;
    r.debugHandle({'type': 'sync', 'value': 'end', 'ok': true}); await tick(); await tick();
    expect(calls.contains('clearExportDirty'), false);
  });

  test('fin de sync sin ok:true no exporta ni limpia dirty', () async {
    for (final m in [{'type': 'sync', 'value': 'end'}, {'type': 'sync', 'value': 'end', 'ok': false}]) {
      r.debugHandle(m); await tick(); await tick();
    }
    expect(g.writes, 0); expect(g.batchCalls, 0);
    expect(calls.contains('clearExportDirty'), false);
  });

  test('con privacyBusy no exporta', () async {
    r.privacyBusy = true;
    r.debugHandle({'type': 'sync', 'value': 'end', 'ok': true}); await tick(); await tick();
    expect(g.writes, 0); expect(calls.contains('clearExportDirty'), false);
  });
}
