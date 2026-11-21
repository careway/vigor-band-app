import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import '../data/sports.dart';
import 'delete_ui.dart';
import 'night_cards.dart';
import 'route_panel.dart';
import 'sport_menu.dart';
import 'sport_picker.dart';
import 'widgets.dart';

/// Pantalla de Actividad: arriba lo que se puede hacer (atajos con lo más frecuente y «Iniciar nueva actividad» con su menú de familias y
/// modos); debajo, SOLO lo realizado hoy. El resto (días anteriores, resumen semanal, borrado por lotes) está en «Historial».
class ActivityPage extends StatefulWidget {
  final VigorRepo repo; const ActivityPage(this.repo, {super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  SportMode mode = sportByKey('OUTDOOR_RUNNING')!;
  bool _picked = false; // ¿el usuario ya eligió un modo? (si no, se propone el más frecuente)

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = widget.repo;
    final quick = frequentSportModes([for (final s in r.sessions) (type: s.sportType, start: s.start)]);
    final cur = _picked ? mode : quick.first;
    final col = groupColor(c, cur.group); final ok = r.conn == 'connected';
    final today = [for (final s in r.sessions) if (startedOnSameDay(s.start, r.clock())) s];
    return ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MetricHeader(Icons.route, 'Iniciar una actividad', c.route),
        const SizedBox(height: Sp.x3),
        Text('Más frecuentes', style: VT.caption(c)), const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [for (final m in quick) _QuickChip2(m, selected: m.id == cur.id, onTap: () => setState(() { mode = m; _picked = true; }))]),
        const SizedBox(height: Sp.x3),
        OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () async {
          final m = await showSportMenu(context, selectedId: cur.id); if (m != null) setState(() { mode = m; _picked = true; });
        }, icon: const Icon(Icons.add), label: const Text('Iniciar nueva actividad…')),
        const SizedBox(height: Sp.x3),
        Semantics(container: true, label: 'Actividad elegida: ${cur.name}. ${cur.group.label}. ${cur.tracksRoute ? 'Recorrido con GPS' : 'Interior, sin GPS'}', child: ExcludeSemantics(child: Container(
          padding: const EdgeInsets.all(Sp.x3), decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(cur.icon, color: col, size: 26), const SizedBox(width: Sp.x3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cur.name, style: VT.heading(c)), Text('${cur.group.label} · ${cur.tracksRoute ? 'recorrido con GPS' : 'interior, sin GPS'}', style: VT.caption(c)),
            ])),
          ])))),
        const SizedBox(height: Sp.x3),
        Row(children: [
          Expanded(flex: 3, child: FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(48, 52)), onPressed: ok ? () => r.startSport(cur.key) : null, icon: const Icon(Icons.play_arrow), label: const Text('Iniciar'))),
          const SizedBox(width: Sp.x2),
          Expanded(flex: 2, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)), onPressed: ok ? r.stopSport : null, icon: const Icon(Icons.stop), label: const Text('Detener'))),
        ]),
        if (!ok) const Note('Conecta la pulsera para iniciar una actividad.'),
        Note(cur.tracksRoute ? 'Modo de recorrido: la pulsera graba sola, con su propio GPS si el modo lo usa (no verificado por modo); luego verás ruta, distancia y ritmo.' : 'Modo de interior: sin GPS; verás duración, pulso y calorías.'),
        const Note('La SDK no indica qué modos admite tu pulsera: si no admite el elegido, no empezará.'),
        if (r.sportMsgs.isNotEmpty) Note(r.sportMsgs.first),
      ])),
      if (r.ageIsDefault) Note('Edad no indicada: el cómputo por pulso, las zonas y el TRIMP usan ${VigorRepo.defaultAge} años por defecto. Indícala en Ajustes → Perfil.'),
      SectionHeader('Actividad de hoy', trailing: r.sessions.isEmpty ? null : TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionHistoryPage(r))), child: const Text('Historial'))),
      if (today.isEmpty) Panel(child: Padding(padding: const EdgeInsets.symmetric(vertical: Sp.x2), child: Text(r.sessions.isEmpty ? 'Aún no hay actividades. Sincroniza la pulsera para leerlas.' : 'Hoy aún no has hecho ninguna actividad. Las de otros días están en «Historial».', style: VT.body(c).copyWith(color: c.muted))))
      else for (final s in today) SessionTile(r, s),
      const Note('Calorías, distancia y ritmo los calcula la pulsera (algoritmo del fabricante).'),
    ]);
  }
}

class _QuickChip2 extends StatelessWidget {
  final SportMode m; final bool selected; final VoidCallback onTap;
  const _QuickChip2(this.m, {required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final col = groupColor(c, m.group);
    return Semantics(button: true, selected: selected, label: m.name, child: ExcludeSemantics(child: Material(
      color: selected ? col.withValues(alpha: .22) : c.surfaceHi, shape: StadiumBorder(side: BorderSide(color: selected ? col : Colors.transparent, width: 1.5)),
      child: InkWell(customBorder: const StadiumBorder(), onTap: onTap, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(m.icon, size: 20, color: col), const SizedBox(width: Sp.x2), Flexible(child: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: VT.body(c)))]))))),
    ));
  }
}

/// Historial: resumen semanal y todas las actividades guardadas, con selección para borrar varias.
class SessionHistoryPage extends StatefulWidget {
  final VigorRepo repo; const SessionHistoryPage(this.repo, {super.key});
  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  bool selecting = false; final sel = <String>{};
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = widget.repo;
    return ListenableBuilder(listenable: r, builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Historial de actividades')),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
        WeeklyActivityCard(r),
        SectionHeader('Actividades guardadas', trailing: r.sessions.isEmpty ? null : TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => setState(() { selecting = !selecting; sel.clear(); }), child: Text(selecting ? 'Cancelar' : 'Seleccionar'))),
        if (selecting) Panel(child: Row(children: [
          Expanded(child: Text(sel.isEmpty ? 'Toca las sesiones que quieras borrar.' : '${sel.length} seleccionada(s)', style: VT.body(c))),
          FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: c.danger), onPressed: sel.isEmpty ? null : () async {
            final keys = sel.toList(); final done = await confirmAndDelete(context, r, type: 'session', keys: keys, title: 'Borrar ${keys.length} sesión(es)', what: 'Se borrarán ${keys.length} sesiones deportivas de la app, con su ruta y pulso por minuto.');
            if (done && mounted) setState(() { selecting = false; sel.clear(); });
          }, icon: const Icon(Icons.delete_outline), label: const Text('Borrar')),
        ])),
        if (r.sessions.isEmpty) const SizedBox(height: 240, child: EmptyState(Icons.directions_run, 'Aún no hay actividades. Sincroniza la pulsera para leerlas.'))
        else for (final s in r.sessions) SessionTile(r, s, selecting: selecting, selected: sel.contains(s.key), onToggle: () => setState(() { if (!sel.remove(s.key)) sel.add(s.key); })),
      ]),
    ));
  }
}

/// Tarjeta de una sesión: icono, nombre, fecha y datos principales. Toca para abrir el detalle (o para marcarla si se está seleccionando).
class SessionTile extends StatelessWidget {
  final VigorRepo repo; final Session s; final bool selecting, selected; final VoidCallback? onToggle;
  const SessionTile(this.repo, this.s, {super.key, this.selecting = false, this.selected = false, this.onToggle});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = repo;
    final hrMax = hrMaxTanaka(r.age);
    final trimp = s.hrPerMinute.isEmpty ? null : edwardsTrimp(zoneMinutes(s.hrPerMinute, hrMax));
    final m = sportById(s.sportType); final col = m == null ? c.exp : groupColor(c, m.group);
    final name = sportLabel(s.sportType); final when = '${s.start.year}-${two(s.start.month)}-${two(s.start.day)} ${hm(s.start)}';
    return Panel(padding: EdgeInsets.zero, child: Semantics(button: true, selected: selecting && selected, label: '${selecting ? (selected ? 'Seleccionada. ' : 'No seleccionada. ') : ''}$name, $when, ${dur(s.seconds)}, ${(s.meters / 1000).toStringAsFixed(2)} kilómetros', child: ExcludeSemantics(child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: selecting ? () => onToggle : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionPage(r, s))),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Padding(padding: const EdgeInsets.all(Sp.x4), child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: col.withValues(alpha: .2), child: Icon(sportIcon(s.sportType), color: col)), const SizedBox(width: Sp.x3),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: VT.heading(c)),
          Text(when, style: VT.caption(c)),
          const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x1, children: [
            _chip(c, Icons.timer_outlined, dur(s.seconds)), if (m?.tracksRoute != false || s.meters > 0) _chip(c, Icons.straighten, '${(s.meters / 1000).toStringAsFixed(2)} km'),
            if (s.avgHr > 0) _chip(c, Icons.favorite, '${s.avgHr} bpm', c.heart), if (trimp != null) _chip(c, Icons.speed, 'TRIMP $trimp'), if (s.hasGps && m?.tracksRoute != false) _chip(c, Icons.route, 'GPS', c.route),
          ]),
        ])),
        selecting ? Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? c.accent : c.muted) : const Icon(Icons.chevron_right),
      ]))),
    ))));
  }

  Widget _chip(VC c, IconData i, String t, [Color? col]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: 3), decoration: BoxDecoration(color: c.surfaceHi, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: col ?? c.muted), const SizedBox(width: 4), Text(t, style: VT.caption(c).copyWith(color: c.text))]));

}

class SessionPage extends StatelessWidget {
  final VigorRepo repo; final Session s; const SessionPage(this.repo, this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final hrMax = hrMaxTanaka(repo.age);
    final zm = zoneMinutes(s.hrPerMinute, hrMax); final trimp = edwardsTrimp(zm);
    final dv = deriveSession(s.seconds, s.meters, s.paceSecKm);
    final hm0 = sportById(s.sportType); final hc = hm0 == null ? c.exp : groupColor(c, hm0.group);
    final indoor = hm0?.tracksRoute == false; // modo de interior / sin GPS: sin mapa, ritmo ni distancia por GPS
    return Scaffold(
      appBar: AppBar(title: Text(sportLabel(s.sportType)), actions: [
        DeleteButton('Borrar esta sesión', () async { final done = await confirmAndDelete(context, repo, type: 'session', keys: [s.key], title: 'Borrar esta sesión', what: 'Se borrará la sesión de ${sportLabel(s.sportType)} del ${s.start.year}-${two(s.start.month)}-${two(s.start.day)} ${hm(s.start)}, con su ruta y su pulso por minuto.'); if (done && context.mounted) Navigator.of(context).pop(); }),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: hc.withValues(alpha: .2), child: Icon(sportIcon(s.sportType), color: hc)), const SizedBox(width: Sp.x3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sportLabel(s.sportType), style: VT.title(c).copyWith(fontSize: 20)),
              Text('${sportById(s.sportType)?.group.label ?? 'Tipo no identificado'} · ${s.start.year}-${two(s.start.month)}-${two(s.start.day)} ${hm(s.start)}', style: VT.caption(c)),
            ])),
          ]),
          const SizedBox(height: Sp.x3),
          if (indoor) BigValue(dur(s.seconds), '') else BigValue((s.meters / 1000).toStringAsFixed(2), 'km'),
          const SizedBox(height: Sp.x3),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final e in [
              if (!indoor) ('Duración', dur(s.seconds)), if (!indoor) ('Ritmo medio', pace(s.paceSecKm)), ('Pulso medio', s.avgHr > 0 ? '${s.avgHr} bpm' : '—'),
              ('Calorías', s.kcal > 0 ? '${s.kcal.toStringAsFixed(1)} kcal' : '—'), if (!indoor || s.steps > 0) ('Pasos', '${s.steps}'),
              if (!indoor && dv.speedKmh != null) ('Velocidad media (calculada)', '${dv.speedKmh!.toStringAsFixed(1)} km/h'),
            ]) Container(constraints: const BoxConstraints(minWidth: 140, minHeight: 48), padding: const EdgeInsets.all(Sp.x3), decoration: BoxDecoration(color: c.surfaceHi, borderRadius: BorderRadius.circular(16)), child: Stat(e.$1, e.$2)),
          ]),
          if (!indoor && dv.speedKmh != null) const Note('Velocidad media calculada con la distancia y el tiempo de la pulsera.'),
          if (!indoor && dv.paceDiffers) Note('Ritmo calculado distinto del de la pulsera: ${pace(dv.paceSecKm!)} frente a ${pace(s.paceSecKm)}. Se muestra el de la pulsera.'),
          Note(indoor ? 'Modo de interior: sin GPS. Las calorías y el pulso los calcula la pulsera (algoritmo del fabricante); el número de series o repeticiones no está disponible en la SDK que usa Vigor (no verificado).' : 'Distancia, calorías y ritmo los calcula la pulsera; la distancia por GPS es solo una comprobación y puede acumular deriva en interiores.'),
        ])),
        if (!indoor) RoutePanel(repo, s),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MetricHeader(Icons.favorite, 'Pulso y zonas', c.heart), const SizedBox(height: Sp.x3),
          if (s.hrPerMinute.length < 2) Text('Sin lecturas de pulso.', style: VT.body(c).copyWith(color: c.muted)) else ...[
            SizedBox(height: 110, child: CustomPaint(size: Size.infinite, painter: LinePainter([for (var i = 0; i < s.hrPerMinute.length; i++) i.toDouble()], s.hrPerMinute.map((e) => e.toDouble()).toList(), c.heart, c.surfaceAlt, c.muted))),
            const SizedBox(height: Sp.x3),
            for (var z = 1; z <= 5; z++) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              SizedBox(width: 64, child: Text('Zona $z', style: VT.caption(c))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: s.hrPerMinute.isEmpty ? 0 : zm[z] / s.hrPerMinute.length, minHeight: 10, backgroundColor: c.surfaceAlt, color: c.heart))),
              SizedBox(width: 56, child: Text('${zm[z]} min', textAlign: TextAlign.right, style: VT.caption(c))),
            ])),
            const SizedBox(height: Sp.x2),
            Text('Carga (TRIMP de Edwards): $trimp · FCmáx estimada ${hrMaxTanaka(repo.age)} ± 10 bpm', style: VT.body(c)),
            const Note('FCmáx = 208 − 0,7·edad (Tanaka 2001). El TRIMP es un índice relativo personal. Ver docs/ANALISIS.md.'),
            if (repo.ageIsDefault) Note('Edad no indicada: se usan ${VigorRepo.defaultAge} años por defecto para la FCmáx y las zonas. Indícala en Dispositivo → Perfil.'),
          ],
        ])),
      ]),
    );
  }
}
