import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigor_app/data/day_kinds.dart';
import 'package:vigor_app/data/repo.dart';
import 'package:vigor_app/theme/tokens.dart';
import 'package:vigor_app/ui/charts.dart';
import 'package:vigor_app/ui/day_kind_legend.dart';

// Datos sintéticos de un día inventado.
DateTime _t(int h, [int m = 0]) => DateTime(2026, 3, 10, h, m);
Session _sess(int type, DateTime start, int min) => Session(key: 's${start.hour}', start: start, sportType: type, seconds: min * 60, meters: 0, kcal: 0, steps: 0, avgHr: 0, paceSecKm: 0, hasGps: false, route: const [], hrPerMinute: const []);

void main() {
  Day day() => Day('2026-03-10');
  List<BinMix> mix(Day d, {List<Night> nights = const [], List<Session> sessions = const [], int hrMax = 185}) => mixDay(day: d, nights: nights, sessions: sessions, hrMax: hrMax);

  group('esfuerzo continuo', () {
    test('la curva de pasos sube sin saltos: 0 reposo, ~1500 marcha ligera, 4000+ carrera', () {
      expect(effortFromSteps(0), 0); expect(effortFromSteps(150), closeTo(.2, 1e-9)); expect(effortFromSteps(1500), closeTo(.5, 1e-9)); expect(effortFromSteps(9000), 1);
      var prev = -1.0; for (var s = 0; s <= 5000; s += 50) { final e = effortFromSteps(s.toDouble()); expect(e, greaterThanOrEqualTo(prev)); prev = e; }
    });
    test('la curva de pulso: 45 % de la FCmáx o menos reposo, 60 % ligera, 80 % o más intensa; FCmáx 0 no rompe', () {
      expect(effortFromHr(80, 185), 0); expect(effortFromHr(111, 185), closeTo(.5, 1e-9)); expect(effortFromHr(150, 185), 1); expect(effortFromHr(120, 0), 0);
    });
    test('mezcla: el esfuerzo es el MAYOR de pasos, pulso y ejercicio', () {
      final d = day(); d.steps5.add(Sample(_t(10), 1500)); d.hr.add(Sample(_t(10, 5), 140)); // pasos → .5, pulso 140/185 (75,7 %) → ~.89
      expect(mix(d)[20].effort, closeTo(.89, .02));
      final d2 = day(); d2.steps5.add(Sample(_t(10), 1500));
      expect(mix(d2)[20].effort, closeTo(.5, 1e-9));
    });
    test('ejercicio deportivo de toda la franja llega al máximo; una caminata, a actividad leve', () {
      final k = mix(day(), sessions: [_sess(1, _t(8), 60), _sess(5, _t(12), 60)]);
      expect(k[16].effort, 1); expect(k[16].kind, DayKind.activity);
      expect(k[24].effort, closeTo(.6, 1e-9)); expect(k[24].kind, DayKind.walk);
      expect(k[18].hasData, false);
    });
    test('un ejercicio de menos de 10 min dentro de la franja no la define', () {
      final k = mix(day(), sessions: [_sess(1, _t(8, 25), 8)]); expect(k[16].effort, 0); expect(k[16].hasData, false);
    });
  });

  group('el sueño predomina', () {
    test('noche que cruza la medianoche: sueño del todo hasta el despertar, sin contaminar la franja siguiente', () {
      final n = Night('2026-03-10', 420, 90, 300, 0, DateTime(2026, 3, 9, 23, 30), _t(6, 30));
      final k = mix(day(), nights: [n]);
      for (var i = 0; i < 13; i++) { expect(k[i].sleep, 1, reason: 'franja $i'); expect(k[i].kind, DayKind.sleep); }
      expect(k[13].sleep, 0);
    });
    test('a partir de 15 min de sueño la franja es del todo sueño aunque haya pasos y pulso altos; con menos se mezcla', () {
      final d = day(); d.steps5.add(Sample(_t(1, 0), 3000)); d.hr.add(Sample(_t(1, 5), 150));
      final n = Night('2026-03-10', 300, 60, 240, 0, DateTime(2026, 3, 9, 23, 0), _t(5, 0));
      expect(mix(d, nights: [n])[2].sleep, 1);
      final corto = Night('2026-03-10', 8, 1, 7, 0, _t(12, 0), _t(12, 8)); // 8 min en la franja de las 12:00
      final m = mix(day(), nights: [corto])[24];
      expect(m.sleep, closeTo(8 / 15, 1e-9)); expect(m.kind, DayKind.sleep, reason: 'más de la mitad: se nombra sueño');
    });
    test('siesta cuenta igual', () {
      final nap = Night('2026-03-10', 80, 16, 64, 0, _t(16, 55), _t(18, 20));
      final k = mix(day(), nights: [nap]); expect(k[34].sleep, 1); expect(k[35].sleep, 1); expect(k[33].sleep, closeTo(5 / 15, 1e-9), reason: '5 min de sueño en 16:30-17:00: se mezcla'); expect(k[32].sleep, 0);
    });
    test('la noche de esta noche solo ocupa su última franja; las muestras de otro día no contaminan', () {
      final tonight = Night('2026-03-11', 420, 90, 300, 0, _t(23, 30), DateTime(2026, 3, 11, 6, 30));
      final k = mix(day(), nights: [tonight]); expect(k[47].sleep, 1); expect(k[46].sleep, 0);
      final d = day(); d.hr.add(Sample(DateTime(2026, 3, 9, 14, 10), 62)); expect(mix(d).every((m) => !m.hasData), true);
    });
  });

  group('nombres dominantes y casos límite', () {
    test('reposo, leve y deportiva según el esfuerzo; sin datos si la franja está vacía', () {
      expect(const BinMix(hasData: true, effort: .05).kind, DayKind.rest);
      expect(const BinMix(hasData: true, effort: .3).kind, DayKind.walk);
      expect(const BinMix(hasData: true, effort: .8).kind, DayKind.activity);
      expect(const BinMix().kind, DayKind.none);
      expect(const BinMix(hasData: true, effort: .9, sleep: .6).kind, DayKind.sleep);
    });
    test('fecha inválida o día vacío: 48 franjas sin datos', () {
      expect(mix(Day('xx')).every((m) => !m.hasData), true); expect(mix(Day('xx')).length, 48); expect(mix(day()).length, 48);
    });
    test('cuenta de franjas por nombre', () { final c = countKinds([DayKind.sleep, DayKind.sleep, DayKind.walk]); expect(c[DayKind.sleep], 2); expect(c[DayKind.walk], 1); });
  });

  group('degradado de color', () {
    test('en los extremos: reposo azul, actividad leve verde, deportiva naranja (claro y oscuro)', () {
      for (final c in [VC.dark, VC.light]) {
        expect(effortColor(c, 0), c.spo2); expect(effortColor(c, .5), c.steps); expect(effortColor(c, 1), c.met);
        expect(dayKindColor(c, DayKind.sleep), c.accent2);
      }
    });
    test('entre medias mezcla: más esfuerzo se parece más al siguiente color', () {
      final c = VC.light; final a = effortColor(c, .1), b = effortColor(c, .4);
      expect((b.g - c.steps.g).abs(), lessThan((a.g - c.steps.g).abs() + 1e-9), reason: '.4 está más cerca del verde que .1');
      expect(effortColor(c, -3), effortColor(c, 0)); expect(effortColor(c, 7), effortColor(c, 1), reason: 'se acota a 0..1');
    });
    test('el sueño manda: con peso 1 la franja es morada sea cual sea el esfuerzo; con 0 conserva el degradado; sin datos, gris', () {
      final c = VC.light;
      expect(mixColor(c, const BinMix(hasData: true, effort: 1, sleep: 1)), c.accent2);
      expect(mixColor(c, BinMix(hasData: true, effort: .5, sleep: 0)), effortColor(c, .5));
      expect(mixColor(c, const BinMix()), c.surfaceHi.withValues(alpha: .7));
      final mid = mixColor(c, const BinMix(hasData: true, effort: 1, sleep: .5)); expect(mid, isNot(c.accent2)); expect(mid, isNot(c.met));
    });
  });

  group('leyenda y reloj', () {
    Future<void> show(WidgetTester t, Widget w, {double scale = 1, Brightness b = Brightness.light}) async {
      t.view.physicalSize = const Size(320, 900) * 3; t.view.devicePixelRatio = 3; addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(theme: buildTheme(b), builder: (c, x) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: x!), home: Scaffold(body: Center(child: w))));
    }
    testWidgets('la leyenda lleva nombres y horas además del color, y una barra de degradado', (t) async {
      final k = [...List.filled(14, DayKind.sleep), ...List.filled(3, DayKind.walk), ...List.filled(31, DayKind.none)];
      await show(t, DayKindLegend(k));
      expect(find.text('Dormir 7 h'), findsOneWidget); expect(find.text('Actividad leve 1 h 30 min'), findsOneWidget);
      expect(find.text('Actividad deportiva —'), findsOneWidget); expect(find.text('Reposo —'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('mezclado entre reposo.*sueño predomina.*Dormir 7 h')), findsOneWidget);
    });
    testWidgets('a 320 px y texto doble no desborda', (t) async {
      await show(t, DayKindLegend(List.filled(48, DayKind.rest)), scale: 2, b: Brightness.dark);
      expect(t.takeException(), isNull);
    });
    testWidgets('el reloj se pinta con la mezcla sin excepciones (claro y oscuro)', (t) async {
      for (final b in Brightness.values) {
        final m = [for (var i = 0; i < 48; i++) BinMix(hasData: i % 7 != 0, effort: i / 47, sleep: i < 12 ? 1 : (i == 12 ? .4 : 0))];
        final d = Day('2026-03-10'); d.steps5.add(Sample(_t(10), 200));
        await show(t, DayDial(day: d, c: b == Brightness.dark ? VC.dark : VC.light, scrubMin: 600, nowMin: 700, onScrub: (_) {}, onLock: (_) {}, mix: m), b: b);
        expect(find.byType(DayDial), findsOneWidget); expect(t.takeException(), isNull);
      }
    });
  });
}
