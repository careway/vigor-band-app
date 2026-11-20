import 'dart:async';
import 'package:flutter/foundation.dart';
import 'heart_meter.dart' show validHeart;

/// Pulso en vivo con la app abierta: bucle startDetectHeart -> primera lectura estable -> stopDetectHeart -> pausa hasta completar el ciclo.
/// La SDK no ofrece pulso continuo: cada ciclo enciende el sensor óptico unos segundos (consumo de batería, ver Ajustes).
/// Estabilidad (decisión propia, no validada): se aceptan dos lecturas válidas (30-220) seguidas que difieran <= 8 lpm (se muestra su media);
/// si tras 3 lecturas válidas no hay dos coherentes, se muestra la mediana de las 3. Así una lectura suele tardar pocos segundos.
enum LivePhase { off, paused, waiting, reading, noReading }

class LiveHeart extends ChangeNotifier {
  static const allowedIntervals = [5, 10, 30, 60];
  /// Tiempo máximo de una lectura; pasado, se para y cuenta como fallo.
  static const readTimeout = Duration(seconds: 20);
  static const maxBackoff = Duration(seconds: 120);
  static const minGap = Duration(seconds: 2);
  static const stableDelta = 8;

  final Future<void> Function() _start;
  final Future<void> Function() _stop;
  /// Condiciones externas (conectada, sin sincronizar, sin deporte, sin medición manual, batería >= 20 %).
  final bool Function() canRun;
  final DateTime Function() clock;
  LiveHeart({required Future<void> Function() start, required Future<void> Function() stop, required this.canRun, this.clock = DateTime.now})
      : _start = start, _stop = stop;

  bool _enabled = true, _visible = false, lowBattery = false, _reading = false, _dead = false, _wasRunning = false;
  int _interval = 10;
  LivePhase phase = LivePhase.off;
  int? value; DateTime? at; int failures = 0;
  final _valid = <int>[]; Timer? _next, _readTimer; DateTime? _readStart;

  bool get enabled => _enabled; int get intervalSec => _interval; bool get reading => _reading;
  bool get _want => _enabled && _visible && !lowBattery;
  /// Valor mostrable: reciente (3 ciclos o 30 s como mínimo) y válido.
  bool get fresh => value != null && at != null && validHeart(value) && clock().difference(at!) < Duration(seconds: _interval * 3 < 30 ? 30 : _interval * 3);

  void setEnabled(bool v) { _enabled = v; _reconcile(); }
  void setInterval(int s) { if (!allowedIntervals.contains(s)) return; _interval = s; if (_next != null) { _next!.cancel(); _next = null; } _reconcile(); }
  /// Visible = pestaña Hoy delante y app en primer plano.
  void setVisible(bool v) { _visible = v; _reconcile(); }
  /// Al volver a primer plano: borra el backoff y pide una lectura enseguida (si se puede).
  void resumeNow() { _wasRunning = false; failures = 0; _reconcile(); }

  /// Una desconexión limpia el aviso de batería baja de la pulsera.
  void clearLowBattery() { lowBattery = false; _reconcile(); }

  /// Llamar cuando cambie cualquier condición externa (conexión, sincronización, deporte, medición manual, batería).
  void recheck() => _reconcile();

  @override
  void notifyListeners() { if (!_dead) super.notifyListeners(); }

  void _reconcile() {
    if (_dead) return;
    if (!_want) { _wasRunning = false; _halt(LivePhase.off); return; }
    if (!canRun()) { _wasRunning = false; _halt(LivePhase.paused); return; }
    // Se reanuda tras una pausa (conexión, sincronización, segundo plano...): sin backoff antiguo y con lectura inmediata.
    if (!_wasRunning) { _wasRunning = true; failures = 0; _next?.cancel(); _next = null; }
    if (!_reading && _next == null) { phase = value == null ? LivePhase.waiting : phase == LivePhase.noReading ? LivePhase.noReading : LivePhase.waiting; _schedule(Duration.zero); }
    notifyListeners();
  }

  /// Para todo (incluida la pulsera si estaba midiendo).
  void _halt(LivePhase p) {
    _next?.cancel(); _next = null; _readTimer?.cancel(); _readTimer = null;
    final was = _reading; _reading = false;
    if (was) _stop().catchError((_) {});
    if (phase != p || was) { phase = p; notifyListeners(); }
  }

  void _schedule(Duration d) { _next?.cancel(); _next = Timer(d, _tick); }

  void _tick() {
    _next = null;
    if (!_want || !canRun()) { _reconcile(); return; }
    _reading = true; phase = LivePhase.reading; _valid.clear(); _readStart = clock(); notifyListeners();
    _readTimer?.cancel(); _readTimer = Timer(readTimeout, () => _fail());
    _start().catchError((_) { _fail(); });
  }

  void onEvent(Map m) {
    if (!_reading) return;
    switch ('${m['status']}') {
      case 'STATE_LOW_BATTERY': lowBattery = true; _halt(LivePhase.off); return;
      case 'STATE_HEART_BUSY': case 'STATE_HEART_WEAR_ERROR': _fail(); return;
    }
    final v = m['value'];
    if (v is! num || !validHeart(v)) return;
    _valid.add(v.round());
    final n = _valid.length;
    int? res;
    if (n >= 2 && (_valid[n - 1] - _valid[n - 2]).abs() <= stableDelta) { res = ((_valid[n - 1] + _valid[n - 2]) / 2).round(); }
    else if (n >= 3) { final l = _valid.sublist(n - 3)..sort(); res = l[1]; }
    if (res == null) return;
    value = res; at = clock(); failures = 0;
    final took = at!.difference(_readStart ?? at!);
    _finish(LivePhase.waiting, _interval * 1000 - took.inMilliseconds);
  }

  void _fail() {
    if (!_reading) return;
    failures++;
    final secs = (_interval * (1 << (failures > 4 ? 4 : failures))).clamp(_interval, maxBackoff.inSeconds);
    _finish(LivePhase.noReading, secs * 1000);
  }

  void _finish(LivePhase p, int waitMs) {
    _readTimer?.cancel(); _readTimer = null; _reading = false; phase = p;
    _stop().catchError((_) {});
    notifyListeners();
    if (_want) _schedule(Duration(milliseconds: waitMs < minGap.inMilliseconds ? minGap.inMilliseconds : waitMs));
  }

  @override
  void dispose() { _dead = true; _next?.cancel(); _readTimer?.cancel(); if (_reading) { _reading = false; _stop().catchError((_) {}); } super.dispose(); }
}
