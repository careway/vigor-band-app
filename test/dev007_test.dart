import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart' show HealthWorkoutActivityType;
import 'package:vigor_app/data/health_gateway.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'package:vigor_app/data/repo.dart';

class FakeGateway implements HealthGateway {
  bool ios; HealthAvail av = HealthAvail.ready; bool permit = true; bool failWrites = false; final failTypes = <HType>{};
  final granted = <HType>{}; final items = <HealthItem>[]; final workouts = <WorkoutOut>[]; final routes = <String, int>{}; final deleted = <HType>[]; final deletedW = <String>[];
  void Function(HealthItem)? onWrite; int requests = 0;
  FakeGateway({this.ios = false});
  @override String get platformName => ios ? 'Apple Salud' : 'Health Connect';
  @override bool get isIos => ios;
  @override Future<HealthAvail> availability() async => av;
  @override bool supports(HType t) => !(ios && (t == HType.hrvRmssd || t == HType.restingHr));
  @override Future<bool> hasPermissions(Set<HType> types) async => types.isNotEmpty && granted.containsAll(types);
  @override Future<bool> requestPermissions(Set<HType> types) async { requests++; if (permit) granted.addAll(types); return permit; }
  @override String? get lastError => failWrites ? 'PlatformException: simulado' : null;
  @override Future<bool> write(HealthItem it) async { if (failWrites || failTypes.contains(it.type)) return false; items.add(it); onWrite?.call(it); return true; }
  @override Future<String?> writeWorkout(WorkoutOut w) async { if (failWrites) return null; workouts.add(w); return 'w-${w.key}'; }
  @override Future<bool> writeRoute(String id, List<RoutePoint> pts) async { routes[id] = pts.length; return true; }
  @override Future<bool> deleteRange(HType t, DateTime a, DateTime b) async { deleted.add(t); return true; }
  final deletedIds = <String>[]; bool failDelete = false;
  @override Future<bool> deleteByClientId(HType t, String id, DateTime a, DateTime b) async { if (failDelete) return false; deletedIds.add(id); return true; }
  @override Future<bool> deleteWorkout(String id) async { deletedW.add(id); return true; }
  @override Future<void> openSettings() async {}
  @override Future<void> installProvider() async {}
}

final now = DateTime(2026, 11, 20, 12, 0);

HealthSource source({int n = 3}) {
  final d = Day('2026-11-20');
  for (var i = 0; i < n; i++) {
    final t = DateTime(2026, 11, 20, 8, i * 5);
    d.steps5.add(Sample(t, 100.0 + i)); d.km5.add(Sample(t, 0.08)); d.kcal5.add(Sample(t, 4));
    d.hr.add(Sample(t, 70.0 + i)); d.hrv.add(Sample(t, 40)); d.spo2.add(Sample(t, 97)); d.temp.add(Sample(t, 36.4));
    d.glucose.add(Sample(t, 5)); d.stress.add(Sample(t, 30)); d.met.add(Sample(t, 2)); d.skin.add(Sample(t, 33));
  }
  final night = Night('2026-11-20', 420, 90, 300, 2, DateTime(2026, 11, 19, 23, 30), DateTime(2026, 11, 20, 6, 30));
  final s = Session(key: 'k1', start: DateTime(2026, 11, 19, 18), sportType: 1, seconds: 3600, meters: 8000, kcal: 500, steps: 9000, avgHr: 140, paceSecKm: 400, hasGps: true,
      route: [(1.0, 2.0), (1.1, 2.1), (double.nan, double.nan), (1.2, 2.2)], hrPerMinute: const []);
  return HealthSource({d.date: d}, [night], [s], {'2026-11-20': 52.0});
}

class Env {
  final FakeGateway g; late final HealthSync h; final prefs = <String, int>{}; String? ledger; HealthSource src = source();
  Env({bool ios = false}) : g = FakeGateway(ios: ios) {
    h = HealthSync(gateway: g, savePref: (k, v) async => prefs[k] = v, loadLedger: () async => ledger, saveLedger: (j) async { ledger = j; return true; }, clock: () => now, batch: 2);
    h.source = () => src;
  }
}

void main() {
  test('apagado de serie: no envía nada ni pide permisos', () async {
    final e = Env(); await e.h.init({}); await e.h.run();
    expect(e.h.master, false); expect(e.g.items, isEmpty); expect(e.g.requests, 0); expect(e.h.state, HealthState.off);
  });

  test('activar pide permisos y envía; segunda ejecución no duplica (idempotente)', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    expect(e.prefs['hcOn'], 1); expect(e.h.master, true);
    await e.h.run();
    final first = e.g.items.length; expect(first, greaterThan(0));
    final ids = e.g.items.map((i) => '${i.type}-${i.id}').toList(); expect(ids.toSet().length, ids.length);
    expect(e.g.workouts.length, 1);
    await e.h.run();
    expect(e.g.items.length, first); expect(e.g.workouts.length, 1);
    expect(e.h.last, now); expect(jsonDecode(e.ledger!)['v'], kHealthLedgerVersion);
  });

  test('datos nuevos posteriores a la marca se envían, los viejos no', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    final before = e.g.items.length;
    final d = e.src.days['2026-11-20']!; d.steps5.add(Sample(DateTime(2026, 11, 20, 9), 55));
    await e.h.run();
    expect(e.g.items.length, before + 1); expect(e.g.items.last.type, HType.steps);
  });

  test('nunca se exportan glucosa, estrés, MET ni piel; temperatura desactivada de serie; ruta también', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.bodyTemp), isEmpty);
    expect(e.g.routes, isEmpty);
    const allowed = {HType.steps, HType.distance, HType.activeEnergy, HType.heartRate, HType.hrvRmssd, HType.restingHr, HType.spo2, HType.bodyTemp, HType.sleep};
    expect(e.g.items.every((i) => allowed.contains(i.type)), true);
    expect(e.g.items.where((i) => i.type == HType.distance).first.value, closeTo(80, 1e-9)); // 0,08 km -> 80 m
  });

  test('temperatura y ruta solo con su interruptor; la ruta quita los cortes y usa la hora de la sesión', () async {
    final e = Env(); await e.h.init({'hc_temperatura': 1, 'hc_ruta': 1, 'hcOn': 1}); await e.h.setMaster(true); await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.bodyTemp), isNotEmpty);
    expect(e.g.routes['w-k1'], 3);
    await e.h.run(); expect(e.g.routes.length, 1);
  });

  test('desactivar una categoría detiene los envíos de inmediato (a mitad de ejecución)', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.g.onWrite = (it) { if (it.type == HType.steps && e.g.items.where((i) => i.type == HType.steps).length == 1) { e.h.cats[HealthCat.activity] = false; } };
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.steps).length, 1);
    expect(e.g.items.where((i) => i.type == HType.distance), isEmpty);
    expect(e.g.items.where((i) => i.type == HType.heartRate), isNotEmpty); // otras categorías siguen
  });

  test('permiso denegado: queda apagado y no escribe', () async {
    final e = Env(); e.g.permit = false; await e.h.init({}); await e.h.setMaster(true);
    expect(e.h.master, false); expect(e.prefs['hcOn'], 0); expect(e.g.items, isEmpty);
  });

  test('permiso revocado después: estado needsPermission y sin escrituras', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    final n = e.g.items.length; e.g.granted.clear(); e.src.days['2026-11-20']!.steps5.add(Sample(DateTime(2026, 11, 20, 10), 9));
    await e.h.run();
    expect(e.g.items.length, n); expect(e.h.state, HealthState.needsPermission);
  });

  test('Health Connect no instalado: aviso y sin envíos', () async {
    final e = Env(); e.g.av = HealthAvail.notInstalled; await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    expect(e.g.items, isEmpty); expect(e.h.state, HealthState.unavailable); expect(e.h.message, contains('Health Connect'));
  });

  test('fallo de escritura: no avanza la marca y se reintenta sin duplicar', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); e.g.failWrites = true; await e.h.run();
    expect(e.h.state, HealthState.error); expect(e.g.items, isEmpty);
    e.g.failWrites = false; await e.h.run();
    expect(e.g.items, isNotEmpty); final n = e.g.items.length; await e.h.run(); expect(e.g.items.length, n);
  });

  test('iPhone (falso): RMSSD y pulso en reposo no se envían; el resto sí', () async {
    final e = Env(ios: true); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.hrvRmssd || i.type == HType.restingHr), isEmpty);
    expect(e.g.items.where((i) => i.type == HType.heartRate), isNotEmpty);
  });

  test('libro de otra versión se ignora; libro válido se respeta entre arranques', () async {
    final e = Env(); e.g.granted.addAll(HType.values); e.ledger = jsonEncode({'v': 99, 'wm': {'steps': 9999999999999}}); await e.h.init({'hcOn': 1}); await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.steps), isNotEmpty);
    final saved = e.ledger; final e2 = Env(); e2.g.granted.addAll(HType.values); e2.ledger = saved; await e2.h.init({'hcOn': 1}); await e2.h.run();
    expect(e2.g.items.where((i) => i.type == HType.steps), isEmpty); expect(e2.g.workouts, isEmpty);
  });

  test('dejar de compartir apaga y guarda la preferencia; borrar lo enviado pide borrar y reinicia el libro', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    final ok = await e.h.deleteSent();
    expect(ok, true); expect(e.g.deleted, contains(HType.steps)); expect(e.g.deletedW, ['w-k1']); expect(e.h.last, isNull);
    await e.h.stopSharing(); expect(e.h.master, false); expect(e.prefs['hcOn'], 0); expect(e.h.state, HealthState.off);
    final n = e.g.items.length; await e.h.run(); expect(e.g.items.length, n);
  });

  test('routePointsOf y tipos de deporte', () {
    final s = DateTime(2026, 1, 1, 10);
    final p = routePointsOf([(1, 2), (double.nan, double.nan), (3, 4)], s, s.add(const Duration(minutes: 10)));
    expect(p.length, 2); expect(p.first.t, s); expect(p.last.t, s.add(const Duration(minutes: 10)));
    expect(routePointsOf([(1, 2)], s, s), isEmpty);
    expect(workoutTypeFor(1, ios: false), HealthWorkoutActivityType.RUNNING);
    expect(workoutTypeFor(3, ios: false), HealthWorkoutActivityType.RUNNING_TREADMILL);
    expect(workoutTypeFor(3, ios: true), HealthWorkoutActivityType.RUNNING);
    expect(workoutTypeFor(165, ios: false), HealthWorkoutActivityType.OTHER);
    expect(workoutTypeFor(99999, ios: true), HealthWorkoutActivityType.OTHER);
  });
}
