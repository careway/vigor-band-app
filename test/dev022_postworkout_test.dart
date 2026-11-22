import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); return null; });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_mc, null));

  VigorRepo repo() { final r = VigorRepo(); r.postWorkoutSyncDelays = const [0, 1]; r.conn = 'connected'; return r; }
  int syncs() => calls.where((c) => c == 'sync').length;

  test('al terminar una actividad desde la app se sincroniza solo, dos veces (reintento)', () async {
    final r = repo(); await r.startSport('OUTDOOR_WALK'); expect(syncs(), 0);
    await r.stopSport(); await Future<void>.delayed(const Duration(milliseconds: 100)); expect(syncs(), 1);
    await Future<void>.delayed(const Duration(milliseconds: 1200)); expect(syncs(), 2);
  });
  test('no sincroniza si la pulsera no esta conectada', () async {
    final r = repo(); r.conn = 'disconnected'; await r.startSport('OUTDOOR_WALK'); await r.stopSport();
    await Future<void>.delayed(const Duration(milliseconds: 1300)); expect(syncs(), 0);
  });
  test('si la termina la pulsera (informe de parada) tambien sincroniza', () async {
    final r = repo(); await r.startSport('OUTDOOR_WALK');
    r.workout.onReport({'runState': 'FINISHED', 'opCode': 'STOP'});
    await Future<void>.delayed(const Duration(milliseconds: 100)); expect(syncs(), 1);
    await Future<void>.delayed(const Duration(milliseconds: 1200)); // deja correr el reintento para que no se cuele en el test siguiente
  });
  test('empezar otra actividad antes del reintento no lo dispara', () async {
    final r = repo(); await r.startSport('OUTDOOR_WALK'); await r.stopSport(); await Future<void>.delayed(const Duration(milliseconds: 100));
    await r.startSport('OUTDOOR_RUNNING'); await Future<void>.delayed(const Duration(milliseconds: 1200)); expect(syncs(), 1);
  });
}
