/// Qué permisos explica y pide Vigor al arrancar, y la regla de «una vez por inicialización de la app».
/// Lógica pura (sin Flutter ni plataforma) para poder probarla.
enum PermKind { bluetooth, location, healthConnect }

class PermNeed {
  final PermKind kind; final String title, why;
  const PermNeed(this.kind, this.title, this.why);
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

  /// [nativeMissing]: grupos que faltan según Android ('bluetooth' | 'location'). [healthMissing]: Health Connect activado pero con permisos sin conceder.
  static List<PermNeed> plan({required List<String> nativeMissing, required bool healthMissing}) => [
        if (nativeMissing.contains('bluetooth')) bluetooth,
        if (nativeMissing.contains('location')) location,
        if (healthMissing) healthConnect,
      ];
}
