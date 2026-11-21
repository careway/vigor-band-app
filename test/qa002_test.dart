// QA_002: pruebas de los arreglos de DEV_001 (JSON y eventos sinteticos, sin datos reales).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/charts.dart';
import 'package:vigor_app/ui/today_page.dart';

const _mc = MethodChannel('vigor/methods');
const _ec = MethodChannel('vigor/events');
Map<String, int> _t(int y, int mo, int d, int h, int mi) => {'year': y, 'month': mo, 'day': d, 'hour': h, 'minute': mi};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() { bm.setMockMethodCallHandler(_mc, null); bm.setMockMethodCallHandler(_ec, null); });

  Future<VigorRepo> load(Map<String, List> data) async {
    bm.setMockMethodCallHandler(_mc, (c) async => c.method == 'getData' ? jsonEncode(data[c.arguments['kind']] ?? []) : null);
    final r = VigorRepo(); await r.reload(); return r;
  }

  group('_t: validacion de fechas (via reload)', () {
    test('anio 1999/2101, mes 13, dia 0, hora 24, minuto 60 se descartan; 2000-01-01 00:00 vale', () async {
      final bad = [_t(1999, 1, 1, 0, 0), _t(2101, 1, 1, 0, 0), _t(2026, 13, 1, 0, 0), _t(2026, 1, 0, 0, 0), _t(2026, 1, 1, 24, 0), _t(2026, 1, 1, 0, 60)];
      final r = await load({'spo2': [for (final t in bad) {'mTime': t, 'oxygenValue': 95}, {'mTime': _t(2000, 1, 1, 0, 0), 'oxygenValue': 95}]});
      expect(r.dayKeys, ['2000-01-01']);
    });
    test('SpO2 69 y 101 se descartan, 70 y 100 valen', () async {
      final r = await load({'spo2': [for (final v in [69, 70, 100, 101]) {'mTime': _t(2026, 3, 5, 8, v % 60), 'oxygenValue': v}]});
      expect(r.days['2026-03-05']!.spo2.map((s) => s.v), [70, 100]);
    });
    test('ppgs: 29 y 221 fuera, 30 y 220 dentro; null y strings dentro de la lista se ignoran', () async {
      final r = await load({'origin5': [{'mTime': _t(2026, 3, 5, 8, 0), 'ppgs': [29, 30, null, '90', 220, 221, double.nan.isNaN ? 100 : 0]}]});
      expect(r.days['2026-03-05']!.hr.map((s) => s.v.round()), [30, 220, 100]);
    });
  });

  group('init / eventos', () {
    test('init con getData fallando y edad invalida: llega a connectSaved, edad por defecto, meta acotada', () async {
      final calls = <String>[];
      bm.setMockMethodCallHandler(_ec, (c) async => null);
      bm.setMockMethodCallHandler(_mc, (c) async {
        calls.add(c.method);
        switch (c.method) {
          case 'savedMac': return 'AA:BB:CC:DD:EE:FF';
          case 'getPrefs': return {'age': 9, 'goal': 999999};
          case 'getData': throw PlatformException(code: 'STORE');
          case 'requestPermissions': return true;
        }
        return null;
      });
      final r = VigorRepo(); await r.init();
      expect(r.loaded, isTrue); expect(r.ageIsDefault, isTrue); expect(r.age, VigorRepo.defaultAge); expect(r.stepGoal, 40000);
      expect(calls, contains('connect'));
      r.dispose();
    });
    test('init con edad valida: ageIsDefault=false; permiso denegado: no se llama a connect', () async {
      final calls = <String>[];
      bm.setMockMethodCallHandler(_ec, (c) async => null);
      bm.setMockMethodCallHandler(_mc, (c) async {
        calls.add(c.method);
        switch (c.method) {
          case 'savedMac': return 'AA:BB:CC:DD:EE:FF';
          case 'getPrefs': return {'age': 50};
          case 'getData': return '[]';
          case 'requestPermissions': return false;
        }
        return null;
      });
      final r = VigorRepo(); await r.init();
      expect(r.ageIsDefault, isFalse); expect(r.age, 50);
      expect(calls, isNot(contains('connect')));
      r.dispose();
    });
    test('setPref acota edad 10..100 y meta 1000..40000', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final r = VigorRepo();
      await r.setPref('age', 0); expect(r.age, 10); expect(r.ageIsDefault, isFalse);
      await r.setPref('age', 300); expect(r.age, 100);
      await r.setPref('goal', 5); expect(r.stepGoal, 1000);
    });
    test('eventos sync start/end: syncing y recarga al terminar; state disconnected', () async {
      var getData = 0;
      bm.setMockMethodCallHandler(_mc, (c) async { if (c.method == 'getData') { getData++; return '[]'; } return null; });
      bm.setMockMethodCallHandler(_ec, (c) async => null);
      final r = VigorRepo(); await r.init(); final base = getData;
      Future<void> send(Map m) => bm.handlePlatformMessage('vigor/events', const StandardMethodCodec().encodeSuccessEnvelope(m), (_) {});
      await send({'type': 'sync', 'value': 'start'}); expect(r.syncing, isTrue);
      await send({'type': 'sync', 'value': 'end'}); expect(r.syncing, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(getData, greaterThan(base)); expect(r.lastSync, isNull); // DEV_012: una sincronización no correcta no cuenta como «última»
      await send({'type': 'sync', 'value': 'start'}); await send({'type': 'sync', 'value': 'end', 'ok': true, 'at': 1900000000000}); expect(r.lastSync, DateTime.fromMillisecondsSinceEpoch(1900000000000));
      await send({'type': 'state', 'value': 'disconnected'}); expect(r.conn, 'disconnected');
      r.dispose();
    });
  });

  group('accesibilidad', () {
    testWidgets('DayDial: accion de aumentar/disminuir avanza por franjas de 30 min y vale 0..1410', (t) async {
      final h = t.ensureSemantics();
      double? got;
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: Builder(builder: (ctx) =>
          DayDial(day: Day('2026-03-05'), c: VC.of(ctx), scrubMin: 100, nowMin: null, onScrub: (v) => got = v, onLock: (_) {})))));
      final n = t.getSemantics(find.byType(DayDial));
      expect(n.label, contains('Reloj del día'));
      expect(n.value, '01:40');
      expect(n.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
      t.semantics.performAction(find.semantics.byLabel(RegExp('Reloj del día')), SemanticsAction.increase); expect(got, 120);
      t.semantics.performAction(find.semantics.byLabel(RegExp('Reloj del día')), SemanticsAction.decrease); expect(got, 60);
      h.dispose();
    });

    testWidgets('Hoy: la tesela de pulso lleva etiqueta con datos verdaderos', (t) async {
      final h = t.ensureSemantics();
      final old = FlutterError.onError; // overflow por fuente Ahem: no es evidencia
      FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) old!(d); };
      addTearDown(() => FlutterError.onError = old);
      final r = VigorRepo(); final d = Day('2026-03-05');
      for (final v in [60.0, 80.0, 100.0]) { d.hr.add(Sample(DateTime(2026, 3, 5, 8, v.toInt() % 60), v)); }
      r.days = {d.date: d}; r.conn = 'connected';
      bm.setMockMethodCallHandler(_mc, (c) async => '[]');
      t.view.physicalSize = const Size(1080, 3300); t.view.devicePixelRatio = 3; // más alto: la leyenda del reloj alarga la pantalla
      addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: Scaffold(body: TodayPage(r))));
      await t.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel(RegExp(r'^Pulso: último \d+ latidos por minuto, mín 60, media 80, máx 100')), findsOneWidget);
      // La etiqueta del centro del reloj (dentro de IgnorePointer) SI llega al arbol semantico.
      expect(find.bySemanticsLabel(RegExp(r'^Pasos: 0 de 8000')), findsOneWidget);
      h.dispose();
    });
  });
}
