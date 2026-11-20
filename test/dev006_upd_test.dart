// DEV_006 adenda: mensajes de fallo, "Más tarde" por versión, banner e indicadores. Red simulada.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/updater.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/about_page.dart';
import 'package:vigor_app/ui/fx.dart';

const _mc = MethodChannel('vigor/methods');
Map _rel(int b) => {'body': 'build: $b', 'assets': [{'name': 'vigor-latest.apk', 'size': 5000000, 'browser_download_url': 'https://github.com/x/y/releases/download/latest/vigor-latest.apk'}]};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  setUp(() { calls = []; bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return c.method == 'openUrl' ? true : null; }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));
  Updater mk(Future<dynamic> Function(Uri) f, {int installed = 10}) => Updater(fetch: f)..installed = installed;

  group('mensajes de fallo manual', () {
    for (final (name, thrower, st, fail) in <(String, Object, UpdateState, UpdateFail)>[
      ('404', const HttpException('HTTP 404'), UpdateState.unavailable, UpdateFail.inaccessible),
      ('401', const HttpException('HTTP 401'), UpdateState.unavailable, UpdateFail.inaccessible),
      ('403', const HttpException('HTTP 403'), UpdateState.unavailable, UpdateFail.inaccessible),
      ('429 (límite)', const HttpException('HTTP 429'), UpdateState.error, UpdateFail.rateLimit),
      ('sin conexión', const SocketException('x'), UpdateState.error, UpdateFail.offline),
      ('500', const HttpException('HTTP 500'), UpdateState.error, UpdateFail.invalid),
      ('JSON roto', const FormatException('x'), UpdateState.error, UpdateFail.invalid),
    ]) {
      test(name, () async {
        final u = mk((_) async => throw thrower); await u.check();
        expect(u.state, st); expect(u.failure, fail); expect(u.message, failText(fail)); expect(u.message, isNot(contains(RegExp(r'\d{3}')))); expect(u.message, startsWith('No se pudo comprobar'));
        // La comprobación automática no enseña nada.
        final s = mk((_) async => throw thrower); await s.check(silent: true); expect(s.message, isNull); expect(s.failure, isNull);
      });
    }
    test('respuesta sin formato: inválida', () async { final u = mk((_) async => {'a': 1}); await u.check(); expect(u.failure, UpdateFail.invalid); });
    test('éxito limpia el fallo anterior', () async {
      var ok = false; final u = mk((_) async => ok ? _rel(11) : throw const HttpException('HTTP 404'));
      await u.check(); expect(u.failure, isNotNull); ok = true; await u.check(); expect(u.failure, isNull); expect(u.message, isNull); expect(u.available, isTrue);
    });
    test('mensaje del repositorio privado es accionable', () { expect(failText(UpdateFail.inaccessible), allOf(contains('privado'), contains('descargar a mano'))); });
  });

  group('"Más tarde" por versión', () {
    test('silencia esa versión, se guarda, y una más nueva vuelve a avisar', () async {
      var b = 11; final u = mk((_) async => _rel(b)); await u.check();
      expect(u.showBanner, isTrue); u.later(); expect(u.showBanner, isFalse); expect(u.available, isTrue); // el indicador sigue
      expect(calls.where((c) => c.method == 'setPref' && c.arguments['key'] == 'updSkip' && c.arguments['value'] == 11), isNotEmpty);
      await u.check(); expect(u.showBanner, isFalse); b = 12; await u.check(); expect(u.showBanner, isTrue);
    });
    test('init recupera la versión silenciada', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => switch (c.method) { 'appVersion' => {'code': 5, 'name': '1'}, 'getPrefs' => {'updSkip': 11, 'updChk': DateTime.now().millisecondsSinceEpoch ~/ 60000}, _ => null });
      final u = Updater(fetch: (_) async => _rel(11)); await u.init(); await u.check(); expect(u.showBanner, isFalse);
    });
  });

  group('UI', () {
    Widget wrap(Widget w) => MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(2)), child: x!), home: Scaffold(body: w));
    testWidgets('banner: Actualizar y Más tarde (48 dp); Más tarde lo oculta', (t) async {
      final r = VigorRepo(); r.updater.installed = 1; r.updater.fetchJson = (_) async => _rel(5); await r.updater.check();
      await t.pumpWidget(wrap(UpdateBanner(r))); expect(find.textContaining('Hay una versión nueva'), findsOneWidget);
      expect(t.getSize(find.widgetWithText(TextButton, 'Más tarde')).height, greaterThanOrEqualTo(48)); expect(t.getSize(find.widgetWithText(FilledButton, 'Actualizar')).height, greaterThanOrEqualTo(48));
      await t.tap(find.text('Más tarde')); await t.pump(); expect(find.textContaining('Hay una versión nueva'), findsNothing); r.dispose();
    });
    testWidgets('Acerca de: 404 manual muestra mensaje claro y abre la página de versiones', (t) async {
      final r = VigorRepo(); r.updater.installed = 1; r.updater.fetchJson = (_) async => throw const HttpException('HTTP 404');
      await t.pumpWidget(wrap(AboutPage(r))); await t.tap(find.text('Buscar actualizaciones')); await t.pumpAndSettle();
      expect(find.textContaining('no es accesible'), findsOneWidget); expect(find.textContaining('404'), findsNothing);
      await t.tap(find.text('Abrir página de versiones')); await t.pump(); expect(calls.last.method, 'openUrl'); expect(calls.last.arguments['url'], kReleasesPage); r.dispose();
    });
    testWidgets('sin conexión: sin botón de abrir página', (t) async {
      final r = VigorRepo(); r.updater.installed = 1; r.updater.fetchJson = (_) async => throw const SocketException('x');
      await t.pumpWidget(wrap(AboutPage(r))); await t.tap(find.text('Buscar actualizaciones')); await t.pumpAndSettle();
      expect(find.textContaining('no hay conexión'), findsOneWidget); expect(find.text('Abrir página de versiones'), findsNothing); r.dispose();
    });
    testWidgets('punto en la pestaña Ajustes solo con versión pendiente', (t) async {
      Widget nav(Set<int> b) => wrap(FloatNav(index: 0, onTap: (_) {}, badges: b, items: const [(Icons.home, Icons.home, 'Hoy'), (Icons.tune, Icons.tune, 'Ajustes')]));
      final h = t.ensureSemantics(); final f = find.bySemanticsLabel(RegExp('novedad pendiente'));
      await t.pumpWidget(nav({1})); expect(f, findsOneWidget);
      await t.pumpWidget(nav({})); expect(f, findsNothing); h.dispose();
    });
  });
}
