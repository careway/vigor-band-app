import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Set<String> failing;
  setUp(() {
    failing = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_mc, (c) async {
      if (failing.contains(c.method)) throw PlatformException(code: 'E', message: 'x');
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_mc, null));
  VigorRepo repo() { final r = VigorRepo(); r.conn = 'connected'; return r; }

  test('sync que falla pone notice y no lanza', () async {
    failing = {'sync'}; final r = repo();
    await r.sync(); expect(r.notice, 'No se pudo sincronizar.');
    r.clearNotice(); expect(r.notice, isNull);
  });
  test('notice se limpia sola', () async {
    failing = {'findBand'}; final r = repo(); r.noticeTtl = const Duration(milliseconds: 20);
    await r.findBand(); expect(r.notice, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 60)); expect(r.notice, isNull);
  });
  test('startSport que falla revierte y no sincroniza', () async {
    failing = {'startSport'}; final r = repo(); r.postWorkoutSyncDelays = const [0];
    await r.startSport('OUTDOOR_WALK');
    expect(r.sportActive, false); expect(r.workout.active, false); expect(r.notice, isNotNull);
  });
  test('stopSport, connect, disconnect, readAutoMeasure no lanzan', () async {
    failing = {'stopSport', 'connect', 'disconnect', 'readAutoMeasure', 'stopScan', 'setPref'}; final r = repo();
    await r.stopSport(); await r.connect('AA'); await r.disconnect(); await r.readAutoMeasure();
    expect(r.notice, isNotNull);
    await r.setPref('goal', 5000); expect(r.stepGoal, isNot(5000));
  });
  test('sync end ok:false y exito', () async {
    final r = repo();
    r.debugHandle({'type': 'sync', 'value': 'start'}); r.debugHandle({'type': 'sync', 'value': 'end', 'ok': false});
    expect(r.lastSyncOk, false); expect(r.syncError, isNotNull);
    r.debugHandle({'type': 'sync', 'value': 'start'}); r.debugHandle({'type': 'sync', 'value': 'end', 'ok': true});
    expect(r.lastSyncOk, true); expect(r.syncError, isNull);
  });
  test('conexion caida a mitad de sync', () async {
    final r = repo(); r.debugHandle({'type': 'sync', 'value': 'start'});
    r.debugHandle({'type': 'state', 'value': 'disconnected'});
    expect(r.syncing, false); expect(r.lastSyncOk, false); expect(r.syncError, isNotNull);
  });
  test('watchdog de syncing', () async {
    final r = repo(); r.syncWatchdog = const Duration(milliseconds: 30);
    r.debugHandle({'type': 'sync', 'value': 'start'}); expect(r.syncing, true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(r.syncing, false); expect(r.syncError, isNotNull);
  });
}
