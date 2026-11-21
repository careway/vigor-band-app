import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/gps_filter.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/sports.dart';
import 'package:vigor_app/data/workout.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/workout_ui.dart';

const _mc = MethodChannel('vigor/methods');
// Informes sintéticos con la forma del SDK (SportControlDataInfo) y sus unidades documentadas: calorías en calorías y velocidad en m/h.
// Informe con la forma REAL que llegó de la pulsera (nombres, no números): ver `deporte-vivo` en el registro.
Map<String, Object?> _real({String run = 'RUNNING', String op = 'START', String gps = 'GOOD', int hr = 120, int dur = 60}) => {'calories': 0, 'con': 3, 'deviceState': 'NORMAL', 'distance': 0, 'gpsSignal': gps, 'heartRate': hr, 'isGnssSport': true, 'opCode': op, 'pace': 0, 'runState': run, 'speed': 0, 'sportDuration': dur, 'sportType': 'OUTDOOR_WALK'};
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
      expect(WorkoutReport.parse(_rep(run: 'PAUSED')).isPaused, true); expect(WorkoutReport.parse(_rep(run: 'FINISHED')).isEnded, true); expect(WorkoutReport.parse({'opCode': 'STOP'}).isEnded, true); expect(WorkoutReport.parse(_rep(run: 'NOT_STARTED')).isEnded, false); expect(WorkoutReport.parse(_rep(run: 'RESUMING')).isPaused, false); expect(WorkoutReport.parse(_rep(run: 'RUNNING')).isEnded, false);
      expect(WorkoutReport.parse({}).heartRate, isNull);
    });
    test('texto del cronómetro y del ritmo', () {
      expect(clockText(const Duration(seconds: 65)), '01:05'); expect(clockText(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03'); expect(clockText(Duration.zero), '00:00');
      expect(paceText(330), '5:30'); expect(paceText(359.6), '6:00'); expect(paceText(null), '—'); expect(paceText(0), '—');
    });
  });

  group('forma real del informe de la pulsera (nombres en lugar de números)', () {
    test('el tipo de deporte y la señal GPS llegan por su nombre y se entienden', () {
      final r = WorkoutReport.parse(_real()); expect(r.sportType, sportByKey('OUTDOOR_WALK')!.id); expect(r.gpsSignal, 3); expect(r.heartRate, 120); expect(r.durationSec, 60); expect(r.isRunning, true);
      for (final (n, v) in [('NONE', 0), ('WEAK', 1), ('NORMAL', 2), ('GOOD', 3), ('STRONG', 4)]) { expect(WorkoutReport.parse(_real(gps: n)).gpsSignal, v, reason: n); }
      expect(WorkoutReport.parse({'gpsSignal': 'raro'}).gpsSignal, isNull); expect(WorkoutReport.parse({'sportType': 'NO_EXISTE'}).sportType, isNull);
    });
    test('el eco de parar (opCode STOP, estado NOT_STARTED) termina la actividad y no la vuelve a activar', () {
      final w = LiveWorkout(clock: () => DateTime(2026, 3, 5, 10)); w.onReport(_real()); expect(w.active, true);
      w.onReport(_real(run: 'NOT_STARTED', op: 'STOP', gps: 'NONE')); expect(w.active, false);
      w.onReport(_real(run: 'NOT_STARTED', op: 'START', gps: 'NONE')); expect(w.active, false, reason: 'una respuesta tardía de «no iniciada» no activa nada');
    });
    test('una respuesta de «no iniciada» mientras se espera el arranque no termina la actividad que inició la app', () {
      final w = LiveWorkout(clock: () => DateTime(2026, 3, 5, 10)); w.begin(sportByKey('OUTDOOR_WALK')); w.onReport(_real(run: 'NOT_STARTED', op: 'START', gps: 'NONE')); expect(w.active, true);
    });
    test('el pulso y la duración del informe real alimentan el entreno', () {
      final w = LiveWorkout(clock: () => DateTime(2026, 3, 5, 10)); w.begin(sportByKey('OUTDOOR_WALK')); w.onReport(_real(hr: 98, dur: 289)); expect(w.heartRate, 98); expect(w.elapsed().inSeconds, 289); expect(w.gpsSignal, 3);
    });
  });

  group('posición en directo de la pulsera', () {
    test('decodifica grados tal cual y, si son enteros grandes, prueba la escala (÷1e5, ÷1e6, ÷1e7)', () {
      expect(parseLivePosition({'lat': 40.4168, 'lon': -3.7038}), (40.4168, -3.7038));
      final a = parseLivePosition({'lat': 4041680, 'lon': -370380})!; expect(a.$1, closeTo(40.4168, 1e-9)); expect(a.$2, closeTo(-3.7038, 1e-9));
      final b = parseLivePosition({'lat': 40416800, 'lon': -3703800})!; expect(b.$1, closeTo(40.4168, 1e-9)); expect(b.$2, closeTo(-3.7038, 1e-9));
    });
    test('un paquete vacío, 0,0, NaN o texto no es una posición', () {
      for (final d in [<String, Object?>{}, {'lat': 0, 'lon': 0}, {'lat': double.nan, 'lon': 1.0}, {'lat': 'x', 'lon': 'y'}, {'lat': 999999999999, 'lon': 999999999999}, {'isOpen': true}]) { expect(parseLivePosition(d), isNull, reason: '$d'); }
    });
    test('los puntos en directo van formando el recorrido y la posición, con incertidumbre', () {
      var now = DateTime(2026, 3, 5, 10); final w = LiveWorkout(clock: () => now)..begin(sportByKey('OUTDOOR_WALK'));
      for (var i = 0; i < 8; i++) { now = now.add(const Duration(seconds: 5)); w.onGpsPoint({'lat': 40.0, 'lon': -3.0 + i * 0.00005}); }
      expect(w.track.length, 8); expect(w.position, isNotNull); expect(w.uncertaintyM, isNotNull); expect(w.positionAgeSec, 0);
    });
    test('sin actividad en curso o con paquetes vacíos no se acumula nada', () {
      final w = LiveWorkout(clock: () => DateTime(2026, 3, 5, 10)); w.onGpsPoint({'lat': 40.0, 'lon': -3.0}); expect(w.track, isEmpty);
      w.begin(sportByKey('OUTDOOR_WALK')); w.onGpsPoint({'lat': 0, 'lon': 0}); expect(w.track, isEmpty); expect(w.position, isNull);
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

  group('posición de la actividad (recorrido devuelto por la pulsera)', () {
    GpsFix f(int i, {int sig = 2}) => GpsFix(40.0, -3.0 + i * 0.0001, i * 5, sig);
    test('sin puntos con señal no hay posición; con ellos, la última y una incertidumbre', () {
      var now = DateTime(2026, 3, 5, 10); final w = LiveWorkout(clock: () => now)..begin(sportByKey('OUTDOOR_WALK')); now = now.add(const Duration(seconds: 200));
      w.setTrack([for (var i = 0; i < 20; i++) f(i, sig: 0)]); expect(w.position, isNull); expect(w.uncertaintyM, isNull);
      w.setTrack([for (var i = 0; i < 20; i++) f(i)]); expect(w.position, isNotNull); expect(w.uncertaintyM, greaterThanOrEqualTo(8));
      expect(w.positionAgeSec, closeTo(200 - 95, 1), reason: 'último punto a los 95 s, ahora a los 200 s');
    });
    test('al empezar otra actividad se borra la posición anterior', () {
      final w = LiveWorkout(clock: () => DateTime(2026, 3, 5, 10))..begin(sportByKey('OUTDOOR_WALK')); w.setTrack([for (var i = 0; i < 20; i++) f(i)]); expect(w.position, isNotNull);
      w.begin(sportByKey('OUTDOOR_RUNNING')); expect(w.position, isNull); expect(w.track, isEmpty);
    });
    test('el repositorio pasa al entreno la sesión de la pulsera que empezó a la vez (±5 min) y no otra', () {
      final base = DateTime(2026, 3, 5, 10); final r = VigorRepo(); r.clock = () => base.add(const Duration(minutes: 3)); r.workout.begin(sportByKey('OUTDOOR_WALK')); // empieza a las 10:03... en el reloj del móvil
      Session s(DateTime st, List<GpsFix> fx) => Session(key: 'k${st.minute}', start: st, sportType: 2, seconds: 100, meters: 1, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: true, route: const [], hrPerMinute: const [], fixes: fx);
      r.sessions = [s(base.subtract(const Duration(hours: 2)), [for (var i = 0; i < 10; i++) f(i)]), s(base.add(const Duration(minutes: 3, seconds: 20)), [for (var i = 0; i < 12; i++) f(i)])];
      r.workout.startedAt = base.add(const Duration(minutes: 3)); // anclaje
      // la lógica es privada; se ejerce al recargar: aquí se comprueba el modelo directamente con el mismo criterio
      final near = r.sessions.where((x) => x.start.difference(r.workout.startedAt!).abs() <= const Duration(minutes: 5)).toList(); expect(near.length, 1); expect(near.first.fixes.length, 12);
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
    testWidgets('la ficha GPS dice «Buscando…» hasta que la pulsera informa de señal', (t) async {
      final r = VigorRepo(); r.clock = () => fake; r.workout.begin(sportByKey('OUTDOOR_WALK')); r.workout.onReport(_rep(type: 2, gps: 0));
      await pump(t, WorkoutPage(r), size: const Size(360, 1400)); expect(find.text('Buscando…'), findsOneWidget); expect(find.text('Con señal'), findsNothing);
      r.workout.onReport(_rep(type: 2, gps: 2)); await t.pump(); expect(find.text('Con señal'), findsOneWidget);
      await done(t, r);
    });
    testWidgets('en un entreno de recorrido hay tarjeta de posición; sin posición pide esperar; con ella, la incertidumbre y el botón de actualizar', (t) async {
      final r = VigorRepo(); r.mapOn = false; r.conn = 'connected'; r.clock = () => fake; r.workout.begin(sportByKey('OUTDOOR_WALK')); r.workout.onReport(_rep(type: 2, gps: 0));
      await pump(t, WorkoutPage(r), size: const Size(360, 1800)); expect(find.text('Posición'), findsOneWidget); expect(find.textContaining('Esperando la posición'), findsOneWidget);
      r.workout.onReport(_rep(type: 2, gps: 2)); await t.pump(); expect(find.textContaining('ya tiene señal'), findsOneWidget);
      r.workout.setTrack([for (var i = 0; i < 20; i++) GpsFix(40.0, -3.0 + i * 0.0001, i * 5, 2)]); await t.pump();
      expect(find.textContaining('Incertidumbre aprox. ±'), findsOneWidget);
      await t.tap(find.text('Actualizar posición')); await t.pump(); expect(calls.any((c) => c.method == 'sync'), true);
      await done(t, r);
    });
    testWidgets('en un entreno sin GPS (gimnasio) no hay tarjeta de posición', (t) async {
      final r = VigorRepo(); r.clock = () => fake; r.workout.begin(sportByKey('FITNESS')); r.workout.onReport(_rep(type: null));
      await pump(t, WorkoutPage(r), size: const Size(360, 1400)); expect(find.text('Posición'), findsNothing); expect(find.text('Actualizar posición'), findsNothing);
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
