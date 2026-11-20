import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../data/analysis.dart';
import '../data/live_heart.dart';
import '../data/repo.dart';
import '../data/sports.dart';
import '../theme/tokens.dart';
import 'about_page.dart';
import 'widgets.dart';

/// Ajustes: pantalla principal con categorías; cada una abre su subpantalla.
class SettingsHome extends StatelessWidget {
  final VigorRepo repo; const SettingsHome(this.repo, {super.key});

  String get _conn => switch (repo.conn) { 'connected' => 'Conectada', 'connecting' => 'Conectando…', 'scanning' => 'Buscando…', 'disconnected' => 'Desconectada', _ => 'Sin conexión' };

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget Function())>[
      (Icons.watch_outlined, 'Pulsera', 'VIGOR · $_conn${repo.battery != null ? ' · ${repo.battery}%' : ''}', () => DevicePage(repo)),
      (Icons.monitor_heart_outlined, 'Mediciones y cadencia', 'Medición automática de la pulsera, intervalos y batería', () => MeasurementsPage(repo)),
      (Icons.sports_score_outlined, 'Actividad y deportes', '${sportModes.length} modos · FCmáx y zonas', () => SportSettingsPage(repo)),
      (Icons.person_outline, 'Perfil', 'Edad ${repo.age} · meta ${repo.stepGoal} pasos', () => ProfilePage(repo)),
      (Icons.satellite_alt_outlined, 'Efemérides GPS', 'Ayuda al GPS de la pulsera, en segundo plano', () => AgpsPage(repo)),
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
        if (r.savedMac != null) Note('Pulsera guardada: ${maskMac(r.savedMac)}'),
        if (r.syncing) ...[const SizedBox(height: Sp.x3), LinearProgressIndicator(value: r.progress > 0 && r.progress < 1 ? r.progress : null), const Note('Sincronizando…')]
        else if (r.lastSync != null) Note('Última sincronización: ${hm(r.lastSync!)}'),
        const SizedBox(height: Sp.x3),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          if (!ok && r.savedMac != null) FilledButton(onPressed: r.connectSaved, child: const Text('Conectar')),
          if (ok) FilledButton(onPressed: r.sync, child: const Text('Sincronizar')),
          if (ok) OutlinedButton(onPressed: r.findBand, child: const Text('Hacer vibrar')),
          if (ok) OutlinedButton(onPressed: r.disconnect, child: const Text('Desconectar')),
          OutlinedButton(onPressed: r.scan, child: Text(r.savedMac == null ? 'Buscar pulsera' : 'Buscar otra')),
        ]),
        if (r.savedMac != null) const Note('Reconecta por la MAC guardada, sin escanear: no necesita la ubicación del móvil. La ubicación solo se pide para buscar una pulsera nueva (Android ≤ 11).'),
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
        if (r.ageIsDefault) Align(alignment: Alignment.centerLeft, child: Note('Edad no indicada: se usa ${VigorRepo.defaultAge} años por defecto. Ajústala para que la FCmáx y las zonas sean más fieles.')),
        Align(alignment: Alignment.centerLeft, child: Note('FCmáx estimada: ${hrMaxTanaka(r.age)} ± 10 bpm (Tanaka 2001)')),
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
        Text('${sportModes.length} modos de la SDK de Veepoo: $route de recorrido (ruta con GPS) y ${sportModes.length - route} de interior o sin GPS.', style: VT.body(c)),
        const Note('La SDK no informa de qué modos admite tu pulsera; si no admite el elegido, no empezará. La clasificación recorrido/interior es de Vigor.'),
        const Note('Los datos de series o repeticiones no los expone la SDK que usa Vigor (no verificado).'),
      ])),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FCmáx estimada: ${hrMaxTanaka(repo.age)} ± 10 bpm', style: VT.body(c)),
        const Note('Se usa para las zonas de pulso y el TRIMP (Tanaka 2001). Cambia tu edad en Perfil.'),
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
        const Note('La pulsera mide sola en segundo plano. Aquí puedes activar o desactivar cada medición y, si la pulsera lo permite, cada cuántos minutos. Medir más a menudo da más lecturas pero gasta más batería (consumo exacto no medido).'),
        const SizedBox(height: Sp.x2),
        FilledButton.icon(onPressed: ok ? r.readAutoMeasure : null, icon: const Icon(Icons.refresh), label: const Text('Leer de la pulsera')),
        if (!ok) const Note('Conecta la pulsera para leer o cambiar la cadencia.'),
        if (r.autoUnsupported) const Note('Esta pulsera no admite ajustar la medición automática (según la SDK).'),
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
          if (autoBatteryWarning(m.interval) != null) Note(autoBatteryWarning(m.interval)!),
        ] else if (m.on) const Note('Esta pulsera no permite cambiar el intervalo de esta medición.'),
      ])),
      const Note('No verificado con la pulsera: la SDK documenta estas funciones, pero esta pulsera puede rechazar valores. No existe en la SDK un ajuste del muestreo durante el deporte.'),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Pulso en vivo con la app abierta', style: VT.heading(c)),
          subtitle: Text(r.liveOn ? 'Mide el pulso cada ${r.liveSec} s mientras ves Hoy' : 'Desactivado: solo mide al tocar el corazón', style: VT.caption(c)),
          value: r.liveOn, onChanged: (v) => r.setLiveOn(v)),
        if (r.liveOn) ...[
          Text('Intervalo', style: VT.caption(c)), const SizedBox(height: Sp.x1),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [for (final v in LiveHeart.allowedIntervals) ChoiceChip(label: Text('$v s'), selected: v == r.liveSec, onSelected: (_) => r.setLiveSec(v))]),
        ],
        const Note('Cada medición enciende el sensor óptico unos segundos: medir a menudo gasta batería de la pulsera (más cuanto más corto el intervalo). Solo funciona con la app abierta en Hoy y la pulsera conectada; se detiene al sincronizar, durante un deporte y con la batería de la pulsera por debajo del 20 %. Función implementada pero no probada con la pulsera.'),
      ])),
      const SectionHeader('Experimentales'),
      Panel(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Mostrar métricas experimentales', style: VT.body(c)),
        subtitle: Text('Glucosa y componentes sanguíneos estimados por el fabricante. Apagado de serie.', style: VT.caption(c)),
        value: r.showExperimental, onChanged: (v) => _toggleExp(context, v))),
    ]);
  }

  Future<void> _toggleExp(BuildContext context, bool v) async {
    if (!v) { await r.setExperimental(false); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Métricas experimentales'),
      content: const Text('La FDA (21‑02‑2024) no ha autorizado ningún reloj ni anillo para medir la glucosa sin pinchar la piel y recomienda no usarlos: un valor erróneo puede llevar a errores de medicación. Para los componentes sanguíneos no hay validación en muñeca. Son estimaciones del fabricante, sin rangos ni interpretación. No las uses para decidir medicación ni tratamientos.'),
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
          const Note('Se descargan una vez al día y se envían a la pulsera cuando está a mano. Todo en segundo plano, sin avisos. Solo afectan a los modos de recorrido.'),
        ])),
      ]);
}

class PrivacyPage extends StatelessWidget {
  final VigorRepo repo; const PrivacyPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) => SettingsScaffold('Privacidad y datos', [PrivacyPanel(repo)]);
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
        const Note('Oscuro es el tema principal. El tema claro está pendiente de revisión visual en el móvil.'),
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
        const Note('Herramientas de laboratorio (solo compilaciones de depuración). El resultado va al registro técnico; el volcado de sueño queda en el directorio privado de la app (files/debug), sin MAC. Con la pulsera conectada y sin sincronizar.'),
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
      title: const Text('Borrar todos mis datos'),
      content: const Text('Se borrarán de este móvil todos los datos de la pulsera que guarda Vigor (pulso, SpO₂, variabilidad, sueño, actividades y rutas), las efemérides descargadas y la copia temporal de exportación (no las copias que ya hayas guardado o enviado fuera de Vigor). '
          'No se borra nada de la pulsera ni de otras apps, y se conservan el emparejamiento, tu edad y tu meta de pasos. No se puede deshacer.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar todo'))]));
    if (ok == true) await repo.wipeData();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo, builder: (context, _) {
    final c = VC.of(context); final busy = repo.privacyBusy;
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Note('Tus datos se guardan solo en este móvil. Al exportar, Vigor prepara una copia temporal privada y abre el selector de compartir de Android: tú eliges dónde guardarla o a qué app enviarla. Lo que elijas queda fuera del control de Vigor (otra app o carpeta puede conservarlo o leerlo). La copia temporal se borra al volver a abrir esta pantalla y con «Borrar todos». Vigor no envía nada a internet por su cuenta.'),
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
