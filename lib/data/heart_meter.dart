import 'dart:async';
import 'package:flutter/foundation.dart';

/// Medición puntual de pulso con la SDK Veepoo (startDetectHeart / stopDetectHeart, verificados en vpprotocol-2.3.96.15.aar).
/// No hay pulso continuo en la SDK: solo hay valor "en vivo" mientras dura la medición que el usuario pide.
enum HeartPhase { idle, starting, measuring, done, failed }

/// Un valor de la pulsera solo se muestra si es plausible (la SDK documenta 20-300; 0 y fuera de rango son inválidos).
bool validHeart(num? v) => v != null && v >= 30 && v <= 220;

class HeartMeter extends ChangeNotifier {
  /// Tiempo máximo de una medición; pasado, se para sí o sí (batería).
  static const maxDuration = Duration(seconds: 60);
  /// Lecturas válidas necesarias para dar la medición por buena.
  static const needed = 6;
  /// Cuánto tiempo se enseña un valor medido antes de volver al último registro.
  static const keepFor = Duration(minutes: 5);

  final Future<void> Function() _start;
  final Future<void> Function() _stop;
  final bool Function() isConnected;
  final DateTime Function() clock;
  HeartMeter({required Future<void> Function() start, required Future<void> Function() stop, required this.isConnected, this.clock = DateTime.now})
      : _start = start, _stop = stop;

  HeartPhase phase = HeartPhase.idle;
  /// Último valor válido de esta medición (en vivo mientras mide; final al acabar).
  int? value; DateTime? at; String? message;
  int _valid = 0; final _recent = <int>[]; Timer? _timer;

  bool get active => phase == HeartPhase.starting || phase == HeartPhase.measuring;
  /// ¿Hay un valor medido por la app, todavía reciente?
  bool get hasFresh => value != null && at != null && (active || clock().difference(at!) < keepFor);
  int get progressCount => _valid;

  Future<void> begin() async {
    if (active) return;
    if (!isConnected()) { _fail('La pulsera no está conectada.'); return; }
    phase = HeartPhase.starting; value = null; at = null; message = null; _valid = 0; _recent.clear(); notifyListeners();
    _timer?.cancel(); _timer = Timer(maxDuration, _timeout);
    try { await _start(); } catch (_) { _end(); _fail('No se pudo iniciar la medición.'); }
  }

  void _timeout() {
    final had = value != null;
    _finish(had ? HeartPhase.done : HeartPhase.failed, had ? null : 'No hubo una lectura válida. Ajusta la pulsera y prueba de nuevo.');
  }

  /// Evento de la SDK: {status: nombre de EHeartStatus, value: int}.
  void onEvent(Map m) {
    if (!active) return;
    final st = '${m['status']}'; final v = m['value'];
    switch (st) {
      case 'STATE_HEART_BUSY': _finish(HeartPhase.failed, 'La pulsera está ocupada midiendo otra cosa.'); return;
      case 'STATE_LOW_BATTERY': _finish(HeartPhase.failed, 'Batería de la pulsera demasiado baja para medir.'); return;
      case 'STATE_HEART_WEAR_ERROR': message = 'Ajusta la pulsera: no detecta bien tu muñeca.'; if (phase == HeartPhase.starting) phase = HeartPhase.measuring; notifyListeners(); return;
    }
    if (phase == HeartPhase.starting) phase = HeartPhase.measuring;
    final n = v is num ? v : null;
    if (validHeart(n)) {
      value = n!.round(); at = clock(); message = null; _valid++; _recent.add(value!);
      if (_valid >= needed) { final l = _recent.sublist(_recent.length - 3)..sort(); value = l[1]; _finish(HeartPhase.done, null); return; }
    }
    notifyListeners();
  }

  void _fail(String msg) { phase = HeartPhase.failed; message = msg; notifyListeners(); }

  void _end() { _timer?.cancel(); _timer = null; }

  void _finish(HeartPhase p, String? msg) {
    _end(); phase = p; message = msg;
    if (p == HeartPhase.failed) { value = null; at = null; }
    notifyListeners();
    _stop().catchError((_) {});
  }

  /// El usuario cancela, sale de la pantalla o la app pasa a segundo plano: se para la medición sin dejar nada encendido.
  void cancel({bool notify = true}) {
    final was = active; _end();
    if (was) { phase = HeartPhase.idle; value = null; at = null; message = null; _valid = 0; _recent.clear(); _stop().catchError((_) {}); }
    if (notify && was) notifyListeners();
  }

  bool _dead = false;
  @override
  void notifyListeners() { if (!_dead) super.notifyListeners(); }
  @override
  void dispose() { cancel(notify: false); _dead = true; super.dispose(); }
}
