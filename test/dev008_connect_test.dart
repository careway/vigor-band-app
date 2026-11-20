// El botón principal de Hoy sin datos: con pulsera guardada conecta; sin ella abre la búsqueda (antes no hacía nada).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  setUp(() {
    calls = [];
    bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); return c.method == 'requestPermissions' ? true : null; });
  });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  Future<void> mount(WidgetTester t, VigorRepo r) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: TodayPage(r))));
    await t.pump();
  }

  testWidgets('sin pulsera guardada: «Buscar pulsera» abre la hoja y lanza la búsqueda', (t) async {
    final r = VigorRepo()..conn = 'idle';
    await mount(t, r);
    expect(find.text('Buscar pulsera'), findsOneWidget);
    expect(find.text('Conectar'), findsNothing);
    await t.tap(find.text('Buscar pulsera'));
    await t.pump(); await t.pump(const Duration(milliseconds: 400));
    expect(calls, contains('startScan'));
    expect(find.text('Buscar pulsera'), findsWidgets); // título de la hoja
    expect(find.textContaining('Acerca la pulsera'), findsOneWidget);
  });

  testWidgets('con una pulsera encontrada, tocarla conecta con su MAC y cierra la hoja', (t) async {
    final r = VigorRepo()..conn = 'idle';
    await mount(t, r);
    await t.tap(find.text('Buscar pulsera'));
    await t.pump(); await t.pump(const Duration(milliseconds: 400));
    r.found['AA:BB:CC:DD:EE:FF'] = {'name': 'VIGOR', 'mac': 'AA:BB:CC:DD:EE:FF', 'rssi': -55};
    r.notifyListeners();
    await t.pump();
    await t.tap(find.text('VIGOR'));
    await t.pump(); await t.pump(const Duration(milliseconds: 400));
    expect(calls, containsAllInOrder(['startScan', 'stopScan', 'connect']));
    expect(find.textContaining('Acerca la pulsera'), findsNothing);
  });
}
