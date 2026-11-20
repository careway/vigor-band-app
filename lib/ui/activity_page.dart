import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import '../data/sports.dart';
import 'night_cards.dart';
import 'sport_picker.dart';
import 'widgets.dart';

class ActivityPage extends StatefulWidget {
  final VigorRepo repo; const ActivityPage(this.repo, {super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  SportMode mode = sportByKey('OUTDOOR_RUNNING')!;

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = widget.repo; final col = groupColor(c, mode.group);
    final ok = r.conn == 'connected';
    return ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MetricHeader(Icons.route, 'Iniciar desde el móvil', c.route),
        const SizedBox(height: Sp.x3),
        Semantics(button: true, label: 'Modo deportivo: ${mode.name}. Cambiar', child: ExcludeSemantics(child: Material(
          color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(20),
          child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () async {
            final m = await showSportPicker(context, mode.id);
            if (m != null) setState(() => mode = m);
          }, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 72), child: Padding(padding: const EdgeInsets.all(Sp.x3), child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: col.withValues(alpha: .25), child: Icon(mode.icon, color: col, size: 28)), const SizedBox(width: Sp.x3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mode.name, style: VT.title(c).copyWith(fontSize: 20)),
              Text('${mode.group.label} · ${mode.tracksRoute ? 'recorrido con GPS' : 'interior, sin GPS'}', style: VT.caption(c)),
            ])),
            Text('Cambiar', style: VT.caption(c).copyWith(color: c.accent, fontWeight: FontWeight.w700)), const Icon(Icons.expand_more),
          ])))),
        ))),
        const SizedBox(height: Sp.x3),
        Row(children: [
          Expanded(flex: 3, child: FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(48, 52)), onPressed: ok ? () => r.startSport(mode.key) : null, icon: const Icon(Icons.play_arrow), label: const Text('Iniciar'))),
          const SizedBox(width: Sp.x2),
          Expanded(flex: 2, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)), onPressed: ok ? r.stopSport : null, icon: const Icon(Icons.stop), label: const Text('Parar'))),
        ]),
        if (!ok) const Note('Conecta la pulsera para iniciar una actividad.'),
        Note(mode.tracksRoute ? 'Modo de recorrido: la pulsera graba sola, con su propio GPS si el modo lo usa (no verificado por modo); luego verás ruta, distancia y ritmo. El móvil solo da la orden y puede desconectarse.' : 'Modo de interior: no se usa ni se pide GPS. Verás duración, pulso y calorías. El móvil solo da la orden y puede desconectarse.'),
        const Note('La SDK no indica qué modos admite tu pulsera: si no admite el elegido, no empezará.'),
        if (r.sportMsgs.isNotEmpty) Note(r.sportMsgs.first),
      ])),
      WeeklyActivityCard(r),
      if (r.ageIsDefault) Note('Edad no indicada: el cómputo por pulso, las zonas y el TRIMP usan ${VigorRepo.defaultAge} años por defecto. Indícala en Dispositivo → Perfil.'),
      const SectionHeader('Actividades guardadas'),
      if (r.sessions.isEmpty) const SizedBox(height: 240, child: EmptyState(Icons.directions_run, 'Aún no hay actividades. Sincroniza la pulsera para leerlas.'))
      else for (final s in r.sessions) _tile(context, c, r, s),
      const Note('Calorías, distancia y ritmo los calcula la pulsera (algoritmo del fabricante).'),
    ]);
  }

  Widget _tile(BuildContext context, VC c, VigorRepo r, Session s) {
    final hrMax = hrMaxTanaka(r.age);
    final trimp = s.hrPerMinute.isEmpty ? null : edwardsTrimp(zoneMinutes(s.hrPerMinute, hrMax));
    final m = sportById(s.sportType); final col = m == null ? c.exp : groupColor(c, m.group);
    final name = sportLabel(s.sportType); final when = '${s.start.year}-${two(s.start.month)}-${two(s.start.day)} ${hm(s.start)}';
    return Panel(padding: EdgeInsets.zero, child: Semantics(button: true, label: '$name, $when, ${dur(s.seconds)}, ${(s.meters / 1000).toStringAsFixed(2)} kilómetros', child: ExcludeSemantics(child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionPage(r, s))),
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
        const Icon(Icons.chevron_right),
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
    final real = s.route.where((p) => !p.$1.isNaN).length;
    final cuts = s.route.where((p) => p.$1.isNaN).length;
    double? gpsDist; if (real > 1) { var d = 0.0; for (var i = 1; i < s.route.length; i++) { final a = s.route[i - 1], b = s.route[i]; if (a.$1.isNaN || b.$1.isNaN) continue; d += haversine(a.$1, a.$2, b.$1, b.$2); } gpsDist = d; }
    return Scaffold(
      appBar: AppBar(title: Text(sportLabel(s.sportType))),
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
        if (!indoor) Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MetricHeader(Icons.route, 'Ruta GPS de la pulsera', c.route), const SizedBox(height: Sp.x3),
          if (real < 2) Text(s.hasGps ? 'La pulsera no obtuvo posición suficiente (¿interior o sin cielo abierto?).' : 'Esta actividad no tiene GPS.', style: VT.body(c).copyWith(color: c.muted))
          else ...[
            SizedBox(height: 240, child: CustomPaint(size: Size.infinite, painter: RoutePainter(s.route, c.route, c.kcal, c.surface))),
            Note('$real puntos · $cuts cortes sin señal · distancia por GPS ≈ ${gpsDist!.round()} m (la pulsera informa ${s.meters} m). Sin suavizado; los tramos sin posición no se unen.'),
          ],
        ])),
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
