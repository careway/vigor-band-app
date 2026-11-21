import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'package:vigor_app/data/repo.dart';
import 'dev007_test.dart' show Env;

// Datos sintéticos. Fases por minuto: 2 ligero, 3 profundo, 2 REM, 1 despierto.
final _down = DateTime(2026, 11, 20, 1, 0);
List<Stage> _st() => [...List.filled(2, Stage.light), ...List.filled(3, Stage.deep), ...List.filled(2, Stage.rem), Stage.awake];
Night _night({bool stages = true}) => Night('2026-11-20', 7, 3, 2, 0, _down, _down.add(const Duration(minutes: 8)), stages: stages ? _st() : null, precise: true);

void main() {
  test('fromNight agrupa el hipnograma en tramos con los códigos de Health Connect (1, 4, 5, 6)', () {
    final o = SleepStagesOut.fromNight(_night())!; final t0 = _down.millisecondsSinceEpoch; const m = 60000;
    expect(o.runs, [[t0, t0 + 2 * m, 4], [t0 + 2 * m, t0 + 5 * m, 5], [t0 + 5 * m, t0 + 7 * m, 6], [t0 + 7 * m, t0 + 8 * m, 1]]);
    expect(o.written, false);
  });
  test('sin fases o sin hora de inicio no hay SleepStagesOut', () {
    expect(SleepStagesOut.fromNight(_night(stages: false)), isNull);
    expect(SleepStagesOut.fromNight(Night('d', 7, 3, 2, 0, null, null, stages: _st())), isNull);
  });

  test('con fases: version = base + offset; si la pasarela las escribe, no se reenvía', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.g.onWrite = (it) { it.stages?.written = true; };
    e.src = HealthSource(const {}, [_night()], const [], const {});
    await e.h.run();
    final w = e.g.items.where((i) => i.type == HType.sleep).toList();
    final base = DateTime(2026, 11, 20, 1, 8).millisecondsSinceEpoch ~/ 60000;
    expect(w.length, 1); expect(w.first.stages, isNotNull); expect(w.first.version, (base + kStagedVersionOffset).toDouble());
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.sleep).length, 1, reason: 'ya enviada con fases');
  });

  test('si las fases no se pudieron escribir (cae a sesión sin fases) se guarda la versión base y se reintenta con fases', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = HealthSource(const {}, [_night()], const [], const {});
    await e.h.run();   // la pasarela falsa no marca written: simula el fallback
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.sleep).length, 2, reason: 'reintenta con fases en la siguiente sincronización');
    e.g.onWrite = (it) { it.stages?.written = true; };
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.sleep).length, 3);
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.sleep).length, 3, reason: 'cuando se escribe con fases deja de reenviar');
  });

  test('noche sin fases: version base y sin SleepStagesOut; si luego llegan fases se reenvía con versión mayor', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = HealthSource(const {}, [_night(stages: false)], const [], const {});
    await e.h.run();
    var w = e.g.items.where((i) => i.type == HType.sleep).toList();
    expect(w.length, 1); expect(w.first.stages, isNull); expect(w.first.version, lessThan(kStagedVersionOffset));
    e.g.onWrite = (it) { it.stages?.written = true; };
    e.src = HealthSource(const {}, [_night()], const [], const {});
    await e.h.run();
    w = e.g.items.where((i) => i.type == HType.sleep).toList();
    expect(w.length, 2); expect(w.last.stages, isNotNull); expect(w.last.version, greaterThan(kStagedVersionOffset));
  });

  test('iPhone: no se usa la ruta de fases de Android (versión base, sin SleepStagesOut)', () async {
    final e = Env(ios: true); await e.h.init({}); await e.h.setMaster(true);
    e.src = HealthSource(const {}, [_night()], const [], const {});
    await e.h.run();
    final w = e.g.items.where((i) => i.type == HType.sleep).toList();
    expect(w.length, 1); expect(w.first.stages, isNull); expect(w.first.version, lessThan(kStagedVersionOffset));
  });
}
