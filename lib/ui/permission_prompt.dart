import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../data/health_sync.dart';
import '../data/repo.dart';
import '../data/startup_permissions.dart';
import '../theme/tokens.dart';

/// Al iniciar la app: si faltan permisos, explica para qué sirve cada uno y los pide. Solo UNA vez por inicialización de la app
/// (no se repite al volver a primer plano ni al rechazar). Si ya están todos concedidos no muestra nada.
/// [android]: solo para pruebas (por defecto, la plataforma real; en iPhone todavía no hay nada que pedir).
Future<void> askMissingPermissionsOnce(BuildContext context, VigorRepo repo, {bool? android}) async {
  if (!(android ?? Platform.isAndroid)) return;
  if (StartupPermissions.askedThisLaunch) return;
  try { await repo.ready.timeout(const Duration(seconds: 15)); } catch (_) {}
  if (!context.mounted || StartupPermissions.askedThisLaunch) return;
  final st = await repo.permissionStatus();
  if (repo.health.master) { try { await repo.health.refreshPermissions(); } catch (_) {} }
  final needs = StartupPermissions.plan(nativeMissing: st.missing, healthMissing: repo.health.master && repo.health.state == HealthState.needsPermission);
  if (needs.isEmpty || !context.mounted) return;
  StartupPermissions.markAsked(); // una vez por arranque, se acepte o no
  final blocked = st.blocked && st.missing.isNotEmpty;
  final go = await showDialog<bool>(context: context, builder: (c) => _PermissionDialog(needs, blocked: blocked));
  if (go != true) return;
  if (st.missing.isNotEmpty) {
    if (blocked) { await repo.openBatterySettings(); } // la ficha de la app: ahí se activan a mano
    else { await repo.requestStartupPermissions(); }
  }
  if (needs.any((n) => n.kind == PermKind.healthConnect)) { try { await repo.health.askMissingPermissions(); } catch (_) {} }
  repo.auto.onResume(); // con Bluetooth concedido, conecta y sincroniza sin esperar
}

class _PermissionDialog extends StatelessWidget {
  final List<PermNeed> needs; final bool blocked;
  const _PermissionDialog(this.needs, {required this.blocked});
  @override
  Widget build(BuildContext context) {
    final c = VC.of(context);
    return AlertDialog(
      title: const Text('Permisos que necesita Vigor'),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Faltan estos permisos. Te explicamos para qué sirve cada uno; si prefieres no darlos, la app funcionará con menos funciones.'),
        const SizedBox(height: Sp.x3),
        for (final n in needs) Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: VT.heading(c)), const SizedBox(height: Sp.x1), Text(n.why),
        ])),
        if (blocked) const Text('Android ya no mostrará la ventana de permisos: te llevaremos a los ajustes de Vigor para activarlos allí.'),
        const SizedBox(height: Sp.x2),
        Text('Tus datos no salen del móvil. Solo te lo preguntamos una vez cada vez que abres la app.', style: TextStyle(color: c.muted)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(blocked ? 'Abrir ajustes' : 'Continuar')),
      ],
    );
  }
}
