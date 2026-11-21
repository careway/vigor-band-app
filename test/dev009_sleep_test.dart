// DEV_009: detalle de sueno. Datos SINTETICOS inventados (nada de noches reales).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vigor_app/ui/sleep_charts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/sleep_page.dart';

Map<String, dynamic> _t(DateTime d) => {'year': d.year, 'month': d.month, 'day': d.day, 'hour': d.hour, 'minute': d.minute, 'second': 0};

/// Noche sintetica: 30 min ligero, 40 profundo, 10 despierto, 30 REM, 3 despiertos cortos, etc.
String _line() => '1' * 30 + '0' * 40 + '4' * 10 + '1' * 20 + '2' * 30 + '4' * 2 + '1' * 40 + '0' * 20 + '4' * 6 + '1' * 22 + '4' * 5;

Future<VigorRepo> _load(List<Map<String, dynamic>> nights) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'),
      (c) async => c.method == 'getData' ? jsonEncode(c.arguments['kind'] == 'sleep' ? nights : []) : null);
  final r = VigorRepo(); await r.reload(); return r;
}

Map<String, dynamic> _night(String date, DateTime down, {String? line, int accurate = 1, int total = 300}) => {
  'Date': date, 'allSleepTime': total, 'deepSleepTime': 60, 'lowSleepTime': total - 60, 'wakeCount': 2, 'accurateType': accurate, 'firstDeepDuration': 30,
  'sleepDown': _t(down), 'sleepUp': _t(down.add(Duration(minutes: total))), 'sleepLine': ?line};

void main() {
  group('decodeStages', () {
    test('modo preciso: 1 char = 1 min, 0 prof, 1 lig, 2 REM, 3/4 despierto, desconocidos ignorados', () {
      final s = decodeStages('01234x', precise: true)!;
      expect(s, [Stage.deep, Stage.light, Stage.rem, Stage.awake, Stage.awake]);
    });
    test('modo normal: 1 char = 5 min, 0 lig, 1 prof, 2 despierto', () {
      final s = decodeStages('012', precise: false)!;
      expect(s.length, 15); expect(s.first, Stage.light); expect(s[5], Stage.deep); expect(s.last, Stage.awake);
    });
    test('vacio o sin validos -> null', () { expect(decodeStages('', precise: true), isNull); expect(decodeStages(null, precise: true), isNull); expect(decodeStages('zz', precise: false), isNull); });
  });

  group('sleepMetrics', () {
    test('totales, eficiencia, despertares >= 5 min entre sueno, tramo mas largo', () {
      final m = sleepMetrics(decodeStages(_line(), precise: true)!);
      expect(m.bedMin, 225); expect(m.deepMin, 60); expect(m.lightMin, 112); expect(m.remMin, 30); expect(m.awakeMin, 23);
      expect(m.asleepMin, 202);
      expect(m.awakenings, 2); // 10 min y 6 min; los 2 min no cuentan; los 5 del final no tienen sueno despues
      expect(m.longestRunMin, 70); // cualquier minuto despierto corta el tramo: 30+40 | 20+30 | 40+20 | 22
      expect(m.efficiency, closeTo(202 / 225, 1e-9));
    });
    test('solo despierto: sin despertares ni sueno', () { final m = sleepMetrics(List.filled(10, Stage.awake)); expect(m.asleepMin, 0); expect(m.awakenings, 0); expect(m.longestRunMin, 0); });
  });

  test('regularidad: cruza medianoche sin partirse y SD solo con >= 3', () {
    expect(minutesFromNoon(DateTime(2026, 1, 1, 23, 30)), 690); expect(minutesFromNoon(DateTime(2026, 1, 2, 0, 30)), 750);
    expect(stdDev([1, 2]), isNull); expect(stdDev([10, 20, 30]), closeTo(10, 1e-9));
    expect(clockFromNoon(750), 30);
  });

  group('Repo y periodo', () {
    test('parsea sleepLine; sin sleepLine cae a totales; siesta < 180', () async {
      final r = await _load([_night('2026-03-05', DateTime(2026, 3, 4, 23, 0), line: _line()), _night('2026-03-04', DateTime(2026, 3, 3, 23, 0)), _night('2026-03-05', DateTime(2026, 3, 5, 15, 0), total: 80, line: '1' * 80)]);
      expect(r.nights.length, 3);
      final a = r.nights.firstWhere((n) => n.stages != null && !n.isNap), b = r.nights.firstWhere((n) => n.stages == null);
      expect(a.precise, isTrue); expect(a.stages!.length, 225); expect(a.firstDeep, 30); expect(b.stages, isNull);
      expect(r.nights.where((n) => n.isNap).length, 1);
    });
    test('SleepPeriod: n de N, media y siestas aparte; pocos datos sin SD', () {
      final ns = [Night('2026-03-05', 420, 90, 300, 1, DateTime(2026, 3, 4, 23), DateTime(2026, 3, 5, 6)), Night('2026-03-03', 360, 80, 250, 0, DateTime(2026, 3, 2, 23, 30), DateTime(2026, 3, 3, 5, 30)), Night('2026-03-05', 60, 5, 55, 0, DateTime(2026, 3, 5, 15), DateTime(2026, 3, 5, 16))];
      final p = SleepPeriod.of(ns, 7, DateTime(2026, 3, 5));
      expect(p.nights.length, 2); expect(p.meanMin, 390); expect(p.naps.length, 1); expect(p.slots.length, 7); expect(p.midN, 2); expect(p.midSd, isNull);
      expect(SleepPeriod.of(const [], 7, DateTime(2026, 3, 5)).meanMin, isNull);
    });
  });

  group('UI', () {
    // Los overflow del test no son evidencia (fuente Ahem: texto mas ancho que el real); se ignoran como en test/a11y_overflow_test.dart.
    // Cualquier otra excepcion falla. El manejador se restaura DENTRO del cuerpo (Flutter lo exige antes de terminar el test).
    void uiTest(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (t) async {
        final old = FlutterError.onError; final other = <Object>[];
        FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) other.add(d.exception); };
        try { await body(t); } finally { FlutterError.onError = old; }
        expect(other, isEmpty, reason: 'excepcion distinta de overflow: $other');
      });
    }
    Future<void> pump(WidgetTester t, VigorRepo r, {double scale = 1, Size size = const Size(320, 700), Brightness b = Brightness.dark}) async {
      t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: w!), home: Scaffold(body: SleepPage(r))));
      await t.pump(const Duration(milliseconds: 100));
    }
    String kd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final today = DateTime.now(); final d0 = DateTime(today.year, today.month, today.day);
    final key1 = kd(d0), key0 = kd(d0.subtract(const Duration(days: 1)));
    VigorRepo repoWith() {
      final r = VigorRepo();
      final down = d0.subtract(const Duration(hours: 1)); // 23:00 de ayer
      r.nights = [Night(key1, 202, 60, 112, 2, down, down.add(const Duration(minutes: 205)), stages: decodeStages(_line(), precise: true), precise: true, firstDeep: 30), Night(key0, 300, 60, 240, 1, d0.subtract(const Duration(hours: 25)), d0.subtract(const Duration(hours: 20)))];
      final d = Day(kd(down)); for (var i = 0; i < 60; i++) { d.hr.add(Sample(down.add(Duration(minutes: i * 3)), 55.0 + i % 7)); }
      r.days = {d.date: d};
      return r;
    }
    for (final scale in [1.0, 2.0]) { for (final b in Brightness.values) {
      uiTest('detalle de noche a 320 px, texto x$scale, $b sin excepciones', (t) async {
        await pump(t, repoWith(), scale: scale, b: b);
        await t.scrollUntilVisible(find.text('Cómo leer este gráfico'), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text('Cómo leer este gráfico'), findsOneWidget);
      });
    } }
    uiTest('arrastrar muestra lectura hora · fase · FC y borrar sigue disponible', (t) async {
      await pump(t, repoWith(), size: const Size(400, 900));
      expect(find.textContaining('Arrastra el dedo'), findsOneWidget);
      final plot = find.descendant(of: find.byType(NightTimeline), matching: find.byType(CustomPaint)).first;
      await t.ensureVisible(plot); await t.pump();
      await t.tapAt(t.getCenter(plot));
      await t.pump();
      expect(find.textContaining(RegExp(r'\d\d:\d\d · (Despierto|REM|Ligero|Profundo)')), findsOneWidget);
      expect(find.byTooltip('Borrar la noche del $key1'), findsOneWidget);
    });
    uiTest('Semantics resume la noche y hay pocos datos explicitos', (t) async {
      await pump(t, repoWith(), size: const Size(400, 900));
      expect(find.bySemanticsLabel(RegExp('Noche del $key1.*dormido.*eficiencia')), findsOneWidget);
      expect(find.textContaining('pocos datos'), findsOneWidget);
      expect(find.textContaining('2 de 7 noches'), findsWidgets);
    });
    uiTest('selector 14/30 cambia el denominador', (t) async {
      await pump(t, repoWith(), size: const Size(400, 900));
      await t.tap(find.text('30')); await t.pump();
      expect(find.textContaining('de 30 noches'), findsWidgets);
    });
  });
}
