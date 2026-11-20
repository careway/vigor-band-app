// DEV_006: bucle de pulso en vivo con fakes y reloj/temporizadores simulados (testWidgets avanza el tiempo falso).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/live_heart.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/heart_ui.dart';

const _mc = MethodChannel('vigor/methods');
Map ev(int v, [String s = 'STATE_HEART_NORMAL']) => {'status': s, 'value': v};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  late int starts, stops; late bool ok; late DateTime now; late LiveHeart h;
  Future<void> adv(WidgetTester t, int s) async { now = now.add(Duration(seconds: s)); await t.pump(Duration(seconds: s)); }
  void mk() { starts = 0; stops = 0; ok = true; now = DateTime(2026, 1, 1, 10); h = LiveHeart(start: () async => starts++, stop: () async => stops++, canRun: () => ok, clock: () => now); }

  testWidgets('solo arranca si está activado y visible; al ocultar para la pulsera', (t) async {
    mk(); h.setEnabled(true); await adv(t, 1); expect(starts, 0); expect(h.phase, LivePhase.off);
    h.setVisible(true); await adv(t, 1); expect(starts, 1); expect(h.reading, isTrue);
    h.setVisible(false); expect(stops, 1); expect(h.reading, isFalse); expect(h.phase, LivePhase.off); await adv(t, 60); expect(starts, 1);
    h.dispose();
  });
  testWidgets('ciclo: dos lecturas coherentes -> valor, stop, y siguiente lectura a los ~10 s del inicio', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); h.onEvent(ev(0)); h.onEvent(ev(300)); expect(h.value, isNull);
    await adv(t, 3); h.onEvent(ev(70)); expect(h.value, isNull); h.onEvent(ev(73)); expect(h.value, 72); expect(stops, 1); expect(h.reading, isFalse); expect(h.fresh, isTrue);
    await adv(t, 5); expect(starts, 1); await adv(t, 3); expect(starts, 2); // 3 s de lectura + 7 s de pausa = ciclo de 10 s
    h.dispose();
  });
  testWidgets('tres lecturas incoherentes: mediana', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); h.onEvent(ev(60)); h.onEvent(ev(90)); h.onEvent(ev(70)); expect(h.value, 70); h.dispose();
  });
  testWidgets('sin lectura (tiempo máximo): fallo, para la pulsera y backoff creciente, no frenético', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); expect(starts, 1);
    await adv(t, 20); expect(h.phase, LivePhase.noReading); expect(stops, 1); expect(h.value, isNull); expect(h.fresh, isFalse);
    await adv(t, 18); expect(starts, 1); await adv(t, 3); expect(starts, 2); // 1.º fallo: espera 20 s
    await adv(t, 20); expect(h.failures, 2); await adv(t, 37); expect(starts, 2); await adv(t, 3); expect(starts, 3); // 2.º fallo: 40 s
    h.dispose();
  });
  testWidgets('sensor sin piel: fallo inmediato con backoff; un éxito reinicia los fallos', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); h.onEvent(ev(0, 'STATE_HEART_WEAR_ERROR')); expect(h.failures, 1); expect(stops, 1);
    await adv(t, 21); expect(starts, 2); h.onEvent(ev(70)); h.onEvent(ev(71)); expect(h.failures, 0); h.dispose();
  });
  testWidgets('batería baja de la pulsera: se apaga y no reintenta hasta reconectar', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); h.onEvent(ev(0, 'STATE_LOW_BATTERY')); expect(h.phase, LivePhase.off); expect(stops, 1);
    await adv(t, 120); expect(starts, 1); h.clearLowBattery(); await adv(t, 1); expect(starts, 2); h.dispose();
  });
  testWidgets('condiciones externas: pausa y reanuda sin solaparse; cambiar intervalo', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); expect(h.reading, isTrue);
    ok = false; h.recheck(); expect(h.reading, isFalse); expect(stops, 1); expect(h.phase, LivePhase.paused); await adv(t, 100); expect(starts, 1); // sin temporizadores mientras está pausado
    ok = true; h.recheck(); await adv(t, 1); expect(starts, 2); h.onEvent(ev(70)); h.onEvent(ev(70));
    h.setInterval(30); await adv(t, 1); expect(starts, 3); h.onEvent(ev(70)); h.onEvent(ev(70)); await adv(t, 20); expect(starts, 3); await adv(t, 12); expect(starts, 4);
    h.setInterval(7); expect(h.intervalSec, 30); h.dispose();
  });
  testWidgets('dispose con lectura en curso para la pulsera', (t) async { mk(); h.setVisible(true); await adv(t, 1); h.dispose(); expect(stops, 1); });
  testWidgets('valores no válidos nunca se muestran', (t) async {
    mk(); h.setVisible(true); await adv(t, 1); for (final v in [0, 5, 29, 221, 255]) { h.onEvent(ev(v)); } expect(h.value, isNull); h.dispose();
  });

  group('integración con el repositorio y el centro del reloj', () {
    Future<VigorRepo> mkRepo(WidgetTester t, List<String> calls) async {
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); return null; });
      final r = VigorRepo()..conn = 'connected'; r.addListener(r.live.recheck); r.heart.addListener(r.live.recheck); return r;
    }
    Widget app(VigorRepo r, Sample? rec) => MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: x!),
        home: Scaffold(body: Center(child: HeartCenter(repo: r, lastRecord: rec, canMeasure: true))));
    testWidgets('no se solapa con sincronización, deporte, batería < 20 % ni medición manual', (t) async {
      final calls = <String>[]; final r = await mkRepo(t, calls); r.live.setVisible(true); await t.pump(const Duration(seconds: 1));
      expect(calls.where((e) => e == 'startHeart').length, 1);
      r.syncing = true; r.notifyListeners(); expect(calls.where((e) => e == 'stopHeart').length, 1); await t.pump(const Duration(seconds: 100)); expect(calls.where((e) => e == 'startHeart').length, 1);
      r.syncing = false; r.sportActive = true; r.notifyListeners(); await t.pump(const Duration(seconds: 100)); expect(calls.where((e) => e == 'startHeart').length, 1);
      r.sportActive = false; r.battery = 15; r.notifyListeners(); await t.pump(const Duration(seconds: 100)); expect(calls.where((e) => e == 'startHeart').length, 1);
      r.battery = 50; r.notifyListeners(); await t.pump(const Duration(seconds: 1)); expect(calls.where((e) => e == 'startHeart').length, 2);
      await r.heart.begin(); // la medición manual detiene el bucle antes de pedir la suya
      expect(r.live.reading, isFalse); r.heart.cancel(); r.live.setVisible(false); r.dispose();
    });
    testWidgets('el círculo enseña "pulso en vivo" con hora, y "sin lectura" si falla; nunca 0', (t) async {
      final calls = <String>[]; final r = await mkRepo(t, calls); final rec = Sample(DateTime(2026, 1, 1, 9, 5), 66);
      await t.pumpWidget(app(r, rec)); expect(find.text('último registro de 09:05'), findsOneWidget);
      r.live.setVisible(true); await t.pump(const Duration(seconds: 1));
      r.live.onEvent(ev(0)); r.live.onEvent(ev(80)); r.live.onEvent(ev(81)); await t.pump();
      expect(find.text('81 bpm'), findsOneWidget); expect(find.textContaining('pulso en vivo ·'), findsOneWidget); expect(find.text('0 bpm'), findsNothing);
      await t.pump(const Duration(seconds: 1)); r.live.setVisible(false); r.dispose();
    });
    testWidgets('fallo: rótulo "sin lectura · último registro"', (t) async {
      final calls = <String>[]; final r = await mkRepo(t, calls); final rec = Sample(DateTime(2026, 1, 1, 9, 5), 66);
      await t.pumpWidget(app(r, rec)); r.live.setVisible(true); await t.pump(const Duration(seconds: 1)); await t.pump(const Duration(seconds: 21)); await t.pump();
      expect(find.text('sin lectura · último registro de 09:05'), findsOneWidget); r.live.setVisible(false); r.dispose();
    });
    testWidgets('ajustes: interruptor e intervalo se guardan y validan', (t) async {
      final saved = <String, int>{}; bm.setMockMethodCallHandler(_mc, (c) async { if (c.method == 'setPref') saved[c.arguments['key']] = c.arguments['value']; return null; });
      final r = VigorRepo(); await r.setLiveOn(false); await r.setLiveSec(30); await r.setLiveSec(7);
      expect(saved, {'liveOn': 0, 'liveSec': 30}); expect(r.live.enabled, isFalse); expect(r.liveSec, 30); r.dispose();
    });
  });
}
