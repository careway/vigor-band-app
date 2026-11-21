import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/sports.dart';
import 'package:vigor_app/data/workout.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/workout_ui.dart';

const _mc = MethodChannel('vigor/methods');
// Informes sintéticos con la forma del SDK (SportControlDataInfo) y sus unidades documentadas: calorías en calorías y velocidad en m/h.
Map<String, Object?> _rep({Object? hr = 140, Object? dist = 1200, Object? pace = 330, Object? dur = 600, String run = 'RUNNING', Object? type = 1, Object? gps = 2, Object? kcal = 80000, Object? speed = 11500}) =>
    {'heartRate': hr, 'distance': dist, 'pace': pace, 'sportDuration': dur, 'runState': run, 'sportType': type, 'gpsSignal': gps, 'calories': kcal, 'speed': speed};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() { calls.clear(); bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; }); });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  group('qué datos según el tipo de actividad', () {
    List<WorkoutField> f(String key) => workoutFields(sportByKey(key));
    test('carrera y caminata al aire libre: distancia, ritmo, pulso, calorías y señal GPS', () {
      expect(f('OUTDOOR_RUNNING'), [WorkoutField.distance, WorkoutField.pace, WorkoutField.heartRate, WorkoutField.calories, WorkoutField.gps]);
      expect(f('OUTDOOR_WALK'), contains(WorkoutField.pace)); expect(f('OUTDOOR_WALK'), contains(WorkoutField.gps));
    });
    test('ciclismo: velocidad en lugar de ritmo', () { final l = f('OUTDOOR_RIDING'); expect(l, contains(WorkoutField.speed)); expect(l, isNot(contains(WorkoutField.pace))); });
    test('correr en interior: sin señal GPS', () { expect(f('INDOOR_RUNNING'), isNot(contains(WorkoutField.gps))); expect(f('INDOOR_RUNNING'), contains(WorkoutField.distance)); });
    test('gimnasio y fitness: solo pulso y calorías', () { expect(f('FITNESS'), [WorkoutField.heartRate, WorkoutField.calories]); });
    test('una actividad desconocida (null) muestra lo mínimo seguro', () { expect(workoutFields(null), [WorkoutField.heartRate, WorkoutField.calories]); });
  });

  group('informe de la pulsera', () {
    test('se sanea: pulso fuera de 30-230, ritmo absurdo, cifras negativas o texto → null; nunca se inventa', () {
      final r = WorkoutReport.parse(_rep(hr: 0, pace: 5, dist: -3, kcal: 'x', speed: 400000, dur: -1));
      expect(r.heartRate, isNull); expect(r.paceSecKm, isNull); expect(r.distanceM, isNull); expect(r.kcal, isNull); expect(r.speedKmh, isNull); expect(r.durationSec, isNull);
      final ok = WorkoutReport.parse(_rep()); expect(ok.heartRate, 140); expect(ok.distanceM, 1200); expect(ok.paceSecKm, 330); expect(ok.durationSec, 600);
      expect(ok.kcal, closeTo(80, 1e-9), reason: 'el SDK da calorías (no kcal): 80000 cal = 80 kcal'); expect(ok.speedKmh, closeTo(11.5, 1e-9), reason: 'el SDK da m/h: 11500 m/h = 11,5 km/h');
    });
    test('estado: pausa y fin por el texto del estado', () {
      expect(WorkoutReport.parse(_rep(run: 'PAUSED')).isPaused, true); expect(WorkoutReport.parse(_rep(run: 'FINISHED')).isEnded, true); expect(WorkoutReport.parse(_rep(run: 'NOT_STARTED')).isEnded, false); expect(WorkoutReport.parse(_rep(run: 'RESUMING')).isPaused, false); expect(WorkoutReport.parse(_rep(run: 'RUNNING')).isEnded, false);
      expect(WorkoutReport.parse({}).heartRate, isNull);
    });
    test('texto del cronómetro y del ritmo', () {
      expect(clockText(const Duration(seconds: 65)), '01:05'); expect(clockText(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03'); expect(clockText(Duration.zero), '00:00');
      expect(paceText(330), '5:30'); expect(paceText(359.6), '6:00'); expect(paceText(null), '—'); expect(paceText(0), '—');
    });
  });

  group('actividad en curso', () {
    late DateTime now; LiveWorkout mk({Duration give = const Duration(minutes: 45)}) => LiveWorkout(clock: () => now, giveUpAfter: give);
    setUp(() => now = DateTime(2026, 3, 5, 10));
    test('empieza al iniciarla desde la app y el reloj corre en el móvil', () {
      final w = mk(); w.begin(sportByKey('OUTDOOR_RUNNING')); expect(w.active, true); expect(w.elapsed(), Duration.zero);
      now = now.add(const Duration(seconds: 90)); expect(w.elapsed(), const Duration(seconds: 90));
    });
    test('un informe ancla el reloj a la duración que da la pulsera y guarda pulso, distancia y demás', () {
      final w = mk(); w.begin(sportByKey('OUTDOOR_RUNNING')); now = now.add(const Duration(seconds: 100));
      w.onReport(_rep(dur: 120)); expect(w.elapsed(), const Duration(seconds: 120)); expect(w.heartRate, 140); expect(w.distanceM, 1200); expect(w.gpsSignal, 2);
      now = now.add(const Duration(seconds: 5)); expect(w.elapsed(), const Duration(seconds: 125));
    });
    test('iniciada desde la pulsera: aparece sola con el modo que dice el informe', () {
      final w = mk(); expect(w.active, false); w.onReport(_rep(type: 2)); expect(w.active, true); expect(w.mode?.id, 2);
    });
    test('un campo ausente en un informe conserva el último valor bueno', () {
      final w = mk(); w.onReport(_rep()); w.onReport(_rep(hr: 0, dist: null)); expect(w.heartRate, 140); expect(w.distanceM, 1200);
    });
    test('la gráfica de pulso acumula una muestra por informe con pulso y no pasa del tope', () {
      final w = mk(); for (var i = 0; i < 700; i++) { w.onReport(_rep(hr: 100 + i % 50)); } expect(w.hrSamples.length, LiveWorkout.maxSamples); expect(w.maxHr, 149);
    });
    test('pausa y fin por el estado del informe; terminar no deja la actividad activa', () {
      final w = mk(); w.onReport(_rep(run: 'PAUSED')); expect(w.paused, true); w.onReport(_rep(run: 'RUNNING')); expect(w.paused, false);
      w.onReport(_rep(run: 'FINISHED')); expect(w.active, false);
    });
    test('sin noticias de la pulsera: pasa a «sin datos» y, pasado un tiempo largo, se da por terminada', () {
      final w = mk(give: const Duration(minutes: 10)); w.onReport(_rep()); expect(w.stale, false);
      now = now.add(const Duration(seconds: 30)); expect(w.stale, true); expect(w.active, true);
      now = now.add(const Duration(minutes: 11)); w.tick(); expect(w.active, false);
    });
    test('zona de pulso según la FCmáx y null sin lectura', () {
      final w = mk(); expect(w.zone(185), isNull); w.onReport(_rep(hr: 150)); expect(w.zone(185), 4);
    });
    test('avisa a quien escucha y no avisa si terminar no cambia nada', () {
      final w = mk(); var n = 0; w.addListener(() => n++); w.begin(null); w.onReport(_rep()); w.end(); w.end(); expect(n, 3);
    });
  });

  group('repositorio', () {
    test('iniciar y parar actualizan la actividad en curso y la bandera de deporte activo', () async {
      final r = VigorRepo(); await r.startSport('OUTDOOR_RUNNING'); expect(r.workout.active, true); expect(r.sportActive, true); expect(r.workout.mode?.key, 'OUTDOOR_RUNNING');
      await r.stopSport(); expect(r.workout.active, false); expect(r.sportActive, false); expect(calls.map((c) => c.method), containsAll(['startSport', 'stopSport']));
    });
  });

  group('pantallas', () {
    Future<void> pump(WidgetTester t, Widget w, {double scale = 1, Size size = const Size(360, 900), Brightness b = Brightness.light}) async {
      t.view.physicalSize = size * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true), child: x!), home: w));
      await t.pump(const Duration(milliseconds: 50));
    }
    DateTime fake = DateTime(2026, 3, 5, 10); // reloj del repositorio controlado por el test (flutter_test no adelanta DateTime.now)
    VigorRepo running() { fake = DateTime(2026, 3, 5, 10); final r = VigorRepo(); r.clock = () => fake; r.workout.begin(sportByKey('OUTDOOR_RUNNING')); r.workout.onReport(_rep(dur: 754)); return r; }
    // Cierra la actividad antes de terminar para que no quede el temporizador del cronómetro pendiente.
    Future<void> done(WidgetTester t, VigorRepo r) async { r.workout.end(); await t.pumpWidget(const SizedBox()); await t.pump(const Duration(seconds: 2)); }

    testWidgets('la isla no aparece sin actividad y con actividad muestra nombre, tiempo y pulso', (t) async {
      final r = VigorRepo(); await pump(t, Scaffold(body: ActivityIsland(r, onOpen: () {}))); expect(find.textContaining('En curso'), findsNothing);
      final a = running(); await pump(t, Scaffold(body: ActivityIsland(a, onOpen: () {})));
      expect(find.textContaining('Correr al aire libre'), findsOneWidget); expect(find.text('12:34'), findsOneWidget); expect(find.text('140'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Actividad en curso.*12:34.*pulso 140.*Abrir la pantalla de entreno')), findsOneWidget);
      await done(t, a);
    });
    testWidgets('tocar la isla abre el entreno; el cronómetro avanza cada segundo', (t) async {
      final r = running(); var opened = 0; await pump(t, Scaffold(body: ActivityIsland(r, onOpen: () => opened++)));
      await t.tap(find.byType(InkWell).first); expect(opened, 1);
      fake = fake.add(const Duration(seconds: 3)); await t.pump(const Duration(seconds: 2)); expect(find.text('12:34'), findsNothing, reason: 'ya no es el mismo segundo'); expect(find.text('12:37'), findsOneWidget);
      await done(t, r);
    });
    testWidgets('el entreno de carrera muestra tiempo, distancia, ritmo, pulso con su zona, calorías y GPS', (t) async {
      final r = running(); await pump(t, WorkoutPage(r), size: const Size(360, 1400));
      expect(find.text('12:34'), findsOneWidget); for (final k in ['Distancia', 'Ritmo', 'Pulso', 'Calorías', 'GPS']) { expect(find.text(k), findsWidgets, reason: k); }
      expect(find.text('1.20'), findsOneWidget); expect(find.text('5:30'), findsOneWidget); expect(find.text('Con señal'), findsOneWidget); expect(find.text('Zona 3'), findsOneWidget);
      await done(t, r);
    });
    testWidgets('el entreno de gimnasio solo muestra pulso y calorías (sin distancia, ritmo ni GPS)', (t) async {
      final r = VigorRepo(); r.workout.begin(sportByKey('FITNESS')); r.workout.onReport(_rep(type: null, dist: null, pace: null));
      await pump(t, WorkoutPage(r), size: const Size(360, 1400));
      expect(find.text('Distancia'), findsNothing); expect(find.text('Ritmo'), findsNothing); expect(find.text('GPS'), findsNothing); expect(find.text('Calorías'), findsOneWidget);
      await done(t, r);
    });
    testWidgets('terminar pide confirmación y, con la pulsera conectada, envía la orden de parar', (t) async {
      final r = running(); r.conn = 'connected'; await pump(t, WorkoutPage(r), size: const Size(360, 1400));
      await t.tap(find.text('Terminar')); await t.pumpAndSettle(); expect(find.text('¿Terminar la actividad?'), findsOneWidget);
      await t.tap(find.text('Seguir')); await t.pumpAndSettle(); expect(r.workout.active, true);
      await t.tap(find.text('Terminar')); await t.pumpAndSettle(); await t.tap(find.widgetWithText(FilledButton, 'Terminar').last); await t.pumpAndSettle();
      expect(r.workout.active, false); expect(calls.any((c) => c.method == 'stopSport'), true);
    });
    testWidgets('sin la pulsera conectada, «Quitar de la pantalla» no envía nada', (t) async {
      final r = running(); await pump(t, WorkoutPage(r), size: const Size(360, 1400));
      await t.tap(find.text('Quitar de la pantalla')); await t.pumpAndSettle(); await t.tap(find.widgetWithText(FilledButton, 'Terminar').last); await t.pumpAndSettle();
      expect(r.workout.active, false); expect(calls.any((c) => c.method == 'stopSport'), false);
    });
    testWidgets('a 320 px, texto doble y tema oscuro no desborda', (t) async {
      final r = running(); await pump(t, WorkoutPage(r), scale: 2, size: const Size(320, 2200), b: Brightness.dark); expect(t.takeException(), isNull);
      await pump(t, Scaffold(body: ActivityIsland(r, onOpen: () {})), scale: 2, size: const Size(320, 700), b: Brightness.dark); expect(t.takeException(), isNull);
      await done(t, r);
    });
  });
}
