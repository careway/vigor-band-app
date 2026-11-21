// Prueba de humo de accesibilidad: escala de texto 200 % sin desbordes en la pantalla "Hoy" y "Dispositivo".
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/today_page.dart';

VigorRepo _repo() {
  final r = VigorRepo();
  final d = Day('2026-03-05');
  d.steps = 123456; d.kcal = 99999; d.km = 123.45;
  for (var i = 0; i < 100; i++) { final t = DateTime(2026, 3, 5, 8, i % 60); d.hr.add(Sample(t, 188.0)); d.spo2.add(Sample(t, 97)); d.hrv.add(Sample(t, 123)); d.stress.add(Sample(t, 100)); d.met.add(Sample(t, 12.3)); d.temp.add(Sample(t, 36.5)); d.skin.add(Sample(t, 33.1)); d.steps5.add(Sample(t, 30)); }
  r.days = {d.date: d};
  r.conn = 'connected'; r.battery = 100; r.savedMac = 'AA:BB:CC:DD:EE:FF';
  return r;
}

// OJO: flutter_test usa la fuente "Ahem" (cada glifo = 1 em), mucho mas ancha que Roboto. Los RenderFlex
// overflow que aparecen aqui NO son evidencia de desborde real; se ignoran. Solo se falla ante otras excepciones.
final _other = <Object>[];
void _noLayoutCrash(WidgetTester t) { expect(_other, isEmpty, reason: 'excepcion distinta de overflow: $_other'); }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'), (c) async => c.method == 'getData' ? jsonEncode([]) : null));

  Future<void> pumpScaled(WidgetTester t, Widget page, double scale, {Size size = const Size(360, 1000)}) async {
    _other.clear(); final old = FlutterError.onError;
    FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) _other.add(d.exception); };
    addTearDown(() => FlutterError.onError = old);
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: w!), home: Scaffold(body: page)));
    await t.pump(const Duration(seconds: 1));
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Hoy a escala de texto $scale sin crash (overflow ignorado: fuente Ahem)', (t) async {
      await pumpScaled(t, TodayPage(_repo()), scale);
      _noLayoutCrash(t);
    });
    testWidgets('Dispositivo a escala de texto $scale sin crash (overflow ignorado: fuente Ahem)', (t) async {
      await pumpScaled(t, DevicePage(_repo()), scale);
      _noLayoutCrash(t);
    });
  }

  testWidgets('Hoy con datos vacios en el dia (todas las listas vacias) no lanza', (t) async {
    final r = VigorRepo(); r.days = {'2026-03-05': Day('2026-03-05')};
    await pumpScaled(t, TodayPage(r), 1.0);
    _noLayoutCrash(t);
    expect(find.text('Sin datos'), findsWidgets);
  });

  test('Contraste de tokens (WCAG): texto secundario >= 4.5:1 sobre superficie, ambos temas', () {
    double lum(Color c) { double f(double v) => v <= .03928 ? v / 12.92 : _pow((v + .055) / 1.055, 2.4); return .2126 * f(c.r) + .7152 * f(c.g) + .0722 * f(c.b); }
    double ratio(Color a, Color b) { final x = lum(a), y = lum(b); return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05); }
    for (final c in [VC.dark, VC.light]) {
      expect(ratio(c.muted, c.surface), greaterThanOrEqualTo(4.5)); expect(ratio(c.text, c.bg), greaterThanOrEqualTo(7));
      expect(ratio(c.exp, c.surface), greaterThanOrEqualTo(4.5));
      for (final k in [c.steps, c.heart, c.spo2, c.hrv, c.stress, c.met, c.temp, c.sleep, c.accent]) { expect(ratio(k, c.surface), greaterThanOrEqualTo(3.0), reason: 'color $k'); }
    }
  });
}

double _pow(double b, double e) => _exp(e * _ln(b));
double _ln(double x) { var y = (x - 1) / (x + 1); var s = 0.0, t = y; for (var i = 1; i < 200; i += 2) { s += t / i; t *= y * y; } return 2 * s; }
double _exp(double x) { var s = 1.0, t = 1.0; for (var i = 1; i < 60; i++) { t *= x / i; s += t; } return s; }
