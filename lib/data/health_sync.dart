import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'repo.dart';

/// Sincronización con Health Connect (Android) y Apple Salud / HealthKit (iPhone).
///
/// Principios (ver docs/equipo/informes/DEV_007.md):
/// - Unidireccional: Vigor SOLO ESCRIBE. No lee datos de otras apps.
/// - Opt-in: interruptor maestro apagado de serie; una categoría por tipo de dato.
/// - Idempotente: `clientRecordId` estable (Health Connect hace "upsert") + marcas de agua y libro de lo enviado en el JsonStore.
/// - Sin estimaciones no validadas: glucosa, componentes sanguíneos, estrés, MET y temperatura de piel NO se exportan.
/// - Lado iPhone: implementado, NO compilado ni probado (no hay Mac/Xcode).

/// Categorías que ve el usuario (un interruptor por cada una).
enum HealthCat {
  activity('actividad', 'Actividad', 'Pasos, distancia y calorías (aprox.) por tramos de 5 minutos.', true),
  heart('corazon', 'Corazón', 'Pulso (1 lectura por minuto), variabilidad RMSSD calculada por Vigor (solo Health Connect) y pulso en reposo nocturno estimado por Vigor (solo Health Connect).', true),
  oxygen('oxigeno', 'Oxígeno en sangre', 'SpO₂ de la pulsera (valores orientativos, no diagnósticos).', true),
  temperature('temperatura', 'Temperatura corporal (aprox.)', 'Temperatura corporal estimada en la muñeca. Puede tener un sesgo de ±1,5 °C: por eso está desactivada de serie.', false),
  sleep('sueno', 'Sueño', 'Cada noche como una sesión, con sus fases (ligero, profundo, REM y despierto) cuando la pulsera las da.', true),
  exercise('ejercicio', 'Ejercicio', 'Sesiones deportivas: tipo de deporte, inicio, fin, duración, distancia y calorías.', true),
  route('ruta', 'Rutas GPS de los ejercicios', 'Los puntos de ubicación de cada recorrido, asociados a su ejercicio. Es un dato sensible: desactivado de serie. Requiere «Ejercicio».', false);

  final String id, title, sends; final bool defaultOn;
  const HealthCat(this.id, this.title, this.sends, this.defaultOn);
  String get prefKey => 'hc_$id';
}

/// Tipos de dato propios de Vigor que se pueden escribir (el servicio los traduce al tipo de cada plataforma).
enum HType { steps, distance, activeEnergy, heartRate, hrvRmssd, restingHr, spo2, bodyTemp, sleep, workout, route }

/// Permisos del sistema que necesita cada categoría. Ejercicio escribe también distancia y energía junto a la sesión.
const Map<HealthCat, Set<HType>> healthCatTypes = {
  HealthCat.activity: {HType.steps, HType.distance, HType.activeEnergy},
  HealthCat.heart: {HType.heartRate, HType.hrvRmssd, HType.restingHr},
  HealthCat.oxygen: {HType.spo2},
  HealthCat.temperature: {HType.bodyTemp},
  HealthCat.sleep: {HType.sleep},
  HealthCat.exercise: {HType.workout, HType.distance, HType.activeEnergy},
  HealthCat.route: {HType.workout, HType.route},
};

const kHealthLedgerVersion = 1;
/// Ventana inicial de envío (días) para datos densos y para sueño/sesiones. Lo anterior no se envía nunca.
const kDenseBackfillDays = 7, kSessionBackfillDays = 30;

enum HealthAvail { ready, unsupported, notInstalled, updateRequired }

/// Un dato puntual o por intervalo a escribir.
class HealthItem {
  final HType type; final HealthCat cat; final String id; final DateTime start, end; final double value; final double version;
  /// Solo sueño: fases de la noche. La pasarela las escribe dentro de UNA sesión y marca [SleepStagesOut.written].
  final SleepStagesOut? stages;
  const HealthItem(this.type, this.cat, this.id, this.start, this.end, this.value, {this.version = 1, this.stages});
}

/// Fases de una noche como tramos [inicio ms, fin ms, tipo de fase de Health Connect: 1 despierto, 4 ligero, 5 profundo, 6 REM].
class SleepStagesOut {
  final List<List<int>> runs; bool written = false;
  SleepStagesOut(this.runs);
  /// Agrupa el hipnograma por minuto en tramos consecutivos de la misma fase. Vacío si no hay fases.
  static SleepStagesOut? fromNight(Night n) {
    final st = n.stages, start = n.start; if (st == null || st.isEmpty || start == null) return null;
    int code(Stage s) => switch (s) { Stage.awake => 1, Stage.light => 4, Stage.deep => 5, Stage.rem => 6 };
    final out = <List<int>>[]; var i = 0; final t0 = start.millisecondsSinceEpoch;
    while (i < st.length) { var j = i; while (j < st.length && st[j] == st[i]) { j++; } out.add([t0 + i * 60000, t0 + j * 60000, code(st[i])]); i = j; }
    return SleepStagesOut(out);
  }
}

/// Resultado de [HealthGateway.writeBatch]: [written] datos consumidos desde el principio de la lista; [error] si se cortó antes del final.
class BatchOut { final int written; final String? error; const BatchOut(this.written, [this.error]); }

class WorkoutOut {
  final String key, title; final int sportType; final DateTime start, end; final int meters, kcal;
  const WorkoutOut(this.key, this.title, this.sportType, this.start, this.end, this.meters, this.kcal);
}

class RoutePoint { final double lat, lng; final DateTime t; const RoutePoint(this.lat, this.lng, this.t); }

/// Interfaz con el sistema de salud. La implementación real usa el paquete `health`; los tests usan un falso.
abstract class HealthGateway {
  String get platformName; // 'Health Connect' | 'Apple Salud'
  bool get isIos;
  Future<HealthAvail> availability();
  /// true si el tipo se puede escribir en esta plataforma (p. ej. RMSSD y pulso en reposo solo en Android).
  bool supports(HType t);
  Future<bool> hasPermissions(Set<HType> types);
  Future<bool> requestPermissions(Set<HType> types);
  Future<bool> write(HealthItem it);
  /// Escribe varios datos del MISMO tipo con pocas llamadas (la cuota de Health Connect cuenta llamadas, no registros).
  /// Devuelve cuántos se consumieron desde el principio (escritos o descartados por inválidos) y la causa si se cortó.
  Future<BatchOut> writeBatch(List<HealthItem> items);
  /// Causa corta (sin datos personales) del último fallo de escritura, o null.
  String? get lastError;
  /// Devuelve el identificador del ejercicio escrito (null si falló).
  Future<String?> writeWorkout(WorkoutOut w);
  Future<bool> writeRoute(String workoutId, List<RoutePoint> pts);
  Future<bool> deleteRange(HType t, DateTime from, DateTime to);
  Future<bool> deleteWorkout(String id);
  /// Borra un registro por su id estable (Android: clientRecordId; iOS: por rango de tiempo, ya que HealthKit no usa ids de cliente).
  Future<bool> deleteByClientId(HType t, String id, DateTime from, DateTime to);
  Future<void> openSettings();
  Future<void> installProvider();
}

/// Resultado de borrar registros de Health Connect / Salud.
class HealthDeleteReport { int ok = 0, failed = 0; final notes = <String>[]; }

enum HealthState { off, idle, running, needsPermission, unavailable, error }

/// Lo que se sincroniza: se entrega ya calculado desde el repositorio (los tests pasan listas propias).
class HealthSource {
  final Map<String, Day> days; final List<Night> nights; final List<Session> sessions;
  /// Pulso en reposo nocturno por fecha (yyyy-MM-dd): calculado por Vigor (regla de la noche 00:00-06:00).
  final Map<String, double> resting;
  const HealthSource(this.days, this.nights, this.sessions, this.resting);
}

/// Tope de datos densos por ronda. Con escritura por lotes (500 por llamada) son pocas llamadas; el tope evita rondas interminables.
const kMaxDensePerRun = 5000;

/// Se suma a la version de la noche cuando se envía con fases (debe ser mayor que cualquier version sin fases).
const kStagedVersionOffset = 1000000000;

class HealthSync extends ChangeNotifier {
  HealthSync({required this.gateway, required this.savePref, required this.loadLedger, required this.saveLedger, DateTime Function()? clock, this.batch = 25}) : clock = clock ?? DateTime.now;
  final HealthGateway gateway;
  final Future<void> Function(String key, int value) savePref;
  final Future<String?> Function() loadLedger;
  final Future<bool> Function(String json) saveLedger;
  DateTime Function() clock; final int batch;

  bool master = false;
  final cats = <HealthCat, bool>{for (final c in HealthCat.values) c: c.defaultOn};
  final granted = <HealthCat, bool>{};
  HealthState state = HealthState.off;
  String? message; DateTime? last; int lastCount = 0, totalSent = 0, pendingHint = 0;
  bool _running = false, _cancel = false;
  /// Diagnóstico por categoría: último error real y último dato enviado (texto corto, sin coordenadas ni datos personales).
  final catError = <HealthCat, String>{}; final catLastOk = <HealthCat, String>{};
  /// Noches disponibles / válidas en el último envío (para distinguir «no hay noches» de «pendiente»).
  int nightsSeen = 0, nightsValid = 0; bool ranOnce = false;
  void _fail(HealthCat c, [String? why]) { catError[c] = why ?? gateway.lastError ?? 'el sistema rechazó la escritura (sin detalle)'; }
  HealthAvail? avail;
  Map<String, dynamic> _ledger = _fresh();
  bool _ledgerLoaded = false;
  HealthSource Function()? source;

  static Map<String, dynamic> _fresh() => {'v': kHealthLedgerVersion, 'wm': <String, dynamic>{}, 'sessions': <String, dynamic>{}, 'routes': <String, dynamic>{}, 'sleep': <String, dynamic>{}};

  bool get running => _running;

  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  static String _dm(DateTime t) => '${t.day} ${_meses[t.month - 1]}';
  static String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Estado legible de una categoría para la pantalla.
  String catStatus(HealthCat c) {
    if (!master) return 'Compartir desactivado.';
    if (cats[c] != true) return 'Desactivada.';
    if (avail != null && avail != HealthAvail.ready) return 'No disponible: ${_availMsg()}';
    if (granted[c] != true) return 'Sin permiso del sistema.';
    if (c == HealthCat.route && cats[HealthCat.exercise] != true) return 'Necesita activar «Ejercicio».';
    final e = catError[c]; if (e != null) return 'Error al escribir: $e';
    final ok = catLastOk[c];
    if (c == HealthCat.sleep) {
      if (ok != null) return 'Última noche enviada: $ok';
      if (ranOnce && nightsValid == 0) return nightsSeen == 0 ? 'No hay noches de sueño para enviar.' : 'Hay $nightsSeen noche(s) pero ninguna con hora de inicio y fin válidas.';
      return 'Pendiente: se enviará en el próximo envío.';
    }
    return ok != null ? 'Último dato enviado: $ok' : (ranOnce ? 'Nada nuevo que enviar.' : 'Pendiente: se enviará en el próximo envío.');
  }

  /// Vuelve a enviar una categoría desde cero (borra sus marcas locales; en Health Connect el id estable evita duplicados).
  Future<void> retryCat(HealthCat c) async {
    if (_running) return;
    catError.remove(c);
    final wm = _ledger['wm'] as Map;
    for (final st in _streamIds[c] ?? const <String>[]) { wm.remove(st); }
    if (c == HealthCat.sleep) { (_ledger['sleep'] as Map).clear(); }
    if (c == HealthCat.exercise) { (_ledger['sessions'] as Map).clear(); }
    if (c == HealthCat.route) { (_ledger['routes'] as Map).clear(); }
    notifyListeners();
    await run();
  }
  static const _streamIds = {HealthCat.activity: ['steps', 'dist', 'kcal'], HealthCat.heart: ['hr', 'hrv', 'rest'], HealthCat.oxygen: ['spo2'], HealthCat.temperature: ['temp']};
  bool get enabledAny => master && HealthCat.values.any(effective);
  /// Una categoría envía solo si el maestro, su interruptor y el permiso del sistema lo permiten (y, la ruta, también «Ejercicio»).
  bool effective(HealthCat c) => master && cats[c] == true && granted[c] == true && (c != HealthCat.route || (cats[HealthCat.exercise] == true && granted[HealthCat.exercise] == true));

  /// Carga preferencias (mapa de getPrefs) y el libro. No toca el sistema de salud si está apagado.
  Future<void> init(Map prefs) async {
    master = prefs['hcOn'] == 1;
    for (final c in HealthCat.values) { final v = prefs[c.prefKey]; if (v is int) cats[c] = v == 1; }
    await _loadLedger();
    last = _ledger['last'] is int ? DateTime.fromMillisecondsSinceEpoch(_ledger['last'] as int) : null;
    totalSent = (_ledger['total'] as num?)?.toInt() ?? 0;
    state = master ? HealthState.idle : HealthState.off;
    if (master) { unawaited(refreshPermissions()); }
    notifyListeners();
  }

  Future<void> _loadLedger() async {
    if (_ledgerLoaded) return;
    try {
      final s = await loadLedger();
      if (s != null && s.isNotEmpty) {
        final m = jsonDecode(s);
        // Control de versión: un libro de otra versión no se reutiliza (se empieza de cero; Health Connect no duplica gracias a clientRecordId).
        if (m is Map && m['v'] == kHealthLedgerVersion) _ledger = Map<String, dynamic>.from(m);
      }
    } catch (_) { _ledger = _fresh(); }
    _ledgerLoaded = true;
  }

  Future<void> _persist() async { try { await saveLedger(jsonEncode(_ledger)); } catch (_) {} }

  Future<void> refreshPermissions() async {
    try {
      avail = await gateway.availability();
      if (avail != HealthAvail.ready) { for (final c in HealthCat.values) { granted[c] = false; } state = HealthState.unavailable; message = _availMsg(); notifyListeners(); return; }
      for (final c in HealthCat.values) { granted[c] = await gateway.hasPermissions(_typesFor(c)); }
      if (state == HealthState.unavailable || state == HealthState.needsPermission) state = HealthState.idle;
      _updateNeedsPermission();
    } catch (_) { state = HealthState.error; message = 'No se pudo consultar el estado de ${gateway.platformName}.'; }
    notifyListeners();
  }

  Set<HType> _typesFor(HealthCat c) => {for (final t in healthCatTypes[c]!) if (gateway.supports(t)) t};

  String _availMsg() => switch (avail) {
        HealthAvail.notInstalled => 'Falta la app Health Connect (Android 13 o anterior). Instálala desde Google Play.',
        HealthAvail.updateRequired => 'Health Connect necesita actualizarse.',
        HealthAvail.unsupported => '${gateway.platformName} no está disponible en este dispositivo.',
        _ => '',
      };

  void _updateNeedsPermission() {
    if (!master) return;
    final missing = [for (final c in HealthCat.values) if (cats[c] == true && granted[c] != true) c];
    if (missing.isNotEmpty && state == HealthState.idle) { state = HealthState.needsPermission; message = 'Faltan permisos en ${gateway.platformName} para: ${missing.map((c) => c.title).join(', ')}.'; }
    else if (missing.isEmpty && state == HealthState.needsPermission) { state = HealthState.idle; message = null; }
  }

  /// Interruptor maestro. Al activarlo pide permisos solo de las categorías activas; si no se concede ninguno, se queda apagado.
  Future<void> setMaster(bool on) async {
    if (!on) { await stopSharing(); return; }
    master = true; state = HealthState.idle; message = null; notifyListeners();
    await savePref('hcOn', 1);
    await refreshPermissions();
    if (avail != HealthAvail.ready) { return; } // se queda encendido pero con el aviso; no envía nada
    await _requestForEnabled();
    if (!HealthCat.values.any(effective)) {
      master = false; await savePref('hcOn', 0); state = HealthState.off;
      message = 'No se concedió ningún permiso: el envío sigue desactivado.'; notifyListeners();
    }
  }

  /// Pide en el sistema los permisos que faltan de las categorías activas (lo usa el aviso de permisos del arranque).
  Future<void> askMissingPermissions() => _requestForEnabled();

  Future<void> _requestForEnabled() async {
    final need = <HType>{for (final c in HealthCat.values) if (cats[c] == true && granted[c] != true) ..._typesFor(c)};
    if (need.isNotEmpty) { try { await gateway.requestPermissions(need); } catch (_) {} }
    await refreshPermissions();
  }

  /// Una categoría. Al apagarla, los envíos futuros se detienen YA (también el que esté en curso).
  Future<void> setCat(HealthCat c, bool on) async {
    cats[c] = on; await savePref(c.prefKey, on ? 1 : 0);
    if (!on && _running) { /* el bucle consulta effective() antes de cada dato */ }
    notifyListeners();
    if (on && master && avail == HealthAvail.ready && granted[c] != true) {
      try { await gateway.requestPermissions(_typesFor(c)); } catch (_) {}
      await refreshPermissions();
    } else { _updateNeedsPermission(); notifyListeners(); }
  }

  /// «Dejar de compartir»: apaga todo y cancela lo que esté en curso. No revoca permisos ni borra nada ya enviado.
  Future<void> stopSharing() async {
    _cancel = true; master = false; state = HealthState.off; message = null; notifyListeners();
    await savePref('hcOn', 0);
  }

  // ---- Borrado individual (DEV_008) ----
  /// Para la UI: asegura que el libro está cargado antes de consultar lo enviado.
  Future<void> loadLedgerForUi() => _loadLedger();
  bool sleepSent(String date) => (_ledger['sleep'] as Map).containsKey(date);
  bool sessionSent(String key) => (_ledger['sessions'] as Map).containsKey(key);
  /// Un día «se envió» si alguna marca de agua llega a su inicio (aprox.).
  bool daySent(String day) { final d = DateTime.tryParse(day); if (d == null) return false; return (_ledger['wm'] as Map).values.any((v) => v is num && v >= d.millisecondsSinceEpoch); }

  /// Borra de Health Connect / Salud lo que Vigor envió de esos registros y limpia el libro. Nunca lanza.
  /// [days]: yyyy-MM-dd (pasos, distancia, calorías, pulso, HRV, pulso en reposo, SpO2, temperatura de ese día).
  Future<HealthDeleteReport> deleteFromHealth({List<Night> nights = const [], List<Session> sessions = const [], List<String> days = const []}) async {
    await cancelAndWait(); // R3: no tocar el libro mientras run() lo usa
    await _loadLedger();
    final rep = HealthDeleteReport();
    final sleepIds = [for (final n in nights) if (sleepSent(n.date)) n], sesIds = [for (final x in sessions) if (sessionSent(x.key)) x], dayList = [for (final d in days) if (daySent(d)) d];
    if (sleepIds.isEmpty && sesIds.isEmpty && dayList.isEmpty) return rep; // nada que borrar allí
    try { avail ??= await gateway.availability(); } catch (_) { avail = HealthAvail.unsupported; }
    if (avail != HealthAvail.ready) { rep.notes.add('${gateway.platformName} no está disponible: no se pudo borrar allí.'); rep.failed += sleepIds.length + sesIds.length + dayList.length; return rep; }
    for (final n in sleepIds) {
      var ok = false;
      try { final a = n.down ?? DateTime.parse(n.date), b = n.up ?? a.add(const Duration(hours: 12)); ok = await gateway.deleteByClientId(HType.sleep, 'vigor-sleep-${n.date}', a.subtract(const Duration(minutes: 1)), b.add(const Duration(minutes: 1))); } catch (_) {}
      if (ok) { (_ledger['sleep'] as Map).remove(n.date); rep.ok++; } else { rep.failed++; }
    }
    var companionNote = false;
    for (final x in sesIds) {
      var ok = false;
      try { ok = await gateway.deleteWorkout((_ledger['sessions'] as Map)[x.key] as String); } catch (_) {}
      if (ok) { (_ledger['sessions'] as Map).remove(x.key); (_ledger['routes'] as Map).remove(x.key); rep.ok++; companionNote = true; } else { rep.failed++; }
    }
    if (companionNote) rep.notes.add('La distancia y las calorías que se escriben junto a un ejercicio no se pueden identificar por separado y pueden seguir en ${gateway.platformName}.');
    for (final d in dayList) {
      final a = DateTime.parse(d), b = DateTime(a.year, a.month, a.day + 1); var all = true;
      for (final t in const [HType.steps, HType.distance, HType.activeEnergy, HType.heartRate, HType.hrvRmssd, HType.restingHr, HType.spo2, HType.bodyTemp]) {
        if (!gateway.supports(t)) continue;
        try { if (!await gateway.deleteRange(t, a, b)) all = false; } catch (_) { all = false; }
      }
      if (all) { rep.ok++; } else { rep.failed++; }
    }
    await _persist(); notifyListeners();
    if (rep.failed > 0) rep.notes.add('No se pudo borrar todo en ${gateway.platformName} (¿falta permiso?). Puedes borrarlo desde sus ajustes.');
    return rep;
  }

  /// Tras «Borrar todos mis datos» el libro local ya no existe: el estado interno se reinicia (lo ya enviado a Health Connect/Salud NO se toca).
  Future<void> afterWipe() async { await cancelAndWait(); _ledger = _fresh(); _ledgerLoaded = true; last = null; totalSent = 0; notifyListeners(); }

  /// Borra lo que Vigor escribió (la API solo deja borrar lo propio). Reinicia el libro. Devuelve true si no hubo fallos.
  Future<bool> deleteSent() async {
    _cancel = true;
    final since = (_ledger['first'] as num?)?.toInt();
    var ok = true;
    if (avail == null) { try { avail = await gateway.availability(); } catch (_) {} }
    if (avail == HealthAvail.ready) {
      final from = since != null ? DateTime.fromMillisecondsSinceEpoch(since).subtract(const Duration(days: 1)) : clock().subtract(const Duration(days: kSessionBackfillDays + 2));
      final to = clock().add(const Duration(days: 1));
      for (final t in HType.values) {
        if (t == HType.workout || t == HType.route || !gateway.supports(t)) continue;
        try { if (!await gateway.deleteRange(t, from, to)) ok = false; } catch (_) { ok = false; }
      }
      final ss = Map<String, dynamic>.from(_ledger['sessions'] as Map? ?? {});
      for (final id in ss.values) { if (id is String && id.isNotEmpty) { try { if (!await gateway.deleteWorkout(id)) ok = false; } catch (_) { ok = false; } } }
    } else { ok = false; }
    if (ok) { _ledger = _fresh(); last = null; totalSent = 0; await _persist(); message = 'Se pidió a ${gateway.platformName} borrar lo que Vigor había escrito.'; }
    else { message = 'No se pudo borrar todo. Puedes borrarlo desde ${gateway.platformName}.'; }
    notifyListeners();
    return ok;
  }

  /// Envía lo nuevo. No lanza excepciones ni bloquea la UI (cede el turno cada [batch] datos).
  /// Devuelve true solo si la ronda terminó sin error y sin cancelarse (si no exportó nada, false).
  Future<bool> run() {
    if (_running || !master || source == null) return Future.value(false);
    return _inflight = _run();
  }

  Future<void>? _inflight;
  /// Cancela un envío en vuelo y espera a que termine (borrados y wipe).
  Future<void> cancelAndWait() async {
    final f = _inflight; if (f == null || !_running) return;
    _cancel = true;
    try { await f; } catch (_) {}
  }

  Future<bool> _run() async {
    var done = false;
    catError.clear(); _running = true; _cancel = false; state = HealthState.running; message = null; lastCount = 0; notifyListeners();
    try {
      await _loadLedger();
      await refreshPermissions();
      if (avail != HealthAvail.ready || !HealthCat.values.any(effective)) { state = avail != HealthAvail.ready ? HealthState.unavailable : (master ? HealthState.needsPermission : HealthState.off); if (state == HealthState.needsPermission) message ??= 'Faltan permisos en ${gateway.platformName}.'; return false; }
      final src = source!();
      var errors = 0;
      // Lo poco y valioso va primero (sueño, ejercicios): Health Connect limita las escrituras por hora y,
      // si lo denso (pasos/pulso cada 5 o 1 min) agota la cuota, lo último se rechazaba siempre.
      if (!_cancel && master) errors += await _sendSleep(src);
      if (!_cancel && master) errors += await _sendSessions(src);
      var dense = 0, denseStop = false;
      for (final st in _streams(src)) {
        if (_cancel || !master || denseStop) break;
        if (!effective(st.cat) || !gateway.supports(st.type)) continue;
        final wm = ((_ledger['wm'] as Map)[st.id] as num?)?.toInt();
        final floor = clock().subtract(const Duration(days: kDenseBackfillDays)).millisecondsSinceEpoch;
        final from = wm == null ? floor : (wm > floor ? wm : floor);
        final pending = <HealthItem>[];
        for (final it in st.items) {
          if (_cancel || !master || !effective(st.cat)) break; // desactivar detiene los envíos futuros inmediatamente
          if (it.start.millisecondsSinceEpoch <= from && (wm != null || it.start.millisecondsSinceEpoch < floor)) continue;
          if (wm != null && it.start.millisecondsSinceEpoch <= wm) continue;
          pending.add(it);
          if (dense + pending.length >= kMaxDensePerRun) break; // tope por ronda; continúa en la siguiente
        }
        if (pending.isEmpty) continue;
        BatchOut r; try { r = await gateway.writeBatch(pending); } catch (_) { r = const BatchOut(0); }
        if (r.written > 0) {
          final lastIt = pending[r.written - 1];
          catLastOk[st.cat] = '${_dm(lastIt.start)} ${_hm(lastIt.start)}';
          (_ledger['wm'] as Map)[st.id] = lastIt.start.millisecondsSinceEpoch; _ledger['first'] ??= pending.first.start.millisecondsSinceEpoch;
          lastCount += r.written; dense += r.written;
        }
        if (r.written < pending.length) { errors++; _fail(st.cat, r.error); denseStop = true; } // cuota agotada u otro rechazo: no se insiste; la marca queda donde se cortó y se reintenta en la siguiente sincronización
        else if (dense >= kMaxDensePerRun) { denseStop = true; }
        await Future<void>.delayed(Duration.zero);
      }
      ranOnce = true; totalSent += lastCount; _ledger['total'] = totalSent;
      if (lastCount > 0 || errors == 0) { last = clock(); _ledger['last'] = last!.millisecondsSinceEpoch; }
      await _persist();
      if (errors > 0) { state = HealthState.error; message = 'Algunos datos no se pudieron enviar a ${gateway.platformName}; se reintentará en la próxima sincronización.'; }
      else { state = master ? HealthState.idle : HealthState.off; done = !_cancel; }
    } catch (_) {
      state = HealthState.error; message = 'Error inesperado al enviar a ${gateway.platformName}.';
    } finally { _running = false; notifyListeners(); }
    return done;
  }

  Future<int> _sendSleep(HealthSource src) async {
    if (!effective(HealthCat.sleep) || !gateway.supports(HType.sleep)) return 0;
    var errors = 0; final sent = _ledger['sleep'] as Map;
    final floor = clock().subtract(const Duration(days: kSessionBackfillDays));
    nightsSeen = src.nights.length; nightsValid = 0;
    for (final n in src.nights.reversed) {
      if (_cancel || !master || !effective(HealthCat.sleep)) break;
      final s = n.down, e = n.up;
      if (s == null || e == null || !e.isAfter(s) || s.isBefore(floor) || n.total <= 0) continue;
      nightsValid++;
      final ver = e.millisecondsSinceEpoch ~/ 60000;
      // Con fases la version sube: Health Connect sustituye la sesion sin fases enviada antes (mismo identificador de registro).
      final stagesOut = SleepStagesOut.fromNight(n);
      final want = stagesOut != null && !gateway.isIos ? ver + kStagedVersionOffset : ver;
      if (sent[n.date] == want) { catLastOk.putIfAbsent(HealthCat.sleep, () => '${_dm(s)} ${_hm(s)}–${_hm(e)}'); continue; }
      bool ok; try { ok = await gateway.write(HealthItem(HType.sleep, HealthCat.sleep, 'vigor-sleep-${n.date}', s, e, n.total.toDouble(), version: want.toDouble(), stages: want == ver ? null : stagesOut)); } catch (x) { ok = false; _ledger['lastEx'] = x.runtimeType.toString(); }
      if (!ok) { errors++; _fail(HealthCat.sleep); break; }
      catError.remove(HealthCat.sleep); catLastOk[HealthCat.sleep] = '${_dm(s)} ${_hm(s)}–${_hm(e)}';
      // Si Health Connect no aceptó las fases, se guardó la sesión sin ellas con la version base: se reintentará con fases.
      sent[n.date] = (want == ver || stagesOut!.written) ? want : ver; _ledger['first'] ??= s.millisecondsSinceEpoch; lastCount++;
    }
    return errors;
  }

  Future<int> _sendSessions(HealthSource src) async {
    final wantEx = effective(HealthCat.exercise), wantRoute = effective(HealthCat.route);
    if (!wantEx && !wantRoute) return 0;
    var errors = 0; final sent = _ledger['sessions'] as Map; final routes = _ledger['routes'] as Map;
    final floor = clock().subtract(const Duration(days: kSessionBackfillDays));
    for (final s in src.sessions.reversed) {
      if (_cancel || !master) break;
      if (s.start.isBefore(floor) || s.seconds < 60) continue;
      final end = s.start.add(Duration(seconds: s.seconds));
      var id = sent[s.key] as String?;
      if (id == null && effective(HealthCat.exercise)) {
        final w = WorkoutOut(s.key, sportName(s.sportType), s.sportType, s.start, end, s.meters, s.kcal.round());
        String? r; try { r = await gateway.writeWorkout(w); } catch (_) { r = null; }
        if (r == null || r.isEmpty) { errors++; _fail(HealthCat.exercise); break; }
        catError.remove(HealthCat.exercise); catLastOk[HealthCat.exercise] = '${_dm(s.start)} ${_hm(s.start)}';
        sent[s.key] = r; id = r; _ledger['first'] ??= s.start.millisecondsSinceEpoch; lastCount++;
      }
      if (id != null && wantRoute && effective(HealthCat.route) && routes[s.key] != true) {
        final pts = routePointsOf(s.route, s.start, end);
        if (pts.length >= 2) {
          bool ok; try { ok = await gateway.writeRoute(id, pts); } catch (_) { ok = false; }
          if (!ok) { errors++; _fail(HealthCat.route); continue; }
          catError.remove(HealthCat.route); catLastOk[HealthCat.route] = '${_dm(s.start)} ${_hm(s.start)}';
          routes[s.key] = true; lastCount++;
        } else { routes[s.key] = true; }
      }
      await Future<void>.delayed(Duration.zero);
    }
    return errors;
  }

  // ---- planificación (pura y testeable) ----
  List<_Stream> _streams(HealthSource src) {
    final keys = src.days.keys.toList()..sort();
    List<HealthItem> collect(HType t, HealthCat c, String id, Iterable<Sample> Function(Day) pick, double Function(double) conv, Duration len) {
      final out = <HealthItem>[];
      for (final k in keys) { for (final s in pick(src.days[k]!)) { out.add(HealthItem(t, c, 'vigor-$id-${s.t.millisecondsSinceEpoch ~/ 60000}', s.t, s.t.add(len), conv(s.v))); } }
      out.sort((a, b) => a.start.compareTo(b.start));
      return out;
    }
    const five = Duration(minutes: 5), minute = Duration(minutes: 1);
    final rest = <HealthItem>[for (final e in src.resting.entries) () { final d = DateTime.parse(e.key); final t = DateTime(d.year, d.month, d.day, 6); return HealthItem(HType.restingHr, HealthCat.heart, 'vigor-rest-${e.key}', t, t, e.value); }()]..sort((a, b) => a.start.compareTo(b.start));
    return [
      _Stream('steps', HType.steps, HealthCat.activity, collect(HType.steps, HealthCat.activity, 'steps', (d) => d.steps5.where((s) => s.v > 0), (v) => v, five)),
      _Stream('dist', HType.distance, HealthCat.activity, collect(HType.distance, HealthCat.activity, 'dist', (d) => d.km5.where((s) => s.v > 0), (v) => v * 1000, five)),
      _Stream('kcal', HType.activeEnergy, HealthCat.activity, collect(HType.activeEnergy, HealthCat.activity, 'kcal', (d) => d.kcal5.where((s) => s.v > 0), (v) => v, five)),
      _Stream('hr', HType.heartRate, HealthCat.heart, collect(HType.heartRate, HealthCat.heart, 'hr', (d) => d.hr, (v) => v, minute)),
      _Stream('hrv', HType.hrvRmssd, HealthCat.heart, collect(HType.hrvRmssd, HealthCat.heart, 'hrv', (d) => d.hrv, (v) => v, Duration.zero)),
      _Stream('rest', HType.restingHr, HealthCat.heart, rest),
      _Stream('spo2', HType.spo2, HealthCat.oxygen, collect(HType.spo2, HealthCat.oxygen, 'spo2', (d) => d.spo2, (v) => v, Duration.zero)),
      _Stream('temp', HType.bodyTemp, HealthCat.temperature, collect(HType.bodyTemp, HealthCat.temperature, 'temp', (d) => d.temp, (v) => v, Duration.zero)),
    ];
  }
}

class _Stream { final String id; final HType type; final HealthCat cat; final List<HealthItem> items; _Stream(this.id, this.type, this.cat, this.items); }

/// Puntos de ruta con hora: la pulsera no da hora por punto, así que se reparten de forma uniforme en la duración (aproximado). Se omiten los cortes (NaN).
List<RoutePoint> routePointsOf(List<(double, double)> route, DateTime start, DateTime end) {
  final valid = [for (final p in route) if (!p.$1.isNaN && !p.$2.isNaN && p.$1.abs() <= 90 && p.$2.abs() <= 180) p];
  if (valid.length < 2) return const [];
  final total = end.difference(start).inMilliseconds;
  return [for (var i = 0; i < valid.length; i++) RoutePoint(valid[i].$1, valid[i].$2, start.add(Duration(milliseconds: (total * i / (valid.length - 1)).round())))];
}
