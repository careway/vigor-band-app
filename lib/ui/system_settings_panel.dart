import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../data/startup_permissions.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Ajustes del sistema que Vigor necesita pero NO puede conceder (no son permisos con ventana de «permitir»): muestra su estado real
/// consultado al sistema y ofrece un acceso directo a cada pantalla. Se refresca al volver de los ajustes.
class SystemSettingsPanel extends StatefulWidget {
  final VigorRepo repo; const SystemSettingsPanel(this.repo, {super.key});
  @override
  State<SystemSettingsPanel> createState() => _SystemSettingsPanelState();
}

class _SystemSettingsPanelState extends State<SystemSettingsPanel> with WidgetsBindingObserver {
  SystemSettingsStatus? st;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) _load(); }
  Future<void> _load() async { final x = await widget.repo.systemSettings(); if (mounted) setState(() => st = x); }

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context); final s = st;
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ajustes del sistema', style: VT.heading(c)),
      const Note('Son ajustes de Android, no permisos con ventana de «permitir»: Vigor puede consultar si los tienes y llevarte a su pantalla, pero no puede activarlos por ti. Sin ellos, la sincronización con la app cerrada puede retrasarse o no ocurrir.'),
      if (s == null) const Padding(padding: EdgeInsets.all(Sp.x3), child: Center(child: CircularProgressIndicator()))
      else ...[
        _Row(icon: Icons.battery_saver_outlined, title: 'Batería: ejecutar sin restricciones', ok: s.batteryUnrestricted,
            okText: 'Vigor puede sincronizar sin restricciones de batería.', noText: 'Android puede retrasar o cerrar la sincronización.',
            onOpen: () => widget.repo.openSystemSetting('battery')),
        if (s.xiaomi) _Row(icon: Icons.rocket_launch_outlined, title: 'Inicio automático (Xiaomi)', ok: s.autostart == true, unknown: s.autostart == null,
            okText: 'El sistema puede arrancar Vigor para sincronizar.', noText: 'El sistema no deja arrancar Vigor cerrado y no se sincroniza nada hasta que lo abras.',
            unknownText: 'No se puede consultar en este móvil: ábrelo para revisarlo.', onOpen: () => widget.repo.openSystemSetting('autostart')),
        _Row(icon: Icons.system_update_outlined, title: 'Instalar actualizaciones', ok: s.installApps,
            okText: 'Vigor puede abrir el instalador al actualizarse.', noText: 'Se pedirá antes de descargar la primera actualización.',
            onOpen: () => widget.repo.openSystemSetting('installApps')),
      ],
    ]));
  }
}

class _Row extends StatelessWidget {
  final IconData icon; final String title, okText, noText; final String? unknownText; final bool ok, unknown; final VoidCallback onOpen;
  const _Row({required this.icon, required this.title, required this.ok, required this.okText, required this.noText, required this.onOpen, this.unknown = false, this.unknownText});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    final state = unknown ? (Icons.help_outline, unknownText ?? '', 'Estado desconocido') : ok ? (Icons.check_circle_outline, okText, 'Concedido') : (Icons.warning_amber_outlined, noText, 'Sin conceder');
    return Padding(padding: const EdgeInsets.only(top: Sp.x3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: c.accent), const SizedBox(width: Sp.x2), Expanded(child: Text(title, style: VT.heading(c)))]),
      const SizedBox(height: Sp.x1),
      Semantics(container: true, label: '$title. ${state.$3}. ${state.$2}', child: ExcludeSemantics(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(state.$1, size: 18, color: c.muted), const SizedBox(width: Sp.x2), Expanded(child: Text('${state.$3}: ${state.$2}', style: VT.body(c))),
      ]))),
      const SizedBox(height: Sp.x2),
      SizedBox(height: 48, child: OutlinedButton.icon(onPressed: onOpen, icon: const Icon(Icons.open_in_new), label: Text(ok ? 'Abrir ajuste' : 'Abrir ajuste para activarlo'))),
    ]));
  }
}
