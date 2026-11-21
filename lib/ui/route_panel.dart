import 'package:flutter/material.dart';
import '../data/gps_filter.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'route_map.dart';
import 'widgets.dart';

/// Puntos GPS de una sesión. Si no traen tiempo ni señal (datos antiguos), se supone un punto cada 5 s y señal buena.
List<GpsFix> fixesOf(Session s) {
  if (s.fixes.isNotEmpty) return s.fixes;
  return [for (var i = 0; i < s.route.length; i++) if (!s.route[i].$1.isNaN) GpsFix(s.route[i].$1, s.route[i].$2, i * 5, 2)];
}

/// Tramos de la ruta original (sin filtrar), cortando donde la pulsera no tuvo posición.
List<List<(double, double)>> rawSegments(Session s) {
  final out = <List<(double, double)>>[]; var cur = <(double, double)>[];
  for (final p in s.route) { if (p.$1.isNaN) { if (cur.length > 1) out.add(cur); cur = []; } else { cur.add(p); } }
  if (cur.length > 1) out.add(cur);
  return out;
}

/// Ruta GPS de la actividad: mapa de OpenStreetMap (si el ajuste está activo) con la ruta suavizada; se puede ver la original.
class RoutePanel extends StatefulWidget {
  final VigorRepo repo; final Session s; const RoutePanel(this.repo, this.s, {super.key});
  @override
  State<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends State<RoutePanel> {
  bool smooth = true; late final TrackReport rep = filterTrack(fixesOf(widget.s), cfg: GpsFilterConfig.forSport(widget.s.sportType));
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final s = widget.s; final r = widget.repo;
    final raw = rawSegments(s); final hasRoute = rep.kept >= 2 || raw.isNotEmpty;
    final segs = smooth && !rep.isEmpty ? rep.segments : raw;
    final parts = <String>[
      if (smooth && rep.corrected > 0) '${rep.corrected} punto${rep.corrected == 1 ? '' : 's'} corregido${rep.corrected == 1 ? '' : 's'}',
      if (rep.noSignal > 0) '${rep.noSignal} sin señal',
    ];
    return ListenableBuilder(listenable: r, builder: (context, _) => Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricHeader(Icons.route, 'Ruta', c.route), const SizedBox(height: Sp.x3),
      if (!hasRoute) Text(s.hasGps ? 'La pulsera no obtuvo posición suficiente.' : 'Esta actividad no tiene GPS.', style: VT.body(c).copyWith(color: c.muted))
      else ...[
        RouteMap(segs, tiles: r.mapOn, style: r.mapStyle),
        const SizedBox(height: Sp.x3),
        Row(children: [
          Expanded(child: SegmentedButton<bool>(showSelectedIcon: false, style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
              segments: const [ButtonSegment(value: true, label: Text('Suavizada')), ButtonSegment(value: false, label: Text('Original'))], selected: {smooth}, onSelectionChanged: (v) => setState(() => smooth = v.first))),
        ]),
        if (parts.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Sp.x2), child: Text(parts.join(' · '), style: VT.caption(c))),
      ],
    ])));
  }
}
