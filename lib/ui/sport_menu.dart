import 'package:flutter/material.dart';
import '../data/sports.dart';
import '../theme/tokens.dart';
import 'sport_picker.dart';
import 'widgets.dart';

/// «Iniciar nueva actividad»: menú compacto de dos niveles en una hoja inferior. Nivel 1: las familias (Carrera, Ciclismo, Gimnasio…);
/// nivel 2: los modos de la familia elegida, con una atrás. Un buscador salta directamente a los modos. Devuelve el modo elegido.
Future<SportMode?> showSportMenu(BuildContext context, {int? selectedId}) => showModalBottomSheet<SportMode>(
      context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, backgroundColor: VC.of(context).bg,
      builder: (_) => SportMenu(selectedId: selectedId));

class SportMenu extends StatefulWidget {
  final int? selectedId; const SportMenu({super.key, this.selectedId});
  @override
  State<SportMenu> createState() => _SportMenuState();
}

class _SportMenuState extends State<SportMenu> {
  SportGroup? group; String q = '';
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return DraggableScrollableSheet(expand: false, initialChildSize: .7, maxChildSize: .95, minChildSize: .4, builder: (ctx, ctl) {
      final searching = q.trim().isNotEmpty;
      final List<Widget> body = searching ? _results(c, ctx) : group == null ? _groups(c) : _modes(c, ctx, group!);
      return ListView(controller: ctl, padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8), children: [
        Row(children: [
          if (group != null && !searching) Semantics(button: true, label: 'Volver a las familias', child: IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), onPressed: () => setState(() => group = null), icon: const Icon(Icons.arrow_back))),
          Expanded(child: Semantics(header: true, child: Text(searching ? 'Resultados' : group == null ? 'Iniciar nueva actividad' : group!.label, style: VT.title(c)))),
        ]),
        const SizedBox(height: Sp.x2),
        TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar actividad', isDense: true, filled: true, fillColor: c.surfaceHi, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: Sp.x3),
        ...body,
      ]);
    });
  }

  List<Widget> _groups(VC c) {
    final by = sportsByGroup();
    return [
      Text('Elige una familia y después la actividad.', style: VT.caption(c)), const SizedBox(height: Sp.x2),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [for (final e in by.entries) _GroupChip(e.key, e.value.length, () => setState(() => group = e.key))]),
    ];
  }

  List<Widget> _modes(VC c, BuildContext ctx, SportGroup g) {
    final modes = sportsByGroup()[g] ?? const [];
    return [for (final m in modes) _ModeRow(m, widget.selectedId == m.id, () => Navigator.of(ctx).pop(m))];
  }

  List<Widget> _results(VC c, BuildContext ctx) {
    final by = sportsByGroup(query: q);
    if (by.isEmpty) return [const EmptyState(Icons.search_off, 'Ninguna actividad coincide con la búsqueda.')];
    return [for (final e in by.entries) for (final m in e.value) _ModeRow(m, widget.selectedId == m.id, () => Navigator.of(ctx).pop(m), subtitle: e.key.label)];
  }
}

class _GroupChip extends StatelessWidget {
  final SportGroup g; final int n; final VoidCallback onTap;
  const _GroupChip(this.g, this.n, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final col = groupColor(c, SportGroup.values.contains(g) ? g : SportGroup.other);
    return Semantics(button: true, label: '${g.label}, $n actividades', child: ExcludeSemantics(child: Material(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48, minWidth: 140), child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(g.icon, color: col, size: 22), const SizedBox(width: Sp.x2), Flexible(child: Text(g.label, style: VT.body(c).copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(width: Sp.x2), Text('$n', style: VT.caption(c)), const Icon(Icons.chevron_right, size: 18)])))))));
  }
}

class _ModeRow extends StatelessWidget {
  final SportMode m; final bool selected; final VoidCallback onTap; final String? subtitle;
  const _ModeRow(this.m, this.selected, this.onTap, {this.subtitle});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final col = groupColor(c, m.group);
    final gps = m.tracksRoute ? 'recorrido con GPS' : 'interior, sin GPS';
    return Semantics(button: true, selected: selected, label: '${m.name}, ${subtitle == null ? '' : '${subtitle!}, '}$gps', child: ExcludeSemantics(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Padding(padding: const EdgeInsets.symmetric(vertical: Sp.x1, horizontal: Sp.x2), child: Row(children: [
        Icon(m.icon, color: col, size: 22), const SizedBox(width: Sp.x3),
        Expanded(child: Text(m.name, style: VT.body(c).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
        if (subtitle != null) Padding(padding: const EdgeInsets.only(right: Sp.x2), child: Text(subtitle!, style: VT.caption(c))),
        Icon(m.tracksRoute ? Icons.route : Icons.home_outlined, size: 16, color: c.muted), if (selected) Padding(padding: const EdgeInsets.only(left: Sp.x2), child: Icon(Icons.check, size: 18, color: col)),
      ]))))));
  }
}
