import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/ui/charts.dart';

void main() {
  test('describeSeries: min, media, max y sin datos', () {
    final d = [for (final v in [60.0, 70.0, 80.0]) Sample(DateTime(2026, 3, 5, 9), v)];
    expect(describeSeries('Pulso', 'bpm', 0, d), 'Pulso: mín 60, media 70, máx 80 bpm');
    expect(describeSeries('Pulso', 'bpm', 0, []), 'Pulso: sin datos');
    expect(describeSeries('Pasos', 'pasos', 0, d, bars: true), contains('total 210'));
  });
}
