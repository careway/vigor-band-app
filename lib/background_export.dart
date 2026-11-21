import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'data/health_sync.dart';
import 'data/repo.dart';

/// Resultado de una pasada sin interfaz: OK, PARTIAL (quedó algo por enviar), NO_PERMISSION, UNAVAILABLE, OFF (el interruptor general está apagado: no se escribe nada).
Future<String> runHeadlessExport({required Map prefs, required HealthSync health, required Future<void> Function() reload, required Future<void> Function() clearDirty}) async {
  if (prefs['hcOn'] != 1) return 'OFF'; // nunca se escribe en Health Connect si el usuario lo tiene desactivado
  await health.init(prefs);
  if (!health.master) return 'OFF';
  await reload();
  await health.run();
  if (!health.master) return 'OFF';
  switch (health.state) {
    case HealthState.unavailable: return 'UNAVAILABLE';
    case HealthState.needsPermission: return 'NO_PERMISSION';
    case HealthState.error: return 'PARTIAL';
    default: await clearDirty(); return 'OK';
  }
}

/// Punto de entrada del motor Flutter sin interfaz que lanza BackgroundExport.kt desde el trabajo de fondo.
@pragma('vm:entry-point')
Future<void> vigorBackgroundExport() async {
  WidgetsFlutterBinding.ensureInitialized();
  const m = MethodChannel('vigor/methods');
  var code = 'ERROR';
  try {
    final repo = VigorRepo();
    final prefs = await m.invokeMethod<Map>('getPrefs') ?? {};
    code = await runHeadlessExport(prefs: prefs, health: repo.health, reload: repo.reload, clearDirty: () => m.invokeMethod('clearExportDirty'));
  } catch (_) { code = 'ERROR'; }
  try { await const MethodChannel('vigor/bg').invokeMethod('done', {'code': code}); } catch (_) {}
}
