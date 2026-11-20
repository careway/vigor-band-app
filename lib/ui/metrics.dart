import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'charts.dart';
import 'fx.dart';
import 'night_cards.dart';
import 'widgets.dart';

Color _cHr(VC c) => c.heart; Color _cSpo2(VC c) => c.spo2; Color _cHrv(VC c) => c.hrv; Color _cStress(VC c) => c.stress;
Color _cMet(VC c) => c.met; Color _cTemp(VC c) => c.temp; Color _cSteps(VC c) => c.steps; Color _cExp(VC c) => c.exp;
List<Sample> _hr(Day d) => d.hr; List<Sample> _spo2(Day d) => d.spo2; List<Sample> _hrv(Day d) => d.hrv; List<Sample> _stress(Day d) => d.stress;
List<Sample> _met(Day d) => d.met; List<Sample> _temp(Day d) => d.temp; List<Sample> _skin(Day d) => d.skin; List<Sample> _glu(Day d) => d.glucose; List<Sample> _steps(Day d) => d.steps5;

class MetricSpec {
  final String id, label, unit, note; final IconData icon; final Color Function(VC) color; final List<Sample> Function(Day) series;
  final int decimals; final double? minY, maxY; final bool experimental, bars; final String? q; // q = clave de calidad en Day.q (E1)
  const MetricSpec(this.id, this.label, this.unit, this.icon, this.color, this.series, this.note, {this.decimals = 0, this.minY, this.maxY, this.experimental = false, this.bars = false, this.q});
}

const kHr = MetricSpec('hr', 'Pulso', 'bpm', Icons.favorite, _cHr, _hr, 'Lecturas del sensor óptico de la pulsera (se supone una por minuto; no verificado). El pulso en reposo es una estimación propia («aprox.», sin validar): de noche, la mediana de las 30 lecturas más bajas de 00:00 a 06:00; de respaldo, la media del 10 % más bajo del día.', q: 'hr');
const kSpo2 = MetricSpec('spo2', 'Oxígeno en sangre (SpO₂)', '%', Icons.air, _cSpo2, _spo2, 'Tendencia orientativa de una pulsera de muñeca (menor perfusión y más ruido que en el dedo). No sustituye a un oxímetro médico ni emite alertas. Las lecturas por debajo de 70 % se descartan (filtro propio). Ver docs/ANALISIS.md §6.', minY: 85, maxY: 100, q: 'spo2');
const kHrv = MetricSpec('hrv', 'Variabilidad del pulso', 'ms', Icons.monitor_heart_outlined, _cHrv, _hrv, 'Variabilidad del pulso (PPG, aprox.): RMSSD que calcula la app con los intervalos RR de la pulsera; con luz en la muñeca tiende a dar valores más bajos que el ECG (un estudio de otro dispositivo). Los valores de distinta duración no son intercambiables (Shaffer & Ginsberg 2017) y no se compara con tablas poblacionales: solo contigo mismo.', q: 'hrv');
const kStress = MetricSpec('stress', 'Estrés (índice)', '', Icons.bolt, _cStress, _stress, 'Índice 0–100 del fabricante; el SDK no documenta su algoritmo. Las revisiones indican que el estrés por HRV en relojes de consumo tiene precisión pobre (Hickey 2021): úsalo solo como tendencia relativa, sin categorías.', minY: 0, maxY: 100, q: 'stress');
const kMet = MetricSpec('met', 'Energía (MET)', 'MET', Icons.local_fire_department, _cMet, _met, 'MET del fabricante (algoritmo no documentado ni validado). 1 MET ≈ reposo sentado (≈ 3,5 mL O₂/kg/min; definición de fuente secundaria). Aquí no se clasifica por intensidad; solo el cómputo semanal de Actividad usa el corte de la OMS (≥ 3 MET), con rótulo «aprox.».', decimals: 1, minY: 0, q: 'met');
const kTemp = MetricSpec('temp', 'Temperatura corporal', '°C', Icons.thermostat, _cTemp, _temp, 'Valor de muñeca, poco exacto en términos absolutos: un dispositivo de muñeca de otro modelo (Yeh 2021) tuvo un sesgo de ≈ 1,5 °C frente a un termómetro de piel y su acuerdo dependió de la temperatura ambiente. No hay validación de esta pulsera. Se interpreta solo frente a tu propia media; sin umbrales de fiebre.', decimals: 1, q: 'temp');
const kSkin = MetricSpec('skin', 'Temperatura de la piel', '°C', Icons.back_hand_outlined, _cTemp, _skin, 'Temperatura superficial en la muñeca; depende mucho del ambiente. Sin validación de esta pulsera.', decimals: 1, q: 'skin');
const kSteps = MetricSpec('steps', 'Pasos', 'pasos', Icons.directions_walk, _cSteps, _steps, 'Pasos por franja de 30 min.', bars: true);
const kGlucose = MetricSpec('glu', 'Glucosa (estimación)', 'mmol/L', Icons.water_drop_outlined, _cExp, _glu, 'EXPERIMENTAL. La FDA (21‑02‑2024) no ha autorizado ningún reloj ni anillo para medir glucosa sin pinchar la piel y recomienda no usarlos. No tomes decisiones médicas con este valor.', decimals: 2, experimental: true);

({double min, double avg, double max})? statsOf(List<Sample> l) {
  if (l.isEmpty) return null;
  var mn = l.first.v, mx = l.first.v, sum = 0.0;
  for (final s in l) { if (s.v < mn) mn = s.v; if (s.v > mx) mx = s.v; sum += s.v; }
  return (min: mn, avg: sum / l.length, max: mx);
}

/// Media habitual: mediana de las medias de los días anteriores (hasta 14). Null con < 3 días.
double? baselineOf(VigorRepo r, MetricSpec s, String dayKey) {
  final keys = r.dayKeys; final pos = keys.indexOf(dayKey);
  final prev = <double>[];
  for (var k = (pos - 14).clamp(0, keys.length); k < pos; k++) { final st = statsOf(s.series(r.days[keys[k]]!)); if (st != null) prev.add(st.avg); }
  return prev.length >= 3 ? median(prev) : null;
}

String fmtNum(double v, int dec) => v.toStringAsFixed(dec);

/// Aviso permanente de métricas experimentales.
class ExperimentalBanner extends StatelessWidget {
  const ExperimentalBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return Container(
      padding: const EdgeInsets.all(Sp.x3), margin: const EdgeInsets.only(bottom: Sp.x3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: c.exp.withValues(alpha: .14), border: Border.all(color: c.exp.withValues(alpha: .4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.science_outlined, color: c.exp, size: 20), const SizedBox(width: Sp.x3),
        Expanded(child: Text('Estimaciones experimentales del fabricante. La FDA (2024) no ha autorizado ningún reloj o anillo para medir glucosa sin pinchar la piel y recomienda no usarlos; para los componentes sanguíneos no hay validación en muñeca. No las uses para decidir medicación ni tratamientos.', style: VT.caption(c).copyWith(color: c.text))),
      ]),
    );
  }
}

/// Tesela del "bento": se abre con transición Hero.
class BentoTile extends StatelessWidget {
  final MetricSpec spec; final Widget child; final VoidCallback? onTap; final double? width; final double minHeight; final String? semanticLabel; final bool poorData; final String poorLabel;
  const BentoTile({super.key, required this.spec, required this.child, this.onTap, this.width, this.minHeight = 0, this.semanticLabel, this.poorData = false, this.poorLabel = 'Pocos datos hoy'});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final col = spec.color(c);
    final tile = Hero(tag: 'tile-${spec.id}', child: Material(type: MaterialType.transparency, child: InkWell(
      borderRadius: BorderRadius.circular(24), onTap: onTap,
      child: Glass(glow: col, padding: const EdgeInsets.all(Sp.x4), child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(spec.icon, size: 16, color: col), const SizedBox(width: 6), Expanded(child: Text(spec.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: VT.caption(c).copyWith(fontWeight: FontWeight.w600))),
          if (poorData) Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.muted, width: 1.5)))]),
        const SizedBox(height: Sp.x3), child,
      ]))))));
    return SizedBox(width: width, child: semanticLabel == null ? tile : Semantics(container: true, button: onTap != null, label: poorData ? '$semanticLabel. $poorLabel' : semanticLabel, child: ExcludeSemantics(child: tile)));
  }
}

/// Detalle: una o varias series de 24 h con cursor táctil, mín/media/máx y media habitual.
class MetricDetailPage extends StatefulWidget {
  final VigorRepo repo; final List<MetricSpec> specs; final String dayKey;
  const MetricDetailPage(this.repo, this.specs, this.dayKey, {super.key});
  @override
  State<MetricDetailPage> createState() => _MetricDetailState();
}

class _MetricDetailState extends State<MetricDetailPage> {
  late String key = widget.dayKey;
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = widget.repo; final keys = r.dayKeys; final i = keys.indexOf(key);
    final first = widget.specs.first;
    return Scaffold(
      appBar: AppBar(title: Text(first.label)),
      body: Aurora(tint: first.color(c), child: SafeArea(child: ListView(padding: const EdgeInsets.all(Sp.x4), children: [
        Row(children: [
          IconButton(tooltip: 'Día anterior', onPressed: i > 0 ? () => setState(() => key = keys[i - 1]) : null, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(key, textAlign: TextAlign.center, style: VT.heading(c))),
          IconButton(tooltip: 'Día siguiente', onPressed: i < keys.length - 1 ? () => setState(() => key = keys[i + 1]) : null, icon: const Icon(Icons.chevron_right)),
        ]),
        if (first.experimental) const ExperimentalBanner(),
        if (first.id == 'hr' && !first.experimental) RestingNightCard(r, key),
        if (first.id == 'hrv') HrvNightCard(r, key),
        for (var n = 0; n < widget.specs.length; n++) _section(context, c, r, widget.specs[n], n == 0),
        Note('Fuentes y límites: docs/ANALISIS.md'),
      ]))),
    );
  }

  Widget _section(BuildContext context, VC c, VigorRepo r, MetricSpec s, bool hero) {
    final day = r.days[key]; final data = day == null ? <Sample>[] : s.series(day); final col = s.color(c);
    final st = statsOf(data); final base = baselineOf(r, s, key);
    final body = Glass(glow: col, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(s.icon, size: 18, color: col), const SizedBox(width: Sp.x2), Expanded(child: Text(s.id == 'hrv' ? '${s.label} · todo el día (aprox.)' : s.label, style: VT.heading(c)))]),
      const SizedBox(height: Sp.x3),
      if (st != null && !s.bars) Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CountUp(st.avg, (v) => fmtNum(v, s.decimals), VT.display(c).copyWith(color: s.experimental ? c.text : c.text)), const SizedBox(width: Sp.x2),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${s.unit} · media del día', style: VT.caption(c))),
      ]),
      if (s.bars) Builder(builder: (_) { final tot = data.fold<double>(0, (a, e) => a + e.v); return CountUp(tot, (v) => v.round().toString(), VT.display(c)); }),
      const SizedBox(height: Sp.x3),
      TimeSeriesChart(data: data, color: col, unit: s.unit, decimals: s.decimals, minY: s.minY, maxY: s.maxY, bars: s.bars, name: s.label),
      if (st != null && !s.bars) ...[const SizedBox(height: Sp.x3), Row(children: [
        Expanded(child: Stat('Mínimo', '${fmtNum(st.min, s.decimals)} ${s.unit}')), Expanded(child: Stat('Media', '${fmtNum(st.avg, s.decimals)} ${s.unit}')), Expanded(child: Stat('Máximo', '${fmtNum(st.max, s.decimals)} ${s.unit}')),
      ])],
      if (st != null && base != null && !s.experimental) Note('Tu media habitual (hasta 14 días): ${fmtNum(base, s.decimals)} ${s.unit} · hoy ${st.avg >= base ? '+' : ''}${fmtNum(st.avg - base, s.decimals)}'),
      if (s.q != null && day != null && !s.experimental) CoverageCaption(day.qOf(s.q!), spo2: s.id == 'spo2'),
      Note(s.note),
    ]));
    return Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: hero ? Hero(tag: 'tile-${s.id}', child: Material(type: MaterialType.transparency, child: body)) : body);
  }
}
