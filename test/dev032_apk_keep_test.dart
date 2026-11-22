import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/updater.dart';

/// Un APK descargado se conserva hasta instalarse: si ya está en la carpeta y es la versión anunciada, no se vuelve a descargar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('vigor/methods');
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  Map<String, dynamic>? pending;
  const md5 = 'd41d8cd98f00b204e9800998ecf8427e';
  final release = {'body': 'build: 99\nmd5: $md5\n', 'assets': [{'name': kApkAsset, 'browser_download_url': 'https://github.com/o/r/releases/download/latest/$kApkAsset', 'size': 2000000}]};

  // init() lanza por su cuenta la comprobación silenciosa: se espera a que termine.
  Future<void> settle(Updater u) async { for (var i = 0; i < 100 && (u.state == UpdateState.unknown || u.state == UpdateState.checking); i++) { await Future<void>.delayed(const Duration(milliseconds: 10)); } }

  setUp(() {
    calls.clear(); pending = null;
    bm.setMockMethodCallHandler(ch, (c) async {
      calls.add(c.method);
      switch (c.method) {
        case 'appVersion': return {'code': 50, 'name': '1.0'};
        case 'getPrefs': return <String, dynamic>{};
        case 'canInstallApps': return true;
        case 'updateDir': return '/nonexistent-vigor-test-dir';
        case 'pendingUpdate': return pending;
        case 'installApk': return 'started';
        default: return null;
      }
    });
  });
  tearDown(() => bm.setMockMethodCallHandler(ch, null));

  test('al arrancar se limpia lo instalado o inválido (cleanUpdates) y se consulta la versión', () async {
    final u = Updater(fetch: (_) async => release);
    await u.init();
    expect(calls, contains('cleanUpdates'));
    u.dispose();
  });

  test('con el APK de la versión anunciada ya descargado no se descarga otra vez: se abre el instalador', () async {
    pending = {'name': 'vigor-update.apk', 'code': 99, 'size': 2000000, 'md5': md5.toUpperCase()};
    final u = Updater(fetch: (_) async => release);
    await u.init(); await settle(u);
    expect(u.state, UpdateState.available);
    await u.install();
    expect(calls, contains('installApk'));
    expect(u.state, UpdateState.ready);
    u.dispose();
  });

  test('mismo tamaño pero MD5 distinto: no se reutiliza (se intenta descargar de nuevo y no se abre el instalador)', () async {
    pending = {'name': 'vigor-update.apk', 'code': 99, 'size': 2000000, 'md5': '0' * 32};
    final u = Updater(fetch: (_) async => release);
    await u.init(); await settle(u); await u.install();
    expect(calls, isNot(contains('installApk')));
    expect(calls, isNot(contains('fileMd5')), reason: 'la descarga falla antes (sin red en el test)');
    u.dispose();
  });

  test('release sin MD5 anunciado: se reutiliza el pendiente de versión igual o mayor con el tamaño exacto', () async {
    pending = {'name': 'vigor-update.apk', 'code': 120, 'size': 2000000, 'md5': '1' * 32};
    final rel = {'body': 'build: 99\n', 'assets': release['assets']};
    final u = Updater(fetch: (_) async => rel);
    await u.init(); await settle(u); await u.install();
    expect(calls, contains('installApk'));
    u.dispose();
  });

  test('parseMd5: solo 32 hexadecimales; sin línea o mal formada es null; se normaliza a minúsculas', () {
    expect(parseMd5('build: 5\nmd5: D41D8CD98F00B204E9800998ECF8427E\nx'), md5);
    expect(parseMd5('build: 5'), isNull);
    expect(parseMd5('md5: zzz'), isNull);
    expect(parseMd5('md5: abc'), isNull);
    expect(parseMd5(null), isNull);
    expect(parseRelease(release)!.md5, md5);
    expect(parseRelease({'body': 'build: 9', 'assets': release['assets']})!.md5, isNull);
  });
}
