import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/sleep_page.dart';
import 'dev007_test.dart' show Env;

const _mc = MethodChannel('vigor/methods');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bm = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => bm.setMockMethodCallHandler(_mc, null));

  test('borrar de Health Connect: noche y sesión enviadas se borran por id y se limpia el libro; lo no enviado se ignora', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    final src = e.src; expect(e.h.sleepSent('2026-11-20'), true); expect(e.h.sessionSent('k1'), true);
    final rep = await e.h.deleteFromHealth(nights: src.nights, sessions: src.sessions);
    expect(rep.ok, 2); expect(rep.failed, 0); expect(e.g.deletedIds, ['vigor-sleep-2026-11-20']); expect(e.g.deletedW, ['w-k1']);
    expect(e.h.sleepSent('2026-11-20'), false); expect(e.h.sessionSent('k1'), false);
    expect(rep.notes.join(), contains('distancia'));
    final again = await e.h.deleteFromHealth(nights: src.nights, sessions: src.sessions); expect(again.ok, 0); expect(again.failed, 0);
  });

  test('borrar de Health Connect falla: informa, no limpia el libro', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    e.g.failDelete = true;
    final rep = await e.h.deleteFromHealth(nights: e.src.nights);
    expect(rep.failed, 1); expect(rep.notes.join(), contains('No se pudo borrar')); expect(e.h.sleepSent('2026-11-20'), true);
  });

  test('Health Connect no disponible al borrar: lo dice', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    e.g.av = HealthAvail.notInstalled; e.h.avail = null;
    final rep = await e.h.deleteFromHealth(sessions: e.src.sessions);
    expect(rep.failed, 1); expect(rep.notes.join(), contains('no está disponible'));
  });

  test('borrar un día: borra por rango los tipos enviados', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true); await e.h.run();
    expect(e.h.daySent('2026-11-20'), true);
    final rep = await e.h.deleteFromHealth(days: ['2026-11-20']);
    expect(rep.ok, 1); expect(e.g.deleted, containsAll([HType.steps, HType.heartRate, HType.spo2]));
  });

  test('repo.deleteRecords llama a Kotlin con tipo y claves y recarga; si Kotlin falla devuelve null', () async {
    final calls = <MethodCall>[]; var fail = false;
    bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); if (c.method == 'deleteRecords' && fail) throw PlatformException(code: 'STORE'); return c.method == 'getData' ? '[]' : null; });
    final repo = VigorRepo();
    final rep = await repo.deleteRecords('sleep', ['2026-11-20']);
    expect(rep, isNotNull); expect(calls.firstWhere((c) => c.method == 'deleteRecords').arguments, {'type': 'sleep', 'keys': ['2026-11-20']});
    expect(calls.any((c) => c.method == 'getData'), true);
    fail = true; expect(await repo.deleteRecords('session', ['x']), isNull);
  });

  testWidgets('Sueño: botón de borrar de 48 dp, confirma y llama a deleteRecords', (t) async {
    final sample = File('test/fixtures_sleep_real.json').readAsStringSync(); final calls = <MethodCall>[];
    bm.setMockMethodCallHandler(_mc, (c) async { calls.add(c); return c.method == 'getData' ? (c.arguments['kind'] == 'sleep' ? sample : '[]') : null; });
    final repo = VigorRepo(); await t.runAsync(repo.reload);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: MediaQuery(data: const MediaQueryData(size: Size(360, 740), textScaler: TextScaler.linear(2)), child: Scaffold(body: SleepPage(repo)))));
    final b = find.byTooltip('Borrar la noche del 2026-11-20');
    await t.scrollUntilVisible(b, 300, scrollable: find.byType(Scrollable).first); expect(b, findsOneWidget);
    expect(t.getSize(b).height, greaterThanOrEqualTo(48));
    await t.tap(b); await t.pumpAndSettle();
    expect(find.textContaining('no se puede deshacer'), findsOneWidget);
    await t.tap(find.text('Cancelar')); await t.pumpAndSettle();
    expect(calls.where((c) => c.method == 'deleteRecords'), isEmpty);
    await t.tap(b); await t.pumpAndSettle(); await t.tap(find.text('Borrar')); await t.pumpAndSettle();
    expect(calls.where((c) => c.method == 'deleteRecords').length, 1);
    expect(t.takeException(), isNull);
  });
}
