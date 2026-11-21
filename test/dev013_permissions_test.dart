import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/data/startup_permissions.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/permission_prompt.dart';

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  var status = <String, dynamic>{'missing': ['bluetooth'], 'blocked': false};
  setUp(() {
    calls.clear(); StartupPermissions.resetForTest(); status = {'missing': ['bluetooth'], 'blocked': false};
    bm.setMockMethodCallHandler(_mc, (c) async {
      calls.add(c.method);
      switch (c.method) {
        case 'permissionStatus': return status;
        case 'requestPermissions': return true;
        case 'openSystemSetting': return 'details';
        default: return null;
      }
    });
  });
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  group('plan', () {
    test('Bluetooth, ubicación y Health Connect solo si faltan', () {
      expect(StartupPermissions.plan(nativeMissing: const [], healthMissing: false), isEmpty);
      expect(StartupPermissions.plan(nativeMissing: const ['bluetooth'], healthMissing: false).map((n) => n.kind), [PermKind.bluetooth]);
      expect(StartupPermissions.plan(nativeMissing: const ['location'], healthMissing: true).map((n) => n.kind), [PermKind.location, PermKind.healthConnect]);
    });
    test('cada permiso trae una explicación de para qué se pide', () {
      for (final n in [StartupPermissions.bluetooth, StartupPermissions.location, StartupPermissions.healthConnect]) { expect(n.why.length, greaterThan(40)); }
    });
    test('una vez por arranque: tras marcarlo no se vuelve a pedir hasta reiniciar', () {
      expect(StartupPermissions.askedThisLaunch, false);
      StartupPermissions.markAsked(); expect(StartupPermissions.askedThisLaunch, true);
      StartupPermissions.resetForTest(); expect(StartupPermissions.askedThisLaunch, false);
    });
  });

  group('diálogo', () {
    Future<void> open(WidgetTester t, VigorRepo repo, {bool android = true}) async {
      repo.markReady();
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Builder(builder: (c) => Scaffold(body: Center(
          child: ElevatedButton(onPressed: () => askMissingPermissionsOnce(c, repo, android: android), child: const Text('abrir')))))));
      await t.tap(find.text('abrir')); await t.pump(); await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('si falta Bluetooth muestra la explicación y «Continuar» pide el permiso y lo anota', (t) async {
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Permisos que necesita Vigor'), findsOneWidget);
      expect(find.textContaining('buscar tu pulsera'), findsOneWidget);
      expect(find.textContaining('una vez cada vez que abres la app'), findsOneWidget);
      await t.tap(find.text('Continuar')); await t.pumpAndSettle();
      expect(calls, containsAllInOrder(['permissionStatus', 'requestPermissions', 'setPref']));
      expect(find.text('Permisos que necesita Vigor'), findsNothing);
      repo.auto.dispose(); // tras conceder, la sincronización automática arranca su temporizador
    });

    testWidgets('solo una vez por inicialización: una segunda llamada no vuelve a mostrar nada', (t) async {
      final repo = VigorRepo(); await open(t, repo);
      await t.tap(find.text('Ahora no')); await t.pumpAndSettle();
      expect(calls.contains('requestPermissions'), false, reason: '«Ahora no» no pide nada');
      await t.tap(find.text('abrir')); await t.pumpAndSettle();
      expect(find.text('Permisos que necesita Vigor'), findsNothing);
    });

    testWidgets('si no falta ningún permiso no muestra nada', (t) async {
      status = {'missing': <String>[], 'blocked': false};
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Permisos que necesita Vigor'), findsNothing);
      expect(StartupPermissions.askedThisLaunch, false, reason: 'no se gasta el «una vez» si no hacía falta preguntar');
    });

    testWidgets('si el sistema ya no muestra su diálogo, ofrece «Abrir ajustes» y abre la ficha de la app', (t) async {
      status = {'missing': ['bluetooth'], 'blocked': true};
      final repo = VigorRepo(); await open(t, repo);
      expect(find.text('Abrir ajustes'), findsOneWidget);
      expect(find.textContaining('Android ya no mostrará'), findsOneWidget);
      await t.tap(find.text('Abrir ajustes')); await t.pumpAndSettle();
      expect(calls.contains('openSystemSetting'), true); expect(calls.contains('requestPermissions'), false);
      repo.auto.dispose();
    });

    testWidgets('fuera de Android no hace nada', (t) async {
      final repo = VigorRepo(); await open(t, repo, android: false);
      expect(find.text('Permisos que necesita Vigor'), findsNothing); expect(calls, isEmpty);
    });

    testWidgets('a 320 px y con texto grande el diálogo no desborda', (t) async {
      t.view.physicalSize = const Size(320, 700) * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      status = {'missing': ['bluetooth', 'location'], 'blocked': false};
      final repo = VigorRepo(); repo.markReady();
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2)), child: w!),
          home: Builder(builder: (c) => Scaffold(body: ElevatedButton(onPressed: () => askMissingPermissionsOnce(c, repo, android: true), child: const Text('abrir'))))));
      await t.tap(find.text('abrir')); await t.pump(); await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Permisos que necesita Vigor'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
