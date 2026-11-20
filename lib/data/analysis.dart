import 'dart:math' as math;

/// Cálculos puros. Fuentes y límites: docs/ANALISIS.md
class Sample { final DateTime t; final double v; const Sample(this.t, this.v); }

/// FCmáx = 208 − 0,7·edad (Tanaka, Monahan & Seals 2001).
int hrMaxTanaka(int age) => (208 - 0.7 * age).round();

/// Zona 0 (<50 %) o 1..5 (50–60, 60–70, 70–80, 80–90, 90–100+ % de FCmáx).
int hrZone(num hr, int hrMax) {
  final p = hr / hrMax;
  if (p < 0.5) return 0;
  if (p < 0.6) return 1;
  if (p < 0.7) return 2;
  if (p < 0.8) return 3;
  if (p < 0.9) return 4;
  return 5;
}

/// Minutos en cada zona (índices 0..5) a partir de una muestra de pulso por minuto.
List<int> zoneMinutes(List<int> hrPerMinute, int hrMax) {
  final z = List<int>.filled(6, 0);
  for (final h in hrPerMinute) { z[hrZone(h, hrMax)]++; }
  return z;
}

/// TRIMP de Edwards: Σ minutos en zona × número de zona. Índice relativo personal, no absoluto.
int edwardsTrimp(List<int> zoneMin) {
  var t = 0;
  for (var i = 1; i <= 5; i++) { t += zoneMin[i] * i; }
  return t;
}

/// RMSSD (ms) de una lista de intervalos RR en ms. Null si hay menos de 5 intervalos válidos.
double? rmssd(List<num> rr) {
  final v = rr.where((r) => r > 0 && r < 2500).toList();
  if (v.length < 5) return null;
  var s = 0.0;
  for (var i = 0; i < v.length - 1; i++) { final d = v[i + 1] - v[i]; s += d * d; }
  return math.sqrt(s / (v.length - 1));
}

double? median(List<double> x) {
  if (x.isEmpty) return null;
  final s = [...x]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// FC en reposo APROXIMADA: media del 10 % más bajo (heurística propia, sin fuente validada).
double? restingHrApprox(List<int> hr) {
  final v = hr.where((h) => h >= 30 && h <= 220).toList()..sort();
  if (v.length < 20) return null;
  final n = math.max(3, (v.length * 0.1).round());
  return v.take(n).reduce((a, b) => a + b) / n;
}

/// Distancia Haversine en metros.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final a = math.pow(math.sin(rad(lat2 - lat1) / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(rad(lon2 - lon1) / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

// ======================= Ronda 3 (ESPECIFICACION_RONDA3.md) =======================

// ---- E1: calidad y cobertura ----
/// Recuento por día y métrica. `raw` = registros presentes; `valid` pasan el filtro; `noData` = 0/255/no numérico ("sin dato", NO es fuera de rango);
/// `low`/`high` = fuera del rango plausible (por debajo / por encima); `possible` = lecturas posibles.
class Quality {
  int raw = 0, valid = 0, noData = 0, low = 0, high = 0; int possible;
  Quality(this.possible);
  int get outOfRange => low + high;
  int get discardedByRange => outOfRange;
  double get coveragePct => possible <= 0 ? 0 : valid / possible * 100;
  bool get hasData => valid > 0;
  /// Punto de aviso de la tesela: hay datos pero la cobertura del día es < 20 %.
  bool get poor => valid > 0 && coveragePct < 20;
  /// Clasifica un valor leído. 0 y 255 = sin dato; fuera de [lo, hi] = descartado por rango.
  void add(dynamic v, num lo, num hi) {
    raw++;
    if (v is! num || !v.isFinite || v == 0 || v == 255) { noData++; return; }
    if (v < lo) { low++; return; }
    if (v > hi) { high++; return; }
    valid++;
  }
}

/// Lecturas posibles de un día: [perDay] si el día ya terminó; en el día de hoy, las transcurridas (no se penaliza el futuro).
int possibleSamples(int perDay, {required bool isToday, required DateTime now}) {
  if (!isToday) return perDay;
  final elapsedMin = now.hour * 60 + now.minute + 1;
  final p = (perDay * elapsedMin / 1440).ceil();
  return p.clamp(1, perDay);
}

/// "Lecturas válidas: {v} de {p} posibles ({c} %). Descartadas por fuera de rango: {d}." (la 2.ª frase se omite si d = 0).
/// SpO₂ con lecturas bajo el mínimo: frase específica.
String coverageText(Quality q, {bool spo2 = false}) {
  final base = 'Lecturas válidas: ${q.valid} de ${q.possible} posibles (${q.coveragePct.round()} %).';
  if (spo2 && q.low > 0) {
    final lo = 'Hay ${q.low} ${q.low == 1 ? 'lectura' : 'lecturas'} por debajo de 70 % descartada${q.low == 1 ? '' : 's'} por posible error de medida; no se muestran.';
    return q.high > 0 ? '$base $lo Además, ${q.high} fuera de rango por arriba (más de 100 %).' : '$base $lo';
  }
  if (q.outOfRange == 0) return base;
  return '$base Descartadas por fuera de rango: ${q.outOfRange}.';
}

// ---- Mediana y línea base propia (regla 5) ----
const kBaselineMinNights = 7, kBaselineMaxNights = 14, kBaselineWindowDays = 30;

/// [prevNewestFirst]: valores nocturnos válidos de noches anteriores (la más reciente primero) ya limitadas a los últimos [kBaselineWindowDays] días naturales. Usa hasta 14; sin línea base si hay < 7.
({double? base, int k}) nightBaseline(List<double> prevNewestFirst) {
  final used = prevNewestFirst.take(kBaselineMaxNights).toList();
  return (base: used.length >= kBaselineMinNights ? median(used) : null, k: used.length);
}

enum NightState { data, insufficient, none }
class NightStat {
  final NightState state; final double? value; final int n, need; final bool lowQuality;
  const NightStat(this.state, this.value, this.n, this.need, {this.lowQuality = false, this.recorded = 0, this.failsFraction = false});
  /// N3: si hay lecturas de sobra pero falla el 60 % de los registros, el texto lo dice (antes: "35 de 30 lecturas").
  final int recorded; final bool failsFraction;
  String get insufficientText => failsFraction
      ? 'Sin datos suficientes: $n de $recorded registros válidos (mínimo ${(kHrvNightMinFrac * 100).round()} %)'
      : 'Sin datos suficientes: $n de $need lecturas';
}

/// Noche provisional (regla 4): lecturas de 00:00 a 05:59 del día [day].
bool inNight(DateTime t, DateTime day) => t.year == day.year && t.month == day.month && t.day == day.day && t.hour < 6;

// ---- E2: FC en reposo nocturna ----
const kRestingNightMin = 60;
/// Mediana de las 30 lecturas más bajas válidas (30–220) de la noche. < 60 válidas -> insuficiente (aprox., umbral propio).
NightStat restingHrNight(List<num> nightReadings) {
  final v = [for (final x in nightReadings) if (x.isFinite && x >= 30 && x <= 220) x.toDouble()]..sort();
  if (nightReadings.isEmpty) return const NightStat(NightState.none, null, 0, kRestingNightMin);
  if (v.length < kRestingNightMin) return NightStat(NightState.insufficient, null, v.length, kRestingNightMin);
  return NightStat(NightState.data, median(v.take(30).toList()), v.length, kRestingNightMin);
}

// ---- E3: HRV nocturna robusta ----
/// Resultado de una medición HRV: RMSSD (null si hay < 5 diferencias válidas), pares reales adyacentes y cuántos quedaron corregidos/descartados.
/// `noData` = el registro es todo centinela ("sin dato"); los pares con centinela NO cuentan ni como pares ni como correcciones (N1).
class MinuteHrv { final double? rmssd; final int pairs, corrected; final bool noData; const MinuteHrv(this.rmssd, this.pairs, this.corrected, {this.noData = false}); }

/// Centinela real del SDK en `rrValue`: 2550 ms (0xFF·10) = "sin dato" (medido: 27 % de los RR de un móvil real). 0 y no numérico también.
bool isRrSentinel(num x) => !x.isFinite || x <= 0 || x == 2550;

/// (1) RR centinela = sin dato: no se usa ni se cuenta como corrección; (2) RR reales fuera de 300–2000 ms se descartan (ruido, cuentan como corregidos);
/// (3) diferencia solo entre RR consecutivos (no cruza huecos); (4) par con |Δ| > 20 % del RR anterior descartado (ruido); (5) mínimo 5 diferencias.
/// Umbrales propios, sin fuente: "aprox.". Cada registro del SDK trae ~10 RR (≈ 9–10 s de latidos), no un minuto completo.
MinuteHrv rmssdMinute(List<num> rr) {
  bool ok(num x) => x >= 300 && x <= 2000;
  var n = 0, pairs = 0, bad = 0; var s = 0.0;
  for (var i = 0; i + 1 < rr.length; i++) {
    final a = rr[i], b = rr[i + 1];
    if (isRrSentinel(a) || isRrSentinel(b)) continue; // sin dato: ni par ni corrección
    pairs++;
    if (!ok(a) || !ok(b)) { bad++; continue; }
    final d = (b - a).toDouble();
    if (d.abs() > 0.2 * a) { bad++; continue; }
    s += d * d; n++;
  }
  return MinuteHrv(n >= 5 ? math.sqrt(s / n) : null, pairs, bad, noData: rr.isNotEmpty && rr.every(isRrSentinel));
}

const kHrvNightMinMinutes = 30; const kHrvNightMinFrac = 0.6;
/// Mediana de los RMSSD por registro (1 por minuto) de la noche. Requiere ≥ 30 válidos y ≥ 60 % de los registros con dato (los todo-centinela no cuentan como registro).
/// "Calidad baja" si > 5 % de los pares de RR reales (sin centinelas) se corrigieron (a nivel de noche).
NightStat hrvNight(List<double> minuteValues, {required int recordedMinutes, int pairs = 0, int corrected = 0}) {
  final v = [for (final x in minuteValues) if (x.isFinite) x];
  if (recordedMinutes <= 0 && v.isEmpty) return const NightStat(NightState.none, null, 0, kHrvNightMinMinutes);
  if (v.length < kHrvNightMinMinutes) return NightStat(NightState.insufficient, null, v.length, kHrvNightMinMinutes, recorded: recordedMinutes);
  if (v.length < kHrvNightMinFrac * recordedMinutes) return NightStat(NightState.insufficient, null, v.length, kHrvNightMinMinutes, recorded: recordedMinutes, failsFraction: true);
  return NightStat(NightState.data, median(v), v.length, kHrvNightMinMinutes, lowQuality: pairs > 0 && corrected / pairs > 0.05, recorded: recordedMinutes);
}

/// Media y coeficiente de variación (%) de varios valores nocturnos. CV null con < 2 valores o media 0.
({double? mean, double? cv}) meanCv(List<double> x) {
  if (x.isEmpty) return (mean: null, cv: null);
  final m = x.reduce((a, b) => a + b) / x.length;
  if (x.length < 2 || m == 0) return (mean: m, cv: null);
  var ss = 0.0; for (final e in x) { ss += (e - m) * (e - m); }
  return (mean: m, cv: math.sqrt(ss / (x.length - 1)) / m * 100);
}

// ---- E4: minutos de actividad semanales (OMS 2020) ----
/// Corte moderada-vigorosa en MET (OMS 2020, absoluto: ≥ 3; nivel de lectura: resumen de búsqueda). Cada registro de `met` = 5 min.
const kMvpaMet = 3.0;
/// Umbral por pulso: constante propia, no es un corte de la OMS. Inicio de la zona 3 (70 % de FCmáx).
const kMvpaHrFraction = 0.70;
/// A. Minutos por MET del fabricante: cada lectura (5 min) con met ≥ 3 suma 5.
int mvpaMinutesByMet(List<num> met5) => met5.where((m) => m.isFinite && m >= kMvpaMet).length * 5;
/// B. Minutos por pulso: lecturas por minuto ≥ [frac]·FCmáx.
int mvpaMinutesByHr(List<num> hrPerMinute, int hrMax, {double frac = kMvpaHrFraction}) => hrPerMinute.where((h) => h.isFinite && h >= frac * hrMax).length;
/// Lunes 00:00 de la semana (local) que contiene [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

class DayAct { final DateTime date; final List<num> met5, hrMin; final int metRecords, metPossible; const DayAct(this.date, this.met5, this.hrMin, this.metRecords, this.metPossible); }
class WeekMvpa { final int byMet, byHr, missingDays, daysElapsed; const WeekMvpa(this.byMet, this.byHr, this.missingDays, this.daysElapsed); }
/// Suma la semana lunes-domingo de [today]. Un día cuenta como "con datos" si ≥ 70 % de sus registros de 5 min; los demás (hasta hoy) se anotan como
/// "faltan datos", no como 0. Los días futuros no cuentan. Sin ponderar los vigorosos (equivalencia no verificada).
WeekMvpa weeklyMvpa(List<DayAct> days, DateTime today, int hrMax, {double hrFrac = kMvpaHrFraction}) {
  final ws = weekStart(today); final we = ws.add(const Duration(days: 7));
  final td = DateTime(today.year, today.month, today.day);
  var a = 0, b = 0, missing = 0, elapsed = 0;
  final byDate = {for (final d in days) DateTime(d.date.year, d.date.month, d.date.day): d};
  for (var i = 0; i < 7; i++) {
    final dt = DateTime(ws.year, ws.month, ws.day + i);
    if (!dt.isBefore(we) || dt.isAfter(td)) continue;
    elapsed++;
    final d = byDate[dt];
    if (d == null || d.metPossible <= 0 || d.metRecords / d.metPossible < 0.7) missing++;
    if (d != null) { a += mvpaMinutesByMet(d.met5); b += mvpaMinutesByHr(d.hrMin, hrMax, frac: hrFrac); }
  }
  return WeekMvpa(a, b, missing, elapsed);
}

// ---- E5: ritmo y velocidad derivados ----
class SessionDerived { final int? paceSecKm; final double? speedKmh; final bool paceDiffers; const SessionDerived(this.paceSecKm, this.speedKmh, this.paceDiffers); }
/// Ritmo = sportTime / (distance/1000); velocidad = distance/sportTime en km/h. Sin distancia o tiempo -> null (sin división por cero).
/// [paceDiffers]: el ritmo de la pulsera [bandPaceSecKm] difiere > 5 % (umbral propio) del calculado.
SessionDerived deriveSession(int seconds, int meters, int bandPaceSecKm) {
  if (seconds <= 0 || meters <= 0) return const SessionDerived(null, null, false);
  final pace = (seconds / (meters / 1000)).round();
  final speed = meters / seconds * 3.6;
  final differs = bandPaceSecKm > 0 && (pace - bandPaceSecKm).abs() / bandPaceSecKm > 0.05;
  return SessionDerived(pace, speed, differs);
}

// ---- E6: decodificador de sleepLine (modo normal, documentado en api_en.md) ----
/// Cada carácter = 5 min; 0 ligero, 1 profundo, 2 despierto. Cualquier otro carácter se ignora (no se inventa).
({int totalMin, int lightMin, int deepMin, int awakeMin}) decodeSleepLineNormal(String line) {
  var l = 0, d = 0, w = 0;
  for (final c in line.split('')) { switch (c) { case '0': l += 5; case '1': d += 5; case '2': w += 5; } }
  return (totalMin: l + d + w, lightMin: l, deepMin: d, awakeMin: w);
}
