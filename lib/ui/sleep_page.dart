import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

class SleepPage extends StatelessWidget {
  final VigorRepo repo; const SleepPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    if (repo.nights.isEmpty) {
      return EmptyState(Icons.bedtime_outlined, 'Aún no hay noches registradas.\nLleva la pulsera puesta al dormir y sincroniza por la mañana.', action: FilledButton(onPressed: repo.conn == 'connected' ? repo.sync : null, child: const Text('Sincronizar')));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
      for (final n in repo.nights) Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MetricHeader(Icons.bedtime, n.date, c.sleep), const SizedBox(height: Sp.x3),
        BigValue(dur(n.total * 60), '', size: 32),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x6, runSpacing: Sp.x2, children: [
          Stat('Despertares', '${n.wake}'),
          if (n.down != null && n.up != null) Stat('Horario', '${hm(n.down!)} – ${hm(n.up!)}'),
          Stat('Profundo aprox.', dur(n.deep * 60)), Stat('Ligero aprox.', dur(n.light * 60)),
        ]),
        const Note('Las fases son aproximadas: los relojes de consumo sobreestiman el sueño ligero (Chinoy 2021). Se prioriza duración y despertares.'),
      ])),
    ]);
  }
}
