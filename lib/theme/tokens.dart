import 'package:flutter/material.dart';

/// Tokens de docs/GUIA_DE_ESTILOS.md (v2 "Aurora"). Si cambian allí, cambian aquí.
class VC {
  final Color bg, surface, surfaceHi, text, muted, accent, accent2, danger;
  final Color steps, heart, spo2, hrv, stress, met, temp, sleep, exp;
  const VC({required this.bg, required this.surface, required this.surfaceHi, required this.text, required this.muted, required this.accent, required this.accent2, required this.danger,
      required this.steps, required this.heart, required this.spo2, required this.hrv, required this.stress, required this.met, required this.temp, required this.sleep, required this.exp});

  static const dark = VC(
    bg: Color(0xFF0A0E13), surface: Color(0xFF141A21), surfaceHi: Color(0xFF1D2630), text: Color(0xFFF2F6F8), muted: Color(0xFF9AA9B5),
    accent: Color(0xFF5EEAD4), accent2: Color(0xFFA78BFA), danger: Color(0xFFFDA4AF),
    steps: Color(0xFF4ADE80), heart: Color(0xFFFB7185), spo2: Color(0xFF38BDF8), hrv: Color(0xFFE879F9), stress: Color(0xFFFBBF24),
    met: Color(0xFFFB923C), temp: Color(0xFF2DD4BF), sleep: Color(0xFF818CF8), exp: Color(0xFF94A3B8));
  static const light = VC(
    bg: Color(0xFFF4F6FB), surface: Color(0xFFFFFFFF), surfaceHi: Color(0xFFE8EDF6), text: Color(0xFF0F172A), muted: Color(0xFF475569),
    accent: Color(0xFF0F766E), accent2: Color(0xFF6D28D9), danger: Color(0xFFB3261E),
    steps: Color(0xFF15803D), heart: Color(0xFFBE123C), spo2: Color(0xFF0369A1), hrv: Color(0xFFA21CAF), stress: Color(0xFFB45309),
    met: Color(0xFFC2410C), temp: Color(0xFF0F766E), sleep: Color(0xFF4338CA), exp: Color(0xFF475569));

  static VC of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
  // alias de la v1 usados por pantallas antiguas
  Color get surfaceAlt => surfaceHi;
  Color get kcal => met;
  Color get route => accent;
}

class Sp { static const double x1 = 4, x2 = 8, x3 = 12, x4 = 16, x6 = 24, x8 = 32; }

class VT {
  static const _tab = [FontFeature.tabularFigures()];
  static TextStyle display(VC c) => TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: c.text, fontFeatures: _tab, height: 1.05, letterSpacing: -1.2);
  static TextStyle title(VC c) => TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text, letterSpacing: -.4);
  static TextStyle heading(VC c) => TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text);
  static TextStyle body(VC c) => TextStyle(fontSize: 14, color: c.text, fontFeatures: _tab, height: 1.35);
  static TextStyle caption(VC c) => TextStyle(fontSize: 12, color: c.muted, fontFeatures: _tab, height: 1.3);
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? VC.dark : VC.light;
  return ThemeData(
    useMaterial3: true, brightness: b, scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: b).copyWith(primary: c.accent, surface: c.surface, error: c.danger),
    appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: c.text, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: VT.title(c)),
    dividerColor: c.surfaceHi,
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: b == Brightness.dark ? const Color(0xFF04201C) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: c.text, side: BorderSide(color: c.surfaceHi), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
  );
}
