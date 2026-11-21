import '../data/day_kinds.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'widgets.dart' show hm, two;

double minutesOf(DateTime t) => t.hour * 60.0 + t.minute;

/// Muestra más cercana a [m] minutos del día, dentro de [within] minutos.
Sample? nearest(List<Sample> l, double m, {double within = 12}) {
  Sample? best; var bd = double.infinity;
  for (final s in l) { final d = (minutesOf(s.t) - m).abs(); if (d < bd) { bd = d; best = s; } }
  return bd <= within ? best : null;
}

List<Sample> bin30(List<Sample> data) {
  final m = <int, double>{}; DateTime? day;
  for (final s in data) { day ??= DateTime(s.t.year, s.t.month, s.t.day); final k = s.t.hour * 2 + s.t.minute ~/ 30; m[k] = (m[k] ?? 0) + s.v; }
  return [for (final e in (m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) Sample(day!.add(Duration(minutes: e.key * 30)), e.value)];
}

/// Descripción textual de una serie para lectores de pantalla: 'Pulso: mín 52, media 70, máx 120 bpm'.
String describeSeries(String name, String unit, int decimals, List<Sample> d, {bool bars = false}) {
  final n = name.isEmpty ? 'Gráfico' : name;
  if (d.isEmpty) return '$n: sin datos';
  String f(double v) => v.toStringAsFixed(decimals);
  if (bars) return '$n: total ${f(d.fold<double>(0, (a, e) => a + e.v))} $unit en el día'.trim();
  final v = d.map((e) => e.v); final mn = v.reduce(math.min), mx = v.reduce(math.max), av = v.reduce((a, b) => a + b) / d.length;
  return '$n: mín ${f(mn)}, media ${f(av)}, máx ${f(mx)} $unit'.trim();
}

/// Serie sobre un eje de 24 h con cursor táctil.
class TimeSeriesChart extends StatefulWidget {
  final List<Sample> data; final Color color; final String unit; final int decimals; final double? minY, maxY; final bool bars; final double height; final String name;
  const TimeSeriesChart({super.key, required this.data, required this.color, required this.unit, this.decimals = 0, this.minY, this.maxY, this.bars = false, this.height = 200, this.name = ''});
  @override
  State<TimeSeriesChart> createState() => _TSState();
}

class _TSState extends State<TimeSeriesChart> {
  int? cur;
  List<Sample> get pts => widget.bars ? bin30(widget.data) : widget.data;
  String f(double v) => v.toStringAsFixed(widget.decimals);

  void _at(double dx, double w) {
    final p = pts; if (p.isEmpty) return;
    final m = ((dx - _TSPainter.left) / (w - _TSPainter.left) * 1440).clamp(0, 1440);
    var bi = 0; var bd = double.infinity;
    for (var i = 0; i < p.length; i++) { final d = (minutesOf(p[i].t) - m).abs(); if (d < bd) { bd = d; bi = i; } }
    if (bi != cur) { HapticFeedback.selectionClick(); setState(() => cur = bi); }
  }

  @override
  void didUpdateWidget(TimeSeriesChart o) { super.didUpdateWidget(o); if (o.data != widget.data) cur = null; }

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final p = pts;
    final i = cur != null && cur! < p.length ? cur : (p.isEmpty ? null : p.length - 1);
    final label = i == null ? 'Sin datos' : '${hm(p[i].t)}${widget.bars ? ' (30 min)' : ''} · ${f(p[i].v)} ${widget.unit}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(liveRegion: true, child: Text(label, style: VT.body(c).copyWith(color: cur == null ? c.muted : c.text, fontWeight: FontWeight.w600))),
      const SizedBox(height: Sp.x2),
      SizedBox(height: widget.height, child: LayoutBuilder(builder: (context, bc) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _at(d.localPosition.dx, bc.maxWidth),
        onHorizontalDragUpdate: (d) => _at(d.localPosition.dx, bc.maxWidth),
        child: Semantics(label: describeSeries(widget.name, widget.unit, widget.decimals, widget.data, bars: widget.bars), image: true, child: CustomPaint(size: Size.infinite, painter: _TSPainter(p, widget.color, c.surfaceHi, c.muted, c.text, widget.minY, widget.maxY, cur, widget.bars))),
      ))),
    ]);
  }
}

class _TSPainter extends CustomPainter {
  static const left = 34.0, bottom = 20.0;
  final List<Sample> pts; final Color color, grid, text, cursorC; final double? minY, maxY; final int? cur; final bool bars;
  _TSPainter(this.pts, this.color, this.grid, this.text, this.cursorC, this.minY, this.maxY, this.cur, this.bars);
  @override
  void paint(Canvas canvas, Size s) {
    final pw = s.width - left, ph = s.height - bottom;
    void label(String t, Offset o, {bool right = false}) { final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: 10, color: text)), textDirection: TextDirection.ltr)..layout(); tp.paint(canvas, right ? Offset(o.dx - tp.width, o.dy - tp.height / 2) : Offset(o.dx - tp.width / 2, o.dy)); }
    final g = Paint()..color = grid..strokeWidth = 1;
    for (final h in [0, 6, 12, 18, 24]) { final x = left + h / 24 * pw; canvas.drawLine(Offset(x, 0), Offset(x, ph), g..color = grid.withValues(alpha: .5)); label('$h', Offset(x, ph + 4)); }
    if (pts.isEmpty) return;
    final vals = pts.map((e) => e.v);
    var lo = minY ?? vals.reduce(math.min), hi = maxY ?? vals.reduce(math.max);
    if (bars) { lo = 0; } else if (minY == null || maxY == null) { final pad = math.max((hi - lo) * .15, 1.0); if (minY == null) lo -= pad; if (maxY == null) hi += pad; }
    if (hi - lo < 1e-6) hi = lo + 1;
    double y(double v) => ph - (v - lo) / (hi - lo) * ph;
    double x(DateTime t) => left + minutesOf(t) / 1440 * pw;
    for (final f in [0.0, .5, 1.0]) { final v = lo + (hi - lo) * f; canvas.drawLine(Offset(left, y(v)), Offset(s.width, y(v)), Paint()..color = grid); label((hi - lo) < 10 ? v.toStringAsFixed(1) : v.round().toString(), Offset(left - 4, y(v)), right: true); }
    if (bars) {
      final bw = pw / 48;
      for (var i = 0; i < pts.length; i++) {
        final h = (pts[i].v / hi) * ph; if (h <= 0) continue;
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(x(pts[i].t) + 1, ph - h, bw - 2, h), const Radius.circular(4));
        canvas.drawRRect(r, Paint()..color = i == cur ? cursorC : color);
      }
      return;
    }
    final line = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    Path? path; Offset? first, last;
    void flush() { if (path != null && first != null && last != null && pts.length > 30) { canvas.drawPath(Path.from(path!)..lineTo(last.dx, ph)..lineTo(first!.dx, ph)..close(), Paint()..color = color.withValues(alpha: .12)); } if (path != null) canvas.drawPath(path!, line); path = null; first = null; }
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(x(pts[i].t), y(pts[i].v));
      final gap = i > 0 && pts[i].t.difference(pts[i - 1].t).inMinutes > 45;
      if (path == null || gap) { flush(); path = Path()..moveTo(o.dx, o.dy); first = o; } else { path?.lineTo(o.dx, o.dy); }
      last = o;
    }
    flush();
    if (pts.length <= 60) { for (final p in pts) { canvas.drawCircle(Offset(x(p.t), y(p.v)), 3, Paint()..color = color); } }
    if (cur != null && cur! < pts.length) {
      final o = Offset(x(pts[cur!].t), y(pts[cur!].v));
      canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, ph), Paint()..color = cursorC.withValues(alpha: .5)..strokeWidth = 1);
      canvas.drawCircle(o, 6, Paint()..color = cursorC); canvas.drawCircle(o, 3.5, Paint()..color = color);
    }
  }
  @override
  bool shouldRepaint(_TSPainter o) => o.pts != pts || o.cur != cur || o.color != color;
}

class SparkPainter extends CustomPainter {
  final List<double> v; final Color color; final double? lo0, hi0;
  SparkPainter(this.v, this.color, {this.lo0, this.hi0});
  @override
  void paint(Canvas canvas, Size s) {
    if (v.length < 2) return;
    final lo = lo0 ?? v.reduce(math.min), hi = hi0 ?? v.reduce(math.max), sp = (hi - lo) == 0 ? 1 : hi - lo;
    // Con eje fijo (p. ej. SpO₂ 90-100) los valores fuera del eje se recortan para no salirse de la tesela.
    double yv(double x) => lo0 != null && hi0 != null ? x.clamp(lo, hi).toDouble() : x;
    Offset p(int i) => Offset(i / (v.length - 1) * s.width, s.height - 3 - (yv(v[i]) - lo) / sp * (s.height - 6));
    final path = Path()..moveTo(p(0).dx, p(0).dy);
    for (var i = 1; i < v.length; i++) { path.lineTo(p(i).dx, p(i).dy); }
    canvas.drawPath(Path.from(path)..lineTo(s.width, s.height)..lineTo(0, s.height)..close(), Paint()..color = color.withValues(alpha: .14));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
    canvas.drawCircle(p(v.length - 1), 3.5, Paint()..color = color);
  }
  @override
  bool shouldRepaint(SparkPainter o) => o.v != v || o.lo0 != lo0;
}

/// Medidor semicircular neutro (sin zonas de color de juicio).
class GaugePainter extends CustomPainter {
  final double frac; final Color color, track;
  GaugePainter(this.frac, this.color, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = math.min(s.width / 2, s.height) - 8; final c = Offset(s.width / 2, s.height - 6);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi, math.pi, false, p..color = track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi, math.pi * frac.clamp(0.02, 1), false, p..color = color);
  }
  @override
  bool shouldRepaint(GaugePainter o) => o.frac != frac;
}

/// Reloj del día: anillo exterior = actividad por franjas de 30 min; anillo medio = pulso en polar.
class DayDial extends StatefulWidget {
  final Day day; final VC c; final double? scrubMin; final double? nowMin; final ValueChanged<double?> onScrub; final ValueChanged<bool> onLock;
  /// Mezcla de cada franja de 30 min (48): sueño y esfuerzo. Si es null, el anillo se pinta solo por pasos, como antes.
  final List<BinMix>? mix;
  const DayDial({super.key, required this.day, required this.c, required this.scrubMin, required this.nowMin, required this.onScrub, required this.onLock, this.mix});
  @override
  State<DayDial> createState() => _DayDialState();
}

class _DayDialState extends State<DayDial> {
  bool _active = false; // persistente entre reconstrucciones

  double _r(Size s) => s.width / 2 - 14;
  bool _onRings(Offset p, Size s) { final d = (p - Offset(s.width / 2, s.height / 2)).distance; return d >= _r(s) * .38 && d <= _r(s) + 18; }

  void _hit(Offset p, Size s) {
    final d = p - Offset(s.width / 2, s.height / 2);
    final a = (math.atan2(d.dy, d.dx) + math.pi / 2) % (2 * math.pi);
    final m = (a / (2 * math.pi) * 1440).clamp(0, 1439).toDouble();
    if (widget.scrubMin == null || (m ~/ 30) != (widget.scrubMin! ~/ 30)) HapticFeedback.selectionClick();
    widget.onScrub(m);
  }

  void _release() { if (_active) { _active = false; widget.onLock(false); } }

  @override
  void dispose() { if (_active) widget.onLock(false); super.dispose(); }

  /// Ajuste accesible por pasos de 30 min (el gesto circular no es operable con lector de pantalla).
  void _step(double d) {
    final cur = widget.scrubMin ?? widget.nowMin ?? 0;
    widget.onScrub(((cur ~/ 30) * 30 + d).clamp(0, 1410).toDouble());
  }

  String get _semValue {
    final m = widget.scrubMin; if (m == null) return 'sin franja seleccionada';
    final h = m ~/ 60, mi = (m % 60).round(); return '${two(h)}:${two(mi)}';
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Reloj del día: actividad y pulso por franjas de 30 minutos', value: _semValue, excludeSemantics: true,
      increasedValue: 'siguiente franja', decreasedValue: 'franja anterior',
      onIncrease: () => _step(30), onDecrease: () => _step(-30),
      child: _build(context));

  Widget _build(BuildContext context) => AspectRatio(aspectRatio: 1, child: LayoutBuilder(builder: (context, bc) {
        final size = Size(bc.maxWidth, bc.maxWidth);
        // Listener (sin arena de gestos): evita que el scroll de la lista robe el arrastre.
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) { if (_onRings(e.localPosition, size)) { _active = true; widget.onLock(true); _hit(e.localPosition, size); } },
          onPointerMove: (e) { if (_active) _hit(e.localPosition, size); },
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: GestureDetector(onDoubleTap: () => widget.onScrub(null), child: CustomPaint(size: size, painter: _DialPainter(widget.day, widget.c, widget.scrubMin, widget.nowMin, widget.mix))),
        );
      }));
}

/// Paleta del anillo del reloj. En el tema oscuro, los colores de siempre; en el claro, tonos más claros y vivos, cercanos a los del oscuro
/// (un 25 % hacia el tono oscuro-sobre-claro del tema, para que no se pierdan sobre fondo blanco). Es un elemento gráfico y no lleva texto:
/// cada color va siempre acompañado de su nombre en la leyenda.
class RingPalette {
  final Color rest, light, sport, sleep;
  const RingPalette(this.rest, this.light, this.sport, this.sleep);
  static Color _soft(Color dark, Color light) => Color.lerp(dark, light, .25)!;
  static RingPalette of(VC c) => identical(c, VC.light)
      ? RingPalette(_soft(VC.dark.spo2, VC.light.spo2), _soft(VC.dark.steps, VC.light.steps), _soft(VC.dark.met, VC.light.met), _soft(VC.dark.accent2, VC.light.accent2))
      : RingPalette(c.spo2, c.steps, c.met, c.accent2);
}

/// Colores de referencia del reloj: dormir morado, reposo azul, actividad leve verde, actividad deportiva naranja.
Color dayKindColor(VC c, DayKind k) { final p = RingPalette.of(c); return switch (k) {
      DayKind.sleep => p.sleep, DayKind.activity => p.sport, DayKind.walk => p.light, DayKind.rest => p.rest, DayKind.none => c.surfaceHi }; }

/// Degradado del esfuerzo: 0 azul (reposo) → 0,5 verde (actividad leve) → 1 naranja (deportiva).
Color effortColor(VC c, double effort) {
  final e = effort.clamp(0.0, 1.0); final p = RingPalette.of(c);
  return e <= .5 ? Color.lerp(p.rest, p.light, e / .5)! : Color.lerp(p.light, p.sport, (e - .5) / .5)!;
}

/// Color de una franja: el degradado del esfuerzo, con el sueño por encima (a partir de 15 min de sueño, morado del todo). Sin datos: gris.
Color mixColor(VC c, BinMix m) {
  if (!m.hasData) return c.surfaceHi.withValues(alpha: .7);
  return Color.lerp(effortColor(c, m.effort), RingPalette.of(c).sleep, m.sleep)!;
}

class _DialPainter extends CustomPainter {
  final Day day; final VC c; final double? scrub, now; final List<BinMix>? mix;
  _DialPainter(this.day, this.c, this.scrub, this.now, this.mix);
  double ang(double m) => -math.pi / 2 + 2 * math.pi * m / 1440;
  @override
  void paint(Canvas canvas, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2); final R = s.width / 2 - 14;
    // 1) actividad (48 franjas)
    final bins = List<double>.filled(48, 0);
    for (final e in day.steps5) { bins[(e.t.hour * 2 + e.t.minute ~/ 30)] += e.v; }
    final mx = bins.reduce(math.max);
    final ring = Rect.fromCircle(center: ctr, radius: R - 8);
    for (var i = 0; i < 48; i++) {
      final k = mx > 0 ? bins[i] / mx : 0.0;
      final Color col = mix == null ? (k > 0 ? c.steps.withValues(alpha: .22 + .78 * k) : c.surfaceHi.withValues(alpha: .7)) : mixColor(c, mix![i]);
      final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.butt..color = col;
      canvas.drawArc(ring, ang(i * 30.0) + .012, 2 * math.pi / 48 - .024, false, p);
    }
    // 2) pulso en polar
    final base = R - 56, amp = 34.0;
    canvas.drawCircle(ctr, base, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = c.surfaceHi);
    if (day.hr.length > 1) {
      final lo = day.hr.map((e) => e.v).reduce(math.min), hi = day.hr.map((e) => e.v).reduce(math.max), sp = (hi - lo) == 0 ? 1 : hi - lo;
      final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeJoin = StrokeJoin.round..color = c.heart;
      Path? path; DateTime? prev;
      for (final e in day.hr) {
        final r = base - amp * .35 + (e.v - lo) / sp * amp;
        final o = ctr + Offset(math.cos(ang(minutesOf(e.t))) * r, math.sin(ang(minutesOf(e.t))) * r);
        if (path == null || (prev != null && e.t.difference(prev).inMinutes > 10)) { if (path != null) canvas.drawPath(path, line); path = Path()..moveTo(o.dx, o.dy); } else { path.lineTo(o.dx, o.dy); }
        prev = e.t;
      }
      if (path != null) canvas.drawPath(path, line);
    }
    // 3) marcas de hora
    for (final h in [0, 6, 12, 18]) {
      final a = ang(h * 60.0); final o = ctr + Offset(math.cos(a) * (R + 9), math.sin(a) * (R + 9));
      final tp = TextPainter(text: TextSpan(text: '$h', style: TextStyle(fontSize: 10, color: c.muted)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
    // 4) ahora
    if (now != null) { final a = ang(now!); canvas.drawCircle(ctr + Offset(math.cos(a) * (R - 8), math.sin(a) * (R - 8)), 5, Paint()..color = c.accent); }
    // 5) cursor
    if (scrub != null) {
      final a = ang(scrub!);
      canvas.drawLine(ctr + Offset(math.cos(a) * (base - amp - 4), math.sin(a) * (base - amp - 4)), ctr + Offset(math.cos(a) * (R + 1), math.sin(a) * (R + 1)), Paint()..color = c.text..strokeWidth = 2..strokeCap = StrokeCap.round);
      canvas.drawCircle(ctr + Offset(math.cos(a) * (R - 8), math.sin(a) * (R - 8)), 8, Paint()..color = c.text);
      canvas.drawCircle(ctr + Offset(math.cos(a) * (R - 8), math.sin(a) * (R - 8)), 4, Paint()..color = c.bg);
    }
  }
  @override
  bool shouldRepaint(_DialPainter o) => o.scrub != scrub || o.day != day || o.now != now || o.c != c || o.mix != mix;
}
