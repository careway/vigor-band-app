// DEV_020: interfaz concisa. Ningún texto visible referencia ficheros internos; los avisos largos van detrás de ⓘ.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/about_page.dart';
import 'package:vigor_app/ui/activity_page.dart';
import 'package:vigor_app/ui/device_page.dart';
import 'package:vigor_app/ui/health_page.dart';
import 'package:vigor_app/ui/limits_page.dart';
import 'package:vigor_app/ui/metrics.dart';
import 'package:vigor_app/ui/sleep_page.dart';
import 'package:vigor_app/ui/today_page.dart';
import 'package:vigor_app/ui/widgets.dart';

VigorRepo _repo() {
  final r = VigorRepo();
  final d = Day('2026-03-05');
  d.steps = 4509;
  for (var i = 0; i < 100; i++) { final t = DateTime(2026, 3, 5, 8, i % 60); d.hr.add(Sample(t, 63.0 + i % 5)); d.spo2.add(Sample(t, 97)); d.hrv.add(Sample(t, 40)); }
  r.days = {d.date: d};
  r.conn = 'connected'; r.battery = 80;
  r.nights = [Night('2026-03-05', 420, 90, 300, 1, DateTime(2026, 3, 4, 23), DateTime(2026, 3, 5, 6))];
  r.sessions = [Session(key: 'k1', start: DateTime(2026, 3, 5, 9), sportType: 1, seconds: 1800, meters: 3000, kcal: 100, steps: 0, avgHr: 120, paceSecKm: 0, hasGps: false, route: const [], hrPerMinute: [100, 110, 120, 130])];
  return r;
}

final _other = <Object>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vigor/methods'), (c) async => c.method == 'getData' ? jsonEncode([]) : null));

  Future<void> pump(WidgetTester t, Widget page, {double scale = 1.0, Brightness b = Brightness.dark, Size size = const Size(360, 1200)}) async {
    _other.clear(); final old = FlutterError.onError;
    FlutterError.onError = (d) { if (!d.exceptionAsString().contains('overflowed')) _other.add(d.exception); };
    addTearDown(() => FlutterError.onError = old);
    t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: w!), home: Scaffold(body: page)));
    await t.pump(const Duration(seconds: 1));
  }

  void clean() {
    for (final bad in ['.md', 'docs/', 'ANALISIS', 'Ver docs']) { expect(find.textContaining(bad), findsNothing, reason: 'texto visible con «$bad»'); }
  }

  testWidgets('ninguna pantalla principal ni submenú muestra referencias a ficheros', (t) async {
    final r = _repo();
    final pages = <String, Widget>{
      'Hoy': TodayPage(r), 'Actividad': ActivityPage(r), 'Historial': SessionHistoryPage(r), 'Sesión': SessionPage(r, r.sessions.first), 'Sueño': SleepPage(r),
      'Pulso': MetricDetailPage(r, [kHr], '2026-03-05'), 'SpO2': MetricDetailPage(r, [kSpo2], '2026-03-05'), 'HRV': MetricDetailPage(r, [kHrv], '2026-03-05'),
      'Ajustes': SettingsHome(r), 'Pulsera': DevicePage(r), 'Mediciones': MeasurementsPage(r), 'Sync': SyncSettingsPage(r), 'Deportes': SportSettingsPage(r),
      'Perfil': ProfilePage(r), 'Efemérides': AgpsPage(r), 'Salud': HealthPage(r), 'Privacidad': PrivacyPage(r), 'Apariencia': AppearancePage(r),
      'Acerca': AboutPage(r), 'Límites': const LimitsPage(), 'Avanzado': AdvancedPage(r),
    };
    for (final e in pages.entries) {
      for (final b in [Brightness.dark, Brightness.light]) {
        await pump(t, e.value, b: b);
        expect(_other, isEmpty, reason: '${e.key}: $_other');
        clean();
      }
    }
  });

  testWidgets('las hojas ⓘ tampoco referencian ficheros y los botones miden >= 48 dp', (t) async {
    await pump(t, MetricDetailPage(_repo(), [kSpo2], '2026-03-05'));
    final btn = find.byType(InfoButton).first;
    expect(t.getSize(find.descendant(of: btn, matching: find.byType(IconButton))).shortestSide, greaterThanOrEqualTo(48));
    await t.tap(btn); await t.pumpAndSettle();
    expect(find.textContaining('oxímetro'), findsOneWidget);
    clean();
  });

  testWidgets('Hoy no muestra el resumen ni el menú del día; el borrado de un día sigue en Privacidad', (t) async {
    final r = _repo();
    await pump(t, TodayPage(r));
    expect(find.textContaining('pulso medio'), findsNothing);
    expect(find.byTooltip('Opciones del día'), findsNothing);
    expect(find.textContaining('incroniz'), findsOneWidget);
    await pump(t, PrivacyPage(r));
    expect(find.text('Datos de un día…'), findsOneWidget);
  });

  testWidgets('la privacidad conserva «nada a internet» y el sueño sus estimaciones, en una frase y en ⓘ', (t) async {
    final r = _repo();
    await pump(t, PrivacyPage(r));
    expect(find.textContaining('no envía nada a internet'), findsWidgets);
    await pump(t, SleepPage(r));
    expect(find.textContaining('fases son aproximadas'), findsOneWidget);
  });

  for (final b in [Brightness.dark, Brightness.light]) {
    testWidgets('Ajustes y límites a 320 px y texto doble ($b) sin crash', (t) async {
      for (final w in <Widget>[SettingsHome(_repo()), const LimitsPage(), PrivacyPage(_repo()), TodayPage(_repo())]) {
        await pump(t, w, scale: 2.0, b: b, size: const Size(320, 900));
        expect(_other, isEmpty);
      }
    });
  }
}
