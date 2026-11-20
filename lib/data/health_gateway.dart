import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'health_sync.dart';
import 'sports.dart';

/// Implementación real de [HealthGateway] con el paquete `health` (Health Connect en Android, HealthKit en iOS).
/// Android: compila (flutter build apk --debug); NO probada en un móvil con Health Connect.
/// iOS: implementada, NO compilada ni probada (no hay Mac/Xcode).
class PlatformHealthGateway implements HealthGateway {
  PlatformHealthGateway({Health? health}) : _h = health ?? Health();
  final Health _h; bool _configured = false;
  static const _ch = MethodChannel('vigor/methods');

  @override String get platformName => Platform.isIOS ? 'Apple Salud' : 'Health Connect';
  @override bool get isIos => Platform.isIOS;

  String? _err;
  @override String? get lastError => _err;
  static String _short(Object e) { final m = '${e is PlatformException ? (e.message ?? e.code) : e}'.replaceAll(RegExp(r'\s+'), ' '); return '${e.runtimeType}: ${m.length > 80 ? m.substring(0, 80) : m}'; }

  Future<void> _cfg() async { if (!_configured) { await _h.configure(); _configured = true; } }

  /// Tipo de la plataforma o null si Vigor no lo escribe allí.
  HealthDataType? _map(HType t) => switch (t) {
        HType.steps => HealthDataType.STEPS,
        HType.distance => isIos ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA,
        HType.activeEnergy => HealthDataType.ACTIVE_ENERGY_BURNED,
        HType.heartRate => HealthDataType.HEART_RATE,
        HType.hrvRmssd => isIos ? null : HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // iOS solo tiene SDNN: no se mezcla
        HType.restingHr => isIos ? null : HealthDataType.RESTING_HEART_RATE, // en iOS lo calcula Apple: no verificado que se pueda escribir
        HType.spo2 => HealthDataType.BLOOD_OXYGEN,
        HType.bodyTemp => HealthDataType.BODY_TEMPERATURE,
        HType.sleep => isIos ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION,
        HType.workout => HealthDataType.WORKOUT,
        HType.route => HealthDataType.WORKOUT_ROUTE,
      };

  @override bool supports(HType t) => _map(t) != null;

  @override
  Future<HealthAvail> availability() async {
    try {
      await _cfg();
      if (Platform.isIOS) return HealthAvail.ready; // HealthKit existe en todo iPhone (no en iPad antiguo: no verificado)
      if (!Platform.isAndroid) return HealthAvail.unsupported;
      final s = await _h.getHealthConnectSdkStatus();
      return switch (s) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvail.ready,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => HealthAvail.updateRequired,
        _ => HealthAvail.notInstalled,
      };
    } catch (_) { return HealthAvail.unsupported; }
  }

  List<HealthDataType> _types(Set<HType> ts) => [for (final t in ts) if (_map(t) != null) _map(t)!];
  List<HealthDataAccess> _w(int n) => List.filled(n, HealthDataAccess.WRITE);

  @override
  Future<bool> hasPermissions(Set<HType> types) async {
    final l = _types(types); if (l.isEmpty) return false;
    try { await _cfg(); return await _h.hasPermissions(l, permissions: _w(l.length)) == true; } catch (_) { return false; }
  }

  @override
  Future<bool> requestPermissions(Set<HType> types) async {
    final l = _types(types); if (l.isEmpty) return false;
    await _cfg(); return await _h.requestAuthorization(l, permissions: _w(l.length));
  }

  @override
  Future<bool> write(HealthItem it) async {
    final type = _map(it.type); if (type == null) return false;
    _err = null;
    try {
      await _cfg();
      Future<bool> w(HealthDataType t) => _h.writeHealthData(value: it.value, type: t, startTime: it.start, endTime: it.end,
          clientRecordId: isIos ? null : it.id, clientRecordVersion: isIos ? null : it.version, recordingMethod: RecordingMethod.automatic);
      var ok = await w(type);
      // Cobertura: si Health Connect rechaza la sesión de sueño, se prueba con una etapa «dormido» (mismo permiso WRITE_SLEEP).
      if (!ok && it.type == HType.sleep && !isIos) ok = await w(HealthDataType.SLEEP_ASLEEP);
      if (!ok) _err = 'el sistema rechazó la escritura (sin detalle; ver logcat FLUTTER_HEALTH)';
      return ok;
    } catch (e) { _err = _short(e); return false; }
  }

  @override
  Future<String?> writeWorkout(WorkoutOut w) async {
    await _cfg();
    final id = await _h.writeWorkoutDataUUID(activityType: workoutTypeFor(w.sportType, ios: isIos), start: w.start, end: w.end,
        totalEnergyBurned: w.kcal > 0 ? w.kcal : null, totalDistance: w.meters > 0 ? w.meters : null, title: w.title, recordingMethod: RecordingMethod.automatic);
    return (id == null || id.isEmpty || id == 'null') ? null : id;
  }

  @override
  Future<bool> writeRoute(String workoutId, List<RoutePoint> pts) async {
    String? builder;
    try {
      await _cfg();
      builder = await _h.startWorkoutRoute();
      // Por lotes para no enviar rutas largas en una sola llamada.
      for (var i = 0; i < pts.length; i += 500) {
        final chunk = pts.sublist(i, (i + 500).clamp(0, pts.length));
        final ok = await _h.insertWorkoutRouteData(builderId: builder, locations: [for (final p in chunk) WorkoutRouteLocation(latitude: p.lat, longitude: p.lng, timestamp: p.t)]);
        if (!ok) { await _h.discardWorkoutRoute(builder); return false; }
      }
      await _h.finishWorkoutRoute(builderId: builder, workoutUuid: workoutId);
      return true;
    } catch (_) { if (builder != null) { try { await _h.discardWorkoutRoute(builder); } catch (_) {} } return false; }
  }

  @override
  Future<bool> deleteRange(HType t, DateTime from, DateTime to) async {
    final type = _map(t); if (type == null) return true;
    await _cfg(); return _h.delete(type: type, startTime: from, endTime: to);
  }

  @override
  Future<bool> deleteWorkout(String id) async { await _cfg(); return _h.deleteByUUID(uuid: id, type: HealthDataType.WORKOUT); }

  @override
  Future<bool> deleteByClientId(HType t, String id, DateTime from, DateTime to) async {
    final type = _map(t); if (type == null) return true;
    await _cfg();
    if (isIos) return _h.delete(type: type, startTime: from, endTime: to);
    return _h.deleteByClientRecordId(dataTypeKey: type, clientRecordId: id);
  }

  @override
  Future<void> openSettings() async { if (Platform.isAndroid) { try { await _ch.invokeMethod('openHealthSettings'); } catch (_) {} } }

  @override
  Future<void> installProvider() async { try { await _h.installHealthConnect(); } catch (_) {} }
}

/// Tipo de deporte de Vigor (id de la SDK Veepoo) -> tipo de Health Connect / HealthKit. Lo que no tiene equivalente claro va como «otro».
HealthWorkoutActivityType workoutTypeFor(int sportId, {required bool ios}) {
  final m = sportModes.where((e) => e.id == sportId);
  final key = m.isEmpty ? '' : m.first.key; final g = m.isEmpty ? SportGroup.other : m.first.group;
  switch (key) {
    case 'INDOOR_RUNNING': case 'Treadmill': return ios ? HealthWorkoutActivityType.RUNNING : HealthWorkoutActivityType.RUNNING_TREADMILL;
    case 'INDOOR_WALK': return ios ? HealthWorkoutActivityType.WALKING : HealthWorkoutActivityType.WALKING_TREADMILL;
    case 'INDOOR_RIDING': case 'SpinningBike': return ios ? HealthWorkoutActivityType.BIKING : HealthWorkoutActivityType.BIKING_STATIONARY;
    case 'HIKE': case 'Mountaineering': return HealthWorkoutActivityType.HIKING;
    case 'ELLIPTICAL': return HealthWorkoutActivityType.ELLIPTICAL;
    case 'ROWING_MACHINE': return ios ? HealthWorkoutActivityType.ROWING : HealthWorkoutActivityType.ROWING_MACHINE;
    case 'ROWING': return HealthWorkoutActivityType.ROWING;
    case 'SWIM': return HealthWorkoutActivityType.SWIMMING;
    case 'JUMP_ROPE': return HealthWorkoutActivityType.JUMP_ROPE;
    case 'YOGA': return HealthWorkoutActivityType.YOGA;
    case 'Pilates': return HealthWorkoutActivityType.PILATES;
    case 'PING_PONG': return HealthWorkoutActivityType.TABLE_TENNIS;
    case 'BASKETBALL': return HealthWorkoutActivityType.BASKETBALL;
    case 'VOLLEYBALL': case 'BeachVolleyball': return HealthWorkoutActivityType.VOLLEYBALL;
    case 'FOOTBALL': case 'BeachSoccer': case 'IndoorSoccer': return HealthWorkoutActivityType.SOCCER;
    case 'BADMINTON': return HealthWorkoutActivityType.BADMINTON;
    case 'TENNIS': return HealthWorkoutActivityType.TENNIS;
    case 'Squash': return HealthWorkoutActivityType.SQUASH;
    case 'CLIMB_STAIRS': case 'ClimbingTheStairs': return HealthWorkoutActivityType.STAIR_CLIMBING;
    case 'WEIGHTLIFTING': case 'Barbell': case 'DUMBBELL': case 'BodybuildingExercise': case 'StrengthTraining': return ios ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING : HealthWorkoutActivityType.STRENGTH_TRAINING;
    case 'BOXING': return HealthWorkoutActivityType.BOXING;
    case 'HIIT': return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
    case 'ROCK_CLIMBING': return ios ? HealthWorkoutActivityType.CLIMBING : HealthWorkoutActivityType.ROCK_CLIMBING;
    case 'DANCE': case 'Zumba': return HealthWorkoutActivityType.CARDIO_DANCE;
    case 'MartialArts': case 'Judo': case 'Karate': case 'Taekwondo': case 'MuayThai': case 'Jujitsu': return HealthWorkoutActivityType.MARTIAL_ARTS;
    case 'Kickboxing': return HealthWorkoutActivityType.KICKBOXING;
    case 'Wrestling': return ios ? HealthWorkoutActivityType.WRESTLING : HealthWorkoutActivityType.MARTIAL_ARTS;
    case 'Fencing': return HealthWorkoutActivityType.FENCING;
    case 'RUGBY_FOOTBALL': return HealthWorkoutActivityType.RUGBY;
    case 'HANDBALL': return HealthWorkoutActivityType.HANDBALL;
    case 'BASEBALL': return HealthWorkoutActivityType.BASEBALL;
    case 'Softball': return HealthWorkoutActivityType.SOFTBALL;
    case 'HOCKEY': return HealthWorkoutActivityType.HOCKEY;
    case 'GOLF': return HealthWorkoutActivityType.GOLF;
    case 'Cricket': return HealthWorkoutActivityType.CRICKET;
    case 'WaterPolo': return HealthWorkoutActivityType.WATER_POLO;
    case 'SAILBOAT': return HealthWorkoutActivityType.SAILING;
    case 'Archery': return HealthWorkoutActivityType.ARCHERY;
    case 'CURLING': return HealthWorkoutActivityType.CURLING;
    case 'SKI': case 'AlpineSkiing': return HealthWorkoutActivityType.DOWNHILL_SKIING;
    case 'CrossCountrySkiing': return HealthWorkoutActivityType.CROSS_COUNTRY_SKIING;
    case 'Snowboarding': case 'Snowboard': return HealthWorkoutActivityType.SNOWBOARDING;
    case 'Snowshoeing': return ios ? HealthWorkoutActivityType.OTHER : HealthWorkoutActivityType.SNOWSHOEING;
    case 'Frisbee': return ios ? HealthWorkoutActivityType.DISC_SPORTS : HealthWorkoutActivityType.FRISBEE_DISC;
    case 'TaiChi': return ios ? HealthWorkoutActivityType.TAI_CHI : HealthWorkoutActivityType.OTHER;
  }
  return switch (g) {
    SportGroup.run => HealthWorkoutActivityType.RUNNING,
    SportGroup.walk => HealthWorkoutActivityType.WALKING,
    SportGroup.bike => HealthWorkoutActivityType.BIKING,
    SportGroup.dance => HealthWorkoutActivityType.CARDIO_DANCE,
    SportGroup.combat => HealthWorkoutActivityType.MARTIAL_ARTS,
    _ => HealthWorkoutActivityType.OTHER,
  };
}
