import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Color de cada fase (nunca es la única señal: hay carriles rotulados, iniciales y leyenda con minutos).
Color stageColor(VC c, Stage s) => switch (s) { Stage.awake => c.met, Stage.rem => c.accent2, Stage.light => c.spo2, Stage.deep => c.sleep };
String stageInitial(Stage s) => switch (s) { Stage.awake => 'D', Stage.rem => 'R', Stage.light => 'L', Stage.deep => 'P' };

/// Carriles visibles: sin REM en el modo normal (la pulsera no lo da).
List<Stage> lanesFor(Night n) => n.precise ? Stage.values : [for (final s in Stage.values) if (s != Stage.rem) s];

String nightSpokenSummary(Night n) {
  final st = n.stages;
  final nap = n.isNap ? 'Siesta' : 'Noche';
  final range = n.start != null && st != null ? ', de ${hm(n.start!)} a ${hm(n.start!.add(Duration(minutes: st.length)))}' : '';
  if (st == null) return '$nap del ${n.date}: ${dur(n.total * 60)} de sueño, ${n.wake} despertares según la pulsera. Sin detalle por fases.';
  final m = sleepMetrics(st);
  return '$nap del ${n.date}$range: ${dur(m.asleepMin * 60)} dormido de ${dur(m.bedMin * 60)} registrados, eficiencia ${(m.efficiency * 100).round()} %. '
      'Profundo ${m.deepMin} min, ligero ${m.lightMin} min${n.precise ? ', REM ${m.remMin} min' : ''}, despierto ${m.awakeMin} min. '
      '${m.awakenings} despertares de 5 minutos o más; la pulsera cuenta ${n.wake}. Fases aproximadas.';
}

/// Serie de [select] de los días que cubre la noche, en minutos desde [start].
List<(double, double)> seriesFor(Map<String, Day> days, DateTime start, int minutes, List<Sample> Function(Day) select) {
  final end = start.add(Duration(minutes: minutes)); final out = <(double, double)>[];
  final keys = {for (final d in [start, end]) '${d.year}-${two(d.month)}-${two(d.day)}'};
  for (final k in keys) {
    final d = days[k]; if (d == null) continue;
    for (final s in select(d)) { if (!s.t.isBefore(start) && !s.t.isAfter(end) && s.v > 0) out.add((s.t.difference(start).inSeconds / 60, s.v)); }
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

const double _gutter = 58, _rightPad = 8;

TextPainter _tp(String t, Color col, double size, {FontWeight w = FontWeight.w400}) => TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: size, color: col, fontWeight: w)), textDirection: TextDirection.ltr, maxLines: 1)..layout();

double _xOf(double min, int total, double width) => _gutter + min / math.max(total, 1) * (width - _gutter - _rightPad);

void _ticks(Canvas canvas, Size s, DateTime? start, int total, Color grid, Color text, double fs, {required bool labels, required double bottom}) {
  final g = Paint()..color = grid..strokeWidth = 1;
  // Marcas cada hora de reloj (o de tiempo relativo si no hay hora de inicio); etiquetas cada 1 o 2 h según el ancho.
  final firstMin = start == null ? 0 : (60 - start.minute) % 60;
  final pxPerHour = (s.width - _gutter - _rightPad) / math.max(total, 1) * 60;
  final every = pxPerHour >= 40 ? 1 : 2;
  for (var m = firstMin; m <= total; m += 60) {
    final x = _xOf(m.toDouble(), total, s.width);
    canvas.drawLine(Offset(x, 0), Offset(x, bottom), g);
    final h = start == null ? m ~/ 60 : start.add(Duration(minutes: m)).hour;
    if (labels && (start == null ? m ~/ 60 : h) % every == 0) {
      final t = _tp(start == null ? '${m ~/ 60} h' : '${two(h)}h', text, fs); t.paint(canvas, Offset(math.min(x - t.width / 2, s.width - t.width), bottom + 3));
    }
  }
}

class _HypnoPainter extends CustomPainter {
  final List<Stage> st; final List<Stage> lanes; final DateTime? start; final VC c; final int? cursor; final double fs; final double laneH;
  _HypnoPainter(this.st, this.lanes, this.start, this.c, this.cursor, this.fs, this.laneH);
  @override
  void paint(Canvas canvas, Size s) {
    final total = st.length; final plotH = lanes.length * laneH;
    for (var i = 0; i < lanes.length; i++) {
      if (i.isOdd) canvas.drawRect(Rect.fromLTWH(_gutter, i * laneH, s.width - _gutter, laneH), Paint()..color = c.surfaceHi.withValues(alpha: .35));
      final t = _tp(stageName(lanes[i]), c.muted, fs); t.paint(canvas, Offset(0, i * laneH + (laneH - t.height) / 2));
    }
    _ticks(canvas, s, start, total, c.surfaceHi, c.muted, fs, labels: true, bottom: plotH);
    // Tramos por minuto (sin agregar): cada tramo = un rectángulo de su carril; ancho mínimo para que un minuto suelto se vea.
    final link = Paint()..color = c.muted.withValues(alpha: .6)..strokeWidth = 1;
    var i = 0; double? prevY; double? prevX;
    while (i < total) {
      var j = i; while (j < total && st[j] == st[i]) { j++; }
      final lane = lanes.indexOf(st[i]); final laneIdx = lane < 0 ? lanes.indexOf(Stage.light) : lane;
      final x0 = _xOf(i.toDouble(), total, s.width), x1 = math.max(_xOf(j.toDouble(), total, s.width), x0 + 1.5);
      final y0 = laneIdx * laneH + 5, y1 = (laneIdx + 1) * laneH - 5;
      if (prevY != null) canvas.drawLine(Offset(prevX!, math.min(prevY, (y0 + y1) / 2)), Offset(prevX, math.max(prevY, (y0 + y1) / 2)), link);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x0, y0, x1, y1), const Radius.circular(2)), Paint()..color = stageColor(c, st[i]));
      prevY = (y0 + y1) / 2; prevX = x1; i = j;
    }
    if (cursor != null) { final x = _xOf(cursor!.toDouble() + .5, total, s.width); canvas.drawLine(Offset(x, 0), Offset(x, plotH), Paint()..color = c.text..strokeWidth = 1.5); }
  }
  @override
  bool shouldRepaint(_HypnoPainter o) => o.cursor != cursor || o.c != c || o.st != st || o.fs != fs;
}

class _SeriesPainter extends CustomPainter {
  final List<(double, double)> pts; final int total; final DateTime? start; final VC c; final Color color; final String unit; final int? cursor; final double fs;
  _SeriesPainter(this.pts, this.total, this.start, this.c, this.color, this.unit, this.cursor, this.fs);
  @override
  void paint(Canvas canvas, Size s) {
    final h = s.height - 4;
    _ticks(canvas, s, start, total, c.surfaceHi, c.muted, fs, labels: false, bottom: h);
    canvas.drawLine(Offset(_gutter, h), Offset(s.width - _rightPad, h), Paint()..color = c.surfaceHi..strokeWidth = 1);
    var lo = pts.map((e) => e.$2).reduce(math.min), hi = pts.map((e) => e.$2).reduce(math.max);
    if (hi - lo < 4) { lo -= 2; hi += 2; }
    double y(double v) => h - 4 - (v - lo) / (hi - lo) * (h - 12);
    _tp(hi.round().toString(), c.muted, fs).paint(canvas, const Offset(0, 0));
    _tp(lo.round().toString(), c.muted, fs).paint(canvas, Offset(0, h - fs - 4));
    final u = _tp(unit, c.muted, fs); u.paint(canvas, Offset(0, (h - u.height) / 2));
    // Se corta la línea si hay un hueco > 15 min (no se une lo que no se midió).
    final p = Path(); double? lastX;
    for (final e in pts) { final x = _xOf(e.$1, total, s.width); if (lastX == null || e.$1 - lastX > 15) { p.moveTo(x, y(e.$2)); } else { p.lineTo(x, y(e.$2)); } lastX = e.$1; }
    canvas.drawPath(p, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeJoin = StrokeJoin.round);
    for (final e in pts) { canvas.drawCircle(Offset(_xOf(e.$1, total, s.width), y(e.$2)), 1.4, Paint()..color = color); }
    if (cursor != null) { final x = _xOf(cursor!.toDouble() + .5, total, s.width); canvas.drawLine(Offset(x, 0), Offset(x, h), Paint()..color = c.text..strokeWidth = 1.5); }
  }
  @override
  bool shouldRepaint(_SeriesPainter o) => o.cursor != cursor || o.pts != pts || o.c != c || o.fs != fs;
}

/// Hipnograma + FC (+ SpO2) en el MISMO eje de hora de reloj, con lectura al arrastrar el dedo.
/// Sin animaciones (respeta "reducir movimiento" por construcción).
class NightTimeline extends StatefulWidget {
  final Night night; final Map<String, Day> days;
  const NightTimeline(this.night, this.days, {super.key});
  @override
  State<NightTimeline> createState() => _NightTimelineState();
}

class _NightTimelineState extends State<NightTimeline> {
  int? _cur;
  void _set(double dx, double width) {
    final total = widget.night.stages!.length;
    final f = (dx - _gutter) / (width - _gutter - _rightPad);
    setState(() => _cur = (f * total).floor().clamp(0, total - 1));
  }
  double? _near(List<(double, double)> s, int m) {
    double? best; var bd = 11.0;
    for (final e in s) { final d = (e.$1 - m).abs(); if (d < bd) { bd = d; best = e.$2; } }
    return best;
  }
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final n = widget.night; final st = n.stages!; final total = st.length; final start = n.start;
    final fs = 11.0 * math.min(MediaQuery.textScalerOf(context).scale(1), 1.3);
    final lanes = lanesFor(n); final laneH = math.max(36.0, fs * 2.6);
    final hr = start == null ? <(double, double)>[] : seriesFor(widget.days, start, total, (d) => d.hr);
    final sp = start == null ? <(double, double)>[] : seriesFor(widget.days, start, total, (d) => d.spo2);
    String reading() {
      if (_cur == null) return 'Arrastra el dedo por el gráfico para leer cada minuto.';
      final t = start == null ? '+${dur(_cur! * 60)}' : hm(start.add(Duration(minutes: _cur!)));
      final h = _near(hr, _cur!), o = _near(sp, _cur!);
      return '$t · ${stageName(st[_cur!])}${h != null ? ' · FC ${h.round()} lpm' : ''}${o != null ? ' · SpO₂ ${o.round()} %' : ''}';
    }
    return LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth;
      Widget gesture(Widget child) => GestureDetector(behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _set(d.localPosition.dx, w), onHorizontalDragStart: (d) => _set(d.localPosition.dx, w), onHorizontalDragUpdate: (d) => _set(d.localPosition.dx, w), child: child);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Align(alignment: Alignment.centerLeft, child: Text(reading(), style: VT.heading(c)))),
        gesture(ExcludeSemantics(child: Column(children: [
          SizedBox(height: lanes.length * laneH + fs + 10, width: w, child: CustomPaint(painter: _HypnoPainter(st, lanes, start, c, _cur, fs, laneH))),
          if (hr.length >= 2) Padding(padding: const EdgeInsets.only(top: Sp.x2), child: SizedBox(height: 84, width: w, child: CustomPaint(painter: _SeriesPainter(hr, total, start, c, c.heart, 'lpm', _cur, fs)))),
          if (sp.length >= 2) Padding(padding: const EdgeInsets.only(top: Sp.x2), child: SizedBox(height: 70, width: w, child: CustomPaint(painter: _SeriesPainter(sp, total, start, c, c.spo2, 'SpO₂', _cur, fs)))),
        ]))),
        if (hr.length < 2) const Note('Sin lecturas de pulso suficientes en esta noche para dibujar la FC.'),
        if (hr.length >= 2 && sp.length < 2) const Note('Sin lecturas de SpO₂ suficientes en esta noche.'),
      ]);
    });
  }
}

/// Barra apilada de fases (minutos y %); % sobre el tiempo dormido, "Despierto" sobre el registrado.
class StageBar extends StatelessWidget {
  final Night night; const StageBar(this.night, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final m = sleepMetrics(night.stages!);
    final mins = {Stage.deep: m.deepMin, Stage.light: m.lightMin, Stage.rem: m.remMin, Stage.awake: m.awakeMin};
    final order = [Stage.deep, Stage.light, if (night.precise) Stage.rem, Stage.awake];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 32, child: Row(children: [
        for (final s in order) if (mins[s]! > 0) Expanded(flex: mins[s]!, child: Container(color: stageColor(c, s), alignment: Alignment.center, child: Text(stageInitial(s), maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0E13) : Colors.white)))),
      ])))),
      const SizedBox(height: Sp.x2),
      for (final s in order) ConstrainedBox(constraints: const BoxConstraints(minHeight: 28), child: Row(children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: stageColor(c, s), borderRadius: BorderRadius.circular(3))), const SizedBox(width: Sp.x2),
        Expanded(child: Text('${stageName(s)} (${stageInitial(s)})', style: VT.body(c))),
        Text(s == Stage.awake ? '${dur(mins[s]! * 60)} · ${(mins[s]! * 100 / math.max(m.bedMin, 1)).round()} % del registro' : '${dur(mins[s]! * 60)} · ${m.pct(mins[s]!).round()} % del sueño', style: VT.body(c)),
      ])),
    ]);
  }
}

class WeekSlot { final DateTime day; final Night? night; const WeekSlot(this.day, this.night); }

class _WeekPainter extends CustomPainter {
  final List<WeekSlot> slots; final VC c; final int? sel; final double fs; final double? mean;
  _WeekPainter(this.slots, this.c, this.sel, this.fs, this.mean);
  @override
  void paint(Canvas canvas, Size s) {
    final maxMin = slots.fold<int>(0, (a, e) => math.max(a, e.night?.total ?? 0));
    final top = math.max(1, (maxMin / 60).ceil()) * 60.0; final h = s.height - fs - 8; const left = 34.0;
    final slotW = (s.width - left) / slots.length;
    double y(num m) => h - m / top * h;
    final g = Paint()..color = c.surfaceHi..strokeWidth = 1;
    canvas.drawLine(Offset(left, h), Offset(s.width, h), g); canvas.drawLine(Offset(left, 0), Offset(s.width, 0), g);
    _tp('${(top / 60).round()} h', c.muted, fs).paint(canvas, const Offset(0, 0)); _tp('0', c.muted, fs).paint(canvas, Offset(0, h - fs - 2));
    final every = slots.length <= 7 ? 1 : slots.length <= 14 ? 2 : 5;
    for (var i = 0; i < slots.length; i++) {
      final sl = slots[i]; final x = left + i * slotW, bw = math.max(slotW * .68, 3.0), bx = x + (slotW - bw) / 2;
      if ((slots.length - 1 - i) % every == 0) { final t = _tp('${sl.day.day}', c.muted, fs); t.paint(canvas, Offset(x + (slotW - t.width) / 2, h + 3)); }
      final n = sl.night; if (n == null) continue;
      if (sel == i) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x, 0, x + slotW, h + fs + 6), const Radius.circular(4)), Paint()..color = c.text.withValues(alpha: .08));
      var base = 0.0;
      final st = n.stages;
      final parts = st == null ? [(c.exp, n.total.toDouble())] : (() { final m = sleepMetrics(st); return [(stageColor(c, Stage.deep), m.deepMin.toDouble()), (stageColor(c, Stage.light), m.lightMin.toDouble()), if (n.precise) (stageColor(c, Stage.rem), m.remMin.toDouble())]; })();
      for (final p in parts) { if (p.$2 <= 0) continue; canvas.drawRect(Rect.fromLTRB(bx, y(base + p.$2), bx + bw, y(base)), Paint()..color = p.$1); base += p.$2; }
      if (st == null) canvas.drawRect(Rect.fromLTRB(bx, y(n.total), bx + bw, h), Paint()..color = c.bg.withValues(alpha: .35)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    if (mean != null) { final yy = y(mean!); final p = Paint()..color = c.text..strokeWidth = 1; for (var x = left; x < s.width; x += 8) { canvas.drawLine(Offset(x, yy), Offset(math.min(x + 4, s.width), yy), p); } }
  }
  @override
  bool shouldRepaint(_WeekPainter o) => o.sel != sel || o.slots != slots || o.c != c || o.fs != fs || o.mean != mean;
}

/// Barras apiladas por noche (profundo/ligero/REM) del periodo; las noches sin fases van en gris. Toca una barra para elegir la noche.
class WeekChart extends StatelessWidget {
  final List<WeekSlot> slots; final String? selectedDate; final void Function(Night) onSelect; final double? meanMin;
  const WeekChart(this.slots, this.selectedDate, this.onSelect, {super.key, this.meanMin});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final fs = 10.0 * math.min(MediaQuery.textScalerOf(context).scale(1), 1.3);
    final sel = slots.indexWhere((e) => e.night?.date == selectedDate);
    return LayoutBuilder(builder: (context, bc) => GestureDetector(behavior: HitTestBehavior.opaque,
      onTapDown: (d) { final i = ((d.localPosition.dx - 34) / ((bc.maxWidth - 34) / slots.length)).floor(); if (i >= 0 && i < slots.length && slots[i].night != null) onSelect(slots[i].night!); },
      child: ExcludeSemantics(child: SizedBox(height: 150 + fs, width: bc.maxWidth, child: CustomPaint(painter: _WeekPainter(slots, c, sel < 0 ? null : sel, fs, meanMin))))));
  }
}
