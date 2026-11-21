import 'dart:async';
import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/repo.dart';
import '../data/workout.dart';
import '../theme/tokens.dart';
import 'fx.dart';
import 'sport_picker.dart';
import 'widgets.dart';

/// Reconstruye cada segundo mientras está en pantalla (el cronómetro) y le recuerda al entreno que compruebe si se dio por perdido.
class _Tick extends StatefulWidget {
  final LiveWorkout w; final WidgetBuilder builder; const _Tick(this.w, this.builder);
  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  Timer? _t;
  @override
  void initState() { super.initState(); _t = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted) return; widget.w.tick(); setState(() {}); }); }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.builder(context);
}

String _stateText(LiveWorkout w) => w.paused ? 'En pausa' : w.stale ? 'Sin datos de la pulsera' : 'En curso';

/// Isla de «actividad en curso», encima de la barra de pestañas. Toca para abrir la pantalla de entreno. No ocupa nada si no hay actividad.
class ActivityIsland extends StatelessWidget {
  final VigorRepo repo; final VoidCallback onOpen;
  const ActivityIsland(this.repo, {super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo.workout, builder: (context, _) {
        final w = repo.workout; if (!w.active) return const SizedBox.shrink();
        return _Tick(w, (context) {
          final c = VC.of(context); final m = w.mode; final col = m == null ? c.accent : groupColor(c, m.group); final name = m?.name ?? 'Actividad';
          final time = clockText(w.elapsed()); final hr = w.heartRate;
          return Padding(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x2), child: Semantics(button: true, container: true,
            label: 'Actividad en curso: $name, $time, ${_stateText(w)}${hr == null ? '' : ', pulso $hr'}. Abrir la pantalla de entreno',
            child: ExcludeSemantics(child: Glass(radius: 28, padding: EdgeInsets.zero, glow: col, child: InkWell(borderRadius: BorderRadius.circular(28), onTap: onOpen,
              child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 56), child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2), child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: col.withValues(alpha: .22), child: Icon(m?.icon ?? Icons.directions_run, size: 20, color: col)), const SizedBox(width: Sp.x3),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('$name · ${_stateText(w)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: VT.caption(c)),
                  Text(time, style: VT.heading(c).copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                ])),
                if (hr != null) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.favorite, size: 16, color: c.heart), const SizedBox(width: 4), Text('$hr', style: VT.heading(c).copyWith(fontSize: 18))]),
                const SizedBox(width: Sp.x2), Icon(Icons.keyboard_arrow_up, color: c.muted),
              ])))))),
          ));
        });
      });
}

/// Pantalla de entreno: el tiempo en grande y los datos que importan según el tipo de actividad.
class WorkoutPage extends StatelessWidget {
  final VigorRepo repo; const WorkoutPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo.workout, builder: (context, _) {
        final w = repo.workout; final c = VC.of(context); final m = w.mode; final col = m == null ? c.accent : groupColor(c, m.group);
        return Scaffold(
          appBar: AppBar(title: Text(m?.name ?? 'Entreno')),
          body: _Tick(w, (context) => ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8), children: [
            Panel(child: Column(children: [
              Semantics(liveRegion: true, container: true, label: 'Tiempo ${clockText(w.elapsed())}. ${w.active ? _stateText(w) : 'Actividad terminada'}', child: ExcludeSemantics(child: Column(children: [
                Text(clockText(w.elapsed()), style: VT.display(c).copyWith(fontSize: 64, color: w.active ? c.text : c.muted)),
                Text(w.active ? _stateText(w) : 'Actividad terminada', style: VT.caption(c).copyWith(color: w.active && !w.stale && !w.paused ? col : c.muted, fontWeight: FontWeight.w700)),
              ]))),
            ])),
            LayoutBuilder(builder: (context, bc) {
              final tile = (bc.maxWidth - Sp.x3) / 2;
              return Wrap(spacing: Sp.x3, runSpacing: Sp.x3, children: [for (final f in workoutFields(m)) SizedBox(width: tile, child: _MetricTile(f, w, repo))]);
            }),
            if (w.hrSamples.length >= 2) Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MetricHeader(Icons.favorite, 'Pulso', c.heart), const SizedBox(height: Sp.x3),
              SizedBox(height: 90, child: CustomPaint(size: Size.infinite, painter: LinePainter([for (var i = 0; i < w.hrSamples.length; i++) i.toDouble()], [for (final h in w.hrSamples) h.toDouble()], c.heart, c.surfaceHi, c.muted))),
              const SizedBox(height: Sp.x2), _ZoneBar(w.zone(hrMaxTanaka(repo.age))),
            ])),
            const SizedBox(height: Sp.x3),
            if (w.active) Row(children: [
              Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(48, 52), backgroundColor: c.danger, foregroundColor: Colors.white), onPressed: () => _finish(context, repo), icon: const Icon(Icons.stop), label: Text(repo.conn == 'connected' ? 'Terminar' : 'Quitar de la pantalla'))),
            ]) else FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(48, 52)), onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.check), label: const Text('Cerrar')),
          ])),
        );
      });

  Future<void> _finish(BuildContext context, VigorRepo r) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('¿Terminar la actividad?'),
        content: Text(r.conn == 'connected' ? 'Se envía la orden de parar a la pulsera.' : 'La pulsera no está conectada: solo se quita de esta pantalla; sigue grabando hasta que la pares tú.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminar'))]));
    if (ok == true) { if (r.conn == 'connected') { await r.stopSport(); } else { r.workout.end(); } if (context.mounted) Navigator.of(context).pop(); }
  }
}

class _MetricTile extends StatelessWidget {
  final WorkoutField f; final LiveWorkout w; final VigorRepo repo;
  const _MetricTile(this.f, this.w, this.repo);
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    final (IconData icon, String label, String value, String unit, Color col) = switch (f) {
      WorkoutField.distance => (Icons.straighten, 'Distancia', w.distanceM == null ? '—' : (w.distanceM! / 1000).toStringAsFixed(2), 'km', c.route),
      WorkoutField.pace => (Icons.speed, 'Ritmo', paceText(w.paceSecKm), '/km', c.accent),
      WorkoutField.speed => (Icons.speed, 'Velocidad', w.speedKmh == null ? '—' : w.speedKmh!.toStringAsFixed(1), 'km/h', c.accent),
      WorkoutField.heartRate => (Icons.favorite, 'Pulso', w.heartRate == null ? '—' : '${w.heartRate}', 'bpm', c.heart),
      WorkoutField.calories => (Icons.local_fire_department, 'Calorías', w.kcal == null ? '—' : '${w.kcal!.round()}', 'kcal', c.kcal),
      WorkoutField.gps => (Icons.gps_fixed, 'GPS', w.gpsSignal == null ? '—' : (w.gpsSignal! > 0 ? 'Con señal' : 'Sin señal'), '', c.steps),
    };
    final zone = f == WorkoutField.heartRate ? w.zone(hrMaxTanaka(repo.age)) : null;
    return Semantics(container: true, label: '$label: $value $unit${zone != null && zone > 0 ? ', zona $zone' : ''}', child: ExcludeSemantics(child: Container(
      padding: const EdgeInsets.all(Sp.x3), constraints: const BoxConstraints(minHeight: 96), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.surfaceHi)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: col), const SizedBox(width: 6), Expanded(child: Text(label, style: VT.caption(c), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: Sp.x1),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: VT.display(c).copyWith(fontSize: 30))), if (unit.isNotEmpty) ...[const SizedBox(width: 4), Text(unit, style: VT.caption(c))]]),
        if (zone != null && zone > 0) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Zona $zone', style: VT.caption(c).copyWith(color: col, fontWeight: FontWeight.w700))),
      ]))));
  }
}

/// Cinco tramos (zonas de pulso); el actual, resaltado. El número va siempre rotulado, el color no es la única señal.
class _ZoneBar extends StatelessWidget {
  final int? zone; const _ZoneBar(this.zone);
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return Semantics(container: true, label: zone == null || zone == 0 ? 'Zona de pulso: ninguna todavía' : 'Zona de pulso $zone de 5', child: ExcludeSemantics(child: Row(children: [
      for (var z = 1; z <= 5; z++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(children: [
        Container(height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: z == zone ? c.heart : c.heart.withValues(alpha: .18))),
        const SizedBox(height: 2), Text('$z', style: VT.caption(c).copyWith(fontWeight: z == zone ? FontWeight.w800 : FontWeight.w400, color: z == zone ? c.text : c.muted)),
      ]))),
    ])));
  }
}
