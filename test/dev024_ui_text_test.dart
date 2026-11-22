// DEV-024 B2/B3: diálogos cortos con el detalle tras ⓘ; Hoy vacío con un solo botón según el estado.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => bm.setMockMethodCallHandler(_mc, (c) async => null));
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  Future<void> mount(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: w)));
    await t.pump();
  }

  FilledButton btn(WidgetTester t) => t.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('Hoy vacío: un solo botón, deshabilitado mientras sincroniza o conecta', (t) async {
    final r = VigorRepo()..conn = 'connected'..syncing = true;
    await mount(t, ListenableBuilder(listenable: r, builder: (_, _) => TodayPage(r)));
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Sincronizando…'), findsWidgets);
    expect(btn(t).onPressed, isNull);
    r.syncing = false; r.notifyListeners(); await t.pump();
    expect(find.text('Sincronizar'), findsOneWidget); expect(btn(t).onPressed, isNotNull);
    r.conn = 'connecting'; r.notifyListeners(); await t.pump();
    expect(find.text('Conectando…'), findsOneWidget); expect(btn(t).onPressed, isNull);
    expect(find.text('Sincronizando…'), findsNothing);
    r.conn = 'idle'; r.notifyListeners(); await t.pump();
    expect(find.text('Buscar pulsera'), findsOneWidget);
  });

  testWidgets('borrar todos mis datos: diálogo corto y el detalle tras ⓘ', (t) async {
    final r = VigorRepo();
    await mount(t, SingleChildScrollView(child: PrivacyPanel(r)));
    await t.tap(find.text('Borrar todos mis datos')); await t.pumpAndSettle();
    expect(find.text('Se borran los datos de este móvil. No se puede deshacer.'), findsOneWidget);
    expect(find.textContaining('efemérides'), findsNothing);
    await t.tap(find.byTooltip('Más información: Borrar todos mis datos')); await t.pumpAndSettle();
    expect(find.textContaining('efemérides'), findsOneWidget);
  });
}
