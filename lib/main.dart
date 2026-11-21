// El punto de entrada de la exportación a Health Connect sin interfaz (lo lanza Kotlin con un motor propio) debe estar en el programa:
// sin este import el compilador no incluye la biblioteca y el motor falla con «library not found».
// ignore: unused_import
import 'background_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/analysis.dart';
import 'data/repo.dart';
import 'ui/fx.dart';
import 'theme/tokens.dart';
import 'ui/about_page.dart';
import 'ui/activity_page.dart';
import 'ui/device_page.dart';
import 'ui/sleep_page.dart';
import 'ui/today_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: Colors.transparent, systemNavigationBarIconBrightness: Brightness.light));
  runApp(const VigorApp());
}

class VigorApp extends StatefulWidget {
  const VigorApp({super.key});
  @override
  State<VigorApp> createState() => _VigorAppState();
}

class _VigorAppState extends State<VigorApp> {
  final repo = VigorRepo();
  @override
  void initState() { super.initState(); repo.init(); }
  @override
  void dispose() { repo.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo, builder: (context, _) => MaterialApp(
        title: 'Vigor', debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: const [ThemeMode.dark, ThemeMode.light, ThemeMode.system][repo.themeMode],
        home: Shell(repo)));
}

class Shell extends StatefulWidget {
  final VigorRepo repo; const Shell(this.repo, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  VigorRepo get repo => widget.repo; int tab = 0;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  /// Al volver a primer plano: comprobar versión (silencioso, con límite de 15 min).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) { repo.updater.onResume(); repo.auto.onResume(); }
    else if (s == AppLifecycleState.paused) { repo.auto.onPause(); }
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo, builder: (context, _) {
        final c = VC.of(context);
        final pages = [TodayPage(repo), ActivityPage(repo), SleepPage(repo), SettingsHome(repo)];
        const titles = ['Hoy', 'Actividad', 'Sueño', 'Ajustes'];
        final tint = repo.days.isEmpty || repo.days[repo.dayKeys.last]!.hr.isEmpty ? c.accent2 : _zoneTint(c, repo);
        return Aurora(tint: tint, child: Scaffold(
          backgroundColor: Colors.transparent, extendBody: true,
          appBar: AppBar(title: Text(titles[tab]), actions: [
            if (repo.syncing) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            else Padding(padding: const EdgeInsets.only(right: 16), child: Icon(Icons.circle, size: 10, color: repo.conn == 'connected' ? c.steps : c.muted)),
          ]),
          body: SafeArea(bottom: false, child: Column(children: [UpdateBanner(repo), Expanded(child: AnimatedSwitcher(duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab])))])),
          bottomNavigationBar: ListenableBuilder(listenable: repo.updater, builder: (context, _) => FloatNav(index: tab, onTap: (i) => setState(() => tab = i), badges: repo.updater.available ? const {3} : const {}, items: const [
            (Icons.blur_circular_outlined, Icons.blur_circular, 'Hoy'), (Icons.route_outlined, Icons.route, 'Actividad'), (Icons.bedtime_outlined, Icons.bedtime, 'Sueño'), (Icons.tune_outlined, Icons.tune, 'Ajustes'),
          ])),
        ));
      });

  /// El resplandor inferior toma el color de la zona de pulso de la última lectura.
  Color _zoneTint(VC c, VigorRepo r) {
    final z = hrZone(r.days[r.dayKeys.last]!.hr.last.v, hrMaxTanaka(r.age));
    return [c.spo2, c.steps, c.steps, c.stress, c.met, c.heart][z];
  }
}
