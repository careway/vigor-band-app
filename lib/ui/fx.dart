import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

bool reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

/// Fondo "Aurora": tres resplandores que derivan muy despacio (bucle de 24 s). Se detiene con "reducir animaciones".
class Aurora extends StatefulWidget {
  final Color tint; final Widget child;
  const Aurora({super.key, required this.tint, required this.child});
  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) { _c.stop(); } else if (!_c.isAnimating) { _c.repeat(); }
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return Stack(children: [
      Positioned.fill(child: RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _AuroraPainter(_c.value, c, widget.tint, Theme.of(context).brightness == Brightness.dark))))),
      widget.child,
    ]);
  }
}

class _AuroraPainter extends CustomPainter {
  final double t; final VC c; final Color tint; final bool dark;
  _AuroraPainter(this.t, this.c, this.tint, this.dark);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = c.bg);
    final k = dark ? 1.0 : .55;
    void blob(Offset o, double r, Color col, double a) {
      canvas.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: a * k), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r)));
    }
    final a = 2 * math.pi * t;
    blob(Offset(s.width * (.25 + .25 * math.sin(a)), s.height * (.12 + .06 * math.cos(a))), s.width * .9, c.accent, .20);
    blob(Offset(s.width * (.8 + .15 * math.cos(a + 1)), s.height * (.30 + .08 * math.sin(a + 2))), s.width * .85, c.accent2, .17);
    blob(Offset(s.width * (.5 + .3 * math.sin(a + 4)), s.height * (.85 + .05 * math.cos(a))), s.width * .9, tint, .13);
  }
  @override
  bool shouldRepaint(_AuroraPainter o) => o.t != t || o.tint != tint;
}

/// Tarjeta de cristal: relleno translúcido + borde de 1 px (sin desenfoque, para ahorrar batería).
class Glass extends StatelessWidget {
  final Widget child; final EdgeInsets padding; final double radius; final Color? glow;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(Sp.x4), this.radius = 24, this.glow});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surface.withValues(alpha: dark ? .88 : .96), c.surface.withValues(alpha: dark ? .66 : .86)]),
        border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: dark ? .08 : .06)),
        boxShadow: glow == null ? null : [BoxShadow(color: glow!.withValues(alpha: .10), blurRadius: 24)],
      ),
      child: child,
    );
  }
}

/// Número que "cuenta" hasta su valor.
class CountUp extends StatelessWidget {
  final double value; final String Function(double) fmt; final TextStyle style;
  const CountUp(this.value, this.fmt, this.style, {super.key});
  @override
  Widget build(BuildContext context) => reduceMotion(context)
      ? Text(fmt(value), style: style)
      : TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: value), duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic, builder: (_, v, _) => Text(fmt(v), style: style));
}

/// Corazón que late al ritmo de la última lectura (lub-dub).
class PulseHeart extends StatefulWidget {
  final double bpm; final Color color; final double size;
  const PulseHeart({super.key, required this.bpm, required this.color, this.size = 22});
  @override
  State<PulseHeart> createState() => _PulseHeartState();
}

class _PulseHeartState extends State<PulseHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _dur);
  Duration get _dur => Duration(milliseconds: (60000 / widget.bpm.clamp(30, 200)).round());
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
  ]);
  @override
  void didChangeDependencies() { super.didChangeDependencies(); if (reduceMotion(context)) { _c.stop(); } else if (!_c.isAnimating) { _c.repeat(); } }
  @override
  void didUpdateWidget(PulseHeart o) { super.didUpdateWidget(o); if (o.bpm != widget.bpm) { _c.duration = _dur; if (_c.isAnimating) _c.repeat(); } }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: ScaleTransition(scale: _c.drive(_scale), child: Icon(Icons.favorite, size: widget.size, color: widget.color)));
}

/// Navegación flotante en píldora.
class FloatNav extends StatelessWidget {
  final int index; final ValueChanged<int> onTap; final List<(IconData, IconData, String)> items;
  const FloatNav({super.key, required this.index, required this.onTap, required this.items});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return SafeArea(top: false, minimum: const EdgeInsets.only(bottom: Sp.x2), child: Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x3),
      child: Glass(radius: 30, padding: const EdgeInsets.all(6), child: Row(children: [
        for (var i = 0; i < items.length; i++) Expanded(child: Semantics(button: true, selected: i == index, label: items[i].$3, child: InkWell(
          borderRadius: BorderRadius.circular(24), onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: i == index ? c.accent.withValues(alpha: .16) : Colors.transparent),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(i == index ? items[i].$2 : items[i].$1, size: 22, color: i == index ? c.accent : c.muted),
              const SizedBox(height: 2),
              Text(items[i].$3, style: TextStyle(fontSize: 11, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? c.accent : c.muted)),
            ]),
          )))),
      ])),
    ));
  }
}

/// Burbuja de día: círculo que se llena de líquido según [fill] (0..1+). La onda se anima solo si [animate] y no se reducen animaciones.
class LiquidDay extends StatefulWidget {
  final double fill, size; final Color liquid, track, textColor; final String label; final bool selected, animate;
  const LiquidDay({super.key, required this.fill, required this.size, required this.liquid, required this.track, required this.textColor, required this.label, this.selected = false, this.animate = false});
  @override
  State<LiquidDay> createState() => _LiquidDayState();
}

class _LiquidDayState extends State<LiquidDay> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  @override
  void dispose() { _a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final run = widget.animate && !reduceMotion(context);
    if (run && !_a.isAnimating) { _a.repeat(); } else if (!run && _a.isAnimating) { _a.stop(); }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.fill.clamp(0.0, 1.0)), duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700), curve: Curves.easeOutCubic,
      builder: (_, lvl, _) => AnimatedBuilder(animation: _a, builder: (_, _) => SizedBox(width: widget.size, height: widget.size, child: CustomPaint(
        painter: _LiquidPainter(lvl, _a.value * 2 * math.pi, widget.liquid, widget.track, widget.selected),
        child: Center(child: Text(widget.label, style: TextStyle(fontSize: widget.size * .36, fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600, color: widget.textColor)))))),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double level, phase; final Color liquid, track; final bool selected;
  _LiquidPainter(this.level, this.phase, this.liquid, this.track, this.selected);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2, ctr = Offset(r, r);
    canvas.drawCircle(ctr, r, Paint()..color = track);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: ctr, radius: r - 1)));
    if (level > 0) {
      final top = s.height * (1 - level), amp = level >= 1 ? 0.0 : s.height * .045;
      Path wave(double ph) {
        final p = Path()..moveTo(0, s.height);
        for (double x = 0; x <= s.width; x += 2) { p.lineTo(x, top + amp * math.sin(x / s.width * 2 * math.pi + ph)); }
        return p..lineTo(s.width, s.height)..close();
      }
      canvas.drawPath(wave(phase + 2), Paint()..color = liquid.withValues(alpha: .45));
      canvas.drawPath(wave(phase), Paint()..color = liquid.withValues(alpha: .85));
    }
    canvas.restore();
    canvas.drawCircle(ctr, r - (selected ? 1.5 : .5), Paint()..style = PaintingStyle.stroke..strokeWidth = selected ? 3 : 1..color = selected ? liquid : liquid.withValues(alpha: .35));
  }
  @override
  bool shouldRepaint(_LiquidPainter o) => o.level != level || o.phase != phase || o.liquid != liquid || o.selected != selected;
}
