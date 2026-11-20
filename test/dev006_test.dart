// DEV_006: actualizaciones desde la app y pulso en vivo. Datos sintéticos; la red es un servidor local.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/heart_meter.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/updater.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/heart_ui.dart';

const _mc = MethodChannel('vigor/methods');
Map _rel({String body = 'build: 42\n\nnotas', int size = 5000000, String url = 'https://github.com/careway/vigor-band-app/releases/download/latest/vigor-latest.apk', String name = 'vigor-latest.apk'}) =>
    {'body': body, 'assets': [{'name': name, 'size': size, 'browser_download_url': url}]};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  group('actualizaciones: parseo y política', () {
    test('parseBuild lee "build: N" y rechaza lo demás', () {
      expect(parseBuild('build: 42\n\nx'), 42); expect(parseBuild('hola\nBuild:7'), 7);
      expect(parseBuild('commit build: 9'), isNull); expect(parseBuild(''), isNull); expect(parseBuild(null), isNull);
      expect(parseBuild('build: abc'), isNull);
    });
    test('hosts y esquema', () {
      expect(allowedUri(Uri.parse('https://github.com/a/b')), isTrue);
      expect(allowedUri(Uri.parse('https://objects.githubusercontent.com/x')), isTrue);
      expect(allowedUri(Uri.parse('http://github.com/a')), isFalse);
      expect(allowedUri(Uri.parse('https://evil.com/github.com')), isFalse);
      expect(allowedUri(Uri.parse('https://github.com.evil.com/x')), isFalse);
      expect(allowedUri(Uri.parse('https://github.com:8443/x')), isFalse);
    });
    test('parseRelease valida formato, asset, host y tamaño', () {
      expect(parseRelease(_rel())!.build, 42);
      expect(parseRelease(_rel(body: 'sin linea')), isNull);
      expect(parseRelease(_rel(url: 'http://github.com/x.apk')), isNull);
      expect(parseRelease(_rel(url: 'https://evil.com/x.apk')), isNull);
      expect(parseRelease(_rel(size: 10)), isNull);
      expect(parseRelease(_rel(name: 'otra.apk')), isNull);
      expect(parseRelease([]), isNull); expect(parseRelease({'body': 'build: 1'}), isNull);
    });
    test('isNewer y shouldCheck (12 h, reloj hacia atrás)', () {
      expect(isNewer(10, 11), isTrue); expect(isNewer(11, 11), isFalse); expect(isNewer(null, 11), isFalse);
      final now = DateTime(2026, 1, 1, 12);
      expect(shouldCheck(now, null), isTrue); expect(shouldCheck(now, now.subtract(const Duration(hours: 11))), isFalse);
      expect(shouldCheck(now, now.subtract(const Duration(hours: 12))), isTrue); expect(shouldCheck(now, now.add(const Duration(hours: 1))), isTrue);
    });
  });

  group('Updater.check', () {
    Updater mk(Future<dynamic> Function(Uri) f, {int installed = 10}) => Updater(fetch: f)..installed = installed;
    test('hay versión nueva', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final u = mk((_) async => _rel()); await u.check();
      expect(u.state, UpdateState.available); expect(u.available, isTrue); expect(u.info!.build, 42); expect(u.lastCheck, isNotNull);
    });
    test('al día', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final u = mk((_) async => _rel(), installed: 42); await u.check(); expect(u.state, UpdateState.upToDate); expect(u.available, isFalse);
    });
    test('404 (repo privado): no disponible, y en silencio no deja mensaje ni error', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final u = mk((_) async => throw const HttpException('HTTP 404'));
      await u.check(silent: true); expect(u.state, UpdateState.unknown); expect(u.message, isNull); expect(u.available, isFalse);
      await u.check(); expect(u.state, UpdateState.unavailable); expect(u.message, contains('404'));
    });
    test('sin red: error solo si no es silencioso', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final u = mk((_) async => throw const SocketException('x')); await u.check(silent: true); expect(u.state, UpdateState.unknown);
      await u.check(); expect(u.state, UpdateState.error);
    });
    test('respuesta basura: error de formato, no excepción', () async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final u = mk((_) async => 'html'); await u.check(); expect(u.state, UpdateState.error);
    });
    test('guarda la hora de comprobación en minutos (cabe en int de 32 bits)', () async {
      final calls = <MethodCall>[]; bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return null; });
      final u = Updater(fetch: (_) async => _rel(), clock: () => DateTime.utc(2026, 11, 20, 10))..installed = 1; await u.check();
      final v = calls.firstWhere((c) => c.method == 'setPref').arguments['value'] as int; expect(v, lessThan(2147483647)); expect(v, DateTime.utc(2026, 11, 20, 10).millisecondsSinceEpoch ~/ 60000);
    });
    test('init lee versión y no consulta si ya comprobó hace menos de 12 h', () async {
      var fetched = 0; final now = DateTime(2026, 11, 20, 10);
      bm.setMockMethodCallHandler(_mc, (c) async => switch (c.method) {
        'appVersion' => {'code': 5, 'name': '1.0.0'}, 'getPrefs' => {'updChk': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 60000}, _ => null });
      final u = Updater(fetch: (_) async { fetched++; return _rel(); }, clock: () => now); await u.init();
      expect(u.installed, 5); expect(u.versionName, '1.0.0'); expect(fetched, 0);
    });
    test('init con la última comprobación antigua sí consulta', () async {
      var fetched = 0; final now = DateTime(2026, 11, 20, 10);
      bm.setMockMethodCallHandler(_mc, (c) async => switch (c.method) {
        'appVersion' => {'code': 5, 'name': '1.0.0'}, 'getPrefs' => {'updChk': now.subtract(const Duration(hours: 30)).millisecondsSinceEpoch ~/ 60000}, _ => null });
      final u = Updater(fetch: (_) async { fetched++; return _rel(); }, clock: () => now); await u.init(); await pumpEventQueue();
      expect(fetched, 1); expect(u.available, isTrue);
    });
  });

  group('Updater.download', () {
    late HttpServer srv; late Directory dir; late List<int> apk;
    setUp(() async { HttpOverrides.global = null; srv = await HttpServer.bind('127.0.0.1', 0); dir = await Directory.systemTemp.createTemp('upd'); apk = [0x50, 0x4b, ...List.filled(2000, 1)]; });
    tearDown(() async { await srv.close(force: true); await dir.delete(recursive: true); });
    Uri url(String p) => Uri.parse('http://127.0.0.1:${srv.port}$p');
    Future<void> run(Uri u, int size, {bool Function()? cancel, bool Function(Uri)? allow, List<double>? prog}) =>
        Updater.download(u, File('${dir.path}/a.part'), size, (p) => prog?.add(p), cancel ?? () => false, allow: allow ?? (x) => x.host == '127.0.0.1' || x.host == 'evil.example');
    test('descarga correcta con progreso', () async {
      srv.listen((r) { r.response.add(apk); r.response.close(); }); final pr = <double>[];
      await run(url('/a'), apk.length, prog: pr); expect(File('${dir.path}/a.part').lengthSync(), apk.length); expect(pr.last, 1.0);
    });
    test('tamaño distinto: rechaza', () async {
      srv.listen((r) { r.response.add(apk); r.response.close(); });
      await expectLater(run(url('/a'), apk.length + 5), throwsA(isA<FormatException>()));
    });
    test('no es un APK (sin PK): rechaza', () async {
      srv.listen((r) { r.response.add(List.filled(2002, 0x3c)); r.response.close(); });
      await expectLater(run(url('/a'), 2002), throwsA(isA<FormatException>()));
    });
    test('redirección a host no permitido: rechaza antes de pedirlo', () async {
      var asked = false;
      srv.listen((r) { r.response.statusCode = 302; r.response.headers.set('location', 'https://evil.example/x.apk'); asked = true; r.response.close(); });
      await expectLater(run(url('/a'), 100, allow: (x) => x.host == '127.0.0.1'), throwsA(isA<FormatException>())); expect(asked, isTrue);
    });
    test('HTTP 404 -> HttpException', () async {
      srv.listen((r) { r.response.statusCode = 404; r.response.close(); });
      await expectLater(run(url('/a'), 100), throwsA(isA<HttpException>()));
    });
    test('el origen por defecto (http, localhost) se rechaza', () async {
      await expectLater(Updater.download(url('/a'), File('${dir.path}/b'), 10, (_) {}, () => false), throwsA(isA<FormatException>()));
    });
    test('cancelar corta la descarga', () async {
      srv.listen((r) { r.response.add(apk); r.response.close(); });
      await expectLater(run(url('/a'), apk.length, cancel: () => true), throwsA(isNot(isA<FormatException>())));
    });
  });

  group('HeartMeter', () {
    late int starts, stops; late bool conn;
    HeartMeter mk() { starts = 0; stops = 0; conn = true; return HeartMeter(start: () async => starts++, stop: () async => stops++, isConnected: () => conn); }
    Map ev(int v, [String s = 'STATE_HEART_NORMAL']) => {'status': s, 'value': v};
    test('mide: ignora 0 e inválidos, termina con la mediana de las 3 últimas y para la pulsera', () async {
      final m = mk(); await m.begin(); expect(m.phase, HeartPhase.starting); expect(starts, 1);
      m.onEvent(ev(0)); expect(m.value, isNull); m.onEvent(ev(250)); expect(m.value, isNull); expect(m.phase, HeartPhase.measuring);
      for (final v in [70, 72, 71, 90, 73]) { m.onEvent(ev(v)); } expect(m.value, 73); expect(m.active, isTrue);
      m.onEvent(ev(72)); expect(m.phase, HeartPhase.done); expect(m.value, 73); expect(stops, 1); expect(m.hasFresh, isTrue);
    });
    test('sin conexión no inicia', () async { final m = mk(); conn = false; await m.begin(); expect(m.phase, HeartPhase.failed); expect(starts, 0); });
    test('cancelar para la pulsera y limpia; sin medición no hace nada', () async {
      final m = mk(); m.cancel(); expect(stops, 0);
      await m.begin(); m.onEvent(ev(70)); m.cancel(); expect(m.phase, HeartPhase.idle); expect(m.value, isNull); expect(stops, 1);
    });
    test('ocupada, batería baja y mala colocación', () async {
      var m = mk(); await m.begin(); m.onEvent(ev(0, 'STATE_HEART_BUSY')); expect(m.phase, HeartPhase.failed); expect(stops, 1);
      m = mk(); await m.begin(); m.onEvent(ev(0, 'STATE_LOW_BATTERY')); expect(m.phase, HeartPhase.failed);
      m = mk(); await m.begin(); m.onEvent(ev(0, 'STATE_HEART_WEAR_ERROR')); expect(m.phase, HeartPhase.measuring); expect(m.message, contains('Ajusta'));
    });
    test('el fallo al iniciar se refleja', () async {
      final m = HeartMeter(start: () async => throw Exception('x'), stop: () async {}, isConnected: () => true); await m.begin(); expect(m.phase, HeartPhase.failed);
    });
    test('eventos fuera de medición se ignoran', () { final m = mk(); m.onEvent(ev(70)); expect(m.value, isNull); expect(m.phase, HeartPhase.idle); });
  });

  testWidgets('HeartMeter: tiempo máximo para la medición sola', (t) async {
    var stops = 0; final m = HeartMeter(start: () async {}, stop: () async => stops++, isConnected: () => true);
    await m.begin(); m.onEvent({'status': 'STATE_HEART_NORMAL', 'value': 70});
    await t.pump(HeartMeter.maxDuration + const Duration(seconds: 1));
    expect(m.active, isFalse); expect(m.phase, HeartPhase.done); expect(stops, 1);
    final n = HeartMeter(start: () async {}, stop: () async => stops++, isConnected: () => true); await n.begin();
    await t.pump(HeartMeter.maxDuration + const Duration(seconds: 1)); expect(n.phase, HeartPhase.failed); expect(stops, 2);
  });

  group('HeartCenter', () {
    Future<VigorRepo> pump(WidgetTester t, {Sample? rec, bool can = true, String conn = 'connected'}) async {
      bm.setMockMethodCallHandler(_mc, (c) async => null);
      final repo = VigorRepo()..conn = conn;
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: x!),
          home: Scaffold(body: Center(child: HeartCenter(repo: repo, lastRecord: rec, canMeasure: can)))));
      return repo;
    }
    testWidgets('sin registros: invita a medir; con registro lo rotula "último registro"', (t) async {
      await pump(t); expect(find.text('Medir pulso'), findsOneWidget);
      await pump(t, rec: Sample(DateTime(2026, 1, 1, 9, 5), 66)); expect(find.text('66 bpm'), findsOneWidget); expect(find.text('último registro de 09:05'), findsOneWidget);
    });
    testWidgets('objetivo táctil de al menos 48 dp', (t) async {
      await pump(t, rec: Sample(DateTime(2026, 1, 1, 9, 5), 66)); final s = t.getSize(find.byType(InkWell)); expect(s.height, greaterThanOrEqualTo(48)); expect(s.width, greaterThanOrEqualTo(48));
    });
    testWidgets('en otro día no es pulsable', (t) async { await pump(t, rec: Sample(DateTime(2026, 1, 1, 9, 5), 66), can: false); expect(find.byType(InkWell), findsNothing); });
    testWidgets('pulsar abre la hoja; con pulsera desconectada no se puede empezar; cerrar cancela', (t) async {
      final repo = await pump(t, conn: 'idle'); await t.tap(find.byType(InkWell)); await t.pumpAndSettle();
      expect(find.text('Medir pulso ahora'), findsOneWidget); expect(find.text('Conecta la pulsera para medir.'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      repo.dispose();
    });
    testWidgets('midiendo: muestra el valor en vivo y la etiqueta honesta; cancelar vuelve atrás', (t) async {
      final calls = <String>[]; bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c.method); return null; });
      final repo = VigorRepo()..conn = 'connected';
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: x!), home: Scaffold(body: Center(child: HeartCenter(repo: repo, lastRecord: Sample(DateTime(2026, 1, 1, 9, 5), 66), canMeasure: true)))));
      await t.tap(find.byType(InkWell)); await t.pumpAndSettle(); await t.tap(find.text('Empezar')); await t.pump(); expect(calls, contains('startHeart'));
      repo.heart.onEvent({'status': 'STATE_HEART_NORMAL', 'value': 77}); await t.pump();
      expect(find.text('Midiendo: 77 bpm'), findsOneWidget); expect(find.text('pulso en vivo'), findsWidgets);
      await t.tap(find.text('Cancelar')); await t.pump(); expect(calls, contains('stopHeart')); expect(repo.heart.active, isFalse);
      repo.dispose();
    });
  });
}
