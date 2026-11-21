import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'device_page.dart';
import 'night_cards.dart';
import 'widgets.dart';

/// Ajustes > Acerca de > «Cómo se calcula y límites»: reúne en un solo sitio los avisos y la metodología
/// que antes se repetían en cada tarjeta.
const List<(String, String)> kLimitSections = [
  ('No es un dispositivo médico', 'Vigor muestra lo que mide una pulsera de consumo. Los datos son orientativos: no sirven para diagnosticar ni tratar enfermedades y no sustituyen a un profesional sanitario.'),
  ('Estimaciones («aprox.»)', 'Lo marcado como «aprox.» lo calcula Vigor a partir de las lecturas de la pulsera con métodos propios sin validar: pulso en reposo nocturno, variabilidad, minutos de actividad semanal y zonas de pulso. Sirven para verte la tendencia contigo mismo.'),
  ('Sueño', 'Las fases son estimaciones de una pulsera de consumo, no una polisomnografía: sobreestiman el sueño ligero (Chinoy 2021) y no sirven para diagnóstico. No hay rangos de referencia personales verificados.'),
  ('Pulso, SpO₂ y temperatura', 'Son lecturas de muñeca con luz (PPG): menos exactas que un oxímetro o termómetro médicos. La SpO₂ descarta lecturas por debajo de 70 %. La temperatura se interpreta solo frente a tu propia media. Vigor no emite alertas.'),
  ('Variabilidad y estrés', hrvLimitText),
  ('Actividad semanal', 'La guía de la OMS 2020 recomienda 150–300 min semanales de actividad moderada (o 75–150 vigorosa) y se basa en cuestionarios y acelerómetros, no en esta pulsera. El esfuerzo moderado se estima con el MET del fabricante (≥ 3) y puede fallar.'),
  ('Pulso máximo y zonas', 'FCmáx = 208 − 0,7·edad (Tanaka 2001), con un margen de ± 10 bpm. El TRIMP es un índice relativo personal. Indica tu edad en Perfil para que sea más fiel.'),
  ('Métricas experimentales', 'La glucosa y los componentes sanguíneos son estimaciones del fabricante: la FDA (2024) no ha autorizado ningún reloj o anillo para medir glucosa sin pinchar la piel y recomienda no usarlos. No las uses para decidir medicación ni tratamientos.'),
  ('Actividades y calorías', 'Calorías, distancia y ritmo los calcula la pulsera con el algoritmo del fabricante. La SDK no indica qué modos admite tu pulsera.'),
  ('Segundo plano', 'La sincronización con la app cerrada depende de Android, que decide cuándo ejecutarla (mínimo cada 15 min y puede retrasarse).'),
  ('Privacidad', 'Tus datos se guardan solo en este móvil. Vigor no envía nada a internet por su cuenta; solo si activas «Salud y compartir» escribe en Health Connect.'),
];

class LimitsPage extends StatelessWidget {
  const LimitsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return SettingsScaffold('Cómo se calcula y límites', [
      for (final s in kLimitSections) Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.$1, style: VT.heading(c)), const SizedBox(height: Sp.x1), Text(s.$2, style: VT.body(c))])),
    ]);
  }
}
