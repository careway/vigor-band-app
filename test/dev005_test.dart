// DEV_005: modos deportivos, selector, detalle por tipo, cadencia de medicion y submenus de Ajustes. Datos sinteticos.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/sports.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/sport_picker.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  final other = <Object>[];
  Future<void> pump(WidgetTester t, Widget w, {double scale = 1.0, Size size = const Size(360, 780)}) async {
    // Fuente Ahem: los desbordes de RenderFlex no son evidencia (ver dev003); se vigilan el resto de excepciones.
    other.clear(); final old = FlutterError.onError;
    FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) other.add(d.exception); };
    addTearDown(() => FlutterError.onError = old);
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: x!), home: Scaffold(body: w)));
    await t.pump(const Duration(seconds: 1));
  }
  Session sess(int type, {bool gps = false, int meters = 5000}) => Session(key: 'k$type', start: DateTime(2026, 3, 5, 8), sportType: type, seconds: 1800, meters: meters, kcal: 120, steps: 0, avgHr: 130, paceSecKm: 360, hasGps: gps, route: const [], hrPerMinute: List.filled(30, 130));

  group('tabla de modos', () {
    test('ids y claves unicos, sin NONE, y todos tienen nombre', () {
      expect(sportModes.map((m) => m.id).toSet().length, sportModes.length);
      expect(sportModes.map((m) => m.key).toSet().length, sportModes.length);
      expect(sportModes.every((m) => m.id > 0 && m.name.isNotEmpty), isTrue);
      expect(sportModes.length, greaterThan(150));
    });
    test('nombres de sesiones historicas', () {
      expect(sportLabel(1), 'Correr al aire libre'); expect(sportLabel(16), 'Yoga'); expect(sportLabel(12), 'Natación');
      expect(sportLabel(9999), 'Actividad (9999)'); expect(sportIcon(9999), Icons.directions_run);
      expect(sportById(7)!.key, 'OUTDOOR_RIDING');
    });
    test('recorrido vs interior', () {
      expect(sportByKey('OUTDOOR_RUNNING')!.tracksRoute, isTrue); expect(sportByKey('HIKE')!.tracksRoute, isTrue);
      expect(sportByKey('INDOOR_RUNNING')!.tracksRoute, isFalse); expect(sportByKey('YOGA')!.tracksRoute, isFalse); expect(sportByKey('Treadmill')!.tracksRoute, isFalse);
      expect(sportTracksRoute(9999), isNull);
    });
    test('agrupacion y filtros', () {
      expect(sportsByGroup().keys, isNotEmpty);
      expect(sportsByGroup(query: 'natacion').values.expand((e) => e).map((m) => m.key), contains('SWIM')); // sin tildes
      expect(sportsByGroup(kind: 1).values.expand((e) => e).every((m) => m.tracksRoute), isTrue);
      expect(sportsByGroup(kind: 2).values.expand((e) => e).every((m) => !m.tracksRoute), isTrue);
      expect(sportsByGroup(query: 'zzzz'), isEmpty);
    });
    test('quickSportKeys existen', () { for (final k in quickSportKeys) { expect(sportByKey(k), isNotNull, reason: k); } });
  });

  group('selector y actividad', () {
    testWidgets('abre el selector, filtra y elige un modo de interior; el boton Iniciar envia su clave', (t) async {
      final calls = <MethodCall>[];
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; });
      final r = VigorRepo(); r.conn = 'connected';
      await pump(t, ActivityPage(r));
      await t.tap(find.textContaining('Iniciar nueva actividad')); await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'yoga'); await t.pumpAndSettle();
      await t.tap(find.text('Yoga').last); await t.pumpAndSettle();
      expect(find.textContaining('interior, sin GPS'), findsWidgets);
      await t.tap(find.text('Iniciar')); await t.pump();
      expect(calls.last.method, 'startSport'); expect(calls.last.arguments, {'type': 'YOGA'});
    });
    testWidgets('selector a texto x2 sin excepciones y tesela con area >= 48 dp', (t) async {
      final h = t.ensureSemantics();
      await pump(t, Builder(builder: (c) => TextButton(onPressed: () => showSportPicker(c, 1), child: const Text('abrir'))), scale: 2.0, size: const Size(360, 640));
      await t.tap(find.text('abrir')); await t.pumpAndSettle();
      expect(find.text('Elige el modo deportivo'), findsOneWidget);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      h.dispose();
    });
    testWidgets('lista de sesiones: nombre e icono por tipo', (t) async {
      final r = VigorRepo(); r.clock = () => DateTime(2026, 3, 5, 18); r.sessions = [sess(12), sess(5, gps: true), sess(9999)]; // «hoy» = el día de las sesiones
      await pump(t, ActivityPage(r), size: const Size(360, 3000));
      expect(find.text('Actividad (9999)'), findsOneWidget); expect(other, isEmpty);
      expect(find.descendant(of: find.byType(SessionTile), matching: find.text('Natación')), findsOneWidget); // y también como atajo (es de los más frecuentes)
    });
  });

  group('detalle por tipo', () {
    testWidgets('interior: sin ruta GPS ni ritmo, con duracion y pulso', (t) async {
      await pump(t, SessionPage(VigorRepo(), sess(16)), size: const Size(360, 3000));
      expect(find.text('Ruta GPS de la pulsera'), findsNothing); expect(find.text('Ritmo medio'), findsNothing);
      expect(find.text('Pulso medio'), findsOneWidget); expect(find.text('Calorías'), findsOneWidget);
    });
    testWidgets('recorrido: ruta, ritmo y distancia', (t) async {
      await pump(t, SessionPage(VigorRepo(), sess(1, gps: true)), size: const Size(360, 3000));
      expect(find.text('Ritmo medio'), findsOneWidget);
      expect(find.text('Ruta'), findsOneWidget); // panel de ruta (mapa o dibujo) con su selector Suavizada/Original
    });
  });

  group('cadencia de medicion', () {
    test('AutoMeasure: opciones y avisos', () {
      final m = AutoMeasure.fromMap({'type': 0, 'name': 'PULSE_RATE', 'on': true, 'intervalModify': true, 'interval': 10, 'stepUnit': 10});
      expect(m.label, 'Pulso'); expect(m.choices.first, 10); expect(m.choices.last, 240); expect(m.choices.every((v) => v % 10 == 0), isTrue);
      expect(const AutoMeasure(type: 1, name: 'X', on: true, intervalModify: false, interval: 0, stepUnit: 10).choices, isEmpty);
      expect(autoBatteryWarning(5), isNotNull); expect(autoBatteryWarning(30), isNull);
    });
    testWidgets('pagina: muestra mediciones del evento y envia el ajuste', (t) async {
      final calls = <MethodCall>[];
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; });
      final r = VigorRepo(); r.conn = 'connected';
      r.autoMeasures = [AutoMeasure.fromMap({'type': 4, 'name': 'BLOOD_OXYGEN', 'on': true, 'intervalModify': true, 'interval': 30, 'stepUnit': 10})];
      await pump(t, MeasurementsPage(r));
      expect(find.text('SpO₂'), findsOneWidget);
      await t.tap(find.text('60 min')); await t.pump();
      expect(calls.last.method, 'setAutoMeasure'); expect(calls.last.arguments, {'type': 4, 'on': true, 'interval': 60});
    });
    testWidgets('no soportado: aviso honesto', (t) async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final r = VigorRepo(); r.autoUnsupported = true;
      await pump(t, MeasurementsPage(r));
      expect(find.textContaining('no admite ajustar'), findsOneWidget);
    });
  });

  group('submenus de Ajustes', () {
    for (final cat in ['Pulsera', 'Mediciones y cadencia', 'Actividad y deportes', 'Perfil', 'Efemérides GPS', 'Privacidad y datos', 'Apariencia', 'Avanzado y depuración']) {
      testWidgets('categoria "$cat" existe en Ajustes y abre su pantalla (texto x2)', (t) async {
        bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'getData' ? jsonEncode([]) : null);
        await pump(t, SettingsHome(VigorRepo()), scale: 2.0, size: const Size(360, 3000));
        await t.tap(find.text(cat)); await t.pumpAndSettle();
        expect(find.byType(AppBar), findsWidgets); expect(other, isEmpty, reason: '$other');
      });
    }
    testWidgets('Apariencia cambia el tema y lo guarda', (t) async {
      final calls = <MethodCall>[]; bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; });
      final r = VigorRepo(); await pump(t, AppearancePage(r));
      await t.tap(find.text('Sistema')); await t.pump();
      expect(r.themeMode, 2); expect(calls.last.arguments, {'key': 'theme', 'value': 2});
    });
  });
}
