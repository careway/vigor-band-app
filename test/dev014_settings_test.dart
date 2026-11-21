import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/startup_permissions.dart';
import 'package:vigor_app/data/updater.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/permission_prompt.dart';
import 'package:vigor_app/ui/system_settings_panel.dart';

const _mc = MethodChannel('vigor/methods');
Map _rel(int b) => {'body': 'build: $b', 'assets': [{'name': 'vigor-latest.apk', 'size': 5000000, 'browser_download_url': 'https://github.com/x/y/releases/download/latest/vigor-latest.apk'}]};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var canInstall = false;
  var sys = <String, dynamic>{'installApps': true, 'batteryUnrestricted': true, 'autostart': null, 'xiaomi': false};
  var perm = <String, dynamic>{'missing': <String>[], 'blocked': false};
  setUp(() {
    calls.clear(); canInstall = false; StartupPermissions.resetForTest();
    sys = {'installApps': true, 'batteryUnrestricted': true, 'autostart': null, 'xiaomi': false}; perm = {'missing': <String>[], 'blocked': false};
    bm.setMockMethodCallHandler(_mc, (c) async {
      calls.add(c);
      switch (c.method) {
        case 'canInstallApps': return canInstall;
        case 'systemSettingsStatus': return sys;
        case 'permissionStatus': return perm;
        case 'openSystemSetting': return 'direct';
        default: return null; // updateDir devuelve null: la descarga falla enseguida, sin red
      }
    });
  });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));
  bool called(String m) => calls.any((c) => c.method == m);

  group('actualización: el permiso se comprueba ANTES de descargar', () {
    Future<Updater> ready() async { final u = Updater(fetch: (_) async => _rel(11))..installed = 10; await u.check(); expect(u.state, UpdateState.available); return u; }

    test('sin permiso: no descarga nada, pide el permiso primero y lo explica', () async {
      final u = await ready();
      await u.install();
      expect(u.state, UpdateState.needsPermission);
      expect(u.message, contains('antes de descargar'));
      expect(called('canInstallApps'), true);
      expect(called('updateDir'), false, reason: 'no se prepara ni se descarga nada');
      expect(called('installApk'), false);
    });
    test('«Permitir instalar» abre la pantalla de Vigor en ajustes (instalar apps desconocidas)', () async {
      final u = await ready(); await u.install(); calls.clear();
      await u.askInstallPermission();
      final c = calls.singleWhere((x) => x.method == 'openSystemSetting'); expect(c.arguments, {'which': 'installApps'});
    });
    test('al volver con el permiso ya concedido, la actualización continúa sola', () async {
      final u = await ready(); await u.install(); calls.clear();
      canInstall = true;
      await u.onResume(); await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(called('updateDir'), true, reason: 'ya pasó la comprobación y empieza la descarga');
    });
    test('al volver SIN permiso no continúa ni vuelve a abrir nada', () async {
      final u = await ready(); await u.install(); calls.clear();
      await u.onResume(); await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(called('updateDir'), false); expect(called('openSystemSetting'), false); expect(u.state, UpdateState.needsPermission);
    });
    test('con permiso desde el principio descarga directamente, sin volver a preguntar', () async {
      canInstall = true; final u = await ready(); await u.install();
      expect(called('updateDir'), true); expect(u.state, isNot(UpdateState.needsPermission));
    });
  });

  group('plan con ajustes del sistema', () {
    test('batería y autoinicio solo si se piden; son ajustes del sistema, no permisos', () {
      final n = StartupPermissions.plan(nativeMissing: const [], healthMissing: false, batteryRestricted: true, autostartDenied: true);
      expect(n.map((x) => x.kind), [PermKind.batteryOptimization, PermKind.autostart]);
      expect(n.every((x) => x.isSystemSetting), true);
      expect(StartupPermissions.plan(nativeMissing: const [], healthMissing: false), isEmpty);
    });
  });

  group('aviso de inicio con ajustes del sistema', () {
    Future<void> open(WidgetTester t, VigorRepo repo) async {
      repo.markReady();
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Builder(builder: (c) => Scaffold(body: Center(
          child: ElevatedButton(onPressed: () => askMissingPermissionsOnce(c, repo, android: true), child: const Text('abrir')))))));
      await t.tap(find.text('abrir')); await t.pump(); await t.pump(const Duration(milliseconds: 80));
    }
    testWidgets('batería sin excepción: se ofrece un acceso directo a su pantalla (sin pedirlo como permiso)', (t) async {
      sys['batteryUnrestricted'] = false;
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Batería: ejecutar sin restricciones'), findsOneWidget);
      expect(find.textContaining('no un permiso'), findsOneWidget);
      expect(find.text('Continuar'), findsNothing, reason: 'solo hay ajustes del sistema: nada que pedir con ventana');
      await t.tap(find.text('Abrir ajustes')); await t.pump();
      expect(calls.singleWhere((x) => x.method == 'openSystemSetting').arguments, {'which': 'battery'});
      expect(called('requestPermissions'), false);
    });
    testWidgets('Xiaomi con inicio automático denegado: lo ofrece; en otras marcas o con estado desconocido no', (t) async {
      sys['xiaomi'] = true; sys['autostart'] = false;
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Inicio automático (Xiaomi)'), findsOneWidget);
      await t.tap(find.text('Abrir ajustes')); await t.pump();
      expect(calls.singleWhere((x) => x.method == 'openSystemSetting').arguments, {'which': 'autostart'});
    });
    testWidgets('inicio automático desconocido (null): no se molesta al usuario', (t) async {
      sys['xiaomi'] = true; sys['autostart'] = null;
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Permisos que necesita Vigor'), findsNothing);
    });
    testWidgets('con la sincronización automática apagada no se piden ajustes de batería', (t) async {
      sys['batteryUnrestricted'] = false;
      final repo = VigorRepo(); repo.auto.enabled = false; await open(t, repo);
      expect(find.text('Permisos que necesita Vigor'), findsNothing);
    });
    testWidgets('permisos de ejecución y ajustes del sistema juntos: «Continuar» sigue pidiendo solo lo que lleva ventana', (t) async {
      perm = {'missing': ['bluetooth'], 'blocked': false}; sys['batteryUnrestricted'] = false;
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Continuar'), findsOneWidget);
      await t.tap(find.text('Continuar')); await t.pumpAndSettle();
      expect(called('requestPermissions'), true);
      repo.auto.dispose();
    });
  });

  group('panel de Ajustes con el estado real', () {
    Future<void> show(WidgetTester t, VigorRepo repo) async {
      t.view.physicalSize = const Size(400, 1400) * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: SingleChildScrollView(child: SystemSettingsPanel(repo)))));
      await t.pump(); await t.pump(const Duration(milliseconds: 50));
    }
    testWidgets('muestra concedido / sin conceder / desconocido y abre cada pantalla', (t) async {
      sys = {'installApps': false, 'batteryUnrestricted': false, 'autostart': false, 'xiaomi': true};
      final repo = VigorRepo(); await show(t, repo);
      expect(find.textContaining('Sin conceder'), findsWidgets, reason: 'el estado se rotula con palabras, no solo con color');
      expect(find.textContaining('Sin conceder: Android puede retrasar'), findsOneWidget);
      expect(find.text('Inicio automático (Xiaomi)'), findsOneWidget);
      await t.tap(find.text('Abrir ajuste para activarlo').first); await t.pump();
      expect(calls.where((x) => x.method == 'openSystemSetting').last.arguments, {'which': 'battery'});
    });
    testWidgets('todo concedido: lo dice y ofrece igualmente el acceso directo', (t) async {
      sys = {'installApps': true, 'batteryUnrestricted': true, 'autostart': true, 'xiaomi': true};
      final repo = VigorRepo(); await show(t, repo);
      expect(find.textContaining('Concedido'), findsWidgets); expect(find.text('Abrir ajuste'), findsWidgets);
    });
    testWidgets('autoinicio desconocido en un Xiaomi: lo dice y propone revisarlo', (t) async {
      sys = {'installApps': true, 'batteryUnrestricted': true, 'autostart': null, 'xiaomi': true};
      final repo = VigorRepo(); await show(t, repo);
      expect(find.textContaining('No se puede consultar en este móvil'), findsOneWidget);
    });
    testWidgets('fuera de Xiaomi no aparece el inicio automático', (t) async {
      final repo = VigorRepo(); await show(t, repo);
      expect(find.text('Inicio automático (Xiaomi)'), findsNothing);
    });
  });
}
