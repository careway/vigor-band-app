import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';

/// Al abrir la app o volver a ella se pregunta (a la parte nativa) si hay una actividad en marcha.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('vigor/methods');
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  setUp(() { calls.clear(); bm.setMockMethodCallHandler(ch, (c) async { calls.add(c.method); return null; }); });
  tearDown(() => bm.setMockMethodCallHandler(ch, null));

  test('checkActivity invoca checkActivity en la parte nativa y no falla si el canal no responde', () async {
    final r = VigorRepo();
    await r.checkActivity();
    expect(calls, contains('checkActivity'));
    r.dispose();
  });
}
