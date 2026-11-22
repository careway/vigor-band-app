// A8-A10: run() concurrente, wipe con run en vuelo, deleteFromHealth durante run. Datos sinteticos.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'dev007_test.dart' show FakeGateway, source, now;

class BlockingGateway extends FakeGateway {
  Completer<void>? gate; int writes = 0;
  @override Future<BatchOut> writeBatch(List<HealthItem> its) async { if (gate != null) await gate!.future; writes++; return super.writeBatch(its); }
  @override Future<bool> write(HealthItem it) async { if (gate != null) await gate!.future; writes++; return super.write(it); }
}

HealthSync mk(BlockingGateway g, List<String?> ledger) {
  final h = HealthSync(gateway: g, savePref: (k, v) async {}, loadLedger: () async => ledger[0], saveLedger: (j) async { ledger[0] = j; return true; }, clock: () => now, batch: 2);
  h.source = () => source();
  return h;
}

void main() {
  test('R1: run() devuelve false si ya hay otro en vuelo y true al terminar bien', () async {
    final g = BlockingGateway(); g.gate = Completer(); final l = <String?>[null]; final h = mk(g, l);
    await h.init({}); await h.setMaster(true);
    final a = h.run(); await Future<void>.delayed(Duration.zero); await Future<void>.delayed(Duration.zero);
    expect(h.running, true);
    expect(await h.run(), false);
    g.gate!.complete(); g.gate = null;
    expect(await a, true);
  });

  test('R1: sin Health Connect disponible run() devuelve false', () async {
    final g = BlockingGateway(); g.av = HealthAvail.notInstalled; final h = mk(g, <String?>[null]);
    await h.init({}); await h.setMaster(true);
    expect(await h.run(), false);
  });

  test('R1: run() con error de escritura devuelve false', () async {
    final g = BlockingGateway(); final h = mk(g, <String?>[null]);
    await h.init({}); await h.setMaster(true); g.failWrites = true;
    expect(await h.run(), false);
  });

  test('R2: afterWipe cancela y espera un run en vuelo; el libro queda vacio', () async {
    final g = BlockingGateway(); final l = <String?>[null]; final h = mk(g, l);
    await h.init({}); await h.setMaster(true);
    g.gate = Completer();
    final a = h.run(); await Future<void>.delayed(Duration.zero); await Future<void>.delayed(Duration.zero);
    expect(h.running, true);
    final w = h.afterWipe();
    g.gate!.complete(); g.gate = null;
    await w; await a;
    expect(h.running, false); expect(h.totalSent, 0); expect(h.last, isNull);
  });

  test('R3: deleteFromHealth espera al run en vuelo', () async {
    final g = BlockingGateway(); final h = mk(g, <String?>[null]);
    await h.init({}); await h.setMaster(true);
    await h.run(); // envia la noche
    g.gate = Completer();
    h.source = () => source();
    final a = h.run(); await Future<void>.delayed(Duration.zero); await Future<void>.delayed(Duration.zero);
    final d = h.deleteFromHealth(nights: source().nights);
    g.gate!.complete(); g.gate = null;
    await a; await d;
    expect(h.running, false);
  });
}
