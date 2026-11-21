import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/sports.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/sport_menu.dart';

const _mc = MethodChannel('vigor/methods');
// Datos sintéticos.
DateTime _d(int day, [int h = 9]) => DateTime(2026, 3, day, h);
Session _s(int type, DateTime start, {String? key}) => Session(key: key ?? 'k$type-${start.day}-${start.hour}', start: start, sportType: type, seconds: 1800, meters: 3000, kcal: 100, steps: 0, avgHr: 120, paceSecKm: 0, hasGps: false, route: const [], hrPerMinute: const []);
({int type, DateTime start}) _r(int type, DateTime start) => (type: type, start: start);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() { calls.clear(); bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  group('más frecuentes (lógica)', () {
    test('ordena por número de sesiones y, a igualdad, por la más reciente; completa con los habituales', () {
      final m = frequentSportModes([_r(1, _d(1)), _r(1, _d(2)), _r(1, _d(3)), _r(2, _d(4)), _r(2, _d(5)), _r(16, _d(6)), _r(5, _d(7))], n: 4);
      expect(m.map((x) => x.id), [1, 2, 5, 16], reason: 'correr x3, caminar x2, y entre los de 1 sesión el más reciente primero (5 antes que 16)');
    });
    test('sin historial: los habituales por defecto, sin repetir', () {
      final m = frequentSportModes(const []); expect(m.length, 4); expect(m.map((x) => x.key).toSet().length, 4); expect(m.first.key, 'OUTDOOR_RUNNING');
    });
    test('los tipos desconocidos no se ofrecen y el resto se completa', () {
      final m = frequentSportModes([_r(9999, _d(1)), _r(9999, _d(2))], n: 3);
      expect(m.length, 3); expect(m.every((x) => x.id != 9999), true);
    });
    test('no pasa de n y los habituales no duplican a los frecuentes', () {
      final m = frequentSportModes([for (final id in [1, 2, 3, 4, 5, 6]) _r(id, _d(id))], n: 2); expect(m.length, 2);
      final k = frequentSportModes([_r(sportByKey('OUTDOOR_RUNNING')!.id, _d(1))], n: 4); expect(k.where((x) => x.key == 'OUTDOOR_RUNNING').length, 1);
    });
    test('mismo día natural', () {
      expect(startedOnSameDay(DateTime(2026, 3, 5, 0, 1), DateTime(2026, 3, 5, 23, 59)), true);
      expect(startedOnSameDay(DateTime(2026, 3, 4, 23, 59), DateTime(2026, 3, 5, 0, 1)), false);
      expect(startedOnSameDay(DateTime(2025, 3, 5), DateTime(2026, 3, 5)), false);
    });
  });

  Future<void> pump(WidgetTester t, Widget w, {double scale = 1, Size size = const Size(360, 900), Brightness b = Brightness.light}) async {
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: x!), home: Scaffold(body: w)));
    await t.pump(const Duration(milliseconds: 50));
  }
  VigorRepo repo({bool connected = true}) {
    final r = VigorRepo(); r.conn = connected ? 'connected' : 'disconnected'; r.clock = () => DateTime(2026, 3, 5, 20);
    r.sessions = [_s(1, _d(5, 8)), _s(2, _d(5, 12)), _s(1, _d(4)), _s(1, _d(3)), _s(16, _d(2))]; return r;
  }

  group('pantalla de Actividad', () {
    testWidgets('muestra solo las actividades de HOY, los atajos más frecuentes y el botón de nueva actividad', (t) async {
      await pump(t, ActivityPage(repo()), size: const Size(360, 1400));
      expect(find.text('Actividad de hoy'), findsOneWidget);
      expect(find.text('Correr al aire libre'), findsWidgets); expect(find.text('Caminar al aire libre'), findsWidgets);
      expect(find.byType(SessionTile), findsNWidgets(2), reason: 'solo las 2 de hoy; las otras 3 están en el historial');
      expect(find.textContaining('Iniciar nueva actividad'), findsOneWidget); expect(find.text('Más frecuentes'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
    });
    testWidgets('sin actividad hoy: lo dice y manda al historial; sin ninguna: pide sincronizar', (t) async {
      final r = repo(); r.clock = () => DateTime(2026, 3, 9);
      await pump(t, ActivityPage(r), size: const Size(360, 1400));
      expect(find.byType(SessionTile), findsNothing); expect(find.textContaining('Hoy aún no has hecho ninguna actividad'), findsOneWidget);
      final v = VigorRepo(); await pump(t, ActivityPage(v), size: const Size(360, 1400));
      expect(find.textContaining('Aún no hay actividades'), findsOneWidget); expect(find.text('Historial'), findsNothing);
    });
    testWidgets('un atajo selecciona el modo y «Iniciar» lo envía a la pulsera', (t) async {
      await pump(t, ActivityPage(repo()), size: const Size(360, 1400));
      await t.tap(find.widgetWithText(InkWell, 'Caminar al aire libre').first); await t.pump();
      await t.tap(find.text('Iniciar')); await t.pump();
      expect(calls.last.method, 'startSport'); expect(calls.last.arguments, {'type': 'OUTDOOR_WALK'});
    });
    testWidgets('el modo propuesto al abrir es el más frecuente', (t) async {
      await pump(t, ActivityPage(repo()), size: const Size(360, 1400));
      await t.tap(find.text('Iniciar')); await t.pump();
      expect(calls.last.arguments, {'type': 'OUTDOOR_RUNNING'});
    });
    testWidgets('desconectada: el botón Iniciar está desactivado y lo explica', (t) async {
      await pump(t, ActivityPage(repo(connected: false)), size: const Size(360, 1400));
      expect(find.textContaining('Conecta la pulsera'), findsOneWidget);
      final b = t.widget<FilledButton>(find.ancestor(of: find.text('Iniciar'), matching: find.byType(FilledButton))); expect(b.onPressed, isNull);
    });
    testWidgets('«Historial» abre todas las actividades, con el resumen semanal y la selección para borrar', (t) async {
      await pump(t, ActivityPage(repo()), size: const Size(360, 3000));
      await t.tap(find.text('Historial')); await t.pumpAndSettle();
      expect(find.text('Historial de actividades'), findsOneWidget); expect(find.byType(SessionTile), findsNWidgets(5));
      await t.tap(find.text('Seleccionar')); await t.pump();
      expect(find.textContaining('Toca las sesiones'), findsOneWidget);
    });
    testWidgets('a 320 px y texto doble no desborda en claro y oscuro', (t) async {
      for (final b in Brightness.values) { await pump(t, ActivityPage(repo()), scale: 2, size: const Size(320, 1600), b: b); expect(t.takeException(), isNull); }
    });
  });

  group('menú «Iniciar nueva actividad»', () {
    Future<void> open(WidgetTester t, {double scale = 1, Size size = const Size(360, 900)}) async {
      await pump(t, Builder(builder: (c) => TextButton(onPressed: () => showSportMenu(c), child: const Text('abrir'))), scale: scale, size: size);
      await t.tap(find.text('abrir')); await t.pumpAndSettle();
    }
    testWidgets('nivel 1: las familias; nivel 2: los modos de la familia; atrás vuelve', (t) async {
      await open(t);
      expect(find.text('Iniciar nueva actividad'), findsOneWidget);
      for (final g in SportGroup.values) { expect(find.textContaining(g.label), findsWidgets, reason: g.label); }
      await t.tap(find.textContaining('Ciclismo')); await t.pumpAndSettle();
      expect(find.text('Ciclismo y ruedas'), findsOneWidget);
      for (final m in sportsByGroup()[SportGroup.bike]!) { expect(find.text(m.name), findsOneWidget, reason: m.name); }
      expect(find.text('Carrera'), findsNothing, reason: 'ya no se ven las familias');
      await t.tap(find.byIcon(Icons.arrow_back)); await t.pumpAndSettle();
      expect(find.text('Iniciar nueva actividad'), findsOneWidget);
    });
    testWidgets('elegir un modo cierra el menú y lo devuelve', (t) async {
      SportMode? got;
      await pump(t, Builder(builder: (c) => TextButton(onPressed: () async { got = await showSportMenu(c); }, child: const Text('abrir'))));
      await t.tap(find.text('abrir')); await t.pumpAndSettle();
      await t.tap(find.textContaining('Carrera')); await t.pumpAndSettle();
      final first = sportsByGroup()[SportGroup.run]!.first;
      await t.tap(find.text(first.name)); await t.pumpAndSettle();
      expect(got?.id, first.id); expect(find.text('Iniciar nueva actividad'), findsNothing);
    });
    testWidgets('el buscador salta directo a los modos, sin tildes, y avisa si no hay ninguno', (t) async {
      await open(t);
      await t.enterText(find.byType(TextField), 'natacion'); await t.pumpAndSettle();
      expect(find.text('Resultados'), findsOneWidget); expect(find.text('Natación'), findsWidgets);
      await t.enterText(find.byType(TextField), 'zzzz'); await t.pumpAndSettle();
      expect(find.textContaining('Ninguna actividad coincide'), findsOneWidget);
    });
    testWidgets('a texto doble en pantalla pequeña no desborda y los controles miden 48 dp', (t) async {
      final h = t.ensureSemantics(); await open(t, scale: 2, size: const Size(320, 640));
      expect(t.takeException(), isNull); await expectLater(t, meetsGuideline(androidTapTargetGuideline)); h.dispose();
    });
  });
}
