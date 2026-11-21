import 'dart:async';

/// Sincronización automática con la app abierta (DEV_012, fase 1). Lógica pura con reloj y acciones inyectadas.
/// Con la app cerrada la hace el trabajo de WorkManager (Kotlin, SyncWorker).
const kAutoSyncIntervals = [15, 30, 60];
const kAutoSyncDefaultMin = 30;
/// Al reanudar la app se sincroniza si la última sincronización correcta tiene más de estos minutos (o el intervalo, si es menor).
const kResumeStaleMin = 5;
/// Espera entre intentos de reconexión (s) tras 1, 2, 3... intentos seguidos sin éxito; el último es el tope (10 min).
const kReconnectDelaysSec = [15, 30, 60, 120, 300, 600];
/// Separación mínima entre dos intentos de sincronizar (evita bucles si una sincronización falla).
const kMinSyncAttemptGap = Duration(minutes: 2);
const kAutoTick = Duration(seconds: 30);

int safeAutoMin(int? m) => m != null && kAutoSyncIntervals.contains(m) ? m : kAutoSyncDefaultMin;
Duration reconnectDelay(int failures) => Duration(seconds: kReconnectDelaysSec[(failures < 1 ? 1 : failures).clamp(1, kReconnectDelaysSec.length) - 1]);

/// «Sincronizado hace X» (sin datos personales). null -> «Aún sin sincronizar».
String syncAgoText(DateTime? last, DateTime now) {
  if (last == null) return 'Aún sin sincronizar';
  final d = now.difference(last);
  if (d.inSeconds < 90) return 'Sincronizado ahora mismo';
  if (d.inMinutes < 60) return 'Sincronizado hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'Sincronizado hace ${d.inHours} h';
  return 'Sincronizado hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
}

enum AutoAction { none, connect, sync }

class AutoSync {
  AutoSync({required this.clock, required this.connState, required this.hasMac, required this.lastSync, required this.busy, required this.connect, required this.sync});
  final DateTime Function() clock;
  /// 'connected' | 'connecting' | 'scanning' | 'idle' | 'disconnected'
  final String Function() connState;
  final bool Function() hasMac;
  final DateTime? Function() lastSync;
  /// true si hay una sincronización, medición de pulso en vivo, deporte, borrado... en curso: no se solapa.
  final bool Function() busy;
  final Future<void> Function() connect, sync;

  bool enabled = true, foreground = false, userHold = false;
  int intervalMin = kAutoSyncDefaultMin;
  int failures = 0; DateTime? nextConnectAt, lastAttempt; bool _resumePending = false, _inFlight = false;
  Timer? _timer;

  void setEnabled(bool v) { enabled = v; _rearm(); if (v) unawaited(evaluate()); }
  void setInterval(int m) { intervalMin = safeAutoMin(m); unawaited(evaluate()); }
  void onResume() { foreground = true; failures = 0; nextConnectAt = null; _resumePending = true; _rearm(); unawaited(evaluate()); }
  void onPause() { foreground = false; _rearm(); }
  void dispose() { _timer?.cancel(); _timer = null; }
  void _rearm() {
    _timer?.cancel(); _timer = null;
    if (enabled && foreground) _timer = Timer.periodic(kAutoTick, (_) => unawaited(evaluate()));
  }

  AutoAction decide() {
    if (!enabled || !foreground || userHold || !hasMac() || busy()) return AutoAction.none;
    final st = connState(), now = clock();
    if (st == 'connecting' || st == 'scanning') return AutoAction.none;
    if (st != 'connected') { final n = nextConnectAt; return n != null && now.isBefore(n) ? AutoAction.none : AutoAction.connect; }
    final la = lastAttempt; if (la != null && now.difference(la) < kMinSyncAttemptGap) return AutoAction.none;
    final last = lastSync(); final limit = _resumePending ? (intervalMin < kResumeStaleMin ? intervalMin : kResumeStaleMin) : intervalMin;
    return last == null || now.difference(last) >= Duration(minutes: limit) ? AutoAction.sync : AutoAction.none;
  }

  /// Decide y actúa. Nunca lanza.
  Future<void> evaluate() async {
    if (_inFlight) return;
    final a = decide();
    if (connState() == 'connected') { failures = 0; nextConnectAt = null; if (a != AutoAction.sync) _resumePending = false; }
    if (a == AutoAction.none) return;
    _inFlight = true;
    try {
      final now = clock();
      if (a == AutoAction.connect) { failures++; nextConnectAt = now.add(reconnectDelay(failures)); await connect(); }
      else { lastAttempt = now; _resumePending = false; await sync(); }
    } catch (_) {} finally { _inFlight = false; }
  }
}
