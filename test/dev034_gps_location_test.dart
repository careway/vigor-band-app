// Iniciar una actividad pide antes la ubicación (ayuda de GPS de la pulsera) y, si se deniega, la actividad se inicia igualmente.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  Future<List<MethodCall>> run(bool granted) async {
    final calls = <MethodCall>[];
    bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return c.method == 'requestPermissions' ? granted : null; });
    final r = VigorRepo();
    await r.startSport('WALK');
    return calls;
  }

  test('pide la ubicación antes de iniciar la actividad', () async {
    final calls = await run(true);
    final i = calls.indexWhere((c) => c.method == 'requestPermissions' && (c.arguments as Map)['location'] == true);
    final j = calls.indexWhere((c) => c.method == 'startSport');
    expect(i, greaterThanOrEqualTo(0));
    expect(j, greaterThan(i));
  });

  test('si se deniega la ubicación, la actividad se inicia igualmente', () async {
    final calls = await run(false);
    expect(calls.any((c) => c.method == 'startSport'), isTrue);
  });
}
