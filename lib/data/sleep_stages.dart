import 'dart:math' as math;

/// Fases del sueño (aproximadas, estimadas por la pulsera). Orden de declaración = orden de los carriles (arriba a abajo).
enum Stage { awake, rem, light, deep }

String stageName(Stage s) => const {Stage.awake: 'Despierto', Stage.rem: 'REM', Stage.light: 'Ligero', Stage.deep: 'Profundo'}[s]!;

/// Decodifica `sleepLine` del SDK de Veepoo a una lista de fases POR MINUTO.
/// - Modo preciso (`accurateType == 1`): 1 carácter = 1 min; 0 profundo, 1 ligero, 2 REM, 3 insomnio, 4 despierto
///   (insomnio y despierto se muestran ambos como "Despierto"). Fuente: VeepooSDK Android Api.md, `sleepLine`.
/// - Modo normal: 1 carácter = 5 min; 0 ligero, 1 profundo, 2 despierto (no hay REM).
/// Los caracteres desconocidos se ignoran (no se inventa nada). Sin ninguna fase válida devuelve null.
List<Stage>? decodeStages(String? line, {required bool precise}) {
  if (line == null || line.isEmpty) return null;
  final out = <Stage>[];
  for (final c in line.split('')) {
    Stage? s;
    if (precise) {
      s = switch (c) { '0' => Stage.deep, '1' => Stage.light, '2' => Stage.rem, '3' || '4' => Stage.awake, _ => null };
    } else {
      s = switch (c) { '0' => Stage.light, '1' => Stage.deep, '2' => Stage.awake, _ => null };
    }
    if (s == null) continue;
    for (var i = 0; i < (precise ? 1 : 5); i++) { out.add(s); }
  }
  return out.isEmpty ? null : out;
}

/// Regla de siesta (propia, simple): una "noche" cuyo sueño total es < 180 min es una siesta.
/// Límite: una noche muy corta (< 3 h) también se marcaría como siesta.
const int kNapMaxMinutes = 180;
bool isNapMinutes(int totalMin) => totalMin < kNapMaxMinutes;

/// Despertar "real" contado del hipnograma: tramo despierto >= 5 min entre dos tramos dormidos
/// (Google/Fitbit destaca los de ~5 min como más disruptivos; el umbral es propio, no clínico).
const int kAwakeningMinMinutes = 5;

class SleepMetrics {
  final int bedMin, asleepMin, awakeMin, deepMin, lightMin, remMin;
  final int awakenings, longestRunMin;
  /// Eficiencia = dormido / tiempo registrado (0..1). OJO: la pulsera solo registra el intervalo que detecta como sueño.
  final double efficiency;
  /// Minuto (desde el inicio del registro) de cada tramo despierto contado, para ayudas visuales.
  const SleepMetrics({required this.bedMin, required this.asleepMin, required this.awakeMin, required this.deepMin, required this.lightMin, required this.remMin, required this.awakenings, required this.longestRunMin, required this.efficiency});
  double pct(int m) => asleepMin == 0 ? 0 : m * 100 / asleepMin;
}

SleepMetrics sleepMetrics(List<Stage> st) {
  var deep = 0, light = 0, rem = 0, awake = 0;
  for (final s in st) { switch (s) { case Stage.deep: deep++; case Stage.light: light++; case Stage.rem: rem++; case Stage.awake: awake++; } }
  final asleep = deep + light + rem;
  // Despertares: tramos awake de >= 5 min con sueño antes y después.
  var first = st.indexWhere((s) => s != Stage.awake), last = st.lastIndexWhere((s) => s != Stage.awake);
  var wakes = 0, longest = 0, run = 0, aw = 0;
  if (first >= 0) {
    for (var i = first; i <= last; i++) {
      if (st[i] == Stage.awake) { aw++; run = 0; } else { if (aw >= kAwakeningMinMinutes) wakes++; aw = 0; run++; if (run > longest) longest = run; }
    }
  }
  return SleepMetrics(bedMin: st.length, asleepMin: asleep, awakeMin: awake, deepMin: deep, lightMin: light, remMin: rem, awakenings: wakes, longestRunMin: longest, efficiency: st.isEmpty ? 0 : asleep / st.length);
}

/// Minutos desde las 12:00 (mediodía) del punto medio: así una noche que cruza la medianoche no se parte.
/// Límite: dormir con el punto medio alrededor de las 12:00 rompe la comparación.
int minutesFromNoon(DateTime t) => ((t.hour * 60 + t.minute) - 720) % 1440;

/// Desviación típica (muestral, n-1) en minutos; null con menos de 3 valores.
double? stdDev(List<num> v) {
  if (v.length < 3) return null;
  final m = v.reduce((a, b) => a + b) / v.length;
  return math.sqrt(v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (v.length - 1));
}

/// Hora de reloj (minutos del día) a partir de minutos desde mediodía.
int clockFromNoon(num m) => ((m.round() + 720) % 1440 + 1440) % 1440;
