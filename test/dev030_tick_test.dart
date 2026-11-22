import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/sports.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/workout_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const mc = MethodChannel('vigor/methods');
  setUp(() => bm.setMockMethodCallHandler(mc, (c) async => null));
  tearDown(() => bm.setMockMethodCallHandler(mc, null));

  Future<VigorRepo> open(WidgetTester t, DateTime Function() clock) async {
    t.view.physicalSize = const Size(1080, 4200); t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final r = VigorRepo(); r.clock = clock; r.mapOn = false; r.workout.begin(sportByKey('OUTDOOR_WALK'));
    r.workout.onReport({'heartRate': 120, 'sportDuration': 60, 'runState': 'RUNNING', 'sportType': 2, 'gpsSignal': 2});
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: WorkoutPage(r)));
    await t.pump(const Duration(milliseconds: 50));
    return r;
  }
  Future<void> close(WidgetTester t, VigorRepo r) async { r.workout.end(); await t.pumpWidget(const SizedBox()); await t.pump(const Duration(seconds: 2)); }

  testWidgets('E1: solo el texto de estado es liveRegion; el tiempo no', (t) async {
    final h = t.ensureSemantics(); final fake = DateTime(2026, 3, 5, 10);
    final r = await open(t, () => fake);
    final time = t.getSemantics(find.bySemanticsLabel(RegExp(r'^Tiempo \d')));
    expect(time.getSemanticsData().flagsCollection.isLiveRegion, false);
    final state = t.getSemantics(find.bySemanticsLabel('En curso'));
    expect(state.getSemanticsData().flagsCollection.isLiveRegion, true);
    await close(t, r); h.dispose();
  });

  testWidgets('E1: cada segundo no se reconstruye el mapa, solo el tiempo', (t) async {
    var fake = DateTime(2026, 3, 5, 10);
    final r = await open(t, () => fake);
    final before = debugLiveMapBuilds; final t0 = find.textContaining(RegExp(r'^\d\d:\d\d$')).evaluate().length;
    expect(t0, 1);
    for (var i = 0; i < 3; i++) { fake = fake.add(const Duration(seconds: 1)); await t.pump(const Duration(seconds: 1)); }
    expect(debugLiveMapBuilds, before, reason: 'el mapa no depende del reloj');
    expect(find.text('01:03'), findsOneWidget, reason: 'el tiempo sí avanza');
    await close(t, r);
  });
}
