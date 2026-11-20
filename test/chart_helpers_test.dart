import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/ui/charts.dart';
import 'package:vigor_app/ui/metrics.dart';
import 'package:vigor_app/ui/widgets.dart';

Sample s(int h, int m, double v, {int d = 5}) => Sample(DateTime(2026, 3, d, h, m), v);

void main() {
  group('statsOf', () {
    test('vacia -> null; una muestra; varias', () {
      expect(statsOf([]), isNull);
      final one = statsOf([s(1, 0, 5)])!; expect((one.min, one.avg, one.max), (5.0, 5.0, 5.0));
      final m = statsOf([s(1, 0, 1), s(1, 5, 4), s(1, 10, 10)])!; expect(m.min, 1); expect(m.max, 10); expect(m.avg, 5);
    });
  });

  group('bin30', () {
    test('suma por franjas de 30 min y ordena', () {
      final b = bin30([s(10, 29, 1), s(10, 30, 2), s(0, 5, 7), s(10, 0, 3)]);
      expect(b.map((e) => (e.t.hour, e.t.minute, e.v)), [(0, 0, 7.0), (10, 0, 4.0), (10, 30, 2.0)]);
    });
    test('vacia -> vacia', () => expect(bin30([]), isEmpty));
    test('23:59 cae en la franja 47', () { final b = bin30([s(23, 59, 1)]); expect((b.single.t.hour, b.single.t.minute), (23, 30)); });
  });

  group('nearest', () {
    final l = [s(10, 0, 1), s(10, 10, 2), s(12, 0, 3)];
    test('elige la mas cercana dentro de la ventana', () { expect(nearest(l, 10 * 60 + 8)!.v, 2); });
    test('fuera de ventana -> null', () { expect(nearest(l, 11 * 60), isNull); });
    test('limite inclusivo (12 min)', () { expect(nearest(l, 10 * 60 + 22)!.v, 2); expect(nearest(l, 10 * 60 + 23), isNull); });
    test('lista vacia -> null', () => expect(nearest([], 100), isNull));
  });

  group('baselineOf', () {
    VigorRepo repoWith(Map<String, double> avgByDay) {
      final r = VigorRepo();
      for (final e in avgByDay.entries) { final d = Day(e.key); d.hrv.add(Sample(DateTime.parse('${e.key}T08:00:00'), e.value)); r.days[e.key] = d; }
      return r;
    }
    test('< 3 dias previos -> null', () {
      final r = repoWith({'2026-03-01': 50, '2026-03-02': 60, '2026-03-03': 70});
      expect(baselineOf(r, kHrv, '2026-03-03'), isNull);
    });
    test('mediana de los 3+ dias previos, excluye el propio dia', () {
      final r = repoWith({'2026-03-01': 50, '2026-03-02': 60, '2026-03-03': 80, '2026-03-04': 999});
      expect(baselineOf(r, kHrv, '2026-03-04'), 60);
    });
    test('solo usa hasta 14 dias previos', () {
      final m = {for (var i = 1; i <= 20; i++) '2026-03-${i.toString().padLeft(2, '0')}': i <= 5 ? 1000.0 : 10.0, '2026-03-21': 0.0};
      expect(baselineOf(repoWith(m), kHrv, '2026-03-21'), 10);
    });
    test('clave inexistente -> null (no lanza)', () {
      expect(baselineOf(repoWith({'2026-03-01': 1}), kHrv, '2099-01-01'), isNull);
    });
    test('dias con huecos de calendario cuentan como consecutivos (documenta QA_001: "14 dias" son 14 dias CON datos)', () {
      final r = repoWith({'2025-01-01': 10, '2025-06-01': 10, '2025-12-01': 10, '2026-03-01': 99});
      expect(baselineOf(r, kHrv, '2026-03-01'), 10);
    });
  });

  group('formato', () {
    test('dur/pace/hm', () {
      expect(dur(59), '0 min'); expect(dur(3600), '1 h 00 min'); expect(dur(3725), '1 h 02 min');
      expect(pace(0), '—'); expect(pace(-5), '—'); expect(pace(365), '6:05 /km');
      expect(hm(DateTime(2026, 1, 1, 7, 3)), '07:03');
    });
    test('fmtNum', () => expect(fmtNum(36.55, 1), anyOf('36.5', '36.6')));
  });
}
