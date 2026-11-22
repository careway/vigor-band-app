import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'fx.dart';

class Panel extends StatelessWidget {
  final Widget child; final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.x4)});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: Glass(padding: padding, child: SizedBox(width: double.infinity, child: child)));
}

class MetricHeader extends StatelessWidget {
  final IconData icon; final String label; final Color color; final Widget? trailing;
  const MetricHeader(this.icon, this.label, this.color, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color), const SizedBox(width: Sp.x2), Expanded(child: Text(label, style: VT.heading(VC.of(context)))), ?trailing]);
}

class BigValue extends StatelessWidget {
  final String value, unit; final double size;
  const BigValue(this.value, this.unit, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return Semantics(label: '$value $unit', child: ExcludeSemantics(child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      Text(value, style: VT.display(c).copyWith(fontSize: size)), const SizedBox(width: Sp.x1), Text(unit, style: VT.caption(c))])));
  }
}

class Stat extends StatelessWidget {
  final String label, value; const Stat(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: VT.caption(c)), const SizedBox(height: 2), Text(value, style: VT.heading(c))]);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon; final String text; final Widget? action;
  const EmptyState(this.icon, this.text, {super.key, this.action});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return Center(child: Padding(padding: const EdgeInsets.all(Sp.x6), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: c.muted.withValues(alpha: .5)), const SizedBox(height: Sp.x3),
      Text(text, textAlign: TextAlign.center, style: VT.body(c).copyWith(color: c.muted)), if (action != null) ...[const SizedBox(height: Sp.x4), action!]])));
  }
}

class Note extends StatelessWidget {
  final String text; const Note(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: Sp.x2), child: Text(text, style: VT.caption(VC.of(context))));
}

/// Botón ⓘ discreto: abre una hoja inferior con la explicación (metodología, fuentes, límites).
class InfoButton extends StatelessWidget {
  final String title, text; const InfoButton(this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Más información: $title', constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(Icons.info_outline, size: 20, color: VC.of(context).muted),
        onPressed: () => showInfoSheet(context, title, text));
}

/// Título de diálogo con ⓘ: el diálogo queda corto y el detalle va en la hoja.
Widget infoTitle(String title, String text) => Row(children: [Expanded(child: Text(title)), InfoButton(title, text)]);

Future<void> showInfoSheet(BuildContext context, String title, String text) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (ctx) { final c = VC.of(ctx); return SafeArea(child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8), child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x4), children: [
      Text(title, style: VT.heading(c)), const SizedBox(height: Sp.x2), Text(text, style: VT.body(c))]))); });

class SectionHeader extends StatelessWidget {
  final String text; final Widget? trailing; const SectionHeader(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(Sp.x1, Sp.x2, Sp.x1, Sp.x2), child: Row(children: [Expanded(child: Text(text, style: VT.heading(VC.of(context)))), ?trailing]));
}

String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
String dur(int sec) { final h = sec ~/ 3600, m = (sec % 3600) ~/ 60; return h > 0 ? '$h h ${two(m)} min' : '$m min'; }
String pace(int secKm) => secKm <= 0 ? '—' : '${secKm ~/ 60}:${two(secKm % 60)} /km';

/// Anillo de progreso (pasos).
class RingPainter extends CustomPainter {
  final double frac; final Color color, track;
  RingPainter(this.frac, this.color, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = math.min(s.width, s.height) / 2 - 8; final c = s.center(Offset.zero);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p..color = track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * frac.clamp(0, 1), false, p..color = color);
  }
  @override
  bool shouldRepaint(RingPainter o) => o.frac != frac || o.color != color;
}

/// Línea simple con relleno tenue y etiquetas mín/máx.
class LinePainter extends CustomPainter {
  final List<double> xs, ys; final Color color, grid, text; final double? minY, maxY;
  LinePainter(this.xs, this.ys, this.color, this.grid, this.text, {this.minY, this.maxY});
  @override
  void paint(Canvas canvas, Size s) {
    if (ys.length < 2) return;
    final lo = minY ?? ys.reduce(math.min), hi = maxY ?? ys.reduce(math.max);
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    final x0 = xs.first, xSpan = (xs.last - xs.first) == 0 ? 1 : (xs.last - xs.first);
    const left = 30.0;
    Offset pt(int i) => Offset(left + (xs[i] - x0) / xSpan * (s.width - left), s.height - 4 - (ys[i] - lo) / span * (s.height - 8));
    final g = Paint()..color = grid..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) { final y = 4 + f * (s.height - 8); canvas.drawLine(Offset(left, y), Offset(s.width, y), g); }
    void label(String t, double y) { final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: 10, color: text)), textDirection: TextDirection.ltr)..layout(); tp.paint(canvas, Offset(0, y - tp.height / 2)); }
    label(hi.round().toString(), 4); label(lo.round().toString(), s.height - 4);
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < ys.length; i++) { path.lineTo(pt(i).dx, pt(i).dy); }
    final fill = Path.from(path)..lineTo(pt(ys.length - 1).dx, s.height)..lineTo(pt(0).dx, s.height)..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .12));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(LinePainter o) => o.ys != ys;
}

/// Barras (empiezan siempre en 0).
class BarPainter extends CustomPainter {
  final List<double> vals; final Color color, grid;
  BarPainter(this.vals, this.color, this.grid);
  @override
  void paint(Canvas canvas, Size s) {
    if (vals.isEmpty) return;
    final mx = vals.reduce(math.max); if (mx <= 0) return;
    final w = s.width / vals.length;
    canvas.drawLine(Offset(0, s.height - 0.5), Offset(s.width, s.height - 0.5), Paint()..color = grid);
    for (var i = 0; i < vals.length; i++) {
      final h = vals[i] / mx * (s.height - 4);
      if (h <= 0) continue;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(i * w + 1, s.height - h, w - 2, h), const Radius.circular(4)), Paint()..color = color);
    }
  }
  @override
  bool shouldRepaint(BarPainter o) => o.vals != vals;
}

/// Ruta GPS: proyección equirrectangular simple, sin suavizado.
class RoutePainter extends CustomPainter {
  final List<(double, double)> pts; final Color color, dot, bg;
  RoutePainter(this.pts, this.color, this.dot, this.bg);
  /// (NaN, NaN) marca un corte: la pulsera no tuvo posición; no se unen los tramos.
  @override
  void paint(Canvas canvas, Size s) {
    final real = pts.where((p) => !p.$1.isNaN).toList();
    if (real.length < 2) return;
    final lats = real.map((p) => p.$1), lons = real.map((p) => p.$2);
    final minLa = lats.reduce(math.min), maxLa = lats.reduce(math.max), minLo = lons.reduce(math.min), maxLo = lons.reduce(math.max);
    final k = math.cos((minLa + maxLa) / 2 * math.pi / 180);
    final w = math.max((maxLo - minLo) * k, 1e-6), h = math.max(maxLa - minLa, 1e-6);
    final sc = math.min((s.width - 24) / w, (s.height - 24) / h);
    final ox = (s.width - w * sc) / 2, oy = (s.height - h * sc) / 2;
    Offset o((double, double) p) => Offset(ox + (p.$2 - minLo) * k * sc, s.height - oy - (p.$1 - minLa) * sc);
    final line = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    Path? path;
    for (final p in pts) {
      if (p.$1.isNaN) { if (path != null) canvas.drawPath(path, line); path = null; continue; }
      final q = o(p);
      if (path == null) { path = Path()..moveTo(q.dx, q.dy); canvas.drawCircle(q, 2.5, Paint()..color = color); } else { path.lineTo(q.dx, q.dy); }
    }
    if (path != null) canvas.drawPath(path, line);
    canvas.drawCircle(o(real.first), 6, Paint()..color = dot);
    canvas.drawCircle(o(real.last), 6, Paint()..color = color);
    canvas.drawCircle(o(real.last), 3, Paint()..color = bg);
  }
  @override
  bool shouldRepaint(RoutePainter o) => o.pts != pts;
}
