import 'package:flutter/material.dart';
import '../data/health_sync.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'device_page.dart';
import 'widgets.dart';

/// Texto de política de privacidad / racionalidad de permisos (el mismo contenido que muestra la pantalla nativa de Android).
const kHealthPolicy = 'Vigor solo ESCRIBE en {P} los datos que su pulsera ha medido, y solo si tú lo activas aquí, categoría por categoría. '
    'Vigor no lee datos de {P} ni de otras apps. No envía estos datos a ningún servidor ni a terceros: van únicamente de tu pulsera a tu móvil. '
    'La glucosa, los componentes sanguíneos, el estrés, el MET y la temperatura de la piel no se envían nunca (son estimaciones no validadas o no tienen un tipo equivalente). '
    'Los datos son orientativos y no sirven para diagnosticar ni tratar enfermedades.';

/// Ajustes > Salud y compartir. Lado iPhone: implementado, no compilado ni probado.
class HealthPage extends StatelessWidget {
  final VigorRepo repo; const HealthPage(this.repo, {super.key});

  @override
  Widget build(BuildContext context) {
    final h = repo.health, g = h.gateway, c = VC.of(context), p = g.platformName;
    return ListenableBuilder(listenable: h, builder: (context, _) => SettingsScaffold('Salud y compartir', [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Compartir con $p', style: VT.heading(c)),
          subtitle: Text(h.master ? 'Activado: Vigor escribe en $p tras cada sincronización de la pulsera.' : 'Desactivado: no se envía nada. Es opcional.', style: VT.caption(c)),
          value: h.master, onChanged: h.running ? null : (v) => h.setMaster(v)),
        Note(kHealthPolicy.replaceAll('{P}', p)),
        if (g.isIos) const Note('iPhone / Apple Salud: implementado pero NO compilado ni probado (no había Mac). Puede fallar.'),
      ])),
      if (h.master) ...[
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(liveRegion: true, container: true, child: Text(_status(h), style: VT.body(c))),
          if (h.message != null) Note(h.message!),
          if (h.running) const Padding(padding: EdgeInsets.only(top: Sp.x2), child: LinearProgressIndicator()),
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            FilledButton(onPressed: h.running ? null : () { h.run(); }, style: FilledButton.styleFrom(minimumSize: const Size(48, 48)), child: const Text('Enviar ahora')),
            if (!g.isIos) OutlinedButton(onPressed: g.openSettings, style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)), child: const Text('Abrir ajustes de Health Connect')),
            if (h.avail == HealthAvail.notInstalled || h.avail == HealthAvail.updateRequired) OutlinedButton(onPressed: g.installProvider, style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)), child: const Text('Instalar Health Connect')),
          ]),
          if (g.isIos) const Note('Para revisar o retirar permisos: app Salud > Compartir > Apps > Vigor.'),
        ])),
        const SectionHeader('Qué se comparte'),
        for (final cat in HealthCat.values) _CatTile(h: h, cat: cat),
        const SectionHeader('Dejar de compartir'),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Note('«Dejar de compartir» desactiva todo y detiene los envíos. No revoca los permisos del sistema ni borra lo ya enviado: para eso, usa $p (en Android: Ajustes de Health Connect > Permisos de apps > Vigor y Datos y acceso) o el borrado de abajo.'),
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            OutlinedButton(onPressed: () => h.stopSharing(), style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)), child: const Text('Dejar de compartir')),
            OutlinedButton(onPressed: h.running ? null : () => _confirmDelete(context, h, p), style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: c.danger, side: BorderSide(color: c.danger.withValues(alpha: .6))), child: Text('Borrar lo que Vigor envió a $p')),
          ]),
        ])),
      ] else if (h.message != null) Panel(child: Text(h.message!, style: VT.body(c))),
    ]));
  }

  static String _status(HealthSync h) {
    final last = h.last == null ? 'Último envío: todavía ninguno.' : 'Último envío: ${h.last!.day}/${h.last!.month} ${hm(h.last!)} · ${h.totalSent} datos en total.';
    final s = switch (h.state) {
      HealthState.running => 'Enviando…',
      HealthState.needsPermission => 'Faltan permisos del sistema.',
      HealthState.unavailable => 'No disponible en este dispositivo.',
      HealthState.error => 'Hubo un problema con el último envío.',
      _ => 'Listo.',
    };
    return '$s $last';
  }

  Future<void> _confirmDelete(BuildContext context, HealthSync h, String p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Borrar de $p'),
      content: Text('Vigor pedirá a $p que borre los datos que Vigor escribió (pasos, pulso, SpO₂, sueño, ejercicios…). Solo se pueden borrar los datos escritos por Vigor, no los de otras apps. Si compartes de nuevo, se volverán a enviar los últimos días. Esta acción no se puede deshacer.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar'))]));
    if (ok == true) await h.deleteSent();
  }
}

class _CatTile extends StatelessWidget {
  final HealthSync h; final HealthCat cat; const _CatTile({required this.h, required this.cat});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final on = h.cats[cat] == true; final perm = h.granted[cat] == true;
    final dep = cat == HealthCat.route && h.cats[HealthCat.exercise] != true;
    final sub = '${cat.sends}\n${h.catStatus(cat)}';
    return Panel(padding: EdgeInsets.zero, child: Column(children: [
      SwitchListTile(title: Text(cat.title, style: VT.heading(c)), subtitle: Text(sub, style: VT.caption(c)), value: on, onChanged: (v) => h.setCat(cat, v)),
      if (on && h.master) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: Sp.x4, bottom: Sp.x2),
        child: TextButton(onPressed: h.running || dep || !perm ? null : () { h.retryCat(cat); }, style: TextButton.styleFrom(minimumSize: const Size(48, 48)), child: Text(cat == HealthCat.sleep ? 'Reintentar sueño' : 'Reenviar ${cat.title.toLowerCase()}')))),
    ]));
  }
}
