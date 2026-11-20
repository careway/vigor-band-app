// QA_004: casos limite de linea base 30 d / noche en curso / centinelas HRV / glucosa oculta / textos. Datos sinteticos.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/analysis.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/night_cards.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');
Map<String, int> _t(int y, int mo, int d, int h, int mi) => {'year': y, 'month': mo, 'day': d, 'hour': h, 'minute': mi};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  Future<VigorRepo> load(Map<String, List> data, DateTime now) async {
    bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'getData' ? jsonEncode(data[c.arguments['kind']] ?? []) : null);
    final r = VigorRepo()..clock = () => now; await r.reload(); return r;
  }
  // 70 lecturas de pulso en la madrugada (00:00-05:xx) de [day]: 14 registros origin5 de 5 valores = 70 min; valor [v].
  List<Map> nightHr(DateTime day, int v) => [for (var i = 0; i < 14; i++) {'mTime': _t(day.year, day.month, day.day, i ~/ 12, (i % 12) * 5), 'ppgs': List.filled(5, v)}];

  group('QA_004 linea base de 30 dias: casos limite', () {
    test('exactamente 7 noches validas en la ventana -> hay linea base (mediana de 7); con 6 no', () async {
      final now = DateTime(2026, 6, 20, 12);
      final o5 = <Map>[]; for (var i = 1; i <= 7; i++) { o5.addAll(nightHr(DateTime(2026, 6, 20 - i), 50 + i)); }
      o5.addAll(nightHr(DateTime(2026, 6, 20), 60));
      var r = await load({'origin5': o5}, now);
      var b = r.nightBase('2026-06-20', r.nightHr);
      expect(b.k, 7); expect(b.base, 54); // mediana de 51..57
      o5.removeWhere((e) => e['mTime']['day'] == 13);
      r = await load({'origin5': o5}, now);
      b = r.nightBase('2026-06-20', r.nightHr);
      expect(b.k, 6); expect(b.base, isNull);
    });
    test('dias sin datos en medio no cuentan ni se rellenan; el borde de 30 dias es inclusivo (-30 entra, -31 no) incluso a traves de un cambio de hora', () async {
      // 2026-03-29 es el cambio de hora europeo; la ventana se calcula por fecha de calendario, no por 24 h * 30.
      final now = DateTime(2026, 4, 5, 12);
      final o5 = <Map>[];
      for (final d in [DateTime(2026, 3, 6), DateTime(2026, 3, 5), DateTime(2026, 3, 28), DateTime(2026, 3, 30)]) { o5.addAll(nightHr(d, 55)); }
      o5.addAll(nightHr(DateTime(2026, 4, 5), 60));
      final r = await load({'origin5': o5}, now);
      final ks = r.nightBase('2026-04-05', r.nightHr);
      // 2026-04-05 - 30 d = 2026-03-06 (entra); 03-05 (-31) no entra. Con dias 03-06, 03-28, 03-30 -> 3 noches.
      expect(ks.k, 3);
    });
    test('mas de 14 noches validas: solo las 14 mas recientes', () async {
      final now = DateTime(2026, 6, 25, 12); final o5 = <Map>[];
      for (var i = 1; i <= 20; i++) { o5.addAll(nightHr(DateTime(2026, 6, 25 - i), i <= 14 ? 50 : 90)); }
      o5.addAll(nightHr(DateTime(2026, 6, 25), 50));
      final r = await load({'origin5': o5}, now);
      final b = r.nightBase('2026-06-25', r.nightHr); expect(b.k, 14); expect(b.base, 50);
    });
    test('noche en curso: 05:59 si, 06:00 no; un dia pasado nunca; y la de hoy no entra en su propia historia', () async {
      final o5 = nightHr(DateTime(2026, 6, 20), 52);
      var r = await load({'origin5': o5}, DateTime(2026, 6, 20, 5, 59));
      expect(r.nightInProgress('2026-06-20'), isTrue); expect(r.nightInProgress('2026-06-19'), isFalse);
      expect(r.nightHistory('2026-06-20', r.nightHr).last.$2, isNull);
      r = await load({'origin5': o5}, DateTime(2026, 6, 20, 6, 0));
      expect(r.nightInProgress('2026-06-20'), isFalse);
      expect(r.nightHistory('2026-06-20', r.nightHr).last.$2, 52);
    });
    test('clave de dia invalida: sin ventana y sin excepcion', () async {
      final r = await load({'origin5': nightHr(DateTime(2026, 6, 20), 52)}, DateTime(2026, 6, 21, 12));
      expect(r.nightBase('xx', r.nightHr).k, 0);
    });
  });

  group('QA_004 HRV con centinelas', () {
    test('registro mixto: 2550 en medio rompe la cadena (no une latidos vecinos) y no cuenta como correccion', () {
      final m = rmssdMinute([900, 910, 2550, 905, 915, 900, 910, 905, 915, 900]);
      expect(m.pairs, 7); expect(m.corrected, 0); expect(m.rmssd, isNotNull);
    });
    test('RR reales fuera de rango SI cuentan como correccion (ruido), a diferencia del centinela', () {
      final m = rmssdMinute([900, 250, 900, 910, 905, 915, 900, 2300, 900, 905]);
      expect(m.corrected, greaterThan(0)); expect(m.noData, isFalse);
    });
    test('un valor 2550 en rmssd() (funcion antigua) tambien queda excluido; 2499 no', () {
      expect(rmssd([900, 905, 910, 915, 920, 2550]), isNotNull);
      expect(rmssd([900, 2550, 2550, 2550, 2550, 2550]), isNull);
    });
    test('calidad baja a nivel de noche: >5 % de pares corregidos -> true; exactamente 5 % -> false; sin pares reales -> false', () {
      final v = List<double>.filled(40, 40);
      expect(hrvNight(v, recordedMinutes: 40, pairs: 100, corrected: 6).lowQuality, isTrue);
      expect(hrvNight(v, recordedMinutes: 40, pairs: 100, corrected: 5).lowQuality, isFalse);
      expect(hrvNight(v, recordedMinutes: 40, pairs: 0, corrected: 0).lowQuality, isFalse);
    });
    test('noche con 100 % de registros todo-centinela: estado "sin datos" (none), no "insuficiente con 0 de 30"', () async {
      final hv = [for (var i = 0; i < 40; i++) {'mTime': _t(2026, 6, 19, 1, i), 'rrValue': List.filled(10, 2550)}];
      final r = await load({'hrv': hv}, DateTime(2026, 6, 20, 12));
      expect(r.nightHrv('2026-06-19').state, NightState.none);
    });
    test('un registro hrv con rrValue ausente o no lista no revienta la carga', () async {
      final r = await load({'hrv': [{'mTime': _t(2026, 6, 19, 1, 0)}, {'mTime': _t(2026, 6, 19, 1, 1), 'rrValue': 'x'}, {'mTime': _t(2026, 6, 19, 1, 2), 'rrValue': [null, 'a', 900]}]}, DateTime(2026, 6, 20, 12));
      expect(r.days['2026-06-19'], isNotNull);
    });
  });

  group('QA_004 glucosa y textos', () {
    test('glucosa y componentes ocultos de serie (flag apagado) aunque haya datos', () async {
      final r = await load({'origin5': [{'mTime': _t(2026, 6, 20, 8, 0), 'bloodGlucose': 5.5, 'bloodComponent': {'uricAcid': 300}, 'ppgs': [70, 71, 72, 73, 74]}]}, DateTime(2026, 6, 20, 12));
      expect(r.showExperimental, isFalse);
      expect(r.days['2026-06-20']!.glucose, isNotEmpty); // se guardan, pero la UI no los muestra sin el interruptor
    });
    testWidgets('pantalla Hoy sin el interruptor: no aparece "Glucosa" ni "Experimental"', (t) async {
      final r = await load({'origin5': [{'mTime': _t(2026, 6, 20, 8, 0), 'bloodGlucose': 5.5, 'ppgs': [70, 71, 72, 73, 74]}]}, DateTime(2026, 6, 20, 12));
      t.view.physicalSize = const Size(1080, 2340); t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: TodayPage(r))));
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('Glucosa'), findsNothing); expect(find.textContaining('Experimental'), findsNothing);
    });
    test('textos de la UI nocturna: sin lenguaje de diagnostico ni de recuperacion/puntuacion como afirmacion', () {
      for (final s in [hrvLimitText, hrvSampleText, hrvLowQualityText, nightInProgressText]) {
        expect(s.toLowerCase(), isNot(contains('diagn')), reason: s);
        expect(s.toLowerCase(), isNot(contains('normal')), reason: s);
      }
      expect(hrvLimitText, contains('Aprox'));
    });
  });
}
