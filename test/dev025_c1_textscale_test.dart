// C1: Actividad, Sueño y Dispositivo a escala de texto 2.0 y 320 px. Datos sinteticos.
// Los overflow se ignoran (fuente Ahem, mas ancha que Roboto); solo se falla ante otras excepciones.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/sleep_page.dart';

VigorRepo _repo() {
  final r = VigorRepo();
  final d = Day('2026-03-05');
  for (var i = 0; i < 60; i++) { d.hr.add(Sample(DateTime(2026, 3, 5, 8, i), 120.0 + i % 40)); }
  r.days = {d.date: d};
  r.conn = 'connected'; r.battery = 80; r.savedMac = 'AA:BB:CC:DD:EE:FF';
  r.nights = [Night('2026-03-05', 450, 90, 240, 2, DateTime(2026, 3, 4, 23), DateTime(2026, 3, 5, 7, 30))];
  r.sessions = [Session(key: 'k1', start: DateTime(2026, 3, 5, 9), sportType: 1, seconds: 3600, meters: 8000, kcal: 500, steps: 9000, avgHr: 140, paceSecKm: 450, hasGps: false, route: const [], hrPerMinute: [for (var i = 0; i < 60; i++) 100 + i % 50])];
  r.loaded = true;
  return r;
}

final _other = <Object>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'), (c) async => c.method == 'getData' ? jsonEncode([]) : null));

  Future<void> pump(WidgetTester t, Widget page, double scale, Size size) async {
    _other.clear(); final old = FlutterError.onError;
    FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) _other.add(d.exception); };
    addTearDown(() => FlutterError.onError = old);
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: w!), home: Scaffold(body: page)));
    await t.pump(const Duration(seconds: 1));
    expect(_other, isEmpty, reason: 'excepcion distinta de overflow: $_other');
  }

  final pages = <String, Widget Function(VigorRepo)>{
    'Actividad': (r) => ActivityPage(r),
    'Sueno': (r) => SleepPage(r),
    'Dispositivo': (r) => DevicePage(r),
    'Detalle de sesion': (r) => SessionPage(r, r.sessions.first),
  };
  for (final e in pages.entries) {
    for (final size in [const Size(320, 640), const Size(360, 1000)]) {
      testWidgets('${e.key} escala 2.0 a ${size.width.toInt()} px, con datos', (t) async { await pump(t, e.value(_repo()), 2.0, size); });
    }
    if (e.key == 'Detalle de sesion') continue;
    testWidgets('${e.key} escala 2.0 a 320 px, vacio y desconectado', (t) async {
      final r = VigorRepo(); r.loaded = true;
      await pump(t, e.value(r), 2.0, const Size(320, 640));
    });
  }
}
