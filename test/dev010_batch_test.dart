import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/health_sync.dart';
import 'dev007_test.dart' show Env, source;

// Datos sintéticos. La cuota de Health Connect cuenta LLAMADAS: cada serie debe ir en una sola llamada por lote.
void main() {
  test('una llamada por lote y serie, no una por dato', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = source(n: 40);
    await e.h.run();
    final datos = e.g.items.where((i) => i.type == HType.heartRate).length;
    expect(datos, 40);
    // 8 series densas como máximo (pasos, distancia, calorías, pulso, HRV, reposo, SpO2, temperatura) -> pocas llamadas, no ~300.
    expect(e.g.batchCalls, lessThanOrEqualTo(8));
    expect(e.g.batchCalls, greaterThan(0));
  });

  test('si se corta a mitad (cuota), la marca queda donde se cortó y se reanuda sin repetir', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = source(n: 10);
    var vistos = 0;
    e.g.onWrite = (it) { if (it.type == HType.heartRate) { vistos++; if (vistos == 3) e.g.failTypes.add(HType.heartRate); } };
    await e.h.run();
    expect(e.g.items.where((i) => i.type == HType.heartRate).length, 3, reason: 'se escribieron 3 y el cuarto fue rechazado');
    expect(e.h.catStatus(HealthCat.heart), isNotEmpty);
    e.g.failTypes.clear();
    await e.h.run();
    final hr = e.g.items.where((i) => i.type == HType.heartRate).toList();
    expect(hr.length, 10, reason: 'reanuda desde el punto de corte sin repetir los 3 primeros');
    expect({for (final i in hr) i.start}.length, 10);
  });

  test('el tope por ronda deja el resto para la siguiente sincronización', () async {
    final e = Env(); await e.h.init({}); await e.h.setMaster(true);
    e.src = source(n: 6);
    await e.h.run();
    final antes = e.g.items.length;
    await e.h.run();
    expect(e.g.items.length, antes, reason: 'sin datos nuevos no se reenvía nada');
    expect(kMaxDensePerRun, greaterThan(500));
  });
}
