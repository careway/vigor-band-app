// DEV_003: ronda 4. Datos sinteticos. Accesibilidad medible (textScaler 2.0, contraste WCAG, areas tactiles), privacidad (exportar/borrar),
// estados de la tesela (E1), noche en curso (N6) y supuestos de datos reales (forma, nunca datos reales).
// LIMITE: flutter_test dibuja con la fuente Ahem (1 em por glifo, mucho mas ancha que Roboto): los desbordes de RenderFlex NO son evidencia y se ignoran;
// aqui solo se comprueba que no hay otras excepciones, que el contenido sigue presente a escala 2.0 y las areas tactiles/semantica.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/ui/widgets.dart';
import 'package:vigor_app/data/analysis.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/metrics.dart';
import 'package:vigor_app/ui/night_cards.dart';
import 'package:vigor_app/ui/sleep_page.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');
Map<String, int> _t(int y, int mo, int d, int h, int mi) => {'year': y, 'month': mo, 'day': d, 'hour': h, 'minute': mi};

double _lin(double v) => v <= .03928 ? v / 12.92 : _pow((v + .055) / 1.055, 2.4);
double _lum(Color c) => .2126 * _lin(c.r) + .7152 * _lin(c.g) + .0722 * _lin(c.b);
double _ratio(Color a, Color b) { final x = _lum(a), y = _lum(b); return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05); }
double _pow(double b, double e) { // exp(e*ln b) sin dart:math para no depender de nada mas
  double ln(double x) { var y = (x - 1) / (x + 1); var s = 0.0, t = y; for (var i = 1; i < 400; i += 2) { s += t / i; t *= y * y; } return 2 * s; }
  final z = e * ln(b); var s = 1.0, t = 1.0; for (var i = 1; i < 80; i++) { t *= z / i; s += t; } return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  Future<VigorRepo> load(Map<String, List> data, {DateTime? now}) async {
    bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'getData' ? jsonEncode(data[c.arguments['kind']] ?? []) : null);
    final r = VigorRepo(); if (now != null) r.clock = () => now; await r.reload(); return r;
  }
  final other = <Object>[];
  Future<void> pump(WidgetTester t, Widget w, {double scale = 1.0, Size size = const Size(360, 1000), Brightness b = Brightness.dark}) async {
    other.clear(); final old = FlutterError.onError;
    FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) other.add(d.exception); };
    addTearDown(() => FlutterError.onError = old);
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: x!), home: Scaffold(body: w)));
    await t.pump(const Duration(seconds: 1));
  }

  VigorRepo rich() {
    final r = VigorRepo(); r.clock = () => DateTime(2026, 3, 5, 20); final d = Day('2026-03-05');
    d.steps = 12345; d.kcal = 999; d.km = 12.3;
    for (var i = 0; i < 100; i++) { final t = DateTime(2026, 3, 5, 8, i % 60); d.hr.add(Sample(t, 70.0 + i % 9)); d.spo2.add(Sample(t, 97)); d.hrv.add(Sample(t, 43)); d.stress.add(Sample(t, 30)); d.met.add(Sample(t, 1.2)); d.temp.add(Sample(t, 36.5)); d.skin.add(Sample(t, 33)); d.steps5.add(Sample(t, 20)); }
    r.days = {d.date: d}; r.conn = 'connected'; r.battery = 80; r.savedMac = 'AA:BB:CC:DD:EE:FF';
    r.sessions = [Session(key: 'k', start: DateTime(2026, 3, 5, 8), sportType: 5, seconds: 1353, meters: 68, kcal: 0, steps: 0, avgHr: 59, paceSecKm: 5999, hasGps: false, route: const [], hrPerMinute: List.filled(23, 58))];
    return r;
  }

  group('D: accesibilidad medible (textScaler 2.0, tamanos de movil reales; fuente Ahem)', () {
    final sizes = {'compacto 360x640': const Size(360, 640), 'estandar 360x780': const Size(360, 780), 'grande 412x915': const Size(412, 915)};
    for (final e in sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Hoy / Actividad / Sueno / Dispositivo / sesion / detalle a ${e.key}, texto x$scale: sin excepciones y contenido presente', (t) async {
          final r = rich();
          await pump(t, TodayPage(r), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other'); expect(find.textContaining('PASOS'), findsOneWidget);
          await pump(t, ActivityPage(r), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other'); expect(find.text('Iniciar'), findsOneWidget);
          await pump(t, SleepPage(r), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other');
          await pump(t, DevicePage(r), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other'); expect(find.text('Sincronizar'), findsOneWidget);
          await pump(t, SessionPage(r, r.sessions.first), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other');
          await pump(t, MetricDetailPage(r, [kHr], '2026-03-05'), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other');
          await pump(t, MetricDetailPage(r, [kHrv], '2026-03-05'), scale: scale, size: e.value); expect(other, isEmpty, reason: '$other');
        });
      }
    }
    testWidgets('Privacidad a x2.0: ambos botones existen y son pulsables (no quedan fuera del arbol)', (t) async {
      await pump(t, ListView(children: [PrivacyPanel(rich())]), scale: 2.0, size: const Size(360, 640));
      expect(other, isEmpty); expect(find.text('Exportar mis datos'), findsOneWidget); expect(find.text('Borrar todos mis datos'), findsOneWidget);
    });
    testWidgets('areas tactiles >= 48 dp y etiquetas en Hoy y Dispositivo (guias de Flutter)', (t) async {
      final h = t.ensureSemantics();
      final r = rich();
      await pump(t, TodayPage(r));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await pump(t, DevicePage(r));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });
    testWidgets('H6: la tesela de Estres lleva visible el rotulo "indice del fabricante · aprox." y Semantics lo dice', (t) async {
      final h = t.ensureSemantics(); final r = rich();
      await pump(t, TodayPage(r));
      await t.scrollUntilVisible(find.text('índice del fabricante · aprox.'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('índice del fabricante · aprox.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Estrés: índice del fabricante, aproximado')), findsOneWidget);
      h.dispose();
    });
    testWidgets('encabezado "Experimental" (visible solo con el interruptor) tambien mide >= 48 dp', (t) async {
      final h = t.ensureSemantics(); final r = rich(); r.showExperimental = true;
      await pump(t, TodayPage(r)); await t.scrollUntilVisible(find.text('Experimental · no fiable'), 400, scrollable: find.byType(Scrollable).first);
      expect(t.getSize(find.ancestor(of: find.text('Experimental · no fiable'), matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(48));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      h.dispose();
    });
    test('contraste WCAG: todo token de texto o metrica >= 4.5:1 sobre bg y surface; graficos >= 3:1 tambien sobre surfaceHi; ambos temas', () {
      for (final e in {'oscuro': VC.dark, 'claro': VC.light}.entries) {
        final c = e.value;
        final texts = {'text': c.text, 'muted': c.muted, 'accent': c.accent, 'accent2': c.accent2, 'danger': c.danger, 'steps': c.steps, 'heart': c.heart, 'spo2': c.spo2, 'hrv': c.hrv, 'stress': c.stress, 'met': c.met, 'temp': c.temp, 'sleep': c.sleep, 'exp': c.exp};
        for (final k in texts.entries) {
          for (final bgName in ['bg', 'surface']) { final bg = bgName == 'bg' ? c.bg : c.surface; expect(_ratio(k.value, bg), greaterThanOrEqualTo(4.5), reason: '${e.key}: ${k.key} sobre $bgName'); }
          expect(_ratio(k.value, c.surfaceHi), greaterThanOrEqualTo(3.0), reason: '${e.key}: ${k.key} sobre surfaceHi');
        }
        expect(_ratio(c.text, c.surfaceHi), greaterThanOrEqualTo(7)); expect(_ratio(c.muted, c.surfaceHi), greaterThanOrEqualTo(4.5));
        final fg = e.key == 'oscuro' ? const Color(0xFF04201C) : Colors.white; // foreground de FilledButton (tokens.dart)
        expect(_ratio(fg, c.accent), greaterThanOrEqualTo(4.5), reason: '${e.key}: texto de boton relleno');
      }
      expect(_ratio(Colors.white, Colors.black), closeTo(21, .01)); // el propio calculo
    });
  });

  group('E: privacidad del usuario (exportar y borrar)', () {
    testWidgets('exportar: llama a exportData, muestra la ruta y los ficheros; sin datos lo dice', (t) async {
      final calls = <String>[];
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); if (c.method == 'exportData') return {'path': 'export', 'files': ['origin5.json', 'hrv.json']}; return null; });
      final r = VigorRepo(); await pump(t, ListView(children: [PrivacyPanel(r)]));
      await t.tap(find.text('Exportar mis datos')); await t.pumpAndSettle();
      expect(calls, ['clearExport', 'exportData']); expect(r.exportFiles.length, 2);
      expect(find.textContaining('Se abrió el selector de compartir con 2 ficheros'), findsOneWidget);
      expect(find.textContaining('fuera del control de Vigor'), findsWidgets);
    });
    testWidgets('exportar con error de la plataforma: mensaje honesto y el boton vuelve a estar activo', (t) async {
      bm.setMockMethodCallHandler(_mc, (c) async { if (c.method == 'exportData') throw PlatformException(code: 'EXPORT'); return null; });
      final r = VigorRepo(); await pump(t, ListView(children: [PrivacyPanel(r)]));
      await t.tap(find.text('Exportar mis datos')); await t.pumpAndSettle();
      expect(find.text('No se pudo exportar los datos.'), findsOneWidget); expect(r.privacyBusy, isFalse);
    });
    testWidgets('borrar: pide confirmacion; Cancelar no llama a wipeData; Borrar todo lo llama y reinicia el estado en Dart', (t) async {
      final calls = <String>[];
      bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); return c.method == 'agpsStatus' ? <String, dynamic>{'downloadedAt': 0, 'pending': false, 'lastError': ''} : null; });
      final r = rich(); r.liveSteps = 5; r.agps = {'lastError': 'viejo'}; r.logs.add('x');
      await pump(t, ListView(children: [PrivacyPanel(r)]));
      await t.tap(find.text('Borrar todos mis datos')); await t.pumpAndSettle();
      expect(find.text('Borrar todos mis datos'), findsNWidgets(2)); // boton + titulo del dialogo
      expect(find.textContaining('No se puede deshacer'), findsOneWidget);
      await t.tap(find.text('Cancelar')); await t.pumpAndSettle();
      expect(calls, ['clearExport']); expect(r.days, isNotEmpty);
      await t.tap(find.text('Borrar todos mis datos')); await t.pumpAndSettle();
      await t.tap(find.text('Borrar todo')); await t.pumpAndSettle();
      expect(calls, contains('wipeData')); expect(r.days, isEmpty); expect(r.sessions, isEmpty); expect(r.nights, isEmpty); expect(r.liveSteps, 0); expect(r.logs, isEmpty);
      expect(r.agps['lastError'], ''); expect(r.exportPath, isNull); expect(find.text('Datos borrados de este móvil.'), findsOneWidget);
      expect(r.savedMac, 'AA:BB:CC:DD:EE:FF'); // el emparejamiento se conserva (lo dice el dialogo)
    });
    testWidgets('borrar con error: conserva los datos en Dart y avisa; con sincronizacion en curso el boton esta desactivado', (t) async {
      bm.setMockMethodCallHandler(_mc, (c) async { if (c.method == 'wipeData') throw PlatformException(code: 'BUSY'); return null; });
      final r = rich(); await pump(t, ListView(children: [PrivacyPanel(r)]));
      await t.tap(find.text('Borrar todos mis datos')); await t.pumpAndSettle(); await t.tap(find.text('Borrar todo')); await t.pumpAndSettle();
      expect(r.days, isNotEmpty); expect(find.textContaining('No se pudo borrar'), findsOneWidget);
      r.syncing = true; r.notifyListeners(); await t.pump();
      expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Borrar todos mis datos')).onPressed, isNull);
    });
    testWidgets('Semantics de la seccion: botones con nombre y mensaje de resultado como region viva', (t) async {
      final h = t.ensureSemantics();
      bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'exportData' ? {'path': '/p/export', 'files': ['a.json']} : null);
      final r = VigorRepo(); await pump(t, ListView(children: [PrivacyPanel(r)]));
      expect(find.bySemanticsLabel('Exportar mis datos'), findsOneWidget); expect(find.bySemanticsLabel('Borrar todos mis datos'), findsOneWidget);
      await t.tap(find.text('Exportar mis datos')); await t.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Se abrió el selector de compartir con 1 ficheros')), findsOneWidget);
      h.dispose();
    });
    testWidgets('Ajustes incluye la categoria "Privacidad y datos" y abre su subpantalla', (t) async {
      await pump(t, SettingsHome(VigorRepo()));
      await t.scrollUntilVisible(find.text('Privacidad y datos'), 300, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Privacidad y datos')); await t.pumpAndSettle();
      expect(find.text('Exportar mis datos'), findsOneWidget);
    });
  });

  group('E1 tres estados tambien en la tesela y N2/N6 en pantalla', () {
    testWidgets('tesela: sin registros -> "Sin datos"; registros pero ninguno valido -> "Sin datos suficientes"; con cifra -> cifra', (t) async {
      final h = t.ensureSemantics();
      final r = await load({'origin5': [
        {'mTime': _t(2026, 3, 5, 9, 0), 'ppgs': [0, 0, 0, 0, 0], 'met': 255, 'pressure': 0}, // todo "sin dato"
      ], 'spo2': []}, now: DateTime(2026, 3, 9, 12));
      await pump(t, TodayPage(r));
      expect(find.bySemanticsLabel(RegExp(r'^Pulso: sin datos suficientes')), findsOneWidget); // hay registros, ninguno valido
      expect(find.bySemanticsLabel(RegExp(r'^Oxígeno en sangre: sin datos')), findsOneWidget); // sin registros
      expect(find.bySemanticsLabel(RegExp(r'^Oxígeno en sangre: sin datos suficientes')), findsNothing);
      expect(find.text('Sin datos suficientes'), findsWidgets); expect(find.text('Sin datos'), findsWidgets);
      h.dispose();
    });
    testWidgets('SpO2 y HRV no activan el punto de pocos datos aunque su cobertura sea < 20 %; el pulso si, y "hoy" solo en el dia en curso', (t) async {
      final h = t.ensureSemantics();
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 9, 9, 0), 'ppgs': [70, 71, 72, 73, 74]}],
        'spo2': [for (var i = 0; i < 30; i++) {'mTime': _t(2026, 3, 9, 3, i), 'oxygenValue': 96}],
        'hrv': [for (var i = 0; i < 30; i++) {'mTime': _t(2026, 3, 9, 3, i), 'rrValue': [800, 820, 800, 820, 800, 820, 800, 820, 800, 820]}]}, now: DateTime(2026, 3, 9, 20));
      await pump(t, TodayPage(r));
      expect(find.bySemanticsLabel(RegExp(r'^Pulso: .*Pocos datos hoy$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Oxígeno en sangre: .*Pocos datos')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Variabilidad cardíaca .*Pocos datos')), findsNothing);
      h.dispose();
    });
    testWidgets('N6: noche en curso (02:00 de hoy) rotulada en la tarjeta, en su Semantics y en la tesela; con 06:00 ya no', (t) async {
      final h = t.ensureSemantics();
      final data = {'origin5': [for (var d = 1; d <= 8; d++) {'mTime': _t(2026, 3, d, 1, 0), 'ppgs': List.filled(60, 50 + d)}]};
      var r = await load(data, now: DateTime(2026, 3, 8, 2, 0));
      await pump(t, ListView(children: [RestingNightCard(r, '2026-03-08')]));
      expect(find.text(nightInProgressText), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Noche en curso: el dato puede cambiar')), findsOneWidget);
      r = await load(data, now: DateTime(2026, 3, 8, 6, 30));
      await pump(t, ListView(children: [RestingNightCard(r, '2026-03-08')]));
      expect(find.text(nightInProgressText), findsNothing);
      h.dispose();
    });
    testWidgets('tarjeta HRV: texto de ventana ultracorta (10 latidos) visible', (t) async {
      final r = await load({}, now: DateTime(2026, 3, 9)); await pump(t, ListView(children: [HrvNightCard(r, '2026-03-05')]));
      await t.tap(find.byType(InfoButton)); await t.pumpAndSettle(); expect(find.textContaining('10 latidos'), findsOneWidget); expect(hrvSampleText, contains('2550'));
    });
  });

  group('B: supuestos de datos reales (forma, no datos)', () {
    test('un registro hrv es UNA medicion de ~10 latidos por minuto (no 60 s de RR): 10 RR de ~0,9 s = ~9 s', () async {
      final r = await load({'hrv': [for (var i = 0; i < 60; i++) {'mTime': _t(2026, 3, 5, 1, i), 'rrValue': [990, 970, 830, 940, 960, 860, 1010, 860, 870, 860], 'rate': '99,97,83,94,96,86,101,86,87,86'}]}, now: DateTime(2026, 3, 9));
      expect(r.days['2026-03-05']!.hrv.length, 60); // 60 registros = 60 minutos con una medicion cada uno
      expect(r.nightHrv('2026-03-05').state, NightState.data);
    });
    test('sportTime en segundos: sesion de 1353 s -> 22 min 33 s y ritmo/velocidad coherentes', () async {
      final r = await load({'sports': [{'_key': 's1', 'startTime': {'year': 2026, 'month': 3, 'day': 5, 'hour': 8, 'minute': 0}, 'sportTime': 1353, 'distance': 1500, 'calories': 0, 'avgPace': 902}], 'sportItems': []}, now: DateTime(2026, 3, 9));
      expect(r.sessions.single.seconds, 1353); expect(r.sessions.single.kcal, 0);
      final d = deriveSession(1353, 1500, 902); expect(d.paceSecKm, 902); expect(d.speedKmh, closeTo(3.99, .01)); expect(d.paceDiffers, isFalse);
    });
  });
}
