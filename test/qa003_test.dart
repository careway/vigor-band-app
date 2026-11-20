// QA_003: huecos de cobertura de la ronda 3 (E1-E7 + N28). JSON/valores sinteticos. Las pruebas marcadas "CARACTERIZACION"
// fijan el comportamiento ACTUAL de algo que QA_003 senala como discutible (ver docs/equipo/informes/QA_003.md); si se corrige, se actualizan.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/analysis.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/night_cards.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');
Map<String, int> _t(int y, int mo, int d, int h, int mi) => {'year': y, 'month': mo, 'day': d, 'hour': h, 'minute': mi};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));
  Future<VigorRepo> load(Map<String, List> data, {DateTime? now}) async {
    bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'getData' ? jsonEncode(data[c.arguments['kind']] ?? []) : null);
    final r = VigorRepo(); if (now != null) r.clock = () => now; await r.reload(); return r;
  }
  Future<void> pump(WidgetTester t, Widget w) async {
    final old = FlutterError.onError; // overflow por la fuente Ahem: no es evidencia
    FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) old!(d); };
    addTearDown(() => FlutterError.onError = old);
    t.view.physicalSize = const Size(1080, 2400); t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: x!), home: Scaffold(body: w)));
    await t.pump(const Duration(seconds: 1));
  }

  group('E1 limites de cobertura', () {
    test('posibles del dia en curso en los bordes (00:00 -> 1; 23:59 -> total)', () {
      expect(possibleSamples(1440, isToday: true, now: DateTime(2026, 3, 5, 0, 0)), 1);
      expect(possibleSamples(1440, isToday: true, now: DateTime(2026, 3, 5, 23, 59)), 1440);
      expect(possibleSamples(288, isToday: true, now: DateTime(2026, 3, 5, 0, 4)), 1);
      expect(possibleSamples(288, isToday: true, now: DateTime(2026, 3, 5, 12, 0)), 145); // ceil(288*721/1440)
    });
    test('Quality: NaN, infinito, texto y null son "sin dato"; 220 y 30 entran, 221 y 29 no', () {
      final q = Quality(1440);
      for (final v in [double.nan, double.infinity, 'x', null, 0, 255, 30, 220, 221, 29, 2550]) { q.add(v, 30, 220); }
      expect(q.raw, 11); expect(q.noData, 6); expect(q.valid, 2); expect(q.low, 1); expect(q.high, 2); // 2550 > 220 es "fuera de rango", no sentinela
    });
    test('SpO2 < 70: frase especifica con plural correcto y que tambien cuenta las > 100 (antes: caracterizacion)', () {
      final q = Quality(1440)..raw = 6..valid = 3..low = 1..high = 2;
      final t = coverageText(q, spo2: true);
      expect(t, contains('Hay 1 lectura por debajo de 70 % descartada')); expect(t, contains('2 fuera de rango por arriba'));
      final q2 = Quality(1440)..raw = 5..valid = 3..low = 2; expect(coverageText(q2, spo2: true), contains('Hay 2 lecturas por debajo de 70 % descartadas'));
      expect(coverageText(q2, spo2: true), isNot(contains('por arriba')));
    });
    test('cobertura sin posibles no divide por cero', () { expect(Quality(0).coveragePct, 0); expect(coverageText(Quality(0)), 'Lecturas válidas: 0 de 0 posibles (0 %).'); });
    test('repo: un registro de ppgs que cruza la medianoche reparte las lecturas por dia y por su hora', () async {
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 5, 23, 55), 'ppgs': [60, 61, 62, 63, 64, 65, 66, 67, 68, 69]}]}, now: DateTime(2026, 3, 9, 12));
      expect(r.days['2026-03-05']!.hr.length, 5); expect(r.days['2026-03-06']!.hr.length, 5);
      expect(r.days['2026-03-06']!.hr.first.t, DateTime(2026, 3, 6, 0, 0));
    });
  });

  group('E2/E3 casos limite', () {
    test('E2: mediana de las 30 mas bajas con valores distintos (par: media de las dos centrales)', () {
      final v = [for (var i = 0; i < 30; i++) 50 + i, for (var i = 0; i < 40; i++) 100 + i]; // 30 bajas = 50..79 -> (64+65)/2
      expect(restingHrNight(v).value, 64.5);
      expect(restingHrNight([...v.reversed]).value, 64.5); // independiente del orden
    });
    test('E2: todas invalidas -> insuficiente con n = 0 (no "sin datos")', () {
      final n = restingHrNight(List.filled(100, 0)); expect(n.state, NightState.insufficient); expect(n.n, 0);
    });
    test('E2: 30 y 220 incluidos, 29 y 221 excluidos', () {
      final n = restingHrNight([...List.filled(60, 30), 29, 221]); expect(n.n, 60); expect(n.value, 30);
    });
    test('E3 (N1): RR 2550 (centinela del SDK) y 0 no unen vecinos y NO cuentan ni como par ni como correccion', () {
      final m = rmssdMinute([900, 910, 2550, 900, 910, 900, 910, 900, 910, 900]);
      expect(m.pairs, 7); expect(m.corrected, 0); expect(m.rmssd, closeTo(10, 1e-9)); expect(m.noData, isFalse);
      final all = rmssdMinute(List.filled(10, 2550)); expect(all.rmssd, isNull); expect(all.pairs, 0); expect(all.corrected, 0); expect(all.noData, isTrue);
      final z = rmssdMinute([900, 0, 900, 910, 900, 910, 900, 910]); expect(z.corrected, 0); expect(z.pairs, 5);
      // un RR real fuera de rango (ruido, no centinela) SI es una correccion
      final r = rmssdMinute([900, 2300, 900, 910, 900, 910, 900, 910]); expect(r.corrected, 2); expect(r.noData, isFalse);
    });
    test('E3: limites 300 y 2000 validos, 299 y 2001 no; salto exactamente 20 % se acepta', () {
      expect(rmssdMinute([300, 310, 300, 310, 300, 310]).rmssd, isNotNull);
      expect(rmssdMinute([299, 310, 299, 310, 299, 310]).rmssd, isNull);
      expect(rmssdMinute([2000, 1990, 2000, 1990, 2000, 1990]).rmssd, isNotNull);
      expect(rmssdMinute([2001, 1990, 2001, 1990, 2001, 1990]).rmssd, isNull);
    });
    test('E3: lista vacia o de un elemento no falla', () {
      expect(rmssdMinute([]).rmssd, isNull); expect(rmssdMinute([800]).pairs, 0);
    });
    test('N3: 35 validos de 100 con registro -> insuficiente por el 60 %, y el texto lo dice (ya no "35 de 30")', () {
      final n = hrvNight(List.filled(35, 40.0), recordedMinutes: 100);
      expect(n.state, NightState.insufficient); expect(n.insufficientText, 'Sin datos suficientes: 35 de 100 registros válidos (mínimo 60 %)');
      expect(hrvNight(List.filled(20, 40.0), recordedMinutes: 25).insufficientText, 'Sin datos suficientes: 20 de 30 lecturas');
    });
    test('nightBaseline usa las 14 mas recientes (la primera de la lista es la mas reciente)', () {
      final b = nightBaseline([for (var i = 1; i <= 20; i++) i.toDouble()]);
      expect(b.k, 14); expect(b.base, 7.5);
    });
    test('N5 "ultimas 14 noches": las 14 mas recientes con dato DENTRO de los ultimos 30 dias naturales; minimo 7', () async {
      final o5 = <Map>[];
      for (var d = 1; d <= 7; d++) { o5.add({'mTime': _t(2026, 1, d, 1, 0), 'ppgs': List.filled(60, 50)}); } // 7 noches de enero
      o5.add({'mTime': _t(2026, 3, 20, 1, 0), 'ppgs': List.filled(60, 56)}); // y una noche 2 meses despues
      var r = await load({'origin5': o5}, now: DateTime(2026, 3, 21));
      var b = r.nightBase('2026-03-20', r.nightHr); expect(b.k, 0); expect(b.base, isNull); // las de enero quedan fuera de los 30 dias
      expect(r.nightHistory('2026-03-20', r.nightHr).length, 1);
      // 16 noches seguidas dentro de ventana: usa solo las 14 mas recientes; el borde de 30 dias entra (dia -30), el -31 no
      final o6 = <Map>[for (var d = 1; d <= 16; d++) {'mTime': _t(2026, 3, d, 1, 0), 'ppgs': List.filled(60, 40 + d)}];
      r = await load({'origin5': o6}, now: DateTime(2026, 3, 20));
      b = r.nightBase('2026-03-16', r.nightHr); expect(b.k, 14);
      final o7 = <Map>[for (final d in [DateTime(2026, 2, 8), DateTime(2026, 2, 7)]) {'mTime': _t(d.year, d.month, d.day, 1, 0), 'ppgs': List.filled(60, 50)}, {'mTime': _t(2026, 3, 10, 1, 0), 'ppgs': List.filled(60, 50)}];
      r = await load({'origin5': o7}, now: DateTime(2026, 3, 11));
      expect(r.nightBase('2026-03-10', r.nightHr).k, 1); // 8-feb = 30 dias antes del 10-mar: entra; 7-feb (31 dias): no
    });
    test('N6: la noche del dia en curso antes de las 06:00 esta "en curso" y no entra en el historial; despues de las 06:00 ya no', () async {
      final o5 = [for (var d = 1; d <= 3; d++) {'mTime': _t(2026, 3, d, 1, 0), 'ppgs': List.filled(60, 50)}];
      var r = await load({'origin5': o5}, now: DateTime(2026, 3, 3, 2, 30));
      expect(r.nightInProgress('2026-03-03'), isTrue); expect(r.nightInProgress('2026-03-02'), isFalse);
      expect(r.nightHistory('2026-03-03', r.nightHr).last.$2, isNull);
      r = await load({'origin5': o5}, now: DateTime(2026, 3, 3, 6, 0));
      expect(r.nightInProgress('2026-03-03'), isFalse); expect(r.nightHistory('2026-03-03', r.nightHr).last.$2, 50);
    });
    test('N1: ~27 % de RR centinela (2550) con la forma del movil real (registros enteros + algunos mixtos) NO disparan "Calidad baja"; el ruido real excesivo SI', () async {
      final rnd = math.Random(7);
      List<int> rec(double wholeSentinel, double mixed, double noise) {
        if (rnd.nextDouble() < wholeSentinel) return List.filled(10, 2550);
        final rr = <int>[]; var base = 900;
        for (var i = 0; i < 10; i++) { base = (base + (rnd.nextInt(3) - 1) * 10).clamp(850, 950); var v = base; if (rnd.nextDouble() < noise) v = rnd.nextBool() ? 2200 : 450; if (rnd.nextDouble() < mixed) v = 2550; rr.add(v); }
        return rr;
      }
      var sent = 0, tot = 0;
      for (final c in [(0.25, 0.03, 0.0, false), (0.25, 0.03, 0.08, true)]) {
        final hv = [for (var i = 0; i < 240; i++) {'mTime': _t(2026, 3, 5, i ~/ 60, i % 60), 'rrValue': rec(c.$1, c.$2, c.$3)}];
        if (c.$4 == false) { for (final h in hv) { for (final x in h['rrValue'] as List) { tot++; if (x == 2550) sent++; } } }
        final r = await load({'hrv': hv}, now: DateTime(2026, 3, 9));
        final n = r.nightHrv('2026-03-05'); expect(n.state, NightState.data, reason: '$c'); expect(n.lowQuality, c.$4, reason: '$c');
      }
      expect(sent / tot, closeTo(0.27, 0.05)); // la sintetica imita la proporcion real (27 %)
    });
    test('hrv por repo: 130 registros de ~1 min por noche (forma real: 10 RR, centinela 2550) -> los todo-centinela no cuentan y no hay calidad baja', () async {
      final hv = <Map>[];
      for (var i = 0; i < 60; i++) { hv.add({'mTime': _t(2026, 3, 5, 1, i), 'rrValue': i % 5 == 0 ? List.filled(10, 2550) : [900, 910, 900, 910, 900, 910, 900, 910, 900, 910]}); }
      final r = await load({'hrv': hv}, now: DateTime(2026, 3, 9));
      final n = r.nightHrv('2026-03-05'); expect(n.state, NightState.data); expect(n.n, 48); expect(n.recorded, 48); expect(n.value, closeTo(10, 1e-9)); expect(n.lowQuality, isFalse);
    });
  });

  group('E4 limites', () {
    test('semana con todos los dias completos pero sin esfuerzo: 0 min, sin "faltan datos"', () {
      DayAct act(int d) => DayAct(DateTime(2026, 3, d), List.filled(288, 1.1), List.filled(1440, 60), 288, 288);
      final w = weeklyMvpa([act(2), act(3)], DateTime(2026, 3, 3, 20), 184);
      expect(w.byMet, 0); expect(w.byHr, 0); expect(w.missingDays, 0); expect(w.daysElapsed, 2);
    });
    test('domingo: la semana tiene 7 dias transcurridos; lunes siguiente empieza otra', () {
      expect(weeklyMvpa([], DateTime(2026, 3, 8, 23, 59), 184).daysElapsed, 7);
      expect(weeklyMvpa([], DateTime(2026, 3, 9, 0, 0), 184).daysElapsed, 1);
    });
    test('A y B se calculan por separado y B usa 70 % de la FCmax: 129 < 0,7*184 = 128,8 -> cuenta 129 pero no 128', () {
      expect(mvpaMinutesByHr([128, 129, 130], 184), 2);
    });
    test('met NaN no suma', () { expect(mvpaMinutesByMet([double.nan, 3.0]), 5); });
  });

  group('E5 limites', () {
    test('umbral exacto 5 %: 315 vs 300 no avisa; 316 vs 300 si', () {
      expect(deriveSession(315, 1000, 300).paceDiffers, isFalse);
      expect(deriveSession(316, 1000, 300).paceDiffers, isTrue);
      expect(deriveSession(300, 1000, 0).paceDiffers, isFalse); // la pulsera sin ritmo: sin comparacion
    });
    testWidgets('N7: sesion sin calorias muestra "—" y no "0.0 kcal"; ritmo vacio muestra guion', (t) async {
      final r = VigorRepo();
      final s = Session(key: 'k', start: DateTime(2026, 3, 5, 8), sportType: 5, seconds: 600, meters: 0, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: false, route: const [], hrPerMinute: const []);
      await pump(t, SessionPage(r, s));
      expect(find.text('0.0 kcal'), findsNothing); expect(find.text('—'), findsWidgets);
      expect(find.text('Esta actividad no tiene GPS.'), findsOneWidget);
    });
  });

  group('E6 decodificador y E7/E6 aislamiento de release', () {
    test('sleepLine vacio -> 0 min', () { expect(decodeSleepLineNormal('').totalMin, 0); });
    test('Kotlin: sondeo y volcado salen al principio si no es debuggable; MainActivity ignora las llamadas', () {
      final dt = File('android/app/src/main/kotlin/com/careway/vigor_app/DebugTools.kt').readAsStringSync();
      expect(RegExp(r'fun probe\([^)]*\) \{\s*if \(!BandClient\.debuggable\) return').hasMatch(dt), isTrue);
      expect(RegExp(r'fun sleepDump\(\) \{\s*if \(!BandClient\.debuggable\) return').hasMatch(dt), isTrue);
      final ma = File('android/app/src/main/kotlin/com/careway/vigor_app/MainActivity.kt').readAsStringSync();
      expect(ma, contains('"debugClearDumps" -> result.success(if (BandClient.debuggable)'));
      expect(dt, isNot(contains('/sdcard'))); expect(dt, isNot(contains('getExternal')));
    });
    test('Dart: el menu Avanzado solo se construye bajo kDebugMode', () {
      final dp = File('lib/ui/device_page.dart').readAsStringSync();
      expect(dp, contains('if (kDebugMode) Panel(')); // DEV_005: las herramientas viven en AdvancedPage, bajo kDebugMode
      expect(RegExp(r'debugSleepDump|debugProbe').allMatches(dp).length, 2); // un solo sitio de uso
    });
    test('release: debugSleepDump/debugProbe/decodeSleepLineNormal no se usan fuera de device_page/tests (sin UI publica de sueño nueva)', () {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final s = f.readAsStringSync(); final p = f.path.replaceAll('\\', '/');
        if (!p.endsWith('device_page.dart') && !p.endsWith('repo.dart')) { expect(s.contains('debugSleepDump') || s.contains('debugProbe'), isFalse, reason: p); }
        if (!p.endsWith('analysis.dart')) { expect(s.contains('decodeSleepLineNormal'), isFalse, reason: p); }
      }
    });
  });

  group('N28 y UI de ronda 3', () {
    testWidgets('Hoy: glucosa/componentes ocultos con showExperimental=false y visibles (plegados) con true', (t) async {
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 5, 9, 0), 'bloodGlucose': 5.5, 'ppgs': [70, 71, 72, 73, 74]}]}, now: DateTime(2026, 3, 5, 12));
      expect(r.days['2026-03-05']!.glucose, isNotEmpty); // el dato existe, pero no se muestra
      await pump(t, ListenableBuilder(listenable: r, builder: (_, _) => TodayPage(r)));
      await t.scrollUntilVisible(find.textContaining('Fuentes y límites de cada análisis'), 400, scrollable: find.byType(Scrollable).first); // el final de la lista esta construido
      expect(find.textContaining('Experimental'), findsNothing); expect(find.textContaining('Glucosa'), findsNothing);
      r.showExperimental = true; r.notifyListeners(); await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Experimental · no fiable'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('Experimental · no fiable'), findsOneWidget);
    });
    testWidgets('Dispositivo: el interruptor esta apagado de serie, pide confirmacion y persiste exp=1; Cancelar no persiste', (t) async {
      final calls = <MethodCall>[];
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; });
      final r = VigorRepo(); r.conn = 'connected';
      await pump(t, MeasurementsPage(r));
      await t.scrollUntilVisible(find.widgetWithText(SwitchListTile, 'Mostrar métricas experimentales'), 300, scrollable: find.byType(Scrollable).first);
      expect(tester(t), isFalse);
      await t.ensureVisible(find.widgetWithText(SwitchListTile, 'Mostrar métricas experimentales')); await t.pumpAndSettle(); await t.tap(find.widgetWithText(SwitchListTile, 'Mostrar métricas experimentales')); await t.pumpAndSettle();
      expect(find.text('Métricas experimentales'), findsOneWidget);
      await t.tap(find.text('Cancelar')); await t.pumpAndSettle();
      expect(r.showExperimental, isFalse); expect(calls.where((c) => c.method == 'setPref'), isEmpty);
      await t.ensureVisible(find.widgetWithText(SwitchListTile, 'Mostrar métricas experimentales')); await t.pumpAndSettle(); await t.tap(find.widgetWithText(SwitchListTile, 'Mostrar métricas experimentales')); await t.pumpAndSettle();
      await t.tap(find.text('Entiendo, activar')); await t.pumpAndSettle();
      expect(r.showExperimental, isTrue); expect(calls.singleWhere((c) => c.method == 'setPref').arguments, {'key': 'exp', 'value': 1});
    });
    testWidgets('tarjeta E2/E3: textos exactos de la especificacion y Semantics con la frase completa', (t) async {
      final h = t.ensureSemantics();
      final o5 = <Map>[], hv = <Map>[];
      for (var d = 1; d <= 8; d++) {
        o5.add({'mTime': _t(2026, 3, d, 1, 0), 'ppgs': List.filled(60, 50 + d)});
        for (var i = 0; i < 40; i++) { hv.add({'mTime': _t(2026, 3, d, 2, i), 'rrValue': [800, 820, 800, 820, 800, 820, 800, 820, 800, 820]}); }
      }
      final r = await load({'origin5': o5, 'hrv': hv}, now: DateTime(2026, 3, 20));
      await pump(t, ListView(children: [RestingNightCard(r, '2026-03-08'), HrvNightCard(r, '2026-03-08')]));
      expect(find.bySemanticsLabel(RegExp(r'^Pulso en reposo \(noche, aprox\.\): 58 lpm\. \+4 lpm frente a tu mediana de 7 noches$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Variabilidad nocturna \(aprox\.\): 20 ms\. 0 ms frente a tu mediana de 7 noches$')), findsOneWidget);
      expect(find.text('Noche = 00:00–06:00 (aprox.)'), findsNWidgets(2));
      expect(find.text('Estimado con las lecturas más bajas de 00:00 a 06:00. Sirve para ver tu tendencia, no es una puntuación de recuperación ni un dato médico.'), findsOneWidget);
      expect(find.text(hrvLimitText), findsOneWidget);
      h.dispose();
    });
    testWidgets('tarjeta E2: con 5 noches previas dice "Aun sin linea base: 5 de 7 noches"; sin lecturas "Sin datos esta noche."', (t) async {
      final o5 = [for (var d = 1; d <= 6; d++) {'mTime': _t(2026, 3, d, 1, 0), 'ppgs': List.filled(60, 55)}];
      final r = await load({'origin5': o5, 'spo2': [{'mTime': _t(2026, 3, 7, 3, 0), 'oxygenValue': 96}]}, now: DateTime(2026, 3, 20));
      await pump(t, ListView(children: [RestingNightCard(r, '2026-03-06'), RestingNightCard(r, '2026-03-07')]));
      expect(find.text('Aún sin línea base: 5 de 7 noches'), findsOneWidget);
      expect(find.text('Sin datos esta noche.'), findsOneWidget);
    });
    testWidgets('N4 a11y: el aviso "Calidad baja" de la tarjeta HRV esta tambien en la etiqueta semantica', (t) async {
      final h = t.ensureSemantics();
      final hv = [for (var i = 0; i < 60; i++) {'mTime': _t(2026, 3, 5, 1, i), 'rrValue': i % 5 == 0 ? [900, 2300, 900, 450, 900, 2300, 900, 450, 900, 2300] : [900, 910, 900, 910, 900, 910, 900, 910, 900, 910]}];
      final r = await load({'hrv': hv}, now: DateTime(2026, 3, 9));
      await pump(t, ListView(children: [HrvNightCard(r, '2026-03-05')]));
      expect(find.textContaining('Calidad baja'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Calidad baja: más del 5 %')), findsOneWidget);
      h.dispose();
    });
    testWidgets('CoverageCaption: Semantics con la frase y vacio si no hay registros', (t) async {
      final h = t.ensureSemantics();
      final q = Quality(1440)..raw = 10..valid = 7..noData = 3;
      await pump(t, Column(children: [CoverageCaption(q), CoverageCaption(Quality(1440))]));
      expect(find.bySemanticsLabel('Lecturas válidas: 7 de 1440 posibles (0 %).'), findsOneWidget);
      h.dispose();
    });
    testWidgets('N2: la tesela de un dia PASADO con poca cobertura dice "Pocos datos este dia"; "hoy" solo el dia en curso; SpO2/HRV no lo activan', (t) async {
      final h = t.ensureSemantics();
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 5, 9, 0), 'ppgs': [70, 71, 72, 73, 74]}]}, now: DateTime(2026, 3, 9, 12)); // el dia 5 no es hoy
      await pump(t, TodayPage(r));
      expect(find.bySemanticsLabel(RegExp(r'^Pulso: .*Pocos datos este día$')), findsOneWidget); expect(find.bySemanticsLabel(RegExp('Pocos datos hoy')), findsNothing);
      h.dispose();
    });
  });
}

bool tester(WidgetTester t) => t.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Mostrar métricas experimentales')).value;
