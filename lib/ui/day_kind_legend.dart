import 'package:flutter/material.dart';
import '../data/day_kinds.dart';
import '../theme/tokens.dart';
import 'charts.dart';

/// Leyenda del reloj: una barra de degradado reposo → actividad leve → actividad deportiva, el morado del sueño y las horas de cada tipo.
/// El color nunca es la única señal: cada tipo lleva su nombre y sus horas.
class DayKindLegend extends StatelessWidget {
  final List<DayKind> kinds; const DayKindLegend(this.kinds, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final n = countKinds(kinds);
    String hours(DayKind k) { final m = (n[k] ?? 0) * 30; return m == 0 ? '—' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min'); }
    const order = [DayKind.rest, DayKind.walk, DayKind.activity, DayKind.sleep];
    final spoken = order.map((k) => '${dayKindLabel(k)} ${hours(k)}').join(', ');
    return Semantics(container: true, label: 'Anillo exterior del reloj por franjas de 30 minutos, con color mezclado entre reposo, actividad leve y actividad deportiva; el sueño predomina: $spoken', child: ExcludeSemantics(child: Column(children: [
      Container(height: 10, margin: const EdgeInsets.symmetric(horizontal: Sp.x4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
          gradient: LinearGradient(colors: [for (var i = 0; i <= 8; i++) effortColor(c, i / 8)]))),
      const SizedBox(height: Sp.x2),
      Wrap(alignment: WrapAlignment.center, spacing: Sp.x4, runSpacing: Sp.x2, children: [
        for (final k in order) ConstrainedBox(constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width - Sp.x4 * 4) / 2), child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Container(width: 12, height: 12, decoration: BoxDecoration(color: dayKindColor(c, k), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(width: Sp.x1 + 2), Flexible(child: Text('${dayKindLabel(k)} ${hours(k)}', style: VT.caption(c))),
        ])),
      ]),
    ])));
  }
}
