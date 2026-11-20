import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/health_page.dart';

void main() {
  testWidgets('Salud y compartir: apagado de serie, texto escalado 2x sin desbordes y objetivos de 48 dp', (t) async {
    final repo = VigorRepo();
    for (final scale in [1.0, 2.0]) {
      await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: MediaQuery(data: MediaQueryData(size: const Size(360, 740), textScaler: TextScaler.linear(scale)), child: HealthPage(repo))));
      expect(find.text('Salud y compartir'), findsOneWidget);
      expect(find.textContaining('Desactivado: no se envía nada'), findsOneWidget);
      expect(find.text('Qué se comparte'), findsNothing); // las categorías solo se ven con el maestro activo
      final sw = find.byType(Switch); expect(sw, findsOneWidget);
      expect(t.getSize(find.byType(SwitchListTile)).height, greaterThanOrEqualTo(48));
      expect(t.takeException(), isNull);
    }
    expect(repo.health.master, false);
  });
}
