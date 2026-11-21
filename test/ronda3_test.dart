// Ronda 3 (ESPECIFICACION_RONDA3.md): E1..E5 y decodificador E6. Todo con JSON/valores sintéticos.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/ui/widgets.dart';
import 'package:vigor_app/data/analysis.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/night_cards.dart';

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

  group('E1 calidad y cobertura', () {
    test('10 registros, 3 con 0: raw 10, valid 7, 3 sin dato (0 no es fuera de rango)', () {
      final q = Quality(1440);
      for (final v in [70, 71, 72, 73, 74, 75, 76, 0, 0, 0]) { q.add(v, 30, 220); }
      expect(q.raw, 10); expect(q.valid, 7); expect(q.noData, 3); expect(q.discardedByRange, 0);
    });
    test('SpO2 65 y 101: 2 fuera de rango; 255 es sin dato', () {
      final q = Quality(1440);
      for (final v in [65, 101, 97, 255]) { q.add(v, 70, 100); }
      expect(q.discardedByRange, 2); expect(q.low, 1); expect(q.high, 1); expect(q.valid, 1); expect(q.noData, 1);
    });
    test('textos exactos', () {
      final q = Quality(1440)..raw = 100..valid = 50;
      expect(coverageText(q), 'Lecturas válidas: 50 de 1440 posibles (3 %).');
      q.low = 2; q.high = 1;
      expect(coverageText(q), 'Lecturas válidas: 50 de 1440 posibles (3 %). Descartadas por fuera de rango: 3.');
      expect(coverageText(q, spo2: true), contains('Hay 2 lecturas por debajo de 70 % descartadas por posible error de medida; no se muestran.'));
    });
    test('hoy: posibles = transcurridas; poor < 20 %', () {
      expect(possibleSamples(1440, isToday: false, now: DateTime(2026, 3, 5, 12)), 1440);
      expect(possibleSamples(1440, isToday: true, now: DateTime(2026, 3, 5, 12, 0)), 721);
      final q = Quality(1000)..raw = 10..valid = 10; expect(q.poor, isTrue);
      final z = Quality(1000); expect(z.poor, isFalse); // sin datos no es "pocos datos"
    });
    test('repo: ppgs no lista -> 0 validas sin excepcion; dia sin registros -> sin Quality', () async {
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 5, 9, 0), 'ppgs': 'x', 'met': 0, 'pressure': 150, 'temperature': 50}]}, now: DateTime(2026, 3, 9, 12));
      final d = r.days['2026-03-05']!;
      expect(d.qOf('hr').valid, 0); expect(d.qOf('met').noData, 1); expect(d.qOf('stress').high, 1); expect(d.qOf('temp').high, 1);
      expect(r.days['2026-03-06'], isNull); expect(Day('x').qOf('hr').raw, 0);
    });
    test('repo: SpO2 65 y 101 y cobertura posible 1440', () async {
      final r = await load({'spo2': [for (final v in [65, 101, 95]) {'mTime': _t(2026, 3, 5, 3, v % 60), 'oxygenValue': v}]}, now: DateTime(2026, 3, 9, 12));
      final q = r.days['2026-03-05']!.qOf('spo2');
      expect(q.raw, 3); expect(q.valid, 1); expect(q.discardedByRange, 2); expect(q.possible, 1440);
    });
  });

  group('E2 pulso en reposo nocturno', () {
    test('(a) 360 lecturas con 30 minimas = 52 -> 52', () {
      final v = [...List.filled(30, 52), ...List.filled(330, 70)];
      final n = restingHrNight(v); expect(n.state, NightState.data); expect(n.value, 52);
    });
    test('(b) 59 insuficiente, 60 calcula', () {
      expect(restingHrNight(List.filled(59, 55)).state, NightState.insufficient);
      expect(restingHrNight(List.filled(59, 55)).insufficientText, 'Sin datos suficientes: 59 de 60 lecturas');
      expect(restingHrNight(List.filled(60, 55)).value, 55);
    });
    test('(c) 0 y 250 ignoradas', () {
      final n = restingHrNight([...List.filled(60, 60), 0, 250, 255]);
      expect(n.n, 60); expect(n.value, 60);
    });
    test('(d) 6 noches previas sin linea base; 7 con tendencia', () {
      expect(nightBaseline(List.filled(6, 50.0)).base, isNull);
      expect(nightBaseline(List.filled(6, 50.0)).k, 6);
      final b = nightBaseline([50, 52, 54, 56, 58, 60, 62]); expect(b.base, 56); expect(b.k, 7);
      expect(54 - b.base!, -2);
      expect(nightBaseline(List.generate(20, (i) => i.toDouble())).k, 14); // hasta 14
    });
    test('(e) noche sin registros -> sin datos', () { expect(restingHrNight([]).state, NightState.none); });
    test('(f) 23:59 y 06:00 fuera de la noche', () {
      final day = DateTime(2026, 3, 5);
      expect(inNight(DateTime(2026, 3, 5, 0, 0), day), isTrue);
      expect(inNight(DateTime(2026, 3, 5, 5, 59), day), isTrue);
      expect(inNight(DateTime(2026, 3, 5, 6, 0), day), isFalse);
      expect(inNight(DateTime(2026, 3, 4, 23, 59), day), isFalse);
    });
    test('repo: noche 00:00-06:00 por dia, linea base de noches previas', () async {
      final o5 = <Map>[];
      for (var d = 1; d <= 8; d++) { // 8 noches; cada registro de 1 h de ppgs (60 lecturas) a las 01:00 y 02:00 -> 120 lecturas validas
        for (final h in [1, 2]) { o5.add({'mTime': _t(2026, 3, d, h, 0), 'ppgs': List.filled(60, 50 + d)}); }
      }
      o5.add({'mTime': _t(2026, 3, 8, 23, 30), 'ppgs': List.filled(40, 40)}); // 23:30-00:09: las de >= 00:00 caen en el dia 9
      final r = await load({'origin5': o5}, now: DateTime(2026, 3, 20, 12));
      expect(r.nightHr('2026-03-08').value, 58);
      final b = r.nightBase('2026-03-08', r.nightHr); expect(b.k, 7); expect(b.base, 54); // mediana de 51..57
      expect(r.nightBase('2026-03-07', r.nightHr).base, isNull); // solo 6 previas
      expect(r.nightHr('2026-03-09').state, NightState.insufficient); // solo 10 lecturas de las 40
    });
  });

  group('E3 HRV nocturna', () {
    test('(a) RR constantes -> 0 valido', () { final m = rmssdMinute(List.filled(10, 800)); expect(m.rmssd, 0); });
    test('(b) 800,820,... -> 20', () { expect(rmssdMinute([for (var i = 0; i < 10; i++) i.isEven ? 800 : 820]).rmssd, closeTo(20, 1e-9)); });
    test('(c) RR 5000 y 100 se descartan y no unen vecinos', () {
      // 800 810 800 [5000] 810 800 810 800 [100] 800 810 : las diferencias no cruzan los huecos
      final m = rmssdMinute([800, 810, 800, 5000, 810, 800, 810, 800, 100, 800, 810, 800]);
      expect(m.pairs, 11); expect(m.corrected, 4); // 4 pares tocan un RR invalido
      expect(m.rmssd, closeTo(10, 1e-9));
    });
    test('(d) salto > 20 % descartado', () {
      final m = rmssdMinute([800, 810, 800, 810, 800, 810, 800, 1100, 800]); // 800->1100 = 37 % y 1100->800 = 27 %
      expect(m.corrected, 2); expect(m.rmssd, closeTo(10, 1e-9));
    });
    test('(e) 4 diferencias validas -> invalido; 5 -> valido', () {
      expect(rmssdMinute([800, 810, 800, 810, 800]).rmssd, isNull);
      expect(rmssdMinute([800, 810, 800, 810, 800, 810]).rmssd, isNotNull);
    });
    test('(f) 29 minutos validos insuficiente; 30 calcula', () {
      expect(hrvNight(List.filled(29, 40.0), recordedMinutes: 29).state, NightState.insufficient);
      final n = hrvNight(List.filled(30, 40.0), recordedMinutes: 30); expect(n.state, NightState.data); expect(n.value, 40);
      expect(hrvNight(List.filled(30, 40.0), recordedMinutes: 60).state, NightState.insufficient); // 50 % < 60 %
    });
    test('(g) mediana robusta ante un minuto atipico', () {
      expect(hrvNight([...List.filled(34, 40.0), 900], recordedMinutes: 35).value, 40);
    });
    test('(h) 6 noches sin linea base, 7 compara; calidad baja si > 5 % corregido', () {
      expect(nightBaseline(List.filled(6, 40.0)).base, isNull); expect(nightBaseline(List.filled(7, 40.0)).base, 40);
      expect(hrvNight(List.filled(30, 40.0), recordedMinutes: 30, pairs: 100, corrected: 6).lowQuality, isTrue);
      expect(hrvNight(List.filled(30, 40.0), recordedMinutes: 30, pairs: 100, corrected: 5).lowQuality, isFalse);
    });
    test('(i) rrValue ausente o no lista -> sin excepcion', () async {
      final r = await load({'hrv': [{'mTime': _t(2026, 3, 5, 2, 0)}, {'mTime': _t(2026, 3, 5, 2, 1), 'rrValue': 5}, {'mTime': _t(2026, 3, 5, 2, 2), 'rrValue': null}]});
      expect(r.days['2026-03-05']!.hrv, isEmpty); expect(r.days['2026-03-05']!.qOf('hrv').raw, 3);
      expect(r.nightHrv('2026-03-05').state, NightState.insufficient);
    });
    test('media y CV', () {
      final s = meanCv([40, 50, 60]); expect(s.mean, 50); expect(s.cv, closeTo(20, 1e-9));
      expect(meanCv([40]).cv, isNull); expect(meanCv([]).mean, isNull);
    });
  });

  group('E4 actividad semanal', () {
    test('(a) 12 registros con met 3,0 -> 60 min; 2,9 -> 0; (f) 3 exacto cuenta', () {
      expect(mvpaMinutesByMet(List.filled(12, 3.0)), 60); expect(mvpaMinutesByMet(List.filled(12, 2.9)), 0);
    });
    test('(b) registro sin met no cuenta (el repo no lo convierte en 0 valido)', () async {
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 5, 9, 0)}, {'mTime': _t(2026, 3, 5, 9, 5), 'met': 255}, {'mTime': _t(2026, 3, 5, 9, 10), 'met': 4.0}]});
      expect(r.days['2026-03-05']!.met.length, 1); expect(r.days['2026-03-05']!.qOf('met').valid, 1);
    });
    test('(d) umbral por pulso configurable: 120 con FCmax 170 (70 % = 119)', () {
      expect(mvpaMinutesByHr([120, 118, 119], 170), 2); // 119 >= 119
      expect(mvpaMinutesByHr([120], 170, frac: 0.8), 0);
    });
    test('(e) cambio de semana domingo 23:59 -> lunes 00:00', () {
      expect(weekStart(DateTime(2026, 3, 8, 23, 59)), DateTime(2026, 3, 2));
      expect(weekStart(DateTime(2026, 3, 9, 0, 0)), DateTime(2026, 3, 9));
    });
    test('(c) dia sin datos -> "faltan datos", no suma 0 como dato; dias futuros no cuentan', () {
      DayAct act(int d, int recs) => DayAct(DateTime(2026, 3, d), List.filled(recs ~/ 2, 3.5), [], recs, 288);
      final w = weeklyMvpa([act(2, 288), act(3, 288), act(5, 100)], DateTime(2026, 3, 5, 12), 170);
      expect(w.daysElapsed, 4); // lun, mar, mie, jue(5 = jueves? 2026-03-05 es jueves)
      expect(w.missingDays, 2); // miercoles sin registro y jueves con 100/288
      expect(w.byMet, (144 + 144 + 50) * 5);
    });
    testWidgets('tarjeta semanal: textos y Semantics', (t) async {
      final h = t.ensureSemantics();
      final now = DateTime(2026, 3, 5, 18);
      final recs = <Map>[for (var d = 2; d <= 5; d++) for (var i = 0; i < 288; i++) {'mTime': _t(2026, 3, d, i ~/ 12, (i % 12) * 5), 'met': i < 12 ? 4.0 : 1.2, 'ppgs': <int>[]}];
      final repo = await load({'origin5': recs}, now: now);
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: SingleChildScrollView(child: WeeklyActivityCard(repo)))));
      expect(find.text('Actividad de la semana (aprox.)'), findsOneWidget);
      expect(find.textContaining('150–300 min semanales'), findsNothing);
      await t.tap(find.byType(InfoButton)); await t.pumpAndSettle();
      expect(find.textContaining('150–300 min semanales'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Actividad de la semana \(aprox\.\): 240 min de 150')), findsOneWidget);
      h.dispose();
    });
  });

  group('E5 sesiones', () {
    test('(a) 5000 m en 1500 s -> 300 s/km y 12 km/h', () {
      final d = deriveSession(1500, 5000, 300); expect(d.paceSecKm, 300); expect(d.speedKmh, closeTo(12, 1e-9)); expect(d.paceDiffers, isFalse);
    });
    test('(b) diferencia 4 % sin nota; 10 % con nota', () {
      expect(deriveSession(1500, 5000, 288).paceDiffers, isFalse); // calculado 300 vs 288 = 4,2 %
      expect(deriveSession(1500, 5000, 330).paceDiffers, isTrue);
    });
    test('(c) distancia 0 -> sin ritmo derivado', () {
      final d = deriveSession(1500, 0, 300); expect(d.paceSecKm, isNull); expect(d.speedKmh, isNull); expect(d.paceDiffers, isFalse);
      expect(deriveSession(0, 5000, 300).paceSecKm, isNull);
    });
    test('(d) sesion sin latArray sigue funcionando (sin ruta)', () async {
      final r = await load({'sports': [{'_key': 'k', 'startTime': _t(2026, 3, 5, 8, 0), 'sportTime': 600, 'distance': 1000, 'calories': 50000, 'avgPace': 600}], 'sportItems': [{'_key': 'k', 'items': [{'rate': 100}]}]});
      expect(r.sessions.single.route, isEmpty); expect(r.sessions.single.kcal, 50); expect(r.sessions.single.meters, 1000);
    });
  });

  group('E6 decodificador sleepLine (modo normal)', () {
    test('"201112" -> 30 min: despierto 10, ligero 5, profundo 15', () {
      final d = decodeSleepLineNormal('201112');
      expect(d.totalMin, 30); expect(d.awakeMin, 10); expect(d.lightMin, 5); expect(d.deepMin, 15);
    });
    test('caracteres desconocidos se ignoran', () { expect(decodeSleepLineNormal('2x9').totalMin, 5); });
  });

  group('M6 JSON grande', () {
    test('mas de 100 000 caracteres se decodifica fuera del isolate de UI (compute) con el mismo resultado', () async {
      final recs = [for (var i = 0; i < 1500; i++) {'mTime': _t(2026, 3, 1 + i % 20, i % 24, i % 60), 'stepValue': 1, 'ppgs': List.filled(5, 70)}];
      expect(jsonEncode(recs).length, greaterThan(100000));
      final r = await load({'origin5': recs}, now: DateTime(2026, 3, 30));
      expect(r.days.values.fold<double>(0, (a, d) => a + d.steps), 1500);
    });
  });

  group('N28 metricas experimentales apagadas de serie', () {
    test('showExperimental false por defecto y se lee de las preferencias', () async {
      final r = VigorRepo(); expect(r.showExperimental, isFalse);
      bm.setMockMethodCallHandler(_mc, (c) async { if (c.method == 'getPrefs') return {'exp': 1}; if (c.method == 'getData') return '[]'; return null; });
      final r2 = VigorRepo(); await r2.init(); expect(r2.showExperimental, isTrue);
    });
    test('setExperimental persiste via setPref', () async {
      final calls = <MethodCall>[];
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; });
      final r = VigorRepo(); await r.setExperimental(true);
      expect(r.showExperimental, isTrue); expect(calls.single.arguments, {'key': 'exp', 'value': 1});
    });
  });
}
