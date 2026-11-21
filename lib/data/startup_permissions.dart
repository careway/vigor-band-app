/// Qué permisos explica y pide Vigor al arrancar, y la regla de «una vez por inicialización de la app».
/// Lógica pura (sin Flutter ni plataforma) para poder probarla.
enum PermKind { bluetooth, location, healthConnect, batteryOptimization, autostart }

class PermNeed {
  final PermKind kind; final String title, why;
  const PermNeed(this.kind, this.title, this.why);
  /// Ajustes del sistema: no se piden con una ventana de «permitir», pero se consultan y se ofrece un acceso directo a su pantalla.
  bool get isSystemSetting => kind == PermKind.batteryOptimization || kind == PermKind.autostart;
}

/// Estado de los ajustes del sistema que Vigor consulta sin poder concederlos. [autostart]: null = desconocido o no aplicable (no es Xiaomi).
class SystemSettingsStatus {
  final bool installApps, batteryUnrestricted, xiaomi; final bool? autostart;
  const SystemSettingsStatus({this.installApps = true, this.batteryUnrestricted = true, this.autostart, this.xiaomi = false});
  static const unknown = SystemSettingsStatus();
}

class StartupPermissions {
  static bool _askedThisLaunch = false;
  /// true si ya se mostró la explicación en esta ejecución de la app (se haya aceptado o no): no se vuelve a mostrar hasta el próximo arranque.
  static bool get askedThisLaunch => _askedThisLaunch;
  static void markAsked() { _askedThisLaunch = true; }
  static void resetForTest() { _askedThisLaunch = false; }

  static const bluetooth = PermNeed(PermKind.bluetooth, 'Dispositivos cercanos (Bluetooth)',
      'Para buscar tu pulsera, conectarte a ella y leer sus datos (pasos, pulso, sueño). Sin este permiso Vigor no puede comunicarse con la pulsera.');
  static const location = PermNeed(PermKind.location, 'Ubicación',
      'Android 11 y anteriores exigen este permiso para buscar dispositivos Bluetooth cercanos. Vigor no lee ni guarda tu ubicación con él.');
  static const healthConnect = PermNeed(PermKind.healthConnect, 'Health Connect',
      'Activaste compartir con Health Connect: Vigor necesita permiso para ESCRIBIR allí los datos de tu pulsera. No lee nada de Health Connect ni de otras apps.');

  static const batteryOptimization = PermNeed(PermKind.batteryOptimization, 'Batería: ejecutar sin restricciones',
      'Es un ajuste del sistema, no un permiso. Sin él, Android puede retrasar o cerrar la sincronización cuando la app está cerrada. Vigor no lo concede por su cuenta: te llevamos a la ventana del sistema para que elijas tú.');
  static const autostart = PermNeed(PermKind.autostart, 'Inicio automático (Xiaomi)',
      'Es un ajuste de Xiaomi, no un permiso. Sin él, el sistema no deja arrancar Vigor cuando está cerrado y no se sincroniza nada hasta que la abras. Te llevamos a su pantalla para que lo actives tú.');

  /// [nativeMissing]: grupos que faltan según Android ('bluetooth' | 'location'). [healthMissing]: Health Connect activado pero con permisos sin conceder.
  /// [batteryRestricted]/[autostartDenied]: solo cuando la sincronización automática está activada (es lo que los necesita).
  static List<PermNeed> plan({required List<String> nativeMissing, required bool healthMissing, bool batteryRestricted = false, bool autostartDenied = false}) => [
        if (nativeMissing.contains('bluetooth')) bluetooth,
        if (nativeMissing.contains('location')) location,
        if (healthMissing) healthConnect,
        if (batteryRestricted) batteryOptimization,
        if (autostartDenied) autostart,
      ];
}
