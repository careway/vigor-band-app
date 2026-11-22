import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/sports.dart';
import 'package:vigor_app/data/workout.dart';

void main() {
  test('un entreno de 4 h (2880 puntos en directo) no se vuelve inmanejable', () {
    var now = DateTime(2026, 3, 5, 10); final w = LiveWorkout(clock: () => now); w.begin(sportByKey('OUTDOOR_WALK'));
    final sw = Stopwatch()..start(); var worst = 0;
    for (var i = 0; i < 2880; i++) {
      now = now.add(const Duration(seconds: 5)); final a = Stopwatch()..start();
      w.onGpsPoint({'lat': 40.0 + i * 0.00004, 'lon': -3.0 + (i % 7) * 0.00001, 'altitude': 600});
      if (a.elapsedMicroseconds > worst) worst = a.elapsedMicroseconds;
    }
    // ignore: avoid_print
    print('total ${sw.elapsedMilliseconds} ms, peor punto ${worst / 1000} ms, puntos ${w.track.length}');
    expect(w.track.length, 2880);
    expect(worst / 1000, lessThan(100), reason: 'cada punto en directo debe procesarse sin bloquear la interfaz');
    w.end();
  });
}
