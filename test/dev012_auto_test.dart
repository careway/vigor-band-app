// DEV_012: sincronización automática con la app abierta (lógica pura con reloj simulado) y exportación sin interfaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/background_export.dart';
import 'package:vigor_app/data/auto_sync.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'package:vigor_app/data/repo.dart';

class _Gw implements HealthGateway {
  int writes = 0;
  @override String get platformName => 'Health Connect'; @override bool get isIos => false;
  @override Future<HealthAvail> availability() async => HealthAvail.ready; @override bool supports(HType t) => true;
  @override Future<bool> hasPermissions(Set<HType> t) async => true; @override Future<bool> requestPermissions(Set<HType> t) async => true;
  @override Future<bool> write(HealthItem it) async { writes++; return true; }
  @override Future<BatchOut> writeBatch(List<HealthItem> items) async { writes += items.length; return BatchOut(items.length); }
  @override String? get lastError => null;
  @override Future<String?> writeWorkout(WorkoutOut w) async => 'id'; @override Future<bool> writeRoute(String id, List<RoutePoint> p) async => true;
  @override Future<bool> deleteRange(HType t, DateTime a, DateTime b) async => true; @override Future<bool> deleteWorkout(String id) async => true;
  @override Future<bool> deleteByClientId(HType t, String id, DateTime a, DateTime b) async => true;
  @override Future<void> openSettings() async {} @override Future<void> installProvider() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now; late String conn; late bool mac, busy; DateTime? last; late int connects, syncs;
  late AutoSync a;
  setUp(() {
    now = DateTime(2030, 1, 1, 12); conn = 'connected'; mac = true; busy = false; last = null; connects = 0; syncs = 0;
    a = AutoSync(clock: () => now, connState: () => conn, hasMac: () => mac, lastSync: () => last, busy: () => busy,
        connect: () async { connects++; }, sync: () async { syncs++; });
    a.foreground = true;
  });

  test('intervalos y espera creciente con tope de 10 min', () {
    expect([for (var i = 1; i <= 8; i++) reconnectDelay(i).inSeconds], [15, 30, 60, 120, 300, 600, 600, 600]);
    expect(safeAutoMin(15), 15); expect(safeAutoMin(7), 30); expect(safeAutoMin(null), 30);
  });
  test('texto «Sincronizado hace X»', () {
    final n = DateTime(2030, 1, 1, 12);
    expect(syncAgoText(null, n), 'Aún sin sincronizar');
    expect(syncAgoText(n.subtract(const Duration(seconds: 20)), n), 'Sincronizado ahora mismo');
    expect(syncAgoText(n.subtract(const Duration(minutes: 7)), n), 'Sincronizado hace 7 min');
    expect(syncAgoText(n.subtract(const Duration(hours: 3)), n), 'Sincronizado hace 3 h');
    expect(syncAgoText(n.subtract(const Duration(days: 1, hours: 2)), n), 'Sincronizado hace 1 día');
  });
  test('sincroniza si nunca sincronizó o si toca por intervalo; no antes', () async {
    await a.evaluate(); expect(syncs, 1);
    last = now; now = now.add(const Duration(minutes: 10)); a.intervalMin = 30; await a.evaluate(); expect(syncs, 1);
    now = now.add(const Duration(minutes: 25)); await a.evaluate(); expect(syncs, 2);
  });
  test('no reintenta una sincronización fallida en menos de 2 min (sin bucles)', () async {
    await a.evaluate(); now = now.add(const Duration(seconds: 30)); await a.evaluate(); expect(syncs, 1);
    now = now.add(const Duration(minutes: 3)); await a.evaluate(); expect(syncs, 2);
  });
  test('al reanudar sincroniza si la última tiene más de 5 min, aunque el intervalo sea mayor', () async {
    last = now.subtract(const Duration(minutes: 8)); a.foreground = false; a.onResume(); await Future<void>.delayed(Duration.zero); expect(syncs, 1);
    a.dispose();
  });
  test('al reanudar no sincroniza si es reciente', () async {
    last = now.subtract(const Duration(minutes: 2)); a.onResume(); await Future<void>.delayed(Duration.zero); expect(syncs, 0); a.dispose();
  });
  test('no solapa: sincronización en curso, pulso en vivo, deporte o borrado (busy)', () async {
    busy = true; await a.evaluate(); expect(syncs, 0); expect(connects, 0);
    busy = false; await a.evaluate(); expect(syncs, 1);
  });
  test('desactivada, en segundo plano, sin MAC o desconectada a propósito: no hace nada', () async {
    a.enabled = false; await a.evaluate(); a.enabled = true;
    a.foreground = false; await a.evaluate(); a.foreground = true;
    mac = false; await a.evaluate(); mac = true;
    a.userHold = true; conn = 'disconnected'; await a.evaluate();
    expect(syncs + connects, 0);
  });
  test('reconecta con espera creciente y sin bucles rápidos', () async {
    conn = 'disconnected';
    await a.evaluate(); expect(connects, 1);
    now = now.add(const Duration(seconds: 10)); await a.evaluate(); expect(connects, 1); // aún dentro de 15 s
    now = now.add(const Duration(seconds: 6)); await a.evaluate(); expect(connects, 2);
    now = now.add(const Duration(seconds: 29)); await a.evaluate(); expect(connects, 2); // espera 30 s
    now = now.add(const Duration(seconds: 2)); await a.evaluate(); expect(connects, 3);
    for (var i = 0; i < 10; i++) { now = now.add(const Duration(minutes: 11)); await a.evaluate(); }
    expect(connects, 13); // tope: 1 intento cada 10 min
    conn = 'connected'; await a.evaluate(); expect(a.failures, 0); // éxito: se reinicia
  });
  test('conectando o buscando: no interfiere', () async { conn = 'connecting'; await a.evaluate(); conn = 'scanning'; await a.evaluate(); expect(connects + syncs, 0); });

  group('exportación sin interfaz (fase 3)', () {
    Future<String> run(Map prefs, _Gw gw, {bool sleepData = false}) async {
      var cleared = 0; String? saved;
      final h = HealthSync(gateway: gw, savePref: (k, v) async {}, loadLedger: () async => saved, saveLedger: (j) async { saved = j; return true; });
      final day = Day('2030-01-01'); final t = DateTime.now().subtract(const Duration(hours: 2)); day.hr.add(Sample(t, 70));
      h.source = () => HealthSource({'2030-01-01': day}, const [], const [], const {});
      final code = await runHeadlessExport(prefs: prefs, health: h, reload: () async {}, clearDirty: () async { cleared++; });
      return '$code:$cleared';
    }
    test('interruptor general apagado: no escribe nada', () async { final g = _Gw(); expect(await run({'hcOn': 0}, g), 'OFF:0'); expect(g.writes, 0); });
    test('activado: escribe lo pendiente y limpia la marca', () async { final g = _Gw(); expect(await run({'hcOn': 1}, g), 'OK:1'); expect(g.writes, greaterThan(0)); });
  });
}
