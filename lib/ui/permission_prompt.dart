import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../data/health_sync.dart';
import '../data/repo.dart';
import '../data/startup_permissions.dart';
import '../theme/tokens.dart';

/// Qué falta ahora mismo: permisos de ejecución (ventana de «permitir») y ajustes del sistema (se consultan y se abre su pantalla).
Future<({List<PermNeed> needs, bool blocked, List<String> missing})> _computePlan(VigorRepo repo) async {
  final st = await repo.permissionStatus();
  if (repo.health.master) { try { await repo.health.refreshPermissions(); } catch (_) {} }
  final sys = await repo.systemSettings();
  final autoOn = repo.auto.enabled; // la excepción de batería y el inicio automático solo importan si la sincronización automática está activada
  final needs = StartupPermissions.plan(
      nativeMissing: st.missing, healthMissing: repo.health.master && repo.health.state == HealthState.needsPermission,
      batteryRestricted: autoOn && !sys.batteryUnrestricted, autostartDenied: autoOn && sys.xiaomi && sys.autostart == false);
  return (needs: needs, blocked: st.blocked && st.missing.isNotEmpty, missing: st.missing);
}

/// Al iniciar la app: si falta algo, explica para qué sirve cada cosa y lo pide. Solo UNA vez por inicialización de la app
/// (no se repite al volver a primer plano ni al rechazar). Si no falta nada no muestra nada.
/// [android]: solo para pruebas (por defecto, la plataforma real; en iPhone todavía no hay nada que pedir).
Future<void> askMissingPermissionsOnce(BuildContext context, VigorRepo repo, {bool? android}) async {
  if (!(android ?? Platform.isAndroid)) return;
  if (StartupPermissions.askedThisLaunch) return;
  try { await repo.ready.timeout(const Duration(seconds: 15)); } catch (_) {}
  if (!context.mounted || StartupPermissions.askedThisLaunch) return;
  final plan = await _computePlan(repo);
  if (plan.needs.isEmpty || !context.mounted) return;
  StartupPermissions.markAsked(); // una vez por arranque, se acepte o no
  final go = await showDialog<bool>(context: context, builder: (c) => _PermissionDialog(plan.needs, blocked: plan.blocked, repo: repo));
  if (go != true) return;
  final now = await _computePlan(repo); // por si ya resolvió algo desde el propio aviso
  if (now.missing.isNotEmpty) {
    if (now.blocked) { await repo.openSystemSetting('details'); } // la ficha de la app: ahí se activan a mano
    else { await repo.requestStartupPermissions(); }
  }
  if (now.needs.any((n) => n.kind == PermKind.healthConnect)) { try { await repo.health.askMissingPermissions(); } catch (_) {} }
  repo.auto.onResume(); // con Bluetooth concedido, conecta y sincroniza sin esperar
}

class _PermissionDialog extends StatefulWidget {
  final List<PermNeed> needs; final bool blocked; final VigorRepo repo;
  const _PermissionDialog(this.needs, {required this.blocked, required this.repo});
  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> with WidgetsBindingObserver {
  late List<PermNeed> needs = widget.needs;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  /// Al volver de una pantalla de ajustes del sistema: se vuelve a consultar y se quita lo que ya está concedido.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if (s != AppLifecycleState.resumed) return;
    final p = await _computePlan(widget.repo);
    if (!mounted) return;
    if (p.needs.isEmpty) { Navigator.pop(context, false); return; }
    setState(() => needs = p.needs);
  }

  String _which(PermKind k) => k == PermKind.autostart ? 'autostart' : 'battery';

  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    final hasRuntime = needs.any((n) => !n.isSystemSetting);
    return AlertDialog(
      title: const Text('Permisos que necesita Vigor'),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Faltan estas cosas. Te explicamos para qué sirve cada una; si prefieres no darlas, la app funcionará con menos funciones.'),
        const SizedBox(height: Sp.x3),
        for (final n in needs) Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: VT.heading(c)), const SizedBox(height: Sp.x1), Text(n.why),
          if (n.isSystemSetting) Padding(padding: const EdgeInsets.only(top: Sp.x2), child: SizedBox(height: 48, child: OutlinedButton.icon(
              onPressed: () => widget.repo.openSystemSetting(_which(n.kind)), icon: const Icon(Icons.open_in_new), label: const Text('Abrir ajustes')))),
        ])),
        if (widget.blocked && hasRuntime) const Text('Android ya no mostrará la ventana de permisos: te llevaremos a los ajustes de Vigor para activarlos allí.'),
        const SizedBox(height: Sp.x2),
        Text('Tus datos no salen del móvil. Solo te lo preguntamos una vez cada vez que abres la app.', style: TextStyle(color: c.muted)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(hasRuntime ? 'Ahora no' : 'Cerrar')),
        if (hasRuntime) FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.blocked ? 'Abrir ajustes' : 'Continuar')),
      ],
    );
  }
}
