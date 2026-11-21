import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'delete_ui.dart';
import 'sleep_charts.dart';
import 'widgets.dart';

/// Resumen del periodo (puro, probado): siestas aparte, sin inventar medias con pocos datos.
class SleepPeriod {
  final int days; final List<WeekSlot> slots; final List<Night> naps;
  final List<Night> nights; // solo noches (no siestas) dentro del periodo
  final double? meanMin; final double? midMean, midSd; final int midN;
  SleepPeriod._(this.days, this.slots, this.naps, this.nights, this.meanMin, this.midMean, this.midSd, this.midN);

  /// Ventana de [days] días naturales que termina en [end] (la última fecha con dato o hoy).
  factory SleepPeriod.of(List<Night> all, int days, DateTime end) {
    final endD = DateTime(end.year, end.month, end.day);
    final slots = <WeekSlot>[]; final naps = <Night>[]; final nights = <Night>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(endD.year, endD.month, endD.day - i); final key = '${d.year}-${two(d.month)}-${two(d.day)}';
      final here = all.where((n) => n.date == key).toList();
      final main = here.where((n) => !n.isNap).fold<Night?>(null, (a, n) => a == null || n.total > a.total ? n : a);
      naps.addAll(here.where((n) => n.isNap));
      if (main != null) nights.add(main);
      slots.add(WeekSlot(d, main));
    }
    final mean = nights.isEmpty ? null : nights.fold<int>(0, (a, n) => a + n.total) / nights.length;
    // Regularidad: punto medio del sueño (inicio + registro/2), medido desde las 12:00 para no partir las noches que cruzan la medianoche.
    final mids = <double>[];
    for (final n in nights) { final s = n.start; if (s != null) { final len = n.stages?.length ?? (n.up != null ? n.up!.difference(s).inMinutes : n.total); mids.add(minutesFromNoon(s.add(Duration(minutes: len ~/ 2))).toDouble()); } }
    final mm = mids.isEmpty ? null : mids.reduce((a, b) => a + b) / mids.length;
    return SleepPeriod._(days, slots, naps, nights, mean, mm, stdDev(mids), mids.length);
  }
}

class SleepPage extends StatefulWidget {
  final VigorRepo repo; const SleepPage(this.repo, {super.key});
  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  int _days = 7; String? _sel;
  VigorRepo get repo => widget.repo;
  Night? _current() {
    final all = repo.nights; if (all.isEmpty) return null;
    for (final n in all) { if (n.date == _sel) return n; }
    return all.firstWhere((n) => !n.isNap, orElse: () => all.first);
  }
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    if (repo.nights.isEmpty) {
      return EmptyState(Icons.bedtime_outlined, 'Aún no hay noches registradas.\nLleva la pulsera puesta al dormir y sincroniza por la mañana.', action: FilledButton(onPressed: repo.conn == 'connected' ? repo.sync : null, child: const Text('Sincronizar')));
    }
    final cur = _current()!;
    final latest = DateTime.parse(repo.nights.first.date); final now = DateTime.now();
    final per = SleepPeriod.of(repo.nights, _days, latest.isAfter(now) ? latest : now);
    return ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
      _periodPanel(context, c, per, cur),
      NightCard(cur, repo.days, onDelete: () => confirmAndDelete(context, repo, type: 'sleep', keys: [cur.date], title: 'Borrar esta noche', what: 'Se borrará la noche del ${cur.date} (${dur(cur.total * 60)} de sueño).')),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Todas las noches y siestas'),
        for (final n in repo.nights) _row(context, c, n, n.date == cur.date),
      ])),
    ]);
  }

  Widget _row(BuildContext context, VC c, Night n, bool selected) {
    final range = n.start != null ? ' · ${hm(n.start!)}' : '';
    final txt = '${n.date}$range · ${dur(n.total * 60)}${n.isNap ? ' · Siesta' : ''}';
    return Semantics(button: true, selected: selected, label: txt, child: ExcludeSemantics(child: InkWell(onTap: () => setState(() => _sel = n.date), borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x2),
        decoration: BoxDecoration(color: selected ? c.surfaceHi : null, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [Icon(n.isNap ? Icons.airline_seat_recline_normal : Icons.bedtime_outlined, size: 18, color: c.sleep), const SizedBox(width: Sp.x2), Expanded(child: Text(txt, style: VT.body(c).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w400))), if (selected) Icon(Icons.check, size: 18, color: c.accent)]))))));
  }

  Widget _periodPanel(BuildContext context, VC c, SleepPeriod per, Night cur) {
    final n = per.nights.length;
    final String mean = per.meanMin == null ? 'Sin noches en este periodo.' : 'Media de sueño: ${dur((per.meanMin! * 60).round())} · $n de ${per.days} noches';
    String reg;
    if (per.midN < 3) { reg = 'Regularidad: pocos datos (${per.midN} de ${per.days} noches con hora; hacen falta 3 o más).'; }
    else { reg = 'Regularidad: punto medio del sueño ${two(clockFromNoon(per.midMean!) ~/ 60)}:${two(clockFromNoon(per.midMean!) % 60)}, desviación típica ±${per.midSd!.round()} min (${per.midN} de ${per.days} noches).'; }
    final napMin = per.naps.fold<int>(0, (a, e) => a + e.total);
    final nap = per.naps.isEmpty ? null : 'Siestas aparte (< 3 h): ${per.naps.length} · ${dur(napMin * 60)} en total.';
    final spoken = '$mean. $reg${nap != null ? ' $nap' : ''}';
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricHeader(Icons.insights, 'Tendencia de noches', c.sleep), const SizedBox(height: Sp.x3),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [for (final d in const [7, 14, 30]) Semantics(button: true, selected: _days == d, label: 'Últimas $d noches', child: ExcludeSemantics(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: ChoiceChip(label: Text('$d'), selected: _days == d, onSelected: (_) => setState(() => _days = d), materialTapTargetSize: MaterialTapTargetSize.padded, visualDensity: VisualDensity.standard))))]),
      const SizedBox(height: Sp.x3),
      Semantics(container: true, label: spoken, child: ExcludeSemantics(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mean, style: VT.heading(c)), const SizedBox(height: Sp.x1), Text(reg, style: VT.body(c)), if (nap != null) Text(nap, style: VT.body(c))]))),
      const SizedBox(height: Sp.x3),
      if (n == 0) Text('Sin datos de noche en estos ${per.days} días.', style: VT.body(c).copyWith(color: c.muted)) else WeekChart(per.slots, cur.date, (x) => setState(() => _sel = x.date), meanMin: per.meanMin),
      Wrap(spacing: Sp.x4, runSpacing: Sp.x1, children: [for (final s in [Stage.deep, Stage.light, Stage.rem]) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, color: stageColor(c, s)), const SizedBox(width: 4), Text(stageName(s), style: VT.caption(c))]), Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, color: c.exp), const SizedBox(width: 4), Text('Sin fases', style: VT.caption(c))]), Text('--- media', style: VT.caption(c))]),
      const Note('Toca una barra para ver esa noche.'),
    ]));
  }
}

const _kSleepInfo = 'Las fases son estimaciones de una pulsera de consumo, no una polisomnografía: sobreestiman el sueño ligero (Chinoy 2021) y no sirven para diagnóstico. Sin rangos de referencia: no hay objetivos personales verificados. Implementado, no probado en hardware.';

/// Detalle de una noche: hipnograma + FC en el mismo eje, fases, métricas y ayuda. Sin fases (`sleepLine`): solo totales.
class NightCard extends StatelessWidget {
  final Night n; final Map<String, Day> days; final VoidCallback onDelete;
  const NightCard(this.n, this.days, {super.key, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final st = n.stages;
    final head = Row(children: [Expanded(child: MetricHeader(n.isNap ? Icons.airline_seat_recline_normal : Icons.bedtime, '${n.isNap ? 'Siesta' : 'Noche'} · ${n.date}', c.sleep)), DeleteButton('Borrar la noche del ${n.date}', onDelete)]);
    if (st == null) {
      return Panel(child: Semantics(container: true, label: nightSpokenSummary(n), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head, const SizedBox(height: Sp.x3), BigValue(dur(n.total * 60), '', size: 32), const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x6, runSpacing: Sp.x2, children: [
          Stat('Despertares', '${n.wake}'),
          if (n.down != null && n.up != null) Stat('Horario', '${hm(n.down!)} – ${hm(n.up!)}'),
          Stat('Profundo aprox.', dur(n.deep * 60)), Stat('Ligero aprox.', dur(n.light * 60)),
        ]),
        const Note('Esta noche solo tiene totales; las fases son aproximadas.'),
      ])));
    }
    final m = sleepMetrics(st); final s0 = n.start;
    final mid = s0?.add(Duration(minutes: m.bedMin ~/ 2));
    final stats = <Widget>[
      Stat('Dormido', dur(m.asleepMin * 60)),
      Stat('Registrado', dur(m.bedMin * 60)),
      Stat('Eficiencia', '${(m.efficiency * 100).round()} %'),
      if (n.firstDeep > 0) Stat('Hasta el 1.er sueño profundo', dur(n.firstDeep * 60)),
      Stat('Despertares (≥ 5 min)', '${m.awakenings} · pulsera: ${n.wake}'),
      Stat('Tramo dormido más largo', dur(m.longestRunMin * 60)),
      if (mid != null) Stat('Punto medio del sueño', hm(mid)),
      if (s0 != null) Stat('Horario', '${hm(s0)} – ${hm(s0.add(Duration(minutes: m.bedMin)))}'),
    ];
    return Panel(child: Semantics(container: true, label: nightSpokenSummary(n), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      head, const SizedBox(height: Sp.x2), BigValue(dur(m.asleepMin * 60), 'dormido', size: 32), const SizedBox(height: Sp.x3),
      NightTimeline(n, days), const SizedBox(height: Sp.x3),
      const SectionHeader('Fases'), StageBar(n), const SizedBox(height: Sp.x3),
      Wrap(spacing: Sp.x6, runSpacing: Sp.x3, children: stats),
      const SizedBox(height: Sp.x2),
      ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Cómo leer este gráfico', style: VT.heading(c)), shape: const Border(), collapsedShape: const Border(), children: [
        Align(alignment: Alignment.centerLeft, child: Text(
          'Arriba, el hipnograma: cada carril es una fase (${n.precise ? 'Despierto, REM, Ligero, Profundo' : 'Despierto, Ligero, Profundo'}) y el eje es la hora de reloj. Debajo, en el mismo eje, el pulso y la SpO₂ de esa noche. '
          'La eficiencia es el tiempo dormido entre el tiempo registrado; la pulsera solo registra el intervalo que detecta como sueño, así que suele salir alta. '
          '«Hasta el primer sueño profundo» no es la latencia de sueño. Los despertares se cuentan del gráfico (tramos despiertos de 5 min o más entre sueño); la pulsera puede contar otros. '
          '${n.precise ? 'El REM solo existe en el modo de sueño preciso.' : 'Esta noche está en modo normal: la pulsera guarda fases cada 5 min y no distingue REM.'}', style: VT.body(c))),
      ]),
      Row(children: [const Expanded(child: Note('Las fases son estimaciones, no un diagnóstico.')), InfoButton('Sobre las fases del sueño', _kSleepInfo)]),
    ])));
  }
}
