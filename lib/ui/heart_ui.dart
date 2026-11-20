import 'package:flutter/material.dart';
import '../data/heart_meter.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'fx.dart';
import 'widgets.dart';

/// Centro del reloj: pulso en vivo (medición pedida), si no el último registro del día. Pulsarlo ofrece medir ahora.
class HeartCenter extends StatelessWidget {
  final VigorRepo repo; final Sample? lastRecord; final bool canMeasure;
  const HeartCenter({super.key, required this.repo, required this.lastRecord, required this.canMeasure});

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final m = repo.heart;
    return ListenableBuilder(listenable: m, builder: (context, _) {
      final live = m.active; final fresh = m.hasFresh; final rec = lastRecord;
      final num? bpm = fresh ? m.value : rec?.v;
      final String cap = live ? (m.value == null ? 'midiendo…' : 'pulso en vivo') : fresh ? 'medido a las ${hm(m.at!)}' : rec != null ? 'último registro de ${hm(rec.t)}' : 'toca para medir';
      final txt = bpm == null ? 'Medir pulso' : '${bpm.round()} bpm';
      final label = bpm == null ? (canMeasure ? 'Medir pulso ahora. Botón' : 'Sin pulso registrado') : 'Pulso $cap: ${bpm.round()} latidos por minuto.${canMeasure ? ' Toca para medir ahora.' : ''}';
      final body = ConstrainedBox(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (bpm != null) PulseHeart(bpm: bpm.toDouble(), color: c.heart, size: 18) else Icon(Icons.favorite_border, size: 18, color: c.heart),
          const SizedBox(width: 6), Text(txt, style: VT.heading(c)),
        ]),
        Text(cap, style: VT.caption(c)),
      ]));
      return Semantics(button: canMeasure, container: true, label: label, child: ExcludeSemantics(child: canMeasure
          ? InkWell(borderRadius: BorderRadius.circular(24), onTap: () => showMeasureSheet(context, repo), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: body))
          : body));
    });
  }
}

/// Hoja "Medir pulso ahora". Al cerrarla (o salir de la app) la medición se cancela y la pulsera deja de medir.
Future<void> showMeasureSheet(BuildContext context, VigorRepo repo) async {
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _MeasureSheet(repo));
  repo.heart.cancel();
}

class _MeasureSheet extends StatelessWidget {
  final VigorRepo repo; const _MeasureSheet(this.repo);
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final m = repo.heart;
    return SafeArea(child: ListenableBuilder(listenable: Listenable.merge([m, repo]), builder: (context, _) {
      final connected = repo.conn == 'connected'; final busy = repo.syncing;
      final head = switch (m.phase) {
        HeartPhase.starting => 'Iniciando la medición…',
        HeartPhase.measuring => m.value == null ? 'Midiendo… espera sin moverte' : 'Midiendo: ${m.value} bpm',
        HeartPhase.done => 'Tu pulso: ${m.value} bpm',
        HeartPhase.failed => 'No se pudo medir',
        HeartPhase.idle => 'Medir pulso ahora',
      };
      return SingleChildScrollView(padding: const EdgeInsets.all(Sp.x4), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, liveRegion: true, child: Text(head, style: VT.heading(c))),
        const SizedBox(height: Sp.x2),
        if (m.active) ...[
          LinearProgressIndicator(value: m.value == null ? null : (m.progressCount / HeartMeter.needed).clamp(0.0, 1.0).toDouble(), minHeight: 8),
          const SizedBox(height: Sp.x2),
        ],
        if (m.message != null) Padding(padding: const EdgeInsets.only(bottom: Sp.x2), child: Semantics(liveRegion: true, child: Text(m.message!, style: VT.body(c)))),
        if (!connected) Text('Conecta la pulsera para medir.', style: VT.body(c))
        else if (busy && !m.active) Text('Espera a que termine la sincronización.', style: VT.body(c))
        else if (m.phase == HeartPhase.idle) Text('Mantén la pulsera ajustada y el brazo quieto. Dura unos 30 s y se para sola (máximo ${HeartMeter.maxDuration.inSeconds} s). Es una medición puntual del sensor óptico, no un diagnóstico.', style: VT.body(c)),
        if (m.phase == HeartPhase.done) Text('Medición puntual del sensor óptico de la pulsera, aproximada. No es un diagnóstico.', style: VT.caption(c)),
        const SizedBox(height: Sp.x3),
        Row(children: [
          if (m.active) Expanded(child: SizedBox(height: 48, child: OutlinedButton(onPressed: m.cancel, child: const Text('Cancelar'))))
          else ...[
            Expanded(child: SizedBox(height: 48, child: FilledButton(onPressed: connected && !busy ? m.begin : null, child: Text(m.phase == HeartPhase.idle ? 'Empezar' : 'Medir otra vez')))),
            const SizedBox(width: Sp.x2),
            Expanded(child: SizedBox(height: 48, child: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cerrar')))),
          ],
        ]),
      ]));
    }));
  }
}
