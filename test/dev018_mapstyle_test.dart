import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/map_style.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/route_map.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() { calls.clear(); bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  group('estilos (lógica)', () {
    test('hay tres vectoriales modernos (con su estilo de OpenFreeMap) y tres de teselas ráster, y ninguno pide clave', () {
      expect(MapStyle.values.where((m) => m.isVector).map((m) => m.name), ['modern', 'minimal', 'bright']);
      expect(MapStyle.values.where((m) => !m.isVector).map((m) => m.name), ['standard', 'topo', 'cycle']);
      for (final m in MapStyle.values) { final u = m.isVector ? m.styleUri! : m.rasterUrl; expect(u, startsWith('https://')); expect(u.toLowerCase(), isNot(contains('key')), reason: m.name); }
      for (final m in MapStyle.values.where((m) => m.isVector)) { expect(m.styleUri, startsWith('https://tiles.openfreemap.org/styles/')); expect(m.rasterUrl, isEmpty); }
    });
    test('las plantillas ráster tienen {z}, {x} e {y}', () {
      for (final m in MapStyle.values.where((m) => !m.isVector)) { for (final k in ['{z}', '{x}', '{y}']) { expect(m.rasterUrl, contains(k), reason: m.name); } }
    });
    test('el servidor de CARTO ya no está: exige clave y servía un aviso en lugar de mapa', () {
      for (final m in MapStyle.values) { expect('${m.styleUri}${m.rasterUrl}', isNot(contains('cartocdn')), reason: m.name); }
    });
    test('OpenTopoMap llega a zoom 17 y los demás a 19', () { expect(MapStyle.topo.maxNativeZoom, 17); expect(MapStyle.standard.maxNativeZoom, 19); expect(MapStyle.cycle.maxNativeZoom, 19); });
    test('la atribución nombra a OpenStreetMap y al proveedor de cada estilo', () {
      for (final m in MapStyle.values) { expect(m.attribution, contains('OpenStreetMap'), reason: m.name); }
      for (final m in [MapStyle.modern, MapStyle.minimal, MapStyle.bright]) { expect(m.attribution, allOf(contains('OpenFreeMap'), contains('OpenMapTiles'))); }
      expect(MapStyle.topo.attribution, contains('OpenTopoMap')); expect(MapStyle.cycle.attribution, contains('CyclOSM'));
    });
    test('el estilo por defecto es el moderno y los valores guardados raros vuelven a él', () {
      expect(MapStyle.byDefault, MapStyle.modern);
      for (final v in [null, -1, 99, 'x']) { expect(MapStyle.fromIndex(v), MapStyle.modern); }
      for (final m in MapStyle.values) { expect(MapStyle.fromIndex(m.index), m); }
    });
  });

  previewRouteChecks();

  group('ajuste', () {
    test('el estilo por defecto es automático y se guarda su posición', () async {
      final r = VigorRepo(); expect(r.mapStyle, MapStyle.modern);
      await r.setMapStyle(MapStyle.topo); expect(r.mapStyle, MapStyle.topo); expect(calls.last.method, 'setPref'); expect(calls.last.arguments, {'key': 'mapStyle', 'value': MapStyle.topo.index});
    });
    Future<void> pump(WidgetTester t, VigorRepo r, {double scale = 1, Size size = const Size(360, 900), Brightness b = Brightness.light}) async {
      t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: x!), home: Scaffold(body: SingleChildScrollView(child: MapSettingPanel(r, preview: false)))));
      await t.pump(const Duration(milliseconds: 50));
    }
    testWidgets('con el mapa activo muestra los 6 aspectos; elegir uno lo guarda', (t) async {
      final r = VigorRepo(); await pump(t, r);
      for (final m in MapStyle.values) { expect(find.text(m.label), findsOneWidget, reason: m.label); }
      await t.tap(find.text('Relieve')); await t.pump();
      expect(r.mapStyle, MapStyle.topo); expect(find.text('Curvas de nivel y senderos'), findsOneWidget);
    });
    testWidgets('la vista previa no descarga nada hasta que se pide', (t) async {
      final r = VigorRepo(); t.view.physicalSize = const Size(360, 1200) * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SingleChildScrollView(child: MapSettingPanel(r))))); await t.pump();
      expect(find.byType(RouteMap), findsNothing); expect(find.text('Ver vista previa'), findsOneWidget);
    });
    testWidgets('con el mapa apagado no ofrece aspectos y lo explica', (t) async {
      final r = VigorRepo(); r.mapOn = false; await pump(t, r);
      expect(find.text('Aspecto'), findsNothing); expect(find.text('Calles'), findsNothing); expect(find.textContaining('no se descarga ningún mapa'), findsOneWidget);
    });
    testWidgets('a 320 px, texto doble y tema oscuro no desborda y los controles miden 48 dp', (t) async {
      final h = t.ensureSemantics(); final r = VigorRepo(); await pump(t, r, scale: 2, size: const Size(320, 1400), b: Brightness.dark);
      expect(t.takeException(), isNull); await expectLater(t, meetsGuideline(androidTapTargetGuideline)); h.dispose();
    });
  });
}

// La vista previa dibuja una ruta de ejemplo fija: no puede ser la ubicación del usuario y debe estar en coordenadas válidas.
void previewRouteChecks() {
  test('la ruta de ejemplo es un bucle cerrado con coordenadas válidas', () {
    expect(kPreviewRoute.length, greaterThan(5)); for (final p in kPreviewRoute) { expect(p.$1.abs(), lessThan(90)); expect(p.$2.abs(), lessThan(180)); }
    expect((kPreviewRoute.first.$1 - kPreviewRoute.last.$1).abs(), lessThan(.0003)); expect((kPreviewRoute.first.$2 - kPreviewRoute.last.$2).abs(), lessThan(.0003));
  });
}
