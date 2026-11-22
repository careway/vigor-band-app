import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/auto_sync.dart';

/// C3 (noche 2026-11-22): AutoSync con fallos encadenados. Reloj y acciones simulados, sin pulsera.
void main() {
  late DateTime now; late String st; late DateTime? last; late bool busy;
  late int connects, syncs; late bool connectThrows, syncThrows;
  AutoSync mk() => AutoSync(
        clock: () => now, connState: () => st, hasMac: () => true, lastSync: () => last, busy: () => busy,
        connect: () async { connects++; if (connectThrows) throw Exception('connect'); },
        sync: () async { syncs++; if (syncThrows) throw Exception('sync'); },
      )..foreground = true;
  setUp(() {
    now = DateTime(2026, 1, 1, 12); st = 'disconnected'; last = null; busy = false;
    connects = 0; syncs = 0; connectThrows = false; syncThrows = false;
  });

  test('reconnectDelay: crece hasta el tope de 10 min y no pasa de ahi', () {
    expect([for (var i = 1; i <= 6; i++) reconnectDelay(i).inSeconds], [15, 30, 60, 120, 300, 600]);
    expect(reconnectDelay(7).inSeconds, 600);
    expect(reconnectDelay(1000).inSeconds, 600);
    expect(reconnectDelay(0).inSeconds, 15);
    expect(reconnectDelay(-3).inSeconds, 15);
  });

  test('fallos de conexion encadenados: backoff real hasta el tope', () async {
    final a = mk(); connectThrows = true;
    final waits = <int>[];
    for (var i = 0; i < 8; i++) {
      await a.evaluate(); expect(connects, i + 1);
      waits.add(a.nextConnectAt!.difference(now).inSeconds);
      // antes de que venza no reintenta
      now = a.nextConnectAt!.subtract(const Duration(seconds: 1)); await a.evaluate(); expect(connects, i + 1);
      now = a.nextConnectAt!;
    }
    expect(waits, [15, 30, 60, 120, 300, 600, 600, 600]);
    expect(a.failures, 8);
  });

  test('un connect que lanza no rompe evaluate ni deja _inFlight colgado', () async {
    final a = mk(); connectThrows = true;
    await a.evaluate(); now = now.add(const Duration(minutes: 11)); await a.evaluate();
    expect(connects, 2);
  });

  test('onResume reinicia fallos y espera', () async {
    final a = mk(); connectThrows = true;
    for (var i = 0; i < 4; i++) { await a.evaluate(); now = a.nextConnectAt!; }
    expect(a.failures, 4);
    connectThrows = false; a.onResume(); await Future<void>.delayed(Duration.zero);
    expect(connects, 5); // reintento inmediato pese a la espera previa
    expect(a.failures, 1); // reiniciado a 0 y este intento cuenta 1
    expect(a.nextConnectAt!.difference(now).inSeconds, 15);
    a.dispose();
  });

  test('al conectar se reinician fallos y espera', () async {
    final a = mk(); connectThrows = true;
    await a.evaluate(); await a.evaluate(); // 2o no pasa (espera)
    expect(a.failures, 1);
    st = 'connected'; last = now; await a.evaluate();
    expect(a.failures, 0); expect(a.nextConnectAt, null);
  });

  test('connecting/scanning no cuentan fallos ni conectan', () async {
    final a = mk();
    for (final s in ['connecting', 'scanning']) { st = s; await a.evaluate(); }
    expect(connects, 0); expect(a.failures, 0);
  });

  test('sync que falla repetidamente: un intento cada >= 2 min mientras lastSync siga viejo', () async {
    final a = mk(); st = 'connected'; syncThrows = true; last = null;
    await a.evaluate(); expect(syncs, 1);
    now = now.add(const Duration(seconds: 119)); await a.evaluate(); expect(syncs, 1);
    now = now.add(const Duration(seconds: 1)); await a.evaluate(); expect(syncs, 2);
    now = now.add(const Duration(minutes: 2)); await a.evaluate(); expect(syncs, 3);
    expect(a.failures, 0); // fallo de sync no cuenta como fallo de conexion
  });

  test('sync que falla no marca lastSync: sigue pendiente; con exito (lastSync nuevo) se detiene', () async {
    final a = mk(); st = 'connected'; syncThrows = true;
    await a.evaluate(); now = now.add(const Duration(minutes: 2)); syncThrows = false;
    await a.evaluate(); expect(syncs, 2);
    last = now; now = now.add(const Duration(minutes: 3)); await a.evaluate(); expect(syncs, 2);
  });

  test('conexion cae durante los reintentos de sync: pasa a connect con backoff desde 15 s', () async {
    final a = mk(); st = 'connected'; syncThrows = true;
    await a.evaluate(); st = 'disconnected'; now = now.add(const Duration(minutes: 3)); connectThrows = true;
    await a.evaluate();
    expect(connects, 1); expect(a.nextConnectAt!.difference(now).inSeconds, 15);
  });

  test('busy bloquea connect y sync aunque haya fallos pendientes', () async {
    final a = mk(); busy = true; await a.evaluate(); st = 'connected'; await a.evaluate();
    expect(connects, 0); expect(syncs, 0);
  });

  test('en segundo plano (onPause) o con enabled=false no actua', () async {
    final a = mk(); a.onPause(); await a.evaluate(); expect(connects, 0);
    a.foreground = true; a.setEnabled(false); await Future<void>.delayed(Duration.zero); expect(connects, 0);
    a.dispose();
  });

  test('onResume con sync pendiente usa el limite corto (5 min) y solo una vez', () async {
    final a = mk(); st = 'connected'; a.intervalMin = 30; last = now.subtract(const Duration(minutes: 6));
    await a.evaluate(); expect(syncs, 0); // sin resume: 6 < 30
    a.onResume(); await Future<void>.delayed(Duration.zero); expect(syncs, 1);
    a.dispose();
  });
}
