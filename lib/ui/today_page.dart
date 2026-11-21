import '../data/day_kinds.dart';
import 'day_kind_legend.dart';
import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/auto_sync.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'charts.dart';
import 'fx.dart';
import 'heart_ui.dart';
import 'metrics.dart';
import 'delete_ui.dart';
import 'widgets.dart';

class TodayPage extends StatefulWidget {
  final VigorRepo repo; const TodayPage(this.repo, {super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  String? key; bool expOpen = false, lock = false;
  /// El arrastre del reloj solo reconstruye la tarjeta del reloj (ValueListenableBuilder), no toda la pantalla.
  final scrub = ValueNotifier<double?>(null);
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); widget.repo.live.setVisible(true); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { final on = s == AppLifecycleState.resumed; if (on) { widget.repo.live.setVisible(true); widget.repo.live.resumeNow(); } else { widget.repo.live.setVisible(false); widget.repo.heart.cancel(); } }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); widget.repo.heart.cancel(notify: false); widget.repo.live.setVisible(false); scrub.dispose(); super.dispose(); }

  void _open(List<MetricSpec> s, String k) => Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 350),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: MetricDetailPage(widget.repo, s, k))));

  String _summary(Day d, VigorRepo r) {
    final p = <String>[];
    final steps = d.steps.round(); if (steps > 0) p.add('${steps.toString()} pasos');
    final hr = statsOf(d.hr); if (hr != null) p.add('pulso medio ${hr.avg.round()} bpm');
    final ox = statsOf(d.spo2); if (ox != null) p.add('SpO₂ ${ox.avg.round()} %');
    return p.isEmpty ? 'Sin datos registrados este día.' : p.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = widget.repo; final keys = r.dayKeys;
    if (keys.isEmpty) {
      return EmptyState(Icons.watch_outlined, r.conn == 'connected' ? 'Sincronizando… aún no hay datos guardados.' : 'Conecta la pulsera para ver tus datos.',
          action: FilledButton(
              onPressed: r.conn == 'connected' ? r.sync : (r.savedMac != null ? r.connectSaved : () => showFindBandSheet(context, r)),
              child: Text(r.conn == 'connected' ? 'Sincronizar' : (r.savedMac != null ? 'Conectar' : 'Buscar pulsera'))));
    }
    final k = (key != null && keys.contains(key)) ? key! : keys.last;
    final d = r.days[k]!; final isLast = k == keys.last;
    final now = DateTime.now(); final isToday = k == '${now.year}-${two(now.month)}-${two(now.day)}';
    final steps = isLast && isToday && r.liveSteps > d.steps ? r.liveSteps : d.steps;
    return RefreshIndicator(onRefresh: () async { await r.sync(); }, child: ListView(physics: lock ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
      Row(children: [Expanded(child: Text(_summary(d, r), style: VT.body(c).copyWith(color: c.muted))),
        PopupMenuButton<String>(tooltip: 'Opciones del día', constraints: const BoxConstraints(minWidth: 48), icon: const Icon(Icons.more_vert), onSelected: (_) => confirmAndDelete(context, r, type: 'day', keys: [k], title: 'Borrar los datos de este día', what: 'Se borrarán pasos, pulso, SpO₂, variabilidad y temperatura del $k. El sueño y los ejercicios se borran por separado.'),
          itemBuilder: (_) => [PopupMenuItem(value: 'del', height: 48, child: Text('Borrar los datos de este día', style: TextStyle(color: c.danger)))]),
      ]),
      Semantics(liveRegion: false, child: Text(r.syncing ? 'Sincronizando…' : syncAgoText(r.lastSync, r.clock()), style: VT.caption(c))),
      const SizedBox(height: Sp.x3),
      _ribbon(c, r, keys, k),
      const SizedBox(height: Sp.x3),
      _dialCard(c, r, d, steps, isToday),
      const SizedBox(height: Sp.x3),
      LayoutBuilder(builder: (context, bc) {
        final w = (bc.maxWidth - Sp.x3) / 2;
        return Wrap(spacing: Sp.x3, runSpacing: Sp.x3, children: [
          _hrTile(c, r, d, k, w), _spo2Tile(c, d, k, w),
          _stressTile(c, d, k, w), _metTile(c, d, k, w),
          _hrvTile(c, r, d, k, w), _tempTile(c, r, d, k, w),
          _moveTile(c, r, d, steps, k, bc.maxWidth),
        ]);
      }),
      const SizedBox(height: Sp.x4),
      if (r.showExperimental) _experimental(c, d, k),
      if (r.ageIsDefault && d.hr.isNotEmpty) Note('Edad no indicada: el color del resplandor inferior usa la FCmáx de ${VigorRepo.defaultAge} años por defecto. Indica tu edad en Dispositivo → Perfil.'),
      const Note('Fuentes y límites de cada análisis: docs/ANALISIS.md'),
    ]));
  }

  /// E1: tres estados también en la tesela: cifra / "Sin datos suficientes" (hay registros pero ninguno válido) / "Sin datos" (sin registros).
  String _nd(Day d, String id) => d.qOf(id).raw > 0 ? 'Sin datos suficientes' : 'Sin datos';
  /// N2: el punto de "pocos datos" solo aplica a métricas continuas; SpO₂ y HRV se miden por tandas (sobre todo de noche) y su cobertura vive en el pie del detalle.
  bool _poor(Day d, String id) => id != 'spo2' && id != 'hrv' && d.qOf(id).poor;
  /// N2: "hoy" solo en el día en curso.
  String _poorLbl(String k) { final n = widget.repo.clock(); return k == '${n.year}-${two(n.month)}-${two(n.day)}' ? 'Pocos datos hoy' : 'Pocos datos este día'; }

  static const _wd = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _wl = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _mo = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  DateTime _dt(String k) => DateTime(int.parse(k.substring(0, 4)), int.parse(k.substring(5, 7)), int.parse(k.substring(8)));
  String _label(String k) {
    final n = widget.repo.clock(); final t = DateTime(n.year, n.month, n.day); final d = _dt(k);
    final diff = t.difference(d).inDays;
    if (diff == 0) return 'Hoy'; if (diff == 1) return 'Ayer';
    return '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';
  }

  void _go(String k) => setState(() { key = k; scrub.value = null; });

  Widget _ribbon(VC c, VigorRepo r, List<String> keys, String sel) {
    final i = keys.indexOf(sel);
    final last = keys.length > 14 ? keys.sublist(keys.length - 14) : keys;
    final prev = i > 0 ? keys[i - 1] : null, next = i < keys.length - 1 ? keys[i + 1] : null;
    final rm = reduceMotion(context);
    return Column(children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (e) { final v = e.primaryVelocity ?? 0; if (v > 200 && prev != null) _go(prev); if (v < -200 && next != null) _go(next); },
        child: Row(children: [
          IconButton(tooltip: 'Día anterior', onPressed: prev == null ? null : () => _go(prev), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: AnimatedSwitcher(duration: rm ? Duration.zero : const Duration(milliseconds: 200),
            child: Column(key: ValueKey(sel), mainAxisSize: MainAxisSize.min, children: [
              Text(_label(sel), style: VT.heading(c)),
              Text('${_dt(sel).day} de ${_mo[_dt(sel).month - 1]} de ${_dt(sel).year}', style: VT.caption(c)),
            ]))),
          IconButton(tooltip: 'Día siguiente', onPressed: next == null ? null : () => _go(next), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
      ),
      const SizedBox(height: Sp.x2),
      SizedBox(height: 96, child: Center(child: ListView(scrollDirection: Axis.horizontal, reverse: true, shrinkWrap: true, children: [
        for (final k in last.reversed) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Semantics(button: true, selected: k == sel, label: '${_label(k)}: ${r.days[k]!.steps.round()} pasos, ${(r.days[k]!.steps / r.stepGoal * 100).round()} % de la meta', child: InkWell(
          borderRadius: BorderRadius.circular(32), onTap: () => _go(k),
          child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 52, minHeight: 88), child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            Text(_wl[_dt(k).weekday - 1], style: VT.caption(c).copyWith(color: k == sel ? c.text : c.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SizedBox(height: 58, child: Center(child: LiquidDay(fill: r.days[k]!.steps / r.stepGoal, size: k == sel ? 56 : 46, liquid: c.steps, track: c.surfaceHi, textColor: c.text, label: '${_dt(k).day}', selected: k == sel, animate: k == sel))),
          ])),
        ))),
      ]))),
    ]);
  }

  Widget _dialCard(VC c, VigorRepo r, Day d, double steps, bool isToday) {
    final mix = mixDay(day: d, nights: r.nights, sessions: r.sessions, hrMax: hrMaxTanaka(r.age));
    final kinds = [for (final m in mix) m.kind];
    return Glass(glow: c.accent, padding: const EdgeInsets.all(Sp.x4), child: Column(children: [
      Stack(alignment: Alignment.center, children: [
        ValueListenableBuilder<double?>(valueListenable: scrub, builder: (_, m, _) => DayDial(day: d, c: c, scrubMin: m, nowMin: isToday ? minutesOf(DateTime.now()) : null, onScrub: (v) => scrub.value = v, mix: mix, onLock: (v) { if (v != lock) setState(() => lock = v); })),
        Column(mainAxisSize: MainAxisSize.min, children: [
          IgnorePointer(child: Semantics(container: true, label: 'Pasos: ${steps.round()} de ${r.stepGoal}', child: ExcludeSemantics(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('PASOS', style: VT.caption(c).copyWith(letterSpacing: 1.6, fontWeight: FontWeight.w700)),
            CountUp(steps, (v) => v.round().toString(), VT.display(c).copyWith(fontSize: 46)),
            Text('de ${r.stepGoal}', style: VT.caption(c)),
          ])))),
          const SizedBox(height: Sp.x2),
          HeartCenter(repo: r, lastRecord: d.hr.isEmpty ? null : d.hr.last, canMeasure: isToday),
        ]),
      ]),
      const SizedBox(height: Sp.x2),
      DayKindLegend(kinds),
      const SizedBox(height: Sp.x2),
      ValueListenableBuilder<double?>(valueListenable: scrub, builder: (_, m, _) => m == null
          ? Text('Toca y arrastra por los anillos para ver tu día minuto a minuto · doble toque para soltar', textAlign: TextAlign.center, style: VT.caption(c))
          : _readout(c, d, m, kinds)),
      TextButton.icon(onPressed: () => _slots(c, d), icon: const Icon(Icons.view_list_outlined, size: 18), label: const Text('Ver datos del día por franjas')),
    ]));
  }

  /// Alternativa accesible (y sin gestos) al reloj: tabla por horas.
  void _slots(VC c, Day d) {
    final rows = <Widget>[];
    for (var h = 0; h < 24; h++) {
      bool inH(Sample s) => s.t.hour == h;
      final steps = d.steps5.where(inH).fold<double>(0, (a, e) => a + e.v);
      final hr = statsOf(d.hr.where(inH).toList()); final ox = statsOf(d.spo2.where(inH).toList());
      if (steps == 0 && hr == null && ox == null) continue;
      final txt = '${two(h)}:00–${two(h + 1 == 24 ? 0 : h + 1)}:00 · ${steps.round()} pasos${hr == null ? '' : ' · pulso mín ${hr.min.round()}, media ${hr.avg.round()}, máx ${hr.max.round()}'}${ox == null ? '' : ' · SpO₂ ${ox.avg.round()} %'}';
      rows.add(Semantics(container: true, label: txt, child: ExcludeSemantics(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(txt, style: VT.body(c))))));
    }
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SafeArea(child: ListView(padding: const EdgeInsets.all(Sp.x4), shrinkWrap: true, children: [
      Text('Datos del día por franjas de 1 h', style: VT.heading(c)), const SizedBox(height: Sp.x2),
      if (rows.isEmpty) Text('Sin datos este día.', style: VT.body(c)) else ...rows,
    ])));
  }

  Widget _readout(VC c, Day d, double m, List<DayKind> kinds) {
    final h = m ~/ 60, mi = (m % 60).round();
    Widget chip(MetricSpec s, List<Sample> l, double within) {
      final e = nearest(l, m, within: within); final col = s.color(c);
      final txt = e == null ? '—' : '${fmtNum(e.v, s.decimals)} ${s.unit}'.trim();
      return Semantics(container: true, label: '${s.label}: ${e == null ? 'sin dato' : txt}', child: ExcludeSemantics(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: col.withValues(alpha: e == null ? .06 : .16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(s.icon, size: 14, color: col), const SizedBox(width: 4), Text(txt, style: VT.caption(c).copyWith(color: c.text, fontWeight: FontWeight.w600))]))));
    }
    final bin = d.steps5.where((e) => e.t.hour * 2 + e.t.minute ~/ 30 == m ~/ 30).fold<double>(0, (a, e) => a + e.v);
    return Column(children: [
      Semantics(liveRegion: true, child: Text('${two(h)}:${two(mi)} · ${dayKindLabel(kinds[(m ~/ 30).clamp(0, 47)])}', style: VT.heading(c))), const SizedBox(height: Sp.x2),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        chip(kHr, d.hr, 6), chip(kSpo2, d.spo2, 8), chip(kHrv, d.hrv, 8), chip(kStress, d.stress, 20), chip(kMet, d.met, 8), chip(kTemp, d.temp, 20),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: c.steps.withValues(alpha: .16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_walk, size: 14, color: c.steps), const SizedBox(width: 4), Text('${bin.round()} pasos/30 min', style: VT.caption(c).copyWith(color: c.text, fontWeight: FontWeight.w600))])),
      ]),
    ]);
  }

  Widget _hrTile(VC c, VigorRepo r, Day d, String k, double w) {
    final v = d.hr.map((e) => e.v).toList(); final last = v.isEmpty ? null : v.last;
    final hs = statsOf(d.hr); return BentoTile(spec: kHr, poorData: _poor(d, 'hr'), poorLabel: _poorLbl(k), semanticLabel: hs == null ? 'Pulso: ${_nd(d, 'hr').toLowerCase()}' : 'Pulso: último ${last!.round()} latidos por minuto, mín ${hs.min.round()}, media ${hs.avg.round()}, máx ${hs.max.round()}. Abrir detalle', width: w, minHeight: 122, onTap: () => _open([kHr], k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (last == null) Text(_nd(d, 'hr'), style: VT.body(c).copyWith(color: c.muted)) else Row(crossAxisAlignment: CrossAxisAlignment.end, children: [CountUp(last, (x) => x.round().toString(), VT.display(c).copyWith(fontSize: 34)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('bpm', style: VT.caption(c)))]),
      const SizedBox(height: Sp.x2), SizedBox(height: 44, child: CustomPaint(size: Size.infinite, painter: SparkPainter(v.length > 90 ? v.sublist(v.length - 90) : v, c.heart))),
      Builder(builder: (_) {
        final nh = r.nightHr(k); final rest = restingHrApprox(d.hrValues);
        return Text(nh.state == NightState.data ? 'reposo nocturno aprox. ${nh.value!.round()}${r.nightInProgress(k) ? ' (en curso)' : ''}' : rest == null ? 'último valor' : 'reposo aprox., todo el día: ${rest.round()}', style: VT.caption(c));
      }),
    ]));
  }

  Widget _spo2Tile(VC c, Day d, String k, double w) {
    final st = statsOf(d.spo2); final v = d.spo2.map((e) => e.v).toList();
    return BentoTile(spec: kSpo2, poorData: _poor(d, 'spo2'), poorLabel: _poorLbl(k), semanticLabel: st == null ? 'Oxígeno en sangre: ${_nd(d, 'spo2').toLowerCase()}' : 'Oxígeno en sangre: media ${st.avg.round()} %, mínimo ${st.min.round()} %. Abrir detalle', width: w, minHeight: 122, onTap: () => _open([kSpo2], k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (st == null) Text(_nd(d, 'spo2'), style: VT.body(c).copyWith(color: c.muted)) else Row(crossAxisAlignment: CrossAxisAlignment.end, children: [CountUp(st.avg, (x) => x.round().toString(), VT.display(c).copyWith(fontSize: 34)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('%', style: VT.caption(c)))]),
      const SizedBox(height: Sp.x2), SizedBox(height: 44, child: CustomPaint(size: Size.infinite, painter: SparkPainter(v.length > 90 ? v.sublist(v.length - 90) : v, c.spo2, lo0: 90, hi0: 100))),
      Text(st == null ? '' : 'media · mín ${st.min.round()} %', style: VT.caption(c)),
    ]));
  }

  Widget _stressTile(VC c, Day d, String k, double w) {
    final st = statsOf(d.stress); final last = d.stress.isEmpty ? null : d.stress.last.v;
    return BentoTile(spec: kStress, poorData: _poor(d, 'stress'), poorLabel: _poorLbl(k), semanticLabel: last == null ? 'Estrés: ${_nd(d, 'stress').toLowerCase()}' : 'Estrés: índice del fabricante, aproximado, ${last.round()} de 100${st == null ? '' : ', media ${st.avg.round()}'}. Abrir detalle', width: w, minHeight: 122, onTap: () => _open([kStress], k), child: Column(children: [
      SizedBox(height: 64, child: Stack(alignment: Alignment.bottomCenter, children: [
        CustomPaint(size: Size.infinite, painter: GaugePainter((last ?? 0) / 100, c.stress, c.surfaceHi)),
        if (last != null) CountUp(last, (x) => x.round().toString(), VT.display(c).copyWith(fontSize: 26)) else Text('—', style: VT.heading(c)),
      ])),
      const SizedBox(height: Sp.x1), Text(st == null ? _nd(d, 'stress').toLowerCase() : 'índice 0–100 · media ${st.avg.round()}', style: VT.caption(c)),
      Text('índice del fabricante · aprox.', style: VT.caption(c)),
    ]));
  }

  Widget _metTile(VC c, Day d, String k, double w) {
    final v = d.met.map((e) => e.v).toList(); final last = v.isEmpty ? null : v.last;
    return BentoTile(spec: kMet, poorData: _poor(d, 'met'), poorLabel: _poorLbl(k), semanticLabel: last == null ? 'Actividad MET: ${_nd(d, 'met').toLowerCase()}' : 'Actividad MET: última lectura ${last.toStringAsFixed(1)}. Abrir detalle', width: w, minHeight: 122, onTap: () => _open([kMet], k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (last == null) Text(_nd(d, 'met'), style: VT.body(c).copyWith(color: c.muted)) else Row(crossAxisAlignment: CrossAxisAlignment.end, children: [CountUp(last, (x) => x.toStringAsFixed(1), VT.display(c).copyWith(fontSize: 34)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('MET', style: VT.caption(c)))]),
      const SizedBox(height: Sp.x2), SizedBox(height: 44, child: CustomPaint(size: Size.infinite, painter: BarPainter(v.length > 18 ? v.sublist(v.length - 18) : v, c.met, c.surfaceHi))),
      Text('últimas lecturas', style: VT.caption(c)),
    ]));
  }

  Widget _hrvTile(VC c, VigorRepo r, Day d, String k, double w) {
    final night = r.nightHrv(k); final dayMed = median(d.hrv.map((e) => e.v).toList()); final nb = r.nightBase(k, r.nightHrv);
    final hasNight = night.state == NightState.data; final med = hasNight ? night.value : dayMed;
    final byHour = <int, List<double>>{}; for (final e in d.hrv) { byHour.putIfAbsent(e.t.hour, () => []).add(e.v); }
    final line = [for (final h in (byHour.keys.toList()..sort())) median(byHour[h]!)!];
    final cap = med == null ? '' : hasNight ? (nb.base == null ? 'noche${r.nightInProgress(k) ? ' (en curso)' : ''} · PPG, aprox.' : 'noche${r.nightInProgress(k) ? ' (en curso)' : ''} · PPG, aprox. · ${med >= nb.base! ? '+' : '−'}${(med - nb.base!).abs().round()} vs tu mediana') : 'todo el día · PPG, aprox.';
    return BentoTile(spec: kHrv, poorData: _poor(d, 'hrv'), poorLabel: _poorLbl(k), semanticLabel: med == null ? 'Variabilidad cardíaca: ${_nd(d, 'hrv').toLowerCase()}' : 'Variabilidad cardíaca RMSSD ${hasNight ? 'nocturna' : 'de todo el día'}, aproximada con luz en la muñeca: ${med.round()} milisegundos. Abrir detalle', width: w, minHeight: 122, onTap: () => _open([kHrv], k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (med == null) Text(_nd(d, 'hrv'), style: VT.body(c).copyWith(color: c.muted)) else Row(crossAxisAlignment: CrossAxisAlignment.end, children: [CountUp(med, (x) => x.round().toString(), VT.display(c).copyWith(fontSize: 34)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('ms', style: VT.caption(c)))]),
      const SizedBox(height: Sp.x2), SizedBox(height: 44, child: CustomPaint(size: Size.infinite, painter: SparkPainter(line, c.hrv))),
      Text(cap, style: VT.caption(c)),
    ]));
  }

  Widget _tempTile(VC c, VigorRepo r, Day d, String k, double w) {
    final last = d.temp.isEmpty ? null : d.temp.last.v; final skin = d.skin.isEmpty ? null : d.skin.last.v;
    final st = statsOf(d.temp); final base = baselineOf(r, kTemp, k);
    return BentoTile(spec: kTemp, poorData: _poor(d, 'temp'), poorLabel: _poorLbl(k), semanticLabel: last == null ? 'Temperatura: ${_nd(d, 'temp').toLowerCase()}' : 'Temperatura: ${last.toStringAsFixed(1)} grados${skin == null ? '' : ', piel ${skin.toStringAsFixed(1)}'}. Abrir detalle', width: w, minHeight: 122, onTap: () => _open([kTemp, kSkin], k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (last == null) Text(_nd(d, 'temp'), style: VT.body(c).copyWith(color: c.muted)) else Row(crossAxisAlignment: CrossAxisAlignment.end, children: [CountUp(last, (x) => x.toStringAsFixed(1), VT.display(c).copyWith(fontSize: 34)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('°C', style: VT.caption(c)))]),
      const SizedBox(height: Sp.x2), SizedBox(height: 44, child: CustomPaint(size: Size.infinite, painter: SparkPainter(d.temp.map((e) => e.v).toList(), c.temp))),
      Text(skin == null ? 'muñeca' : 'piel ${skin.toStringAsFixed(1)} °C${st != null && base != null ? ' · ${st.avg >= base ? '+' : ''}${(st.avg - base).toStringAsFixed(1)} vs tu media' : ''}', style: VT.caption(c)),
    ]));
  }

  Widget _moveTile(VC c, VigorRepo r, Day d, double steps, String k, double w) => BentoTile(spec: kSteps, semanticLabel: 'Movimiento: ${steps.round()} pasos, ${d.km.toStringAsFixed(2)} kilómetros, ${d.kcal.round()} kilocalorías aproximadas, ${(steps / r.stepGoal * 100).round()} % de la meta. Abrir detalle', width: w, onTap: () => _open([kSteps], k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Stat('Distancia', '${d.km.toStringAsFixed(2)} km')), Expanded(child: Stat('Calorías aprox.', '${d.kcal.round()} kcal')), Expanded(child: Stat('Meta', '${(steps / r.stepGoal * 100).round()} %')),
        ]),
        const SizedBox(height: Sp.x3),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (steps / r.stepGoal).clamp(0, 1), minHeight: 8, backgroundColor: c.surfaceHi, color: c.steps)),
      ]));

  Widget _experimental(VC c, Day d, String k) {
    final lastGlu = d.glucose.isEmpty ? null : d.glucose.last; final blood = d.blood.isEmpty ? null : d.blood.last;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(borderRadius: BorderRadius.circular(16), onTap: () => setState(() => expOpen = !expOpen), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Row(children: [
        Icon(Icons.science_outlined, size: 18, color: c.exp), const SizedBox(width: Sp.x2),
        Expanded(child: Text('Experimental · no fiable', style: VT.heading(c).copyWith(color: c.muted))), Icon(expOpen ? Icons.expand_less : Icons.expand_more, color: c.muted),
      ]))),
      if (expOpen) ...[
        const ExperimentalBanner(),
        BentoTile(spec: kGlucose, onTap: () => _open([kGlucose], k), width: double.infinity, child: Row(children: [
          Expanded(child: lastGlu == null ? Text('Sin datos', style: VT.body(c).copyWith(color: c.muted)) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(lastGlu.v.toStringAsFixed(2), style: VT.display(c).copyWith(fontSize: 30, color: c.exp)), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('mmol/L (est.)', style: VT.caption(c)))]),
            Text('a las ${hm(lastGlu.t)}', style: VT.caption(c)),
          ])),
          SizedBox(width: 110, height: 44, child: CustomPaint(painter: SparkPainter(d.glucose.map((e) => e.v).toList(), c.exp))),
        ])),
        const SizedBox(height: Sp.x3),
        Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.biotech_outlined, size: 16, color: c.exp), const SizedBox(width: 6), Text('Componentes sanguíneos (est.)', style: VT.caption(c).copyWith(fontWeight: FontWeight.w600))]),
          const SizedBox(height: Sp.x2),
          if (blood == null) Text('Sin datos', style: VT.body(c).copyWith(color: c.muted)) else Wrap(spacing: Sp.x6, runSpacing: Sp.x2, children: [
            Stat('Ácido úrico', '${_f(blood.$2['uricAcid'], 0)} µmol/L'), Stat('Colesterol total', '${_f(blood.$2['tCHO'], 2)} mmol/L'), Stat('Triglicéridos', '${_f(blood.$2['tAG'], 2)} mmol/L'),
            Stat('HDL', '${_f(blood.$2['hDL'], 2)} mmol/L'), Stat('LDL', '${_f(blood.$2['lDL'], 2)} mmol/L'),
          ]),
          if (blood != null) Note('Lectura de las ${hm(blood.$1)}. Sin rangos ni interpretación a propósito.'),
        ])),
      ],
    ]);
  }

  String _f(dynamic v, int dec) => v is num ? v.toStringAsFixed(dec) : '—';
}


/// Hoja de búsqueda de pulsera: escanea, lista lo encontrado y conecta al tocar. Detiene la búsqueda al cerrarse.
Future<void> showFindBandSheet(BuildContext context, VigorRepo r) async {
  r.scan();
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => ListenableBuilder(listenable: r, builder: (ctx, _) {
    final c = VC.of(ctx); final found = r.found.values.toList();
    return SafeArea(child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7), child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x4), children: [
      Text('Buscar pulsera', style: VT.heading(c)),
      const SizedBox(height: Sp.x2),
      Semantics(liveRegion: true, child: Text(
        r.conn == 'connecting' ? 'Conectando…' : r.conn == 'connected' ? 'Conectada.' : found.isEmpty ? (r.conn == 'scanning' ? 'Buscando pulseras cercanas…' : (r.logs.isNotEmpty ? r.logs.first : 'No se ha encontrado ninguna pulsera.')) : 'Toca tu pulsera para conectar:',
        style: VT.body(c).copyWith(color: c.muted))),
      const SizedBox(height: Sp.x2),
      if (r.conn == 'scanning' && found.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: Sp.x3), child: LinearProgressIndicator()),
      for (final d in found) Padding(padding: const EdgeInsets.only(bottom: Sp.x2), child: Glass(padding: EdgeInsets.zero, child: ListTile(
        minVerticalPadding: 12,
        leading: const Icon(Icons.watch_outlined),
        title: Text(d['name'].toString().isEmpty ? '(sin nombre)' : d['name'].toString()),
        subtitle: Text('${maskMac(d['mac']?.toString())} · ${d['rssi']} dBm'),
        onTap: () async { await r.connect(d['mac'].toString()); if (ctx.mounted) Navigator.of(ctx).pop(); }))),
      if (r.conn != 'scanning' && r.conn != 'connecting') Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: r.scan, icon: const Icon(Icons.refresh), label: const Text('Buscar de nuevo'))),
      const Note('Acerca la pulsera al móvil y activa el Bluetooth. En Android 11 o anterior hace falta tener la ubicación activada solo para esta búsqueda.'),
    ])));
  }));
  try { await r.stopScan(); } catch (_) {}
}
