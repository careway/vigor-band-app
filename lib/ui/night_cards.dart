import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/repo.dart';
import '../theme/tokens.dart';
import 'fx.dart';
import 'widgets.dart';

/// E1: texto de cobertura bajo el gráfico (con Semantics).
class CoverageCaption extends StatelessWidget {
  final Quality q; final bool spo2;
  const CoverageCaption(this.q, {super.key, this.spo2 = false});
  @override
  Widget build(BuildContext context) {
    if (q.raw == 0) return const SizedBox.shrink();
    final t = coverageText(q, spo2: spo2);
    return Semantics(container: true, label: t, child: ExcludeSemantics(child: Note(t)));
  }
}

String _signed(double v, {int dec = 0}) {
  final r = double.parse(v.toStringAsFixed(dec));
  final a = r.abs().toStringAsFixed(dec);
  return r > 0 ? '+$a' : r < 0 ? '−$a' : a;
}

/// Gráfico simple de las últimas noches (solo las que tienen valor). Semantics con el resumen.
class _NightTrend extends StatelessWidget {
  final List<(String, double?)> hist; final Color color; final String unit, name;
  const _NightTrend(this.hist, this.color, this.unit, this.name);
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    final pts = [for (var i = 0; i < hist.length; i++) if (hist[i].$2 != null) (i.toDouble(), hist[i].$2!)];
    if (pts.length < 2) return const SizedBox.shrink();
    final label = '$name, ${pts.length} noches con dato: de ${pts.first.$2.round()} a ${pts.last.$2.round()} $unit';
    return Semantics(container: true, label: label, child: ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: Sp.x3), child: SizedBox(height: 90,
      child: CustomPaint(size: Size.infinite, painter: LinePainter([for (final p in pts) p.$1], [for (final p in pts) p.$2], color, c.surfaceHi, c.muted))))));
  }
}

Widget _stateText(BuildContext context, NightStat n) {
  final c = VC.of(context);
  return Text(n.state == NightState.none ? 'Sin datos esta noche.' : n.insufficientText, style: VT.body(c).copyWith(color: c.muted));
}

/// E2: pulso en reposo nocturno + tendencia.
class RestingNightCard extends StatelessWidget {
  final VigorRepo repo; final String dayKey;
  const RestingNightCard(this.repo, this.dayKey, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final n = repo.nightHr(dayKey);
    final b = repo.nightBase(dayKey, repo.nightHr);
    String? trend;
    if (n.state == NightState.data) trend = b.base == null ? 'Aún sin línea base: ${b.k} de $kBaselineMinNights noches' : '${_signed(n.value! - b.base!)} lpm frente a tu mediana de ${b.k} noches';
    final main = n.state == NightState.data ? 'Pulso en reposo (noche, aprox.): ${n.value!.round()} lpm' : null;
    final prog = repo.nightInProgress(dayKey) && n.state != NightState.none;
    return Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: Glass(glow: c.heart, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricHeader(Icons.bedtime_outlined, 'Pulso en reposo nocturno (aprox.)', c.heart, trailing: const InfoButton('Pulso en reposo nocturno', 'Noche = 00:00–06:00 (aprox.). Estimado con las lecturas más bajas de ese tramo. Sirve para ver tu tendencia, no es una puntuación de recuperación ni un dato médico.')), const SizedBox(height: Sp.x3),
      if (main == null) _stateText(context, n) else Semantics(container: true, label: '$main. $trend${prog ? '. $nightInProgressText' : ''}', child: ExcludeSemantics(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BigValue(n.value!.round().toString(), 'lpm', size: 36), const SizedBox(height: Sp.x1), Text('Pulso en reposo (noche, aprox.)', style: VT.caption(c)),
        const SizedBox(height: Sp.x2), Text(trend!, style: VT.body(c)),
        if (prog) Padding(padding: const EdgeInsets.only(top: Sp.x1), child: Text(nightInProgressText, style: VT.caption(c))),
      ]))),
      if (n.state == NightState.data) _NightTrend(repo.nightHistory(dayKey, repo.nightHr), c.heart, 'lpm', 'Pulso en reposo nocturno'),
    ])));
  }
}

const hrvLowQualityText = 'Calidad baja: más del 5 % de las diferencias entre latidos se corrigieron o descartaron.';
const nightInProgressText = 'Noche en curso: el dato puede cambiar hasta las 06:00 y no entra en la línea base.';

const hrvLimitText = 'Variabilidad del pulso medida con luz en la muñeca (PPG), no HRV por ECG. Tiende a dar valores más bajos que el ECG. Útil solo para compararte contigo mismo; el alcohol, el sueño, la enfermedad y el estrés la modifican. Aprox.';

const hrvSampleText = 'Cada medición del SDK trae unos 10 latidos (≈ 10 s), una vez por minuto: el RMSSD es de ventana ultracorta. Los valores con RR «sin dato» (2550 ms) se ignoran.';

/// E3: HRV nocturna con línea base propia.
class HrvNightCard extends StatelessWidget {
  final VigorRepo repo; final String dayKey;
  const HrvNightCard(this.repo, this.dayKey, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final n = repo.nightHrv(dayKey);
    final b = repo.nightBase(dayKey, repo.nightHrv);
    final week = [for (final h in repo.nightHistory(dayKey, repo.nightHrv, n: 7)) if (h.$2 != null) h.$2!];
    final st = meanCv(week);
    String? cmp;
    if (n.state == NightState.data) cmp = b.base == null ? 'Aún sin línea base: ${b.k} de $kBaselineMinNights noches' : '${_signed(n.value! - b.base!)} ms frente a tu mediana de ${b.k} noches';
    final main = n.state == NightState.data ? 'Variabilidad nocturna (aprox.): ${n.value!.round()} ms' : null;
    final prog = repo.nightInProgress(dayKey) && n.state != NightState.none;
    return Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: Glass(glow: c.hrv, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricHeader(Icons.monitor_heart_outlined, 'Variabilidad nocturna (PPG, aprox.)', c.hrv, trailing: const InfoButton('Variabilidad nocturna', 'Noche = 00:00–06:00 (aprox.). $hrvLimitText $hrvSampleText')), const SizedBox(height: Sp.x3),
      if (main == null) _stateText(context, n) else Semantics(container: true, label: '$main. $cmp${n.lowQuality ? '. $hrvLowQualityText' : ''}${prog ? '. $nightInProgressText' : ''}', child: ExcludeSemantics(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BigValue(n.value!.round().toString(), 'ms', size: 36), const SizedBox(height: Sp.x1), Text('Variabilidad nocturna (aprox.)', style: VT.caption(c)),
        const SizedBox(height: Sp.x2), Text(cmp!, style: VT.body(c)),
        if (n.lowQuality) Padding(padding: const EdgeInsets.only(top: Sp.x1), child: Text(hrvLowQualityText, style: VT.caption(c))),
        if (prog) Padding(padding: const EdgeInsets.only(top: Sp.x1), child: Text(nightInProgressText, style: VT.caption(c))),
      ]))),
      if (n.state == NightState.data && st.mean != null) Padding(padding: const EdgeInsets.only(top: Sp.x2), child: Text(
        'Media de ${week.length} noches: ${st.mean!.round()} ms${st.cv == null ? '' : ' · variación (CV) ${st.cv!.round()} %'}', style: VT.caption(c))),
      if (n.state == NightState.data) _NightTrend(repo.nightHistory(dayKey, repo.nightHrv), c.hrv, 'ms', 'Variabilidad nocturna'),
    ])));
  }
}

/// E4: minutos de actividad semanales frente a la guía de la OMS 2020 (dos estimaciones separadas, sin fusionar).
class WeeklyActivityCard extends StatelessWidget {
  final VigorRepo repo; const WeeklyActivityCard(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final w = repo.weekMvpa();
    final noData = w.daysElapsed == 0 || w.missingDays >= w.daysElapsed && w.byMet == 0;
    final byHrTxt = 'Por pulso: ${w.byHr} min (aprox.)';
    final miss = w.missingDays > 0 ? 'Faltan datos en ${w.missingDays} ${w.missingDays == 1 ? 'día' : 'días'}' : null;
    final label = noData ? 'Actividad de la semana (aprox.): sin datos suficientes' : 'Actividad de la semana (aprox.): ${w.byMet} min de 150. $byHrTxt.${miss == null ? '' : ' $miss.'}';
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MetricHeader(Icons.local_fire_department, 'Actividad de la semana (aprox.)', c.met, trailing: const InfoButton('Actividad de la semana', 'Estimación con tu pulsera. La guía de la OMS 2020 recomienda 150–300 min semanales de actividad moderada (o 75–150 vigorosa) y se basa en cuestionarios y acelerómetros, no en esta pulsera. El esfuerzo moderado se estima con el MET del fabricante (≥ 3) y puede fallar. No es un diagnóstico.')), const SizedBox(height: Sp.x3),
      Semantics(container: true, label: label, child: ExcludeSemantics(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (noData) Text('Sin datos suficientes esta semana.', style: VT.body(c).copyWith(color: c.muted)) else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${w.byMet}', style: VT.display(c).copyWith(fontSize: 36)), const SizedBox(width: Sp.x2), Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('min de 150', style: VT.body(c)))]),
          const SizedBox(height: Sp.x1), Text('Por MET del fabricante (≥ 3 MET, aprox.)', style: VT.caption(c)),
          const SizedBox(height: Sp.x2),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (w.byMet / 150).clamp(0.0, 1.0), minHeight: 8, backgroundColor: c.surfaceHi, color: c.met)),
          const SizedBox(height: Sp.x3), Text(byHrTxt, style: VT.body(c)),
        ],
        if (miss != null) Padding(padding: const EdgeInsets.only(top: Sp.x2), child: Text(miss, style: VT.caption(c))),
      ]))),
    ]));
  }
}
