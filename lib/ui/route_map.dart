import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../data/map_style.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

const _mc = MethodChannel('vigor/methods');

/// Estilos vectoriales ya leídos (se descargan una vez por sesión de la app; si falla, se reintenta la próxima vez).
final Map<MapStyle, Future<Style>> _styles = {};
Future<Style> _readStyle(MapStyle m) => _styles.putIfAbsent(m, () => StyleReader(uri: m.styleUri!).read()..catchError((Object _) { _styles.remove(m); return Future<Style>.error('sin estilo'); }));

/// Ruta GPS sobre un mapa (o, sin mapa, solo la ruta dibujada). [segments]: tramos continuos (grados); no se unen entre sí.
/// [tiles] = false: no se descarga nada (ajuste «Mapa de fondo» apagado) y se usa el dibujo propio.
class RouteMap extends StatelessWidget {
  final List<List<(double, double)>> segments; final bool tiles; final double height; final MapStyle style;
  /// Posición actual (si se conoce) y radio de incertidumbre aproximado en metros: se dibuja un círculo traslúcido a escala real.
  final (double, double)? position; final double? uncertaintyM;
  const RouteMap(this.segments, {super.key, this.tiles = true, this.height = 260, this.style = MapStyle.byDefault, this.position, this.uncertaintyM});

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    final all = [for (final s in segments) ...s, ?position];
    if (all.length < 2 && position == null) return const SizedBox.shrink();
    if (!tiles) {
      return SizedBox(height: height, child: CustomPaint(size: Size.infinite, painter: RoutePainter([for (final s in segments) ...[...s, (double.nan, double.nan)]], c.route, c.kcal, c.surface)));
    }
    final lines = [for (final s in segments) if (s.length >= 2) [for (final p in s) LatLng(p.$1, p.$2)]];
    final pos = position == null ? null : LatLng(position!.$1, position!.$2);
    final pts = [for (final p in all) LatLng(p.$1, p.$2)];
    final single = all.length < 2 || (pts.length > 1 && pts.every((p) => p == pts.first)); // un solo punto: no hay caja, se centra
    final first = LatLng(all.first.$1, all.first.$2), last = LatLng(all.last.$1, all.last.$2);
    Widget map(Widget base) => FlutterMap(
          options: MapOptions(initialCameraFit: single ? null : CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(28), maxZoom: 18), initialCenter: single ? pts.first : const LatLng(0, 0), initialZoom: single ? 17 : 2,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom), minZoom: 3, maxZoom: 19),
          children: [
            base,
            PolylineLayer(polylines: [for (final l in lines) Polyline(points: l, strokeWidth: 5, color: c.route, borderStrokeWidth: 2.5, borderColor: Colors.white.withValues(alpha: .9), strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round)]),
            if (pos != null && uncertaintyM != null) CircleLayer(circles: [CircleMarker(point: pos, radius: uncertaintyM!, useRadiusInMeter: true, color: c.accent.withValues(alpha: .18), borderColor: c.accent.withValues(alpha: .7), borderStrokeWidth: 1.5)]),
            MarkerLayer(markers: [
              if (pos == null || lines.isNotEmpty) Marker(point: first, width: 22, height: 22, child: const _Dot(Color(0xFF16A34A))),
              if (pos == null && !single) Marker(point: last, width: 22, height: 22, child: const _Dot(Color(0xFFDC2626))),
              if (pos != null) Marker(point: pos, width: 26, height: 26, child: _Dot(c.accent)),
            ]),
            // Atribución obligatoria (licencias ODbL, OpenMapTiles y de cada servidor): visible y con enlace.
            Align(alignment: Alignment.bottomRight, child: Padding(padding: const EdgeInsets.all(4), child: Material(color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(6),
              child: InkWell(borderRadius: BorderRadius.circular(6), onTap: () { try { _mc.invokeMethod('openUrl', {'url': 'https://www.openstreetmap.org/copyright'}); } catch (_) {} },
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 28), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Center(widthFactor: 1, heightFactor: 1, child: Text(style.attribution, style: const TextStyle(fontSize: 10, color: Color(0xFF1F2937)))))))))),
          ],
        );
    Widget raster(MapStyle m) => TileLayer(urlTemplate: m.rasterUrl, userAgentPackageName: 'com.careway.vigor_app', maxNativeZoom: m.maxNativeZoom);
    return Semantics(label: 'Mapa de la ruta', child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: height, child: !style.isVector ? map(raster(style)) : FutureBuilder<Style>(
      future: _readStyle(style),
      builder: (context, snap) {
        if (snap.hasData) { final st = snap.data!; return map(VectorTileLayer(theme: st.theme, sprites: st.sprites, tileProviders: st.providers, layerMode: VectorTileLayerMode.vector)); }
        // Mientras carga el estilo se ve el color de fondo; si no hay red, se cae al mapa estándar para no dejar la ruta sin mapa.
        if (snap.hasError) return map(raster(MapStyle.standard));
        return ColoredBox(color: c.surfaceHi, child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
      },
    ))));
  }
}

class _Dot extends StatelessWidget {
  final Color color; const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)]));
}
