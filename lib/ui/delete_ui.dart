import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Confirma y ejecuta un borrado individual. [type]: 'sleep' | 'session' | 'day'. [what]: texto de lo que se borra.
/// Devuelve true si se borró en este móvil. Muestra un SnackBar con lo que se borró y lo que no.
Future<bool> confirmAndDelete(BuildContext context, VigorRepo repo, {required String type, required List<String> keys, required String title, required String what}) async {
  final h = repo.health; await h.loadLedgerForUi();
  final sent = switch (type) { 'sleep' => keys.any(h.sleepSent), 'session' => keys.any(h.sessionSent), _ => keys.any(h.daySent) };
  if (!context.mounted) return false;
  final p = h.gateway.platformName;
  var also = sent;
  final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('$what\n\nSe borra de este móvil y no se puede deshacer. La pulsera puede seguir guardándolo, pero Vigor no volverá a mostrarlo ni a guardarlo al sincronizar.'),
      if (sent) CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: also, onChanged: (v) => set(() => also = v ?? false),
          title: Text('También borrar de $p'), subtitle: const Text('Ya se envió. Solo se puede borrar lo que escribió Vigor.')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar'))])));
  if (ok != true) return false;
  final rep = await repo.deleteRecords(type, keys, alsoHealth: sent && also);
  if (!context.mounted) return rep != null;
  final msg = rep == null ? 'No se pudo borrar. Inténtalo de nuevo.' : [
    'Borrado de este móvil.',
    if (sent && !also) 'Sigue en $p (no lo marcaste).' else if (rep.ok > 0 && rep.failed == 0) 'También borrado de $p.',
    ...rep.notes,
  ].join(' ');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
  return rep != null;
}

/// Botón de borrar de 48 dp con tooltip y etiqueta accesible.
class DeleteButton extends StatelessWidget {
  final String label; final VoidCallback onPressed; const DeleteButton(this.label, this.onPressed, {super.key});
  @override
  Widget build(BuildContext context) => IconButton(tooltip: label, onPressed: onPressed, constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: Icon(Icons.delete_outline, color: VC.of(context).danger));
}

/// Settings > Privacidad y datos > Gestionar datos: borrar por tipo o por día.
class ManageDataPanel extends StatelessWidget {
  final VigorRepo repo; const ManageDataPanel(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = repo;
    final btn = OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: c.danger, side: BorderSide(color: c.danger.withValues(alpha: .6)));
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Gestionar datos', style: VT.heading(c)),
      const Note('Borra registros concretos de este móvil. La pulsera puede seguir guardándolos, pero Vigor los ignora al sincronizar. Cada borrado pide confirmación.'),
      const SizedBox(height: Sp.x2),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
        OutlinedButton(style: btn, onPressed: r.nights.isEmpty ? null : () => confirmAndDelete(context, r, type: 'sleep', keys: [for (final n in r.nights) n.date], title: 'Borrar todas las noches', what: 'Se borrarán las ${r.nights.length} noches de sueño guardadas.'), child: Text('Sueño: todas las noches (${r.nights.length})')),
        OutlinedButton(style: btn, onPressed: r.sessions.isEmpty ? null : () => confirmAndDelete(context, r, type: 'session', keys: [for (final s in r.sessions) s.key], title: 'Borrar todas las sesiones', what: 'Se borrarán las ${r.sessions.length} sesiones deportivas guardadas, con su ruta y pulso.'), child: Text('Ejercicios: todas las sesiones (${r.sessions.length})')),
        OutlinedButton(style: btn, onPressed: r.days.isEmpty ? null : () async {
          final ks = r.dayKeys; final last = DateTime.parse(ks.last);
          final d = await showDatePicker(context: context, initialDate: last, firstDate: DateTime.parse(ks.first), lastDate: last, selectableDayPredicate: (x) => ks.contains('${x.year}-${two(x.month)}-${two(x.day)}'), helpText: 'Día cuyos datos borrar');
          if (d != null && context.mounted) { final k = '${d.year}-${two(d.month)}-${two(d.day)}'; await confirmAndDelete(context, r, type: 'day', keys: [k], title: 'Borrar los datos del $k', what: 'Se borrarán pasos, pulso, SpO₂, variabilidad y temperatura del $k. El sueño y los ejercicios se borran por separado.'); }
        }, child: const Text('Datos de un día…')),
      ]),
    ]));
  }
}
