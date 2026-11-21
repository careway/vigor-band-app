import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/gps_filter.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/route_map.dart';
import 'package:vigor_app/ui/route_panel.dart';

const _mc = MethodChannel('vigor/methods');
// Datos sintéticos: una recta hacia el este con un salto imposible y puntos sin señal.
GpsFix _f(int i, {double dx = 0, double dy = 0, int sig = 2}) => GpsFix(40.0 + dy / 111320, -3.0 + (i * 15.0 + dx) / 85000, i * 5, sig);
Session _sess({List<GpsFix>? fixes, List<(double, double)>? route}) {
  final fx = fixes ?? [for (var i = 0; i < 40; i++) i == 20 ? _f(i, dx: 3000, dy: 2000) : _f(i, sig: (i == 5 || i == 6) ? 0 : 2)];
  return Session(key: 'k', start: DateTime(2026, 3, 5, 8), sportType: 1, seconds: 200, meters: 600, kcal: 10, steps: 0, avgHr: 120, paceSecKm: 0, hasGps: true,
      route: route ?? [for (final f in fx) if (f.signal > 0) (f.lat, f.lng)], hrPerMinute: const [], fixes: fx);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() { calls.clear(); bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));
  Future<void> pump(WidgetTester t, Widget w, {double scale = 1, Size size = const Size(360, 1400), Brightness b = Brightness.light}) async {
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: x!), home: Scaffold(body: SingleChildScrollView(child: w))));
    await t.pump(const Duration(milliseconds: 50));
  }
  VigorRepo noTiles() { final r = VigorRepo(); r.mapOn = false; return r; } // sin descargar teselas en los tests

  test('fixesOf: sin tiempos ni señal (datos antiguos) supone un punto cada 5 s con señal buena', () {
    final s = Session(key: 'a', start: DateTime(2026), sportType: 1, seconds: 60, meters: 1, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: true, route: const [(40.0, -3.0), (double.nan, double.nan), (40.001, -3.0)], hrPerMinute: const []);
    final f = fixesOf(s); expect(f.length, 2); expect(f.every((x) => x.signal == 2), true); expect(f[1].t, 10);
  });
  test('rawSegments corta donde no hubo posición y descarta tramos de un solo punto', () {
    final s = Session(key: 'a', start: DateTime(2026), sportType: 1, seconds: 60, meters: 1, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: true,
        route: const [(1.0, 1.0), (1.1, 1.1), (double.nan, double.nan), (2.0, 2.0), (double.nan, double.nan), (3.0, 3.0), (3.1, 3.1), (3.2, 3.2)], hrPerMinute: const []);
    expect(rawSegments(s).map((x) => x.length), [2, 3]);
  });

  group('panel de ruta', () {
    testWidgets('muestra la ruta, el selector Suavizada/Original y cuántos puntos se corrigieron (sin mapa)', (t) async {
      await pump(t, RoutePanel(noTiles(), _sess()));
      expect(find.text('Ruta'), findsOneWidget); expect(find.text('Suavizada'), findsOneWidget); expect(find.text('Original'), findsOneWidget);
      expect(find.textContaining('corregido'), findsOneWidget); expect(find.textContaining('2 sin señal'), findsOneWidget);
      await t.tap(find.text('Original')); await t.pump();
      expect(find.textContaining('corregido'), findsNothing, reason: 'la ruta original no se corrige');
    });
    testWidgets('sin posición suficiente o sin GPS: lo dice en una frase', (t) async {
      final nope = Session(key: 'b', start: DateTime(2026), sportType: 1, seconds: 60, meters: 0, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: false, route: const [], hrPerMinute: const []);
      await pump(t, RoutePanel(noTiles(), nope)); expect(find.text('Esta actividad no tiene GPS.'), findsOneWidget);
      final weak = Session(key: 'c', start: DateTime(2026), sportType: 1, seconds: 60, meters: 0, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: true, route: const [], hrPerMinute: const []);
      await pump(t, RoutePanel(noTiles(), weak)); expect(find.textContaining('no fijó el GPS'), findsOneWidget);
    });
    testWidgets('a 320 px, texto doble y tema oscuro no desborda', (t) async {
      await pump(t, RoutePanel(noTiles(), _sess()), scale: 2, size: const Size(320, 1600), b: Brightness.dark); expect(t.takeException(), isNull);
    });
    testWidgets('el detalle de la actividad usa el panel de ruta y no los textos largos de antes', (t) async {
      t.view.physicalSize = const Size(360, 3000) * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: SessionPage(noTiles(), _sess()))); await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(RoutePanel), findsOneWidget); expect(find.textContaining('Sin suavizado'), findsNothing);
    });
  });

  group('mapa', () {
    testWidgets('sin teselas (ajuste apagado) dibuja la ruta y no pide ningún mapa', (t) async {
      await pump(t, RouteMap([[(40.0, -3.0), (40.001, -3.001), (40.002, -3.0)]], tiles: false));
      expect(find.descendant(of: find.byType(RouteMap), matching: find.byType(CustomPaint)), findsWidgets); expect(find.text('© OpenStreetMap'), findsNothing);
    });
    testWidgets('con una sola posición o vacío no muestra nada', (t) async {
      await pump(t, const RouteMap([[(40.0, -3.0)]], tiles: false)); expect(find.descendant(of: find.byType(RouteMap), matching: find.byType(CustomPaint)), findsNothing);
    });
  });

  group('ajuste del mapa de fondo', () {
    test('mapOn por defecto está activo y setMapOn guarda la preferencia', () async {
      final r = VigorRepo(); expect(r.mapOn, true);
      await r.setMapOn(false); expect(r.mapOn, false); expect(calls.last.method, 'setPref'); expect(calls.last.arguments, {'key': 'mapOn', 'value': 0});
    });
  });
}
