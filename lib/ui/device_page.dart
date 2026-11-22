import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/auto_sync.dart';
import '../data/live_heart.dart';
import '../data/repo.dart';
import '../data/sports.dart';
import '../theme/tokens.dart';
import 'about_page.dart';
import 'delete_ui.dart';
import 'health_page.dart';
import 'system_settings_panel.dart';
import '../data/map_style.dart';
import 'route_map.dart';
import 'widgets.dart';

/// Ajustes: pantalla principal con categorías; cada una abre su subpantalla.
class SettingsHome extends StatelessWidget {
  final VigorRepo repo; const SettingsHome(this.repo, {super.key});

  String get _conn => switch (repo.conn) { 'connected' => 'Conectada', 'connecting' => 'Conectando…', 'scanning' => 'Buscando…', 'disconnected' => 'Desconectada', _ => 'Sin conexión' };

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo.updater, builder: (context, _) => _body(context));

  Widget _body(BuildContext context) {
    final items = <(IconData, String, String, Widget Function())>[
      (Icons.watch_outlined, 'Pulsera', 'VIGOR · $_conn${repo.battery != null ? ' · ${repo.battery}%' : ''}', () => DevicePage(repo)),
      (Icons.monitor_heart_outlined, 'Mediciones y cadencia', 'Medición automática de la pulsera, intervalos y batería', () => MeasurementsPage(repo)),
      (Icons.sync_outlined, 'Sincronización', repo.autoOn ? 'Automática cada ${repo.autoMin} min · ${syncAgoText(repo.lastSync, repo.clock())}' : 'Desactivada · solo manual', () => SyncSettingsPage(repo)),
      (Icons.sports_score_outlined, 'Actividad y deportes', '${sportModes.length} modos · FCmáx y zonas', () => SportSettingsPage(repo)),
      (Icons.person_outline, 'Perfil', 'Edad ${repo.age} · meta ${repo.stepGoal} pasos', () => ProfilePage(repo)),
      (Icons.satellite_alt_outlined, 'Efemérides GPS', 'Ayuda al GPS de la pulsera, en segundo plano', () => AgpsPage(repo)),
      (Icons.favorite_border, 'Salud y compartir', repo.health.master ? 'Compartiendo con ${repo.health.gateway.platformName}' : 'Health Connect / Apple Salud · desactivado', () => HealthPage(repo)),
      (Icons.lock_outline, 'Privacidad y datos', 'Exportar y borrar tus datos', () => PrivacyPage(repo)),
      (Icons.palette_outlined, 'Apariencia', 'Tema de la app', () => AppearancePage(repo)),
      (Icons.system_update_outlined, 'Acerca de y actualizaciones', 'Versión ${repo.updater.versionName ?? ''}${repo.updater.available ? ' · hay una nueva' : ''}', () => AboutPage(repo)),
      (Icons.build_outlined, 'Avanzado y depuración', kDebugMode ? 'Herramientas de laboratorio y registro técnico' : 'Registro técnico', () => AdvancedPage(repo)),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, 120), children: [
      for (final e in items) Panel(padding: EdgeInsets.zero, child: Semantics(button: true, label: '${e.$2}. ${e.$3}', child: ExcludeSemantics(child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListenableBuilder(listenable: repo, builder: (ctx, _) => e.$4()))),
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 64), child: Padding(padding: const EdgeInsets.all(Sp.x4), child: Row(children: [
          Icon(e.$1, color: VC.of(context).accent), const SizedBox(width: Sp.x3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.$2, style: VT.heading(VC.of(context))), Text(e.$3, style: VT.caption(VC.of(context)))])),
          if (e.$2 == 'Acerca de y actualizaciones' && repo.updater.available) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.circle, size: 12, color: VC.of(context).heart)),
          const Icon(Icons.chevron_right),
        ]))),
      )))),
    ]);
  }
}

/// Marco de una subpantalla de ajustes.
class SettingsScaffold extends StatelessWidget {
  final String title; final List<Widget> children; const SettingsScaffold(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x8), children: children));
}

/// Pulsera: conexión, sincronización y búsqueda.
class DevicePage extends StatelessWidget {
  final VigorRepo repo; const DevicePage(this.repo, {super.key});

  String get _label => switch (repo.conn) { 'connected' => 'Conectada', 'connecting' => 'Conectando…', 'scanning' => 'Buscando…', 'disconnected' => 'Desconectada', _ => 'Sin conexión' };

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = repo; final ok = r.conn == 'connected';
    return SettingsScaffold('Pulsera', [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.circle, size: 12, color: ok ? c.steps : (r.conn == 'connecting' ? c.kcal : c.danger)), const SizedBox(width: Sp.x2),
          Text('VIGOR · $_label', style: VT.heading(c)), const Spacer(),
          if (r.battery != null) Text('${r.battery}%${r.charging ? ' ⚡' : ''}', style: VT.heading(c)),
        ]),
        if (r.syncing) ...[const SizedBox(height: Sp.x3), LinearProgressIndicator(value: r.progress > 0 && r.progress < 1 ? r.progress : null), const Note('Sincronizando…')]
        else if (r.lastSync != null) Note('${syncAgoText(r.lastSync, r.clock())} (${hm(r.lastSync!)})'),
        StatusLine(syncError: r.syncError, notice: r.notice),
        const SizedBox(height: Sp.x3),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          if (!ok && r.savedMac != null) FilledButton(onPressed: r.connectSaved, child: const Text('Conectar')),
          if (ok) FilledButton(onPressed: r.sync, child: const Text('Sincronizar')),
          if (ok) OutlinedButton(onPressed: r.findBand, child: const Text('Hacer vibrar')),
          if (ok) OutlinedButton(onPressed: r.disconnect, child: const Text('Desconectar')),
          OutlinedButton(onPressed: r.scan, child: Text(r.savedMac == null ? 'Buscar pulsera' : 'Buscar otra')),
        ]),
      ])),
      if (r.found.isNotEmpty) ...[
        const SectionHeader('Encontradas'),
        for (final d in r.found.values) Panel(padding: EdgeInsets.zero, child: ListTile(title: Text(d['name'].toString().isEmpty ? '(sin nombre)' : d['name']), subtitle: Text('${maskMac(d['mac']?.toString())} · ${d['rssi']} dBm'), onTap: () => r.connect(d['mac']))),
      ],
    ]);
  }
}

/// Perfil: edad y meta de pasos.
class ProfilePage extends StatelessWidget {
  final VigorRepo repo; const ProfilePage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = repo;
    return SettingsScaffold('Perfil', [
      Panel(child: Column(children: [
        _stepper(context, 'Edad', '${r.age} años', () => r.setPref('age', (r.age - 1).clamp(10, 100)), () => r.setPref('age', (r.age + 1).clamp(10, 100))),
        if (r.ageIsDefault) Align(alignment: Alignment.centerLeft, child: Note('Edad no indicada: se usa un valor por defecto.')),
        Row(children: [Expanded(child: Note('FCmáx estimada: ${hrMaxTanaka(r.age)} bpm')), const InfoButton('FCmáx estimada', 'FCmáx = 208 − 0,7·edad (Tanaka 2001), con un margen de ± 10 bpm. Se usa para las zonas de pulso y el TRIMP.')]),
        const Divider(),
        _stepper(context, 'Meta de pasos', '${r.stepGoal}', () => r.setPref('goal', (r.stepGoal - 500).clamp(1000, 40000)), () => r.setPref('goal', (r.stepGoal + 500).clamp(1000, 40000))),
      ])),
    ]);
  }
}

Widget _stepper(BuildContext ctx, String l, String v, VoidCallback minus, VoidCallback plus) => Row(children: [
      Expanded(child: Text(l, style: VT.body(VC.of(ctx)))), IconButton(tooltip: 'Menos', onPressed: minus, icon: const Icon(Icons.remove_circle_outline)),
      SizedBox(width: 72, child: Text(v, textAlign: TextAlign.center, style: VT.heading(VC.of(ctx)))), IconButton(tooltip: 'Más', onPressed: plus, icon: const Icon(Icons.add_circle_outline))]);

/// Actividad y deportes.
class SportSettingsPage extends StatelessWidget {
  final VigorRepo repo; const SportSettingsPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final route = sportModes.where((m) => m.tracksRoute).length;
    return SettingsScaffold('Actividad y deportes', [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${sportModes.length} modos: $route de recorrido (con GPS) y ${sportModes.length - route} de interior.', style: VT.body(c))),
          const InfoButton('Modos de actividad', 'La SDK no informa de qué modos admite tu pulsera; si no admite el elegido, no empezará. La clasificación recorrido/interior es de Vigor. Las series o repeticiones no están disponibles (no verificado).')]),
      ])),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('FCmáx estimada: ${hrMaxTanaka(repo.age)} bpm', style: VT.body(c))), const InfoButton('FCmáx estimada', 'FCmáx = 208 − 0,7·edad (Tanaka 2001), con un margen de ± 10 bpm. Se usa para las zonas de pulso y el TRIMP. Cambia tu edad en Perfil.')]),
      ])),
    ]);
  }
}

/// Mediciones y cadencia: medición automática de la pulsera (SDK) y métricas experimentales.
class MeasurementsPage extends StatefulWidget {
  final VigorRepo repo; const MeasurementsPage(this.repo, {super.key});
  @override
  State<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends State<MeasurementsPage> {
  VigorRepo get r => widget.repo;
  @override
  void initState() { super.initState(); if (r.conn == 'connected' && r.autoMeasures == null) r.readAutoMeasure(); }

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final ok = r.conn == 'connected'; final list = r.autoMeasures;
    return SettingsScaffold('Mediciones y cadencia', [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [FilledButton.icon(onPressed: ok ? r.readAutoMeasure : null, icon: const Icon(Icons.refresh), label: const Text('Leer de la pulsera')), const Spacer(),
          const InfoButton('Mediciones automáticas', 'La pulsera mide sola en segundo plano. Puedes activar cada medición y, si la pulsera lo permite, elegir cada cuántos minutos. Medir más a menudo da más lecturas pero gasta más batería (consumo exacto no medido). No verificado con la pulsera: la SDK documenta estas funciones, pero esta pulsera puede rechazar valores.')]),
        if (!ok) const Note('Conecta la pulsera para leer o cambiar la cadencia.'),
        if (r.autoUnsupported) const Note('Esta pulsera no admite ajustar la medición automática.'),
        if (r.autoMsg != null) Semantics(liveRegion: true, child: Note(r.autoMsg!)),
      ])),
      if (list != null && list.isEmpty && !r.autoUnsupported) const Note('La pulsera no devolvió ninguna medición ajustable.'),
      for (final m in list ?? const <AutoMeasure>[]) Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(m.label, style: VT.heading(c)), subtitle: Text(m.on ? (m.interval > 0 ? 'Cada ${m.interval} min' : 'Activada') : 'Desactivada', style: VT.caption(c)),
          value: m.on, onChanged: ok ? (v) => r.setAutoMeasure(m.type, v) : null),
        if (m.intervalModify && m.on && m.choices.isNotEmpty) ...[
          Text('Intervalo', style: VT.caption(c)), const SizedBox(height: Sp.x1),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final v in m.choices.where((v) => v <= 60 || v % 60 == 0)) ChoiceChip(label: Text('$v min'), selected: v == m.interval, onSelected: ok ? (_) => r.setAutoMeasure(m.type, true, interval: v) : null),
          ]),
          if (autoBatteryWarning(m.interval) != null) Note('Menos de 10 min gasta más batería.'),
        ] else if (m.on) const Note('Esta pulsera no permite cambiar el intervalo de esta medición.'),
      ])),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Pulso en vivo con la app abierta', style: VT.heading(c)),
          subtitle: Text(r.liveOn ? 'Mide el pulso cada ${r.liveSec} s mientras ves Hoy' : 'Desactivado: solo mide al tocar el corazón', style: VT.caption(c)),
          value: r.liveOn, onChanged: (v) => r.setLiveOn(v)),
        if (r.liveOn) ...[
          Text('Intervalo', style: VT.caption(c)), const SizedBox(height: Sp.x1),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [for (final v in LiveHeart.allowedIntervals) ChoiceChip(label: Text('$v s'), selected: v == r.liveSec, onSelected: (_) => r.setLiveSec(v))]),
        ],
        const Align(alignment: Alignment.centerRight, child: InfoButton('Pulso en vivo', 'Cada medición enciende el sensor óptico unos segundos: medir a menudo gasta batería de la pulsera. Solo funciona con la app abierta en Hoy y la pulsera conectada; se detiene al sincronizar, durante un deporte y con la batería de la pulsera por debajo del 20 %. Función implementada pero no probada con la pulsera.')),
      ])),
      const SectionHeader('Experimentales'),
      Panel(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Mostrar métricas experimentales', style: VT.body(c)),
        subtitle: Text('Glucosa y análisis de sangre estimados.', style: VT.caption(c)),
        value: r.showExperimental, onChanged: (v) => _toggleExp(context, v))),
    ]);
  }

  Future<void> _toggleExp(BuildContext context, bool v) async {
    if (!v) { await r.setExperimental(false); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: infoTitle('Métricas experimentales', 'La FDA (21‑02‑2024) no ha autorizado ningún reloj ni anillo para medir la glucosa sin pinchar la piel y recomienda no usarlos: un valor erróneo puede llevar a errores de medicación. Para los componentes sanguíneos no hay validación en muñeca. Son estimaciones del fabricante, sin rangos ni interpretación. No las uses para decidir medicación ni tratamientos.'),
      content: const Text('Estimaciones sin validar. No sirven para decidir medicación.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entiendo, activar'))]));
    if (ok == true) await r.setExperimental(true);
  }
}

class AgpsPage extends StatelessWidget {
  final VigorRepo repo; const AgpsPage(this.repo, {super.key});
  String _agps(Map a) {
    String f(dynamic ms) { final v = (ms as num?)?.toInt() ?? 0; if (v == 0) return 'nunca'; final t = DateTime.fromMillisecondsSinceEpoch(v); return '${t.day}/${t.month} ${hm(t)}'; }
    final err = (a['lastError'] ?? '').toString();
    return 'Última descarga: ${f(a['downloadedAt'])}\nÚltimo envío a la pulsera: ${f(a['transferredAt'])}\n${a['pending'] == true ? 'Envío pendiente' : 'Al día'}${err.isEmpty ? '' : '\nÚltimo aviso: $err'}';
  }
  @override
  Widget build(BuildContext context) => SettingsScaffold('Efemérides GPS', [
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_agps(repo.agps), style: VT.body(VC.of(context))),
          const Note('Se actualizan solas en segundo plano.'),
        ])),
      ]);
}

class PrivacyPage extends StatelessWidget {
  final VigorRepo repo; const PrivacyPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) => SettingsScaffold('Privacidad y datos', [MapSettingPanel(repo), PrivacyPanel(repo), ManageDataPanel(repo)]);
}

class AppearancePage extends StatelessWidget {
  final VigorRepo repo; const AppearancePage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return SettingsScaffold('Apariencia', [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tema', style: VT.heading(c)), const SizedBox(height: Sp.x2),
        SegmentedButton<int>(showSelectedIcon: false, style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
          segments: const [ButtonSegment(value: 0, label: Text('Oscuro')), ButtonSegment(value: 1, label: Text('Claro')), ButtonSegment(value: 2, label: Text('Sistema'))],
          selected: {repo.themeMode}, onSelectionChanged: (v) => repo.setThemeMode(v.first)),
      ])),
    ]);
  }
}

class AdvancedPage extends StatelessWidget {
  final VigorRepo repo; const AdvancedPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return SettingsScaffold('Avanzado y depuración', [
      if (kDebugMode) Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Note('Herramientas de depuración. El resultado va al registro técnico.'),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          OutlinedButton(onPressed: repo.conn == 'connected' ? repo.debugSleepDump : null, child: const Text('Volcado de sueño')),
          OutlinedButton(onPressed: repo.debugClearDumps, child: const Text('Borrar volcados')),
          for (final e in const {'pressure': 'Sondeo estrés', 'met': 'Sondeo MET', 'temp': 'Sondeo temperatura', 'hrv': 'Sondeo HRV'}.entries)
            OutlinedButton(onPressed: repo.conn == 'connected' ? () => repo.debugProbe(e.key) : null, child: Text(e.value)),
        ]),
      ])),
      const SectionHeader('Registro técnico'),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (repo.logs.isEmpty) Text('Sin mensajes.', style: VT.caption(c)),
        for (final l in repo.logs.take(60)) Text(l, style: TextStyle(fontSize: 11, color: c.muted)),
      ])),
    ]);
  }
}

/// Privacidad y datos: exportar y borrar. Todo local; no se envía nada a internet.
const _kPrivacyInfo = 'Tus datos se guardan solo en este móvil. Al exportar, Vigor prepara una copia temporal privada y abre el selector de compartir de Android: tú eliges dónde guardarla o a qué app enviarla. Lo que elijas queda fuera del control de Vigor (otra app o carpeta puede conservarlo o leerlo). La copia temporal se borra al volver a abrir esta pantalla y con «Borrar todos». Vigor no envía nada a internet por su cuenta. Solo si activas «Salud y compartir», Vigor escribe en Health Connect / Apple Salud (en tu móvil, sin leer nada de allí): lo que ya enviaste se borra desde esa pantalla, no con «Borrar todos».';

class PrivacyPanel extends StatefulWidget {
  final VigorRepo repo; const PrivacyPanel(this.repo, {super.key});
  @override
  State<PrivacyPanel> createState() => _PrivacyPanelState();
}

class _PrivacyPanelState extends State<PrivacyPanel> {
  VigorRepo get repo => widget.repo;
  @override
  void initState() { super.initState(); repo.clearExport(); } // H2: al abrir la pantalla no queda ninguna copia anterior

  Future<void> _wipe(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: infoTitle('Borrar todos mis datos', 'Se borrarán de este móvil todos los datos de la pulsera que guarda Vigor (pulso, SpO₂, variabilidad, sueño, actividades y rutas), las efemérides descargadas y la copia temporal de exportación (no las copias que ya hayas guardado o enviado fuera de Vigor, ni lo escrito en Health Connect / Apple Salud). No se borra nada de la pulsera ni de otras apps, y se conservan el emparejamiento, tu edad y tu meta de pasos. No se puede deshacer.'),
      content: const Text('Se borran los datos de este móvil. No se puede deshacer.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar todo'))]));
    if (ok == true) await repo.wipeData();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo, builder: (context, _) {
    final c = VC.of(context); final busy = repo.privacyBusy;
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Note('Tus datos se guardan solo en este móvil. Vigor no envía nada a internet por su cuenta.')), InfoButton('Privacidad', _kPrivacyInfo)]),
      const SizedBox(height: Sp.x3),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
        OutlinedButton.icon(onPressed: busy ? null : repo.exportData, icon: const Icon(Icons.upload_file_outlined, size: 18), label: const Text('Exportar mis datos')),
        OutlinedButton.icon(onPressed: busy || repo.syncing ? null : () => _wipe(context), style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger.withValues(alpha: .6))),
          icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Borrar todos mis datos')),
      ]),
      if (repo.syncing) const Note('Hay una sincronización en curso: no se puede borrar hasta que termine.'),
      if (repo.privacyMsg != null) Semantics(liveRegion: true, container: true, label: repo.privacyMsg, child: ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: Sp.x2), child: Text(repo.privacyMsg!, style: VT.body(c))))),
    ]));
  });
}


/// Sincronización automática (DEV_012): interruptor, intervalo, pantalla encendida, estado y ajustes de batería.
class SyncSettingsPage extends StatelessWidget {
  final VigorRepo repo; const SyncSettingsPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final r = repo; final ok = r.conn == 'connected';
    return SettingsScaffold('Sincronización', [
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Sincronización automática', style: VT.heading(c)),
          subtitle: Text(r.autoOn ? 'La pulsera se lee sola, con la app abierta o cerrada' : 'Desactivada: solo sincronizas tú', style: VT.caption(c)),
          value: r.autoOn, onChanged: (v) => r.setAutoSync(enabled: v)),
        if (r.autoOn) ...[
          Text('Intervalo', style: VT.caption(c)), const SizedBox(height: Sp.x1),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [for (final v in kAutoSyncIntervals) ChoiceChip(label: Text('$v min'), selected: v == r.autoMin, onSelected: (_) => r.setAutoSync(minutes: v))]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Solo con la pantalla encendida', style: VT.body(c)),
            subtitle: Text('Con la pantalla apagada no se sincroniza: ahorra batería.', style: VT.caption(c)),
            value: r.screenOnly, onChanged: (v) => r.setAutoSync(screenOnlyOnly: v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Enviar a Health Connect sin abrir la app', style: VT.body(c)),
            subtitle: Text(r.health.master ? 'Con la app cerrada; si no, al abrir Vigor.' : 'Activa «Salud y compartir» para usarlo.', style: VT.caption(c)),
            value: r.bgExport, onChanged: (v) => r.setAutoSync(bgExportOn: v)),
        ],
      ])),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.syncing ? 'Sincronizando…' : syncAgoText(r.lastSync, r.clock()), style: VT.heading(c)),
        if (r.lastBg != null) Note('Última pasada en segundo plano: ${hm(r.lastBg!)} · ${r.bgResult}'),
        const SizedBox(height: Sp.x2),
        FilledButton.icon(onPressed: ok && !r.syncing ? r.sync : null, icon: const Icon(Icons.sync), label: const Text('Sincronizar ahora')),
        if (!ok) const Note('Conecta la pulsera para sincronizar a mano.'),
      ])),
      SystemSettingsPanel(r),
      const Row(children: [Expanded(child: Note('En segundo plano, Android decide cuándo se ejecuta.')), InfoButton('Sincronización en segundo plano', 'La sincronización en segundo plano se ha comprobado con la pulsera real en un solo móvil (Xiaomi, Android 10) y una sola vez. El sistema decide cuándo ejecutarla: el intervalo mínimo de Android es de 15 min y puede retrasarse.')]),
    ]);
  }
}


/// Mapa de fondo de las rutas: interruptor y aspecto. Apagado: no se descarga ningún mapa y la ruta se dibuja sola.
/// Ruta de ejemplo para la vista previa (un paseo inventado alrededor de un punto fijo; NO es tu ubicación).
const List<(double, double)> kPreviewRoute = [
  (40.41700, -3.68500), (40.41760, -3.68410), (40.41850, -3.68350), (40.41960, -3.68340), (40.42050, -3.68400), (40.42090, -3.68510),
  (40.42050, -3.68620), (40.41960, -3.68690), (40.41850, -3.68680), (40.41760, -3.68620), (40.41700, -3.68520),
];

class MapSettingPanel extends StatefulWidget {
  final VigorRepo repo; final bool preview; const MapSettingPanel(this.repo, {super.key, this.preview = true});
  @override
  State<MapSettingPanel> createState() => _MapSettingPanelState();
}

class _MapSettingPanelState extends State<MapSettingPanel> {
  bool _showPreview = false; // la vista previa descarga mapa: solo si se pide
  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return ListenableBuilder(listenable: repo, builder: (context, _) {
      final c = VC.of(context);
      return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mapa de fondo', style: VT.heading(c)),
            Text(repo.mapOn ? 'Las rutas se muestran sobre un mapa. Se pide la zona a su servidor, nunca tus datos.' : 'Apagado: no se descarga ningún mapa y la ruta se dibuja sola.', style: VT.caption(c)),
          ])),
          Semantics(label: 'Mapa de fondo', child: Switch(value: repo.mapOn, onChanged: repo.setMapOn)),
        ]),
        if (repo.mapOn) ...[
          const SizedBox(height: Sp.x3), Text('Aspecto', style: VT.caption(c)), const SizedBox(height: Sp.x2),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final m in MapStyle.values) Semantics(button: true, selected: repo.mapStyle == m, label: '${m.label}. ${m.hint}', child: ExcludeSemantics(child: ChoiceChip(
                label: Text(m.label), selected: repo.mapStyle == m, onSelected: (_) => repo.setMapStyle(m), materialTapTargetSize: MaterialTapTargetSize.padded, visualDensity: VisualDensity.standard))),
          ]),
          Padding(padding: const EdgeInsets.only(top: Sp.x2), child: Text(repo.mapStyle.hint, style: VT.caption(c))),
          if (widget.preview) ...[
            if (!_showPreview) Align(alignment: Alignment.centerLeft, child: TextButton.icon(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => setState(() => _showPreview = true), icon: const Icon(Icons.map_outlined), label: const Text('Ver vista previa')))
            else Padding(padding: const EdgeInsets.only(top: Sp.x3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RouteMap(const [kPreviewRoute], style: repo.mapStyle, height: 190),
              Padding(padding: const EdgeInsets.only(top: Sp.x1), child: Text('Vista previa con una ruta de ejemplo', style: VT.caption(c))),
            ])),
          ],
        ],
      ]));
    });
  }
}
