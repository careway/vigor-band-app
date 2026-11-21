import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/sports.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Modos que se ofrecen arriba, sin buscar (selección editorial, no una afirmación de soporte de la pulsera).
const quickSportKeys = ['OUTDOOR_RUNNING', 'OUTDOOR_WALK', 'OUTDOOR_RIDING', 'HIKE', 'SWIM', 'FITNESS', 'YOGA', 'INDOOR_RUNNING'];

Color groupColor(VC c, SportGroup g) => switch (g) {
      SportGroup.run => c.heart, SportGroup.walk => c.steps, SportGroup.bike => c.met, SportGroup.gym => c.stress,
      SportGroup.mind => c.sleep, SportGroup.dance => c.hrv, SportGroup.combat => c.heart, SportGroup.ball => c.steps,
      SportGroup.racket => c.temp, SportGroup.water => c.spo2, SportGroup.snow => c.spo2, SportGroup.other => c.exp,
    };

/// Hoja inferior con buscador y rejilla (bento) agrupada de todos los modos. Devuelve el modo elegido.
Future<SportMode?> showSportPicker(BuildContext context, int selectedId) => showModalBottomSheet<SportMode>(
      context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true,
      backgroundColor: VC.of(context).bg,
      builder: (_) => SportPicker(selectedId: selectedId),
    );

class SportPicker extends StatefulWidget {
  final int selectedId; const SportPicker({super.key, required this.selectedId});
  @override
  State<SportPicker> createState() => _SportPickerState();
}

class _SportPickerState extends State<SportPicker> {
  String q = ''; int kind = 0; // 0 todos, 1 recorrido, 2 interior
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    final groups = sportsByGroup(query: q, kind: kind);
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
    final extent = 104.0 * math.max(1.0, scale * .9);
    return DraggableScrollableSheet(
      expand: false, initialChildSize: .92, maxChildSize: .98, minChildSize: .5,
      builder: (ctx, ctl) => CustomScrollView(controller: ctl, slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x2), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Elige el modo deportivo', style: VT.title(c)),
          const SizedBox(height: Sp.x2),
          Text('Si tu pulsera no admite el modo elegido, no empezará.', style: VT.caption(c)),
          const SizedBox(height: Sp.x3),
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar modo', filled: true, fillColor: c.surfaceHi, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: Sp.x3),
          SegmentedButton<int>(
            showSelectedIcon: false, style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
            segments: const [ButtonSegment(value: 0, label: Text('Todos')), ButtonSegment(value: 1, icon: Icon(Icons.route), label: Text('Recorrido')), ButtonSegment(value: 2, icon: Icon(Icons.home_outlined), label: Text('Interior'))],
            selected: {kind}, onSelectionChanged: (v) => setState(() => kind = v.first)),
          const SizedBox(height: Sp.x2),
          Text(kind == 1 ? 'Recorrido: la pulsera traza la ruta con GPS; verás mapa, distancia y ritmo.' : kind == 2 ? 'Interior / sin GPS: no se usa ni se pide GPS; verás duración, pulso y calorías.' : 'Recorrido = ruta con GPS. Interior = sin GPS.', style: VT.caption(c)),
          if (q.isEmpty && kind == 0) ...[
            const SizedBox(height: Sp.x4), Text('Habituales', style: VT.heading(c)), const SizedBox(height: Sp.x2),
            Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
              for (final k in quickSportKeys) if (sportByKey(k) != null) _QuickChip(sportByKey(k)!, widget.selectedId, (m) => Navigator.of(ctx).pop(m)),
            ]),
          ],
        ]))),
        if (groups.isEmpty) const SliverFillRemaining(hasScrollBody: false, child: EmptyState(Icons.search_off, 'Ningún modo coincide con la búsqueda.')),
        for (final e in groups.entries) ...[
          SliverPadding(padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x2), sliver: SliverToBoxAdapter(child: Semantics(header: true, child: Row(children: [
            Icon(e.key.icon, size: 18, color: groupColor(c, e.key)), const SizedBox(width: Sp.x2),
            Expanded(child: Text('${e.key.label} (${e.value.length})', style: VT.heading(c)))])))),
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: Sp.x4), sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 124, mainAxisExtent: extent, mainAxisSpacing: Sp.x2, crossAxisSpacing: Sp.x2),
            delegate: SliverChildBuilderDelegate((_, i) => SportTile(e.value[i], selected: e.value[i].id == widget.selectedId, onTap: () => Navigator.of(ctx).pop(e.value[i])), childCount: e.value.length),
          )),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: Sp.x8)),
      ]),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final SportMode m; final int selectedId; final ValueChanged<SportMode> onTap;
  const _QuickChip(this.m, this.selectedId, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final sel = m.id == selectedId; final col = groupColor(c, m.group);
    return Semantics(button: true, selected: sel, label: m.name, child: ExcludeSemantics(child: Material(
      color: sel ? col.withValues(alpha: .22) : c.surfaceHi, shape: StadiumBorder(side: BorderSide(color: sel ? col : Colors.transparent, width: 1.5)),
      child: InkWell(customBorder: const StadiumBorder(), onTap: () => onTap(m), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.x3), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(m.icon, size: 20, color: col), const SizedBox(width: Sp.x2), Text(m.name, style: VT.body(c))])))),
    )));
  }
}

/// Tesela de la rejilla: icono sobre fondo tintado + nombre (máx. 2 líneas). Alto >= 48 dp y área táctil completa.
class SportTile extends StatelessWidget {
  final SportMode mode; final bool selected; final VoidCallback onTap;
  const SportTile(this.mode, {super.key, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final col = groupColor(c, mode.group);
    return Semantics(button: true, selected: selected, label: '${mode.name}, ${mode.group.label}${mode.tracksRoute ? ', recorrido con GPS' : ', interior o sin GPS'}', child: ExcludeSemantics(child: Material(
      color: selected ? col.withValues(alpha: .20) : c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: selected ? col : c.muted.withValues(alpha: .25), width: selected ? 2 : 1)),
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.all(Sp.x2), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(mode.icon, size: 28, color: col), const SizedBox(height: Sp.x1),
        Flexible(child: Text(mode.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: VT.caption(c).copyWith(color: c.text, fontWeight: FontWeight.w600))),
        Icon(mode.tracksRoute ? Icons.route : Icons.home_outlined, size: 12, color: c.muted),
      ]))),
    )));
  }
}
