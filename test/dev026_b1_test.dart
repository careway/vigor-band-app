import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/ui/widgets.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Set<String> failing; late List<String> calls;
  setUp(() {
    failing = {}; calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_mc, (c) async {
      calls.add(c.method);
      if (failing.contains(c.method)) throw PlatformException(code: 'E');
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_mc, null));

  testWidgets('StatusLine: vacio, syncError con info y notice', (t) async {
    Future<void> show(String? e, String? n) => t.pumpWidget(MaterialApp(home: Scaffold(body: StatusLine(syncError: e, notice: n))));
    await show(null, null);
    expect(find.byType(Text), findsNothing);
    await show('No se pudo sincronizar. Reintentando.', 'otro');
    expect(find.text('No se pudo sincronizar. Reintentando.'), findsOneWidget);
    expect(find.text('otro'), findsNothing);
    expect(find.byType(InfoButton), findsOneWidget);
    await show(null, 'No se pudo guardar.');
    expect(find.text('No se pudo guardar.'), findsOneWidget);
  });

  test('setters no cambian memoria si falla el guardado', () async {
    failing = {'setPref'}; final r = VigorRepo();
    await r.setThemeMode(1); expect(r.themeMode, 0);
    await r.setMapOn(false); expect(r.mapOn, true);
    await r.setLiveOn(false); expect(r.liveOn, true);
    await r.setLiveSec(30); expect(r.liveSec, 10);
    await r.setExperimental(true); expect(r.showExperimental, false);
    expect(r.notice, isNotNull);
    failing = {}; await r.setThemeMode(1); expect(r.themeMode, 1);
    r.dispose();
  });

  test('setAutoSync que falla no cambia auto.enabled', () async {
    failing = {'setAutoSync'}; final r = VigorRepo();
    await r.setAutoSync(enabled: false);
    expect(r.auto.enabled, true); expect(r.notice, isNotNull);
    r.dispose();
  });

  test('setAutoMeasure sin respuesta -> no respondio; con respuesta no', () async {
    final r = VigorRepo(); r.autoMeasureTimeout = const Duration(milliseconds: 20);
    await r.setAutoMeasure(1, true, interval: 10);
    expect(r.autoMsg, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(r.autoMsg, 'La pulsera no respondió.');
    await r.setAutoMeasure(1, true);
    r.debugHandle({'type': 'autoMeasureResult', 'ok': true});
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(r.autoMsg, 'Ajuste enviado a la pulsera.');
    r.dispose();
  });

  test('setAutoMeasure que falla pone notice', () async {
    failing = {'setAutoMeasure'}; final r = VigorRepo();
    await r.setAutoMeasure(1, true); expect(r.notice, isNotNull);
    r.dispose();
  });

  test('reconexion relee cadencia una vez; primer connected no', () async {
    final r = VigorRepo();
    r.debugHandle({'type': 'state', 'value': 'connected'}); await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c == 'readAutoMeasure'), isEmpty);
    r.debugHandle({'type': 'state', 'value': 'disconnected'});
    r.debugHandle({'type': 'state', 'value': 'connected'}); await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c == 'readAutoMeasure').length, 1);
    r.dispose();
  });
}
