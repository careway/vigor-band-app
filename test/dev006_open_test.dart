// DEV_006 adenda 3: pulso en vivo al abrir/reanudar y comprobación de versión al iniciar/reanudar. Reloj y ciclo de vida simulados.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/live_heart.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/updater.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/heart_ui.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');
Map ev(int v) => {'status': 'STATE_HEART_NORMAL', 'value': v};
Map _rel(int b) => {'body': 'build: $b', 'assets': [{'name': 'vigor-latest.apk', 'size': 5000000, 'browser_download_url': 'https://github.com/x/y/releases/download/latest/vigor-latest.apk'}]};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  setUp(() { calls = []; bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); return null; }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));
  int starts() => calls.where((e) => e == 'startHeart').length;
  Future<void> mount(WidgetTester t, VigorRepo r) async {
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: x!), home: Scaffold(body: TodayPage(r))));
  }
  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox());
  VigorRepo mk({String conn = 'connected'}) { final r = VigorRepo()..conn = conn; r.addListener(r.live.recheck); r.heart.addListener(r.live.recheck); return r; }

  group('pulso en vivo al abrir', () {
    testWidgets('arranque en frío ya conectado: primera lectura inmediata (sin esperar un intervalo)', (t) async {
      final r = mk(); await mount(t, r); await t.pump(const Duration(milliseconds: 10)); expect(starts(), 1); expect(r.live.reading, isTrue);
      await unmount(t); r.dispose();
    });
    testWidgets('arranque sin conexión que conecta después, con sincronización inicial por delante', (t) async {
      final r = mk(conn: 'connecting'); await mount(t, r); await t.pump(const Duration(seconds: 5)); expect(starts(), 0);
      r.conn = 'connected'; r.syncing = true; r.notifyListeners(); await t.pump(const Duration(seconds: 5)); expect(starts(), 0); // sincronizando: espera
      r.syncing = false; r.notifyListeners(); await t.pump(const Duration(milliseconds: 10)); expect(starts(), 1); // termina la sync: lee ya
      await unmount(t); r.dispose();
    });
    testWidgets('segundo plano para la pulsera; resume lee enseguida y borra el backoff antiguo', (t) async {
      final r = mk(); await mount(t, r); await t.pump(const Duration(milliseconds: 10));
      await t.pump(liveTimeout); // fallo 1
      await t.pump(const Duration(seconds: 25)); await t.pump(liveTimeout); expect(r.live.failures, greaterThanOrEqualTo(2)); // backoff creciente
      final s0 = starts();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(); expect(calls.where((e) => e == 'stopHeart'), isNotEmpty); expect(r.live.reading, isFalse); await t.pump(const Duration(seconds: 200)); expect(starts(), s0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await t.pump(const Duration(milliseconds: 10));
      expect(starts(), s0 + 1); expect(r.live.failures, 0); expect(r.live.reading, isTrue);
      await unmount(t); r.dispose();
    });
    testWidgets('resume con la sincronización en curso: espera y lee al acabar', (t) async {
      final r = mk(); await mount(t, r); await t.pump(const Duration(milliseconds: 10));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); await t.pump(); r.syncing = true; r.notifyListeners();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await t.pump(const Duration(seconds: 3)); final s = starts(); expect(r.live.reading, isFalse);
      r.syncing = false; r.notifyListeners(); await t.pump(const Duration(milliseconds: 10)); expect(starts(), s + 1);
      await unmount(t); r.dispose();
    });
    testWidgets('pestaña distinta a Hoy (página desmontada): no mide; al volver a Hoy, mide enseguida', (t) async {
      final r = mk(); await unmount(t); await t.pump(const Duration(seconds: 30)); expect(starts(), 0);
      await mount(t, r); await t.pump(const Duration(milliseconds: 10)); expect(starts(), 1);
      await unmount(t); expect(r.live.reading, isFalse); expect(calls.where((e) => e == 'stopHeart'), isNotEmpty); r.dispose();
    });
  });

  group('círculo: no presenta el dato viejo como actual', () {
    Widget app(VigorRepo r) => MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: Center(child: HeartCenter(repo: r, lastRecord: Sample(DateTime(2026, 1, 1, 9, 5), 66), canMeasure: true))));
    testWidgets('conectando…, midiendo pulso…, y luego pulso en vivo; falla -> sin lectura con último registro', (t) async {
      final r = mk(conn: 'connecting'); await t.pumpWidget(app(r));
      expect(find.text('conectando…'), findsOneWidget); expect(find.text('66 bpm'), findsNothing);
      r.live.setVisible(true); r.conn = 'connected'; r.notifyListeners(); await t.pump(const Duration(milliseconds: 10));
      expect(find.text('midiendo pulso…'), findsOneWidget); expect(find.text('66 bpm'), findsNothing); expect(find.text('— bpm'), findsOneWidget);
      r.live.onEvent(ev(75)); r.live.onEvent(ev(76)); await t.pump(); expect(find.textContaining('pulso en vivo ·'), findsOneWidget); expect(find.text('76 bpm'), findsOneWidget);
      await t.pump(const Duration(seconds: 61)); // el valor caduca y se vuelve a medir: no se muestra el viejo
      r.clock = () => DateTime.now().add(const Duration(minutes: 10)); // el valor ya es viejo
      for (var i = 0; i < 90 && r.live.phase != LivePhase.noReading; i++) { await t.pump(const Duration(seconds: 1)); }
      await t.pump(); expect(find.text('sin lectura · último registro de 09:05'), findsOneWidget);
      r.live.setVisible(false); r.dispose();
    });
    testWidgets('con el pulso en vivo apagado: solo el último registro etiquetado', (t) async {
      final r = mk(); r.live.setEnabled(false); await t.pumpWidget(app(r)); expect(find.text('último registro de 09:05'), findsOneWidget); expect(find.text('66 bpm'), findsOneWidget); r.dispose();
    });
  });

  group('comprobación de versión al iniciar y al reanudar', () {
    late DateTime now; late int fetched; late int build;
    Updater mkU() { fetched = 0; return Updater(fetch: (_) async { fetched++; return _rel(build); }, clock: () => now)..installed = 5; }
    setUp(() { now = DateTime(2026, 11, 20, 10); build = 7; });
    test('al arrancar comprueba (init) y no dos veces seguidas en 15 min', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => switch (c.method) { 'appVersion' => {'code': 5, 'name': '1'}, _ => null });
      final u = mkU(); await u.init(); await pumpEventQueue(); expect(fetched, 1); expect(u.available, isTrue);
      now = now.add(const Duration(minutes: 14)); await u.onResume(); expect(fetched, 1);
      now = now.add(const Duration(minutes: 2)); await u.onResume(); expect(fetched, 2);
    });
    test('resume antes/después de 15 min', () async {
      final u = mkU(); await u.check(silent: true); expect(fetched, 1);
      now = now.add(const Duration(minutes: 5)); await u.onResume(); expect(fetched, 1);
      now = now.add(const Duration(minutes: 10)); await u.onResume(); expect(fetched, 2);
    });
    test('nunca dos en vuelo', () async {
      final u = mkU(); final a = u.check(silent: true); final b = u.check(silent: true); await Future.wait([a, b]); expect(fetched, 1);
    });
    test('versión descartada no vuelve a avisar al reanudar; una más nueva sí', () async {
      final u = mkU(); await u.check(silent: true); expect(u.showBanner, isTrue); u.later(); expect(u.showBanner, isFalse);
      now = now.add(const Duration(minutes: 20)); await u.onResume(); expect(u.showBanner, isFalse);
      build = 9; now = now.add(const Duration(minutes: 20)); await u.onResume(); expect(u.showBanner, isTrue); expect(u.info!.build, 9);
    });
    test('fallo al reanudar: silencioso, conserva el aviso previo', () async {
      final u = mkU(); await u.check(silent: true); expect(u.showBanner, isTrue);
      u.fetchJson = (_) async => throw Exception('red'); now = now.add(const Duration(minutes: 20)); await u.onResume();
      expect(u.message, isNull); expect(u.failure, isNull); expect(u.showBanner, isTrue);
    });
  });
}

// Tiempo máximo de una lectura (20 s) + un segundo.
const liveTimeout = Duration(seconds: 21);
