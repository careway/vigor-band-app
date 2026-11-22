import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'analysis.dart';
import 'auto_sync.dart';
import 'health_gateway.dart';
import 'health_sync.dart';
import 'startup_permissions.dart';
import 'heart_meter.dart';
import 'live_heart.dart';
import 'updater.dart';
import 'sleep_stages.dart';
import 'gps_filter.dart';
import 'map_style.dart';
import 'workout.dart';
import 'sports.dart';
export 'sleep_stages.dart';
export 'analysis.dart' show Sample;

class Day {
  final String date;
  double steps = 0, kcal = 0, km = 0;
  final hr = <Sample>[], spo2 = <Sample>[], hrv = <Sample>[];
  final met = <Sample>[], stress = <Sample>[], temp = <Sample>[], skin = <Sample>[], glucose = <Sample>[], steps5 = <Sample>[], km5 = <Sample>[], kcal5 = <Sample>[];
  final blood = <(DateTime, Map)>[]; // estimaciones experimentales (ácido úrico, colesterol, ...)
  /// E1: calidad por métrica ('hr','spo2','hrv','met','stress','temp','skin').
  final q = <String, Quality>{};
  Quality qOf(String id) => q[id] ?? Quality(0);
  /// E3: minutos con registro de HRV en la noche (00:00-06:00) y diferencias totales/corregidas (calidad).
  int hrvNightRecords = 0, hrvNightPairs = 0, hrvNightCorrected = 0;
  Day(this.date);
  List<int> get hrValues => hr.map((s) => s.v.round()).toList();
}

class Night {
  final String date; final int total, deep, light, wake;
  final DateTime? down, up;
  /// Fases por minuto de `sleepLine` (null si la noche no la trae: se muestra solo con totales). [precise]: modo preciso (con REM).
  final List<Stage>? stages; final bool precise;
  /// Minutos hasta el primer sueño profundo según la pulsera (`firstDeepDuration`); 0 = sin dato.
  final int firstDeep;
  Night(this.date, this.total, this.deep, this.light, this.wake, this.down, this.up, {this.stages, this.precise = false, this.firstDeep = 0});
  /// Siesta: sueño total < 180 min (regla propia, ver sleep_stages.dart).
  bool get isNap => isNapMinutes(total);
  /// Inicio del registro: sleepDown o, si falta, sleepUp menos la duración del hipnograma.
  DateTime? get start { if (down != null) return down; if (up != null && stages != null) return up!.subtract(Duration(minutes: stages!.length)); return null; }
}

class Session {
  final String key; final DateTime start; final int sportType, seconds, meters, steps, avgHr, paceSecKm; final double kcal; final bool hasGps;
  final List<(double, double)> route; final List<int> hrPerMinute;
  /// Puntos GPS con su instante (s desde el inicio) y su señal; vacío si la sesión no los trae. [route] es lo mismo sin tiempo ni señal.
  final List<GpsFix> fixes;
  Session({required this.key, required this.start, required this.sportType, required this.seconds, required this.meters, required this.kcal, required this.steps, required this.avgHr, required this.paceSecKm, required this.hasGps, required this.route, required this.hrPerMinute, this.fixes = const []});
}

String sportName(int t) => sportLabel(t);

num _n(dynamic v) => v is num && v.isFinite ? v : 0;
/// Lista numérica que conserva las posiciones: lo no numérico pasa a 0 (inválido) para no unir latidos vecinos por encima de un hueco.
List<num> _numsKeep(dynamic v) => v is List ? [for (final e in v) (e is num && e.isFinite) ? e : 0] : <num>[];
dynamic _decode(String s) => jsonDecode(s);
/// Fecha válida o null (mapa vacío, año < 2000, mes/día/hora/minuto fuera de rango -> null).
DateTime? _t(dynamic m) {
  if (m is! Map) return null;
  final y = _n(m['year']).toInt(), mo = _n(m['month']).toInt(), d = _n(m['day']).toInt(), h = _n(m['hour']).toInt(), mi = _n(m['minute']).toInt();
  if (y < 2000 || y > 2100 || mo < 1 || mo > 12 || d < 1 || d > 31 || h < 0 || h > 23 || mi < 0 || mi > 59) return null;
  return DateTime(y, mo, d, h, mi);
}
/// Muestra solo los 2 últimos bytes de una MAC (privacidad).
String maskMac(String? m) => (m == null || m.length < 5) ? '' : '••:••:••:••:${m.substring(m.length - 5)}';
String _d(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class VigorRepo extends ChangeNotifier {
  static const _m = MethodChannel('vigor/methods');
  static const _e = EventChannel('vigor/events');

  String conn = 'idle'; // idle|scanning|connecting|connected|disconnected
  int? battery; bool charging = false;
  bool syncing = false; double progress = 0; DateTime? lastSync;
  String? savedMac;
  /// Aviso corto para el usuario (fallo de una acción); se limpia solo a los 8 s o con [clearNotice].
  String? notice; Timer? _noticeTimer;
  Duration noticeTtl = const Duration(seconds: 8);
  void clearNotice() { _noticeTimer?.cancel(); if (notice != null) { notice = null; notifyListeners(); } }
  void _setNotice(String t) {
    notice = t; _noticeTimer?.cancel();
    _noticeTimer = Timer(noticeTtl, () { notice = null; if (!_disposed) notifyListeners(); });
    notifyListeners();
  }
  /// Ejecuta una llamada de canal sin dejar escapar la excepción; true si fue bien.
  Future<bool> _try(String fail, Future<dynamic> Function() f) async {
    try { await f(); return true; } catch (_) { if (!_disposed) _setNotice(fail); return false; }
  }
  bool _disposed = false;
  /// Resultado de la última sincronización: null = ninguna aún; false = falló (ver [syncError]).
  bool? lastSyncOk; String? syncError;
  /// Si no llega el fin de una sincronización en este tiempo, se da por colgada.
  Duration syncWatchdog = const Duration(minutes: 5); Timer? _syncWatchdogTimer;
  void _failSync() { lastSyncOk = false; syncError = 'No se pudo sincronizar. Reintentando.'; }
  void _armWatchdog() {
    _syncWatchdogTimer?.cancel();
    _syncWatchdogTimer = Timer(syncWatchdog, () { if (syncing && !_disposed) { syncing = false; _failSync(); notifyListeners(); } });
  }
  final found = <String, Map>{};
  final logs = <String>[]; final sportMsgs = <String>[];
  /// Medición automática de la pulsera (SDK readAutoMeasureSettingData); null = aún no leída.
  List<AutoMeasure>? autoMeasures; bool autoUnsupported = false; String? autoMsg;
  Map<String, Day> days = {}; List<Night> nights = []; List<Session> sessions = [];
  static const defaultAge = 35;
  int age = defaultAge, stepGoal = 8000; double liveSteps = 0;
  bool ageIsDefault = true; // true si el usuario no ha indicado su edad: FCmáx y zonas usan 35 años
  String? loadError;
  Map agps = {};
  bool loaded = false;
  Map healthPrefs = const {};
  /// N28: glucosa y componentes sanguíneos solo tras activarlo en Dispositivo → Ajustes. Apagado de serie.
  bool showExperimental = false;
  /// 0 oscuro (principal), 1 claro, 2 sistema.
  int themeMode = 0;
  Future<void> setThemeMode(int v) async { themeMode = v.clamp(0, 2); await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': 'theme', 'value': themeMode})); notifyListeners(); }
  DateTime Function() clock = DateTime.now;
  StreamSubscription? _sub;
  /// Sincronización automática (DEV_012). Ajustes guardados en Kotlin (vigor_sync): interruptor, intervalo, «solo con pantalla encendida» y exportación sin la app.
  bool autoOn = true, screenOnly = true, bgExport = true; int autoMin = kAutoSyncDefaultMin; DateTime? lastBg; String bgResult = '';
  late final auto = AutoSync(clock: () => clock(), connState: () => conn, hasMac: () => savedMac != null, lastSync: () => lastSync,
      busy: () => syncing || live.reading || heart.active || sportActive || privacyBusy || !loaded,
      connect: _autoConnect, sync: () async { await _m.invokeMethod('sync'); });
  Future<void> _autoConnect() async {
    // Sin diálogos: si falta el permiso de Bluetooth no se insiste desde aquí.
    if (savedMac == null || await _m.invokeMethod<bool>('hasConnectPermission') != true) return;
    await _m.invokeMethod('connect', {'mac': savedMac, 'pwd': '0000'});
  }
  void _readSyncInfo(dynamic i) {
    if (i is! Map) return;
    autoOn = i['enabled'] != false; screenOnly = i['screenOnly'] != false; bgExport = i['bgExport'] != false; autoMin = safeAutoMin((i['minutes'] as num?)?.toInt());
    final ok = (i['lastOkAt'] as num?)?.toInt() ?? 0; if (ok > 0) lastSync = DateTime.fromMillisecondsSinceEpoch(ok);
    final bg = (i['bgAt'] as num?)?.toInt() ?? 0; lastBg = bg > 0 ? DateTime.fromMillisecondsSinceEpoch(bg) : null; bgResult = '${i['bgResult'] ?? ''}';
    auto.enabled = autoOn; auto.intervalMin = autoMin;
  }
  Future<void> setAutoSync({bool? enabled, int? minutes, bool? screenOnlyOnly, bool? bgExportOn}) async {
    try {
      _readSyncInfo(await _m.invokeMethod('setAutoSync', {'enabled': ?enabled, 'minutes': ?(minutes == null ? null : safeAutoMin(minutes)), 'screenOnly': ?screenOnlyOnly, 'bgExport': ?bgExportOn}));
    } catch (_) {}
    if (enabled != null) auto.setEnabled(enabled);
    notifyListeners();
  }
  /// Medición puntual de pulso (SDK startDetectHeart). Solo mide cuando el usuario lo pide.
  late final heart = HeartMeter(start: () => _m.invokeMethod('startHeart'), stop: () => _m.invokeMethod('stopHeart'), isConnected: () => conn == 'connected');
  final updater = Updater();
  /// Sincronización opcional con Health Connect / Apple Salud (solo escribe; apagada de serie). Ver health_sync.dart.
  late final health = HealthSync(gateway: PlatformHealthGateway(),
      savePref: (k, v) => _m.invokeMethod('setPref', {'key': k, 'value': v}),
      loadLedger: () => _m.invokeMethod<String>('healthLoad'),
      saveLedger: (j) async => await _m.invokeMethod<bool>('healthSave', {'json': j}) ?? false)
    ..source = (() => HealthSource(days, nights, sessions, restingByDay()));
  /// Pulso en reposo nocturno por fecha (calculado por Vigor, noche 00:00-06:00); solo noches ya terminadas y con datos suficientes.
  Map<String, double> restingByDay() {
    final out = <String, double>{};
    for (final k in dayKeys) { if (nightInProgress(k)) continue; final n = nightHr(k); if (n.state == NightState.data && n.value != null) out[k] = n.value!; }
    return out;
  }
  /// Pulso en vivo con la app abierta (bucle de mediciones cortas). Condiciones: conectada, sin sincronizar, sin deporte, sin medición manual, batería >= 20 %.
  late final live = LiveHeart(start: () => _m.invokeMethod('startHeart'), stop: () => _m.invokeMethod('stopHeart'),
      clock: () => clock(), canRun: () => conn == 'connected' && !syncing && !sportActive && !heart.active && !(battery != null && battery! < 20));
  /// true entre pedir un deporte y detenerlo/desconectar (conservador: durante él no se mide el pulso en vivo).
  bool sportActive = false;
  /// Actividad en curso (iniciada desde la app o desde la pulsera) con sus datos en vivo.
  late final LiveWorkout workout = LiveWorkout(clock: () => clock())..addListener(() {
    if (_workoutWasActive && !workout.active) _syncAfterWorkout();
    if (workout.active) { for (final t in _postWorkoutTimers) { t.cancel(); } _postWorkoutTimers.clear(); }
    _workoutWasActive = workout.active;
    if (workout.active != sportActive) { sportActive = workout.active; notifyListeners(); }
  });
  bool _workoutWasActive = false;
  /// Esperas (s) tras terminar una actividad antes de sincronizar: la pulsera tarda en guardarla; la segunda es el reintento por si aun no estaba.
  List<int> postWorkoutSyncDelays = const [6, 45];
  final List<Timer> _postWorkoutTimers = [];
  /// Al terminar una actividad (desde la app o la pulsera) se sincroniza solo, para que aparezca en el historial sin pulsar nada.
  bool _syncOnReconnect = false;
  void _syncAfterWorkout() {
    if (conn != 'connected') { _syncOnReconnect = true; return; } // sin conexion: se sincroniza al reconectar
    _syncOnReconnect = false;
    for (final t in _postWorkoutTimers) { t.cancel(); }
    _postWorkoutTimers.clear();
    for (final d in postWorkoutSyncDelays) {
      _postWorkoutTimers.add(Timer(Duration(seconds: d), () { if (conn == 'connected' && !syncing && !sportActive) unawaited(sync().catchError((_) {})); }));
    }
  }
  bool liveOn = true; int liveSec = 10;
  /// Mapa de fondo de OpenStreetMap en las rutas (descarga teselas de openstreetmap.org; apagado = solo la ruta dibujada).
  bool mapOn = true;
  /// Aspecto del mapa (ver [MapStyle]); por defecto, el moderno.
  MapStyle mapStyle = MapStyle.byDefault;
  Future<void> setMapStyle(MapStyle v) async { mapStyle = v; await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': 'mapStyle', 'value': v.index})); notifyListeners(); }
  Future<void> setMapOn(bool v) async { mapOn = v; await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': 'mapOn', 'value': v ? 1 : 0})); notifyListeners(); }
  Future<void> setLiveOn(bool v) async { liveOn = v; live.setEnabled(v); await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': 'liveOn', 'value': v ? 1 : 0})); notifyListeners(); }
  Future<void> setLiveSec(int v) async { if (!LiveHeart.allowedIntervals.contains(v)) return; liveSec = v; live.setInterval(v); await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': 'liveSec', 'value': v})); notifyListeners(); }

  final Completer<void> _ready = Completer<void>();
  /// Se completa cuando las preferencias, los datos y Health Connect están cargados (antes de conectar con la pulsera).
  Future<void> get ready => _ready.future;

  @visibleForTesting void markReady() { if (!_ready.isCompleted) _ready.complete(); }

  /// Permisos de ejecución que faltan (Android): {'missing': ['bluetooth'|'location'], 'blocked': bool}. 'blocked': el sistema ya no mostrará su diálogo.
  Future<({List<String> missing, bool blocked})> permissionStatus() async {
    try {
      final r = await _m.invokeMethod<Map>('permissionStatus');
      return (missing: [for (final x in (r?['missing'] as List? ?? const [])) x.toString()], blocked: r?['blocked'] == true);
    } catch (_) { return (missing: <String>[], blocked: false); }
  }
  /// Consulta (sin conceder nada) los ajustes del sistema que importan: instalar apps, excepción de batería e inicio automático de Xiaomi.
  Future<SystemSettingsStatus> systemSettings() async {
    try {
      final r = await _m.invokeMethod<Map>('systemSettingsStatus');
      if (r == null) return SystemSettingsStatus.unknown;
      return SystemSettingsStatus(installApps: r['installApps'] != false, batteryUnrestricted: r['batteryUnrestricted'] != false,
          autostart: r['autostart'] is bool ? r['autostart'] as bool : null, xiaomi: r['xiaomi'] == true);
    } catch (_) { return SystemSettingsStatus.unknown; }
  }
  /// Abre la pantalla del sistema de [which] ('installApps' | 'battery' | 'autostart').
  Future<void> openSystemSetting(String which) async { try { await _m.invokeMethod('openSystemSetting', {'which': which}); } catch (_) {} }

  /// Lanza el diálogo del sistema para Bluetooth/ubicación y anota que ya se pidió (para detectar «no volver a preguntar»).
  Future<bool> requestStartupPermissions() async {
    final ok = await _perm(true);
    try { await _m.invokeMethod('setPref', {'key': 'permAsked', 'value': 1}); } catch (_) {}
    return ok;
  }

  Future<void> init() async {
    addListener(live.recheck); heart.addListener(live.recheck);
    _sub = _e.receiveBroadcastStream().listen(_onEvent);
    try {
      savedMac = await _m.invokeMethod<String>('savedMac');
      final p = await _m.invokeMethod<Map>('getPrefs') ?? {};
      final a = p['age']; ageIsDefault = !(a is int && a >= 10 && a <= 100);
      age = ageIsDefault ? defaultAge : a as int;
      final g = p['goal']; if (g is int) stepGoal = g.clamp(1000, 40000);
      showExperimental = p['exp'] == 1;
      mapOn = p['mapOn'] != 0; mapStyle = MapStyle.fromIndex(p['mapStyle']); liveOn = p['liveOn'] != 0; final ls = p['liveSec']; liveSec = ls is int && LiveHeart.allowedIntervals.contains(ls) ? ls : 10;
      live.setEnabled(liveOn); live.setInterval(liveSec);
      themeMode = ((p['theme'] as num?)?.toInt() ?? 0).clamp(0, 2);
      healthPrefs = Map<dynamic, dynamic>.from(p);
    } catch (e) { loadError = 'preferencias: ${e.runtimeType}'; }
    try { _readSyncInfo(await _m.invokeMethod('syncInfo')); } catch (_) {}
    try { await reload(); } catch (e) { loadError = 'datos: ${e.runtimeType}'; loaded = true; }
    try { await health.init(healthPrefs); } catch (_) {}
    if (!_ready.isCompleted) _ready.complete();
    try { agps = await _m.invokeMethod<Map>('agpsStatus') ?? {}; } catch (_) {}
    notifyListeners();
    unawaited(updater.init());
    if (savedMac != null) { try { await connectSaved(); } catch (_) {} }
    // Datos que el trabajo de fondo guardó y no pudo enviar a Health Connect (o no llegó a enviar): se envían ahora (opción B de respaldo).
    try { final i = await _m.invokeMethod('syncInfo'); if (i is Map && i['dirty'] == true && health.master) unawaited(_exportThenClear()); } catch (_) {}
    auto.onResume();
  }

  Future<void> _exportThenClear() async {
    await health.run();
    if (health.master && health.state != HealthState.error) { try { await _m.invokeMethod('clearExportDirty'); } catch (_) {} }
  }

  @override
  void dispose() { _disposed = true; for (final t in _postWorkoutTimers) { t.cancel(); } _noticeTimer?.cancel(); _syncWatchdogTimer?.cancel(); _sub?.cancel(); auto.dispose(); live.dispose(); heart.dispose(); updater.dispose(); health.dispose(); super.dispose(); }

  void _onEvent(dynamic ev) {
    if (ev is! Map) return;
    try { _handle(Map<String, dynamic>.from(ev)); } catch (_) {}
  }

  @visibleForTesting
  void debugHandle(Map<String, dynamic> m) => _handle(m);

  void _handle(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'scan': found[m['mac']] = m;
      case 'state':
        conn = m['value']; if (conn != 'connected' && syncing) { syncing = false; _syncWatchdogTimer?.cancel(); _failSync(); }
        if (conn == 'connected' && _syncOnReconnect) _syncAfterWorkout();
        if (conn != 'connected') { heart.cancel(); sportActive = false; live.clearLowBattery(); }
        if (conn == 'connected') { _m.invokeMethod<String>('savedMac').then((v) { savedMac = v; notifyListeners(); }, onError: (_) {}); }
      case 'battery': final pc = m['percent']; if (pc is num) battery = pc.toInt(); charging = m['charging'] == true;
      case 'sync':
        syncing = m['value'] == 'start';
        if (syncing) { _armWatchdog(); } else { _syncWatchdogTimer?.cancel(); if (m['ok'] == true) { lastSyncOk = true; syncError = null; } else if (m['ok'] == false) { _failSync(); } }
        if (!syncing) {
          // «Última sincronización» solo cuenta si fue correcta (Kotlin manda ok y la hora).
          if (m['ok'] == true) { final at = (m['at'] as num?)?.toInt(); lastSync = at != null && at > 0 ? DateTime.fromMillisecondsSinceEpoch(at) : clock(); }
          reload().then((_) { if (health.master) unawaited(_exportThenClear()); }, onError: (_) {});
        }
      case 'syncProgress': final pv = m['value']; if (pv is num) progress = pv.toDouble();
      case 'sportLive': { final d = m['data']; if (d is Map) workout.onReport(d); }
      case 'gpsLive': { final d = m['data']; if (d is Map) workout.onGpsPoint(d); }
      case 'sport': sportMsgs.insert(0, '${m['msg']}'); if ('${m['msg']}' == 'Actividad detenida') { sportActive = false; workout.end(); }
      case 'autoMeasure':
        autoUnsupported = m['unsupported'] == true;
        final it = m['items'];
        if (it is List) autoMeasures = [for (final e in it) if (e is Map) AutoMeasure.fromMap(e)];
      case 'autoMeasureResult': autoMsg = m['ok'] == true ? 'Ajuste enviado a la pulsera.' : (m['msg']?.toString() ?? 'La pulsera no aceptó el ajuste.'); if (m['ok'] == true) readAutoMeasure();
      case 'heart': if (heart.active) { heart.onEvent(m); } else { live.onEvent(m); }
      case 'log': logs.insert(0, '${m['msg']}'); if (logs.length > 200) logs.removeLast();
    }
    notifyListeners();
    auto.evaluate();
  }

  Future<void> setPref(String k, int v) async {
    if (k == 'age') v = v.clamp(10, 100);
    if (k == 'goal') v = v.clamp(1000, 40000);
    if (!await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': k, 'value': v}))) return;
    if (k == 'age') { age = v; ageIsDefault = false; }
    if (k == 'goal') stepGoal = v;
    notifyListeners();
  }

  /// N28: preferencia persistente (apagada de serie).
  Future<void> setExperimental(bool on) async {
    if (!await _try('No se pudo guardar.', () => _m.invokeMethod('setPref', {'key': 'exp', 'value': on ? 1 : 0}))) return;
    showExperimental = on; notifyListeners();
  }

  // Solo depuración (E6/E7): el lado Kotlin ignora estas llamadas en release.
  Future<bool> debugEnabled() async { try { return await _m.invokeMethod<bool>('debugEnabled') ?? false; } catch (_) { return false; } }
  Future<void> debugSleepDump() => _m.invokeMethod('debugSleepDump');
  Future<void> debugProbe(String kind) => _m.invokeMethod('debugProbe', {'kind': kind});
  Future<void> debugClearDumps() => _m.invokeMethod('debugClearDumps');

  Future<bool> _perm(bool scan) async => await _m.invokeMethod<bool>('requestPermissions', {'scan': scan}) ?? false;
  Future<void> connectSaved() async { auto.userHold = false; await _try('No se pudo conectar.', () async { if (savedMac == null || !await _perm(false)) return; await _m.invokeMethod('connect', {'mac': savedMac, 'pwd': '0000'}); }); }
  Future<void> scan() async { if (!await _perm(true)) { logs.insert(0, 'Faltan permisos (ubicación solo para buscar por primera vez)'); notifyListeners(); return; } found.clear(); try { await _m.invokeMethod('startScan'); } catch (e) { logs.insert(0, 'No se pudo buscar: $e'); notifyListeners(); } }
  Future<void> stopScan() => _m.invokeMethod('stopScan');
  Future<void> connect(String mac) async { auto.userHold = false; await _try('No se pudo conectar.', () async { await stopScan(); await _m.invokeMethod('connect', {'mac': mac, 'pwd': '0000'}); }); }
  Future<void> disconnect() { auto.userHold = true; return _try('No se pudo desconectar.', () => _m.invokeMethod('disconnect')); }
  Future<void> sync() => _try('No se pudo sincronizar.', () => _m.invokeMethod('sync'));
  Future<void> startSport(String t) async {
    sportActive = true; workout.begin(sportByKey(t)); notifyListeners();
    if (!await _try('No se pudo iniciar la actividad.', () => _m.invokeMethod('startSport', {'type': t}))) {
      _workoutWasActive = false; // revertir sin disparar la sincronización de fin de actividad
      workout.end(); sportActive = false; notifyListeners();
    }
  }
  Future<void> readAutoMeasure() => _try('No se pudo leer el ajuste.', () => _m.invokeMethod('readAutoMeasure'));
  Future<void> setAutoMeasure(int type, bool on, {int? interval}) { autoMsg = null; return _m.invokeMethod('setAutoMeasure', {'type': type, 'on': on, 'interval': interval}); }
  Future<void> stopSport() { sportActive = false; workout.end(); notifyListeners(); return _try('No se pudo detener la actividad.', () => _m.invokeMethod('stopSport')); }
  /// Xiaomi/MIUI: ¿existe la pantalla de «Inicio automático»? (sin ella el sistema no arranca la app cerrada para sincronizar)
  Future<bool> autostartSupported() async { try { return (await _m.invokeMethod<bool>('autostartSupported')) ?? false; } catch (_) { return false; } }
  Future<void> openAutostartSettings() async { try { await _m.invokeMethod('openAutostartSettings'); } catch (_) {} }
  Future<void> openBatterySettings() async { try { await _m.invokeMethod('openBatterySettings'); } catch (_) {} }
  Future<void> findBand() => _try('No se pudo buscar la pulsera.', () => _m.invokeMethod('findBand'));
  Future<void> forget() async { await _m.invokeMethod('forgetMac'); savedMac = null; notifyListeners(); }

  // ---- Privacidad y datos (solo local: no se envía nada a internet) ----
  /// Última exportación: carpeta de la app y nombres copiados (null si aún no se exportó o falló).
  String? exportPath; List<String> exportFiles = const []; String? privacyMsg; bool privacyBusy = false;
  /// Copia los JSON a una carpeta PRIVADA de la app y abre el selector de compartir de Android (el usuario elige el destino). Devuelve true si salió bien.
  Future<bool> exportData() async {
    privacyBusy = true; privacyMsg = null; notifyListeners();
    try {
      final m = await _m.invokeMethod<Map>('exportData');
      final path = m?['path']; final files = m?['files'];
      if (path is! String) throw StateError('sin ruta');
      exportPath = path; exportFiles = [for (final f in (files is List ? files : const [])) f.toString()];
      privacyMsg = exportFiles.isEmpty ? 'No hay datos guardados que exportar.' : 'Se abrió el selector de compartir con ${exportFiles.length} ficheros. Lo que elijas allí queda fuera del control de Vigor.';
      return true;
    } catch (_) { exportPath = null; privacyMsg = 'No se pudo exportar los datos.'; return false; }
    finally { privacyBusy = false; notifyListeners(); }
  }

  // ---- Borrado individual (DEV_008) ----
  /// Borra noches ('sleep', clave = fecha), sesiones ('session', clave = inicio) o días enteros ('day', yyyy-MM-dd). Deja tumbas en Kotlin para que la pulsera no los resucite al sincronizar.
  /// Si [alsoHealth], también pide a Health Connect / Salud que borre lo que Vigor envió. Devuelve null si el borrado local falló.
  Future<HealthDeleteReport?> deleteRecords(String type, List<String> keys, {bool alsoHealth = false}) async {
    if (keys.isEmpty) return HealthDeleteReport();
    final nightsDel = type == 'sleep' ? [for (final n in nights) if (keys.contains(n.date)) n] : <Night>[];
    final sesDel = type == 'session' ? [for (final s in sessions) if (keys.contains(s.key)) s] : <Session>[];
    try { await _m.invokeMethod('deleteRecords', {'type': type, 'keys': keys}); } catch (_) { privacyMsg = 'No se pudo borrar.'; notifyListeners(); return null; }
    HealthDeleteReport rep = HealthDeleteReport();
    if (alsoHealth) { try { rep = await health.deleteFromHealth(nights: nightsDel, sessions: sesDel, days: type == 'day' ? keys : const []); } catch (_) { rep.failed++; } }
    try { await reload(); } catch (_) {}
    notifyListeners();
    return rep;
  }

  /// Borra la copia privada de exportación (al abrir la pantalla de privacidad). Los errores se ignoran.
  Future<void> clearExport() async { try { await _m.invokeMethod('clearExport'); } catch (_) {} exportPath = null; exportFiles = const []; }

  /// Borra todos los datos de la pulsera guardados por la app (Kotlin: files/vigor, files/agps, files/debug y la exportación) y reinicia el estado en Dart.
  /// No toca la MAC emparejada ni edad/meta. Devuelve true si salió bien.
  Future<bool> wipeData() async {
    privacyBusy = true; privacyMsg = null; notifyListeners();
    try {
      await _m.invokeMethod('wipeData');
      await health.afterWipe();
      days = {}; nights = []; sessions = []; liveSteps = 0; lastSync = null; progress = 0; loadError = null; agps = {};
      logs.clear(); sportMsgs.clear(); exportPath = null; exportFiles = const [];
      try { agps = await _m.invokeMethod<Map>('agpsStatus') ?? {}; } catch (_) {}
      loaded = true; privacyMsg = 'Datos borrados de este móvil.';
      return true;
    } catch (_) { privacyMsg = 'No se pudo borrar (¿sincronizando?). Inténtalo cuando termine.'; return false; }
    finally { privacyBusy = false; notifyListeners(); }
  }

  Future<List<Map>> _list(String kind) async {
    try {
      final s = await _m.invokeMethod<String>('getData', {'kind': kind});
      final d = (s ?? '[]').length > 100000 ? await compute(_decode, s!) : jsonDecode(s ?? '[]'); // M6: JSON grande fuera del isolate de UI
      return d is List ? [for (final e in d) if (e is Map) e] : <Map>[];
    } catch (_) { return <Map>[]; } // un tipo ilegible no debe impedir cargar el resto
  }

  /// Si hay una actividad de recorrido en curso y la pulsera ya devolvió su sesión (al sincronizar), pasa sus puntos al entreno para dibujar la posición.
  /// La sesión se reconoce por su hora de inicio (±5 min respecto al inicio en el móvil: los relojes pueden no coincidir exactamente).
  void _trackForWorkout() {
    final w = workout; final st = w.startedAt; if (!w.active || st == null || !(w.mode?.tracksRoute ?? false)) return;
    Session? best; Duration? bd;
    for (final s in sessions) { final d = s.start.difference(st).abs(); if (d <= const Duration(minutes: 5) && (bd == null || d < bd)) { best = s; bd = d; } }
    if (best != null && best.fixes.isNotEmpty) w.setTrack(best.fixes);
  }

  Future<void> reload() async {
    final o5 = await _list('origin5'), spo = await _list('spo2'), hv = await _list('hrv'), sl = await _list('sleep');
    final sp = await _list('sports'), si = await _list('sportItems'), live = await _list('live');
    final ds = <String, Day>{};
    Day day(DateTime t) => ds.putIfAbsent(_d(t), () => Day(_d(t)));
    final now = clock();
    Quality qq(Day d, String id) => d.q.putIfAbsent(id, () => Quality(0));
    for (final o in o5) { try {
      final t = _t(o['mTime']); if (t == null) continue;
      final d = day(t);
      d.steps += _n(o['stepValue']); d.kcal += _n(o['calValue']); d.km += _n(o['disValue']);
      d.steps5.add(Sample(t, _n(o['stepValue']).toDouble()));
      d.km5.add(Sample(t, _n(o['disValue']).toDouble())); d.kcal5.add(Sample(t, _n(o['calValue']).toDouble()));
      final rawMet = o['met'], rawSt = o['pressure'], rawTc = o['temperature'], rawTs = o['baseTemperature'];
      qq(d, 'met').add(rawMet, 0.0001, 254); qq(d, 'stress').add(rawSt, 1, 100); qq(d, 'temp').add(rawTc, 30, 43); qq(d, 'skin').add(rawTs, 15, 43);
      final met = _n(rawMet).toDouble(); if (met > 0 && met < 255) d.met.add(Sample(t, met));
      final st = _n(rawSt).toDouble(); if (st > 0 && st <= 100) d.stress.add(Sample(t, st));
      final tc = _n(rawTc).toDouble(); if (tc >= 30 && tc <= 43) d.temp.add(Sample(t, tc));
      final ts = _n(rawTs).toDouble(); if (ts >= 15 && ts <= 43) d.skin.add(Sample(t, ts));
      final gl = _n(o['bloodGlucose']).toDouble(); if (gl > 0) d.glucose.add(Sample(t, gl));
      final bc = o['bloodComponent']; if (bc is Map && bc.values.any((v) => _n(v) > 0)) d.blood.add((t, bc));
      final ppgs = o['ppgs'] is List ? o['ppgs'] as List : const [];
      for (var i = 0; i < ppgs.length; i++) {
        final ts2 = t.add(Duration(minutes: i)); final dd = day(ts2); // cada lectura va al día de su propia hora
        qq(dd, 'hr').add(ppgs[i], 30, 220);
        final v = _n(ppgs[i]); if (v >= 30 && v <= 220) dd.hr.add(Sample(ts2, v.toDouble()));
      }
    } catch (_) {} }
    for (final o in spo) { try {
      final t = _t(o['mTime']); if (t == null) continue;
      final d = day(t); qq(d, 'spo2').add(o['oxygenValue'], 70, 100);
      final v = _n(o['oxygenValue']); if (v >= 70 && v <= 100) d.spo2.add(Sample(t, v.toDouble()));
    } catch (_) {} }
    for (final o in hv) { try {
      final t = _t(o['mTime']); if (t == null) continue;
      final d = day(t); final m = rmssdMinute(_numsKeep(o['rrValue'])); final hq = qq(d, 'hrv');
      hq.raw++;
      if (m.rmssd != null) { hq.valid++; d.hrv.add(Sample(t, m.rmssd!)); } else { hq.noData++; }
      // N1: los registros todo-centinela (2550) son "sin dato": no cuentan como registro de la noche ni aportan pares/correcciones.
      if (t.hour < 6 && !m.noData) { d.hrvNightRecords++; d.hrvNightPairs += m.pairs; d.hrvNightCorrected += m.corrected; }
    } catch (_) {} }
    final todayKey = _d(now);
    for (final d in ds.values) {
      final today = d.date == todayKey;
      for (final e in d.q.entries) { e.value.possible = possibleSamples(const {'hr': 1440, 'spo2': 1440, 'hrv': 1440}[e.key] ?? 288, isToday: today, now: now); }
    }
    for (final d in ds.values) {
      for (final l in [d.hr, d.spo2, d.hrv, d.met, d.stress, d.temp, d.skin, d.glucose, d.steps5, d.km5, d.kcal5]) { l.sort((a, b) => a.t.compareTo(b.t)); }
    }
    days = ds;

    nights = <Night>[];
    for (final o in sl) { try {
      final date = (o['Date'] ?? o['date'] ?? '').toString(); final precise = _n(o['accurateType']) == 1;
      final n = Night(date, _n(o['allSleepTime']).toInt(), _n(o['deepSleepTime']).toInt(), _n(o['lowSleepTime']).toInt(), _n(o['wakeCount']).toInt(), _t(o['sleepDown']), _t(o['sleepUp']), stages: decodeStages(o['sleepLine'] is String ? o['sleepLine'] as String : null, precise: precise), precise: precise, firstDeep: _n(o['firstDeepDuration']).toInt());
      if (n.total > 0) nights.add(n);
    } catch (_) {} }
    nights.sort((a, b) => b.date.compareTo(a.date));

    final items = <String, Map>{};
    for (final i in si) { final k = i['_key']; if (k is String) items[k] = i; }
    sessions = <Session>[];
    for (final o in sp) { try {
      final key = o['_key']; final start = _t(o['startTime']);
      if (key is! String || start == null || _n(o['sportTime']) <= 0) continue; // sin hora de inicio fiable no se inventa una sesión
      final its = items[key]?['items'] is List ? items[key]!['items'] as List : const [];
      final route = <(double, double)>[]; final hrs = <int>[]; final fixes = <GpsFix>[]; var minuteIdx = 0, seq = 0;
      for (final it in its) {
        if (it is! Map) continue;
        final mi = _n(it['minute']).toInt(); minuteIdx = mi > 0 ? mi - 1 : seq; seq++; // cada elemento es 1 minuto de la sesión; 12 puntos, uno cada 5 s
        final sg = it['signalArray'] is List ? it['signalArray'] as List : const [];
        final la = it['latArray'] is List ? it['latArray'] as List : const [], lo = it['lngArray'] is List ? it['lngArray'] as List : const [];
        for (var i = 0; i < la.length && i < lo.length; i++) {
          final a = _n(la[i]).toDouble(), b = _n(lo[i]).toDouble();
          if (a != 0 || b != 0) { route.add((a, b)); fixes.add(GpsFix(a, b, minuteIdx * 60 + i * 5, i < sg.length ? _n(sg[i]).toInt() : 2)); }
          else if (route.isNotEmpty && !route.last.$1.isNaN) { route.add((double.nan, double.nan)); } // corte: sin fix GPS
        }
        final r = _n(it['rate']).toInt(); if (r >= 30 && r <= 220) hrs.add(r);
      }
      sessions.add(Session(key: key, start: start, sportType: _n(o['sportType']).toInt(), seconds: _n(o['sportTime']).toInt(), meters: _n(o['distance']).toInt(),
        kcal: _n(o['calories']) / 1000, steps: _n(o['stepCount']).toInt(), avgHr: _n(o['avgHeartRate'] ?? o['averRate']).toInt(), paceSecKm: _n(o['avgPace']).toInt(), hasGps: o['hasGpsInfo'] == true, route: route, hrPerMinute: hrs, fixes: fixes));
    } catch (_) {} }
    sessions.sort((a, b) => b.start.compareTo(a.start));

    // Pasos "en vivo": solo si la lectura es de hoy (campo 'at', epoch ms).
    liveSteps = 0;
    if (live.isNotEmpty) {
      final at = _n(live.first['at']).toInt();
      if (at > 0) {
        final t = DateTime.fromMillisecondsSinceEpoch(at), n = DateTime.now();
        if (t.year == n.year && t.month == n.month && t.day == n.day) liveSteps = _n(live.first['step']).toDouble();
      }
    }
    _trackForWorkout();
    loaded = true; notifyListeners();
  }

  List<String> get dayKeys => (days.keys.toList()..sort());

  // ---- E2 / E3: noche provisional 00:00–06:00 (regla 4) ----
  NightStat nightHr(String key) {
    final d = days[key]; if (d == null) return const NightStat(NightState.none, null, 0, kRestingNightMin);
    return restingHrNight([for (final s in d.hr) if (s.t.hour < 6) s.v]);
  }
  NightStat nightHrv(String key) {
    final d = days[key]; if (d == null) return const NightStat(NightState.none, null, 0, kHrvNightMinMinutes);
    return hrvNight([for (final s in d.hrv) if (s.t.hour < 6) s.v], recordedMinutes: d.hrvNightRecords, pairs: d.hrvNightPairs, corrected: d.hrvNightCorrected);
  }
  /// N6: la noche del día en curso, antes de las 06:00, aún no ha terminado.
  bool nightInProgress(String key) { final n = clock(); return key == _d(n) && n.hour < 6; }
  /// Claves de día de [ks] dentro de los [kBaselineWindowDays] días naturales anteriores a [key] (N5), de más antiguo a más reciente.
  List<String> _windowKeys(String key, {bool includeKey = false}) {
    final k = DateTime.tryParse(key); if (k == null) return const [];
    final from = DateTime(k.year, k.month, k.day - kBaselineWindowDays);
    return [for (final x in dayKeys) if (!(DateTime.tryParse(x) ?? DateTime(1970)).isBefore(from) && (includeKey ? x.compareTo(key) <= 0 : x.compareTo(key) < 0)) x];
  }
  /// Línea base propia (regla 5) de la función [f] antes de la noche [key]: las 14 noches válidas más recientes de los últimos 30 días naturales; mínimo 7.
  ({double? base, int k}) nightBase(String key, NightStat Function(String) f) {
    final ks = _windowKeys(key); final prev = <double>[];
    for (var i = ks.length - 1; i >= 0 && prev.length < kBaselineMaxNights; i--) { final n = f(ks[i]); if (n.state == NightState.data) prev.add(n.value!); }
    return nightBaseline(prev);
  }
  /// Últimas [n] noches hasta [key] (valor o null), solo dentro de los últimos 30 días naturales; la noche en curso va sin valor (N6).
  List<(String, double?)> nightHistory(String key, NightStat Function(String) f, {int n = 14}) {
    if (!days.containsKey(key)) return const [];
    final ks = _windowKeys(key, includeKey: true); final from = (ks.length - n).clamp(0, ks.length);
    return [for (var i = from; i < ks.length; i++) (ks[i], () { if (nightInProgress(ks[i])) return null; final r = f(ks[i]); return r.state == NightState.data ? r.value : null; }())];
  }

  // ---- E4 ----
  /// Semana lunes-domingo de hoy. Pulso: FCmáx de la edad configurada (35 por defecto, ver ageIsDefault).
  WeekMvpa weekMvpa() {
    final acts = <DayAct>[for (final d in days.values) DayAct(DateTime.parse(d.date), [for (final s in d.met) s.v], [for (final s in d.hr) s.v], d.qOf('met').valid, d.qOf('met').possible)];
    return weeklyMvpa(acts, clock(), hrMaxTanaka(age));
  }
}


/// Una medición automática de la pulsera (pulso, SpO₂, temperatura, HRV...). Los intervalos están en minutos.
class AutoMeasure {
  final int type; final String name; final bool on, intervalModify; final int interval, stepUnit;
  const AutoMeasure({required this.type, required this.name, required this.on, required this.intervalModify, required this.interval, required this.stepUnit});
  factory AutoMeasure.fromMap(Map m) => AutoMeasure(type: (m['type'] as num?)?.toInt() ?? -1, name: '${m['name']}', on: m['on'] == true, intervalModify: m['intervalModify'] == true,
      interval: (m['interval'] as num?)?.toInt() ?? 0, stepUnit: (m['stepUnit'] as num?)?.toInt() ?? 0);
  String get label => autoMeasureLabel(name);
  /// Intervalos válidos: múltiplos de stepUnit hasta 240 min (misma regla que AutoMeasureRules en Kotlin). Vacío si no es modificable.
  List<int> get choices => !intervalModify || stepUnit <= 0 ? const [] : [for (var v = stepUnit; v <= 240; v += stepUnit) v];
}

String autoMeasureLabel(String n) => const {'PULSE_RATE': 'Pulso', 'BLOOD_PRESSURE': 'Presión arterial', 'BLOOD_GLUCOSE': 'Glucosa', 'STRESS': 'Estrés', 'BLOOD_OXYGEN': 'SpO₂',
      'BODY_TEMPERATURE': 'Temperatura', 'LORENZ': 'Lorenz (diagrama RR)', 'HRV': 'HRV', 'BLOOD_COMPOSITION': 'Componentes sanguíneos', 'FALL_DETECTION': 'Detección de caídas'}[n] ?? n;

/// Aviso de batería según el intervalo (umbral de aviso propio, no del fabricante): medir muy a menudo gasta más batería.
String? autoBatteryWarning(int intervalMin) => intervalMin > 0 && intervalMin < 10 ? 'Medir cada menos de 10 min gasta más batería (el consumo exacto no está medido).' : null;
