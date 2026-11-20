import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Único sitio donde se configura de dónde salen las actualizaciones.
/// El repositorio es privado: la API devuelve 404 y la app lo trata como "no se puede comprobar" (sin error visible).
/// Cuando el usuario haga público el repositorio, esta URL empieza a funcionar sola. La app NO lleva ningún token.
const kUpdateUrl = 'https://api.github.com/repos/careway/vigor-band-app/releases/tags/latest';
const kApkAsset = 'vigor-latest.apk';
const kAllowedHosts = {'github.com', 'objects.githubusercontent.com', 'api.github.com'};
const kCheckEvery = Duration(hours: 12);
const kMaxApkBytes = 200 * 1024 * 1024;

class UpdateInfo {
  final int build; final String url; final int size;
  const UpdateInfo(this.build, this.url, this.size);
}

/// Línea parseable del cuerpo de la release: "build: N".
int? parseBuild(String? body) {
  if (body == null) return null;
  final m = RegExp(r'^\s*build:\s*(\d{1,9})\s*$', multiLine: true, caseSensitive: false).firstMatch(body);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Solo https y los hosts de GitHub (la descarga redirige a objects.githubusercontent.com).
bool allowedUri(Uri u) => u.scheme == 'https' && kAllowedHosts.contains(u.host.toLowerCase()) && (!u.hasPort || u.port == 443);

/// Interpreta la respuesta de la API de releases. null si no tiene el formato esperado.
UpdateInfo? parseRelease(dynamic j) {
  if (j is! Map) return null;
  final build = parseBuild(j['body'] is String ? j['body'] as String : null);
  final assets = j['assets'];
  if (build == null || assets is! List) return null;
  for (final a in assets) {
    if (a is Map && a['name'] == kApkAsset && a['browser_download_url'] is String) {
      final u = Uri.tryParse(a['browser_download_url'] as String); final s = a['size'];
      if (u == null || !allowedUri(u) || s is! int || s < 1000000 || s > kMaxApkBytes) return null;
      return UpdateInfo(build, u.toString(), s);
    }
  }
  return null;
}

bool isNewer(int? installed, int latest) => installed != null && latest > installed;
bool shouldCheck(DateTime now, DateTime? last) => last == null || now.difference(last) >= kCheckEvery || now.isBefore(last);

enum UpdateState { unknown, checking, upToDate, available, unavailable, error, downloading, ready, needsPermission }

class Updater extends ChangeNotifier {
  static const _m = MethodChannel('vigor/methods');
  /// Para pruebas: sustituye la consulta de red (devuelve el JSON ya decodificado o lanza HttpStatus).
  Future<dynamic> Function(Uri) fetchJson;
  final DateTime Function() clock;
  Updater({Future<dynamic> Function(Uri)? fetch, this.clock = DateTime.now}) : fetchJson = fetch ?? _httpJson;

  UpdateState state = UpdateState.unknown; UpdateInfo? info; int? installed; String? versionName;
  DateTime? lastCheck; double progress = 0; String? message; bool dismissed = false; bool _cancel = false;

  bool _dead = false;
  @override
  void notifyListeners() { if (!_dead) super.notifyListeners(); }
  @override
  void dispose() { _dead = true; super.dispose(); }

  bool get available => info != null && isNewer(installed, info!.build) && state != UpdateState.upToDate;

  Future<void> init() async {
    try {
      final v = await _m.invokeMethod<Map>('appVersion');
      installed = (v?['code'] as num?)?.toInt(); versionName = v?['name'] as String?;
      final p = await _m.invokeMethod<Map>('getPrefs') ?? {};
      final mins = p['updChk']; if (mins is int && mins > 0) lastCheck = DateTime.fromMillisecondsSinceEpoch(mins * 60000);
      await _m.invokeMethod('cleanUpdates'); // un APK de una descarga anterior no debe quedarse en la cache
    } catch (_) {}
    notifyListeners();
    if (installed != null && shouldCheck(clock(), lastCheck)) unawaited(check(silent: true));
  }

  /// [silent]: la comprobación automática no enseña errores. Nunca lanza.
  Future<void> check({bool silent = false}) async {
    if (state == UpdateState.checking || state == UpdateState.downloading) return;
    final before = state; state = UpdateState.checking; message = null; notifyListeners();
    lastCheck = clock();
    try { await _m.invokeMethod('setPref', {'key': 'updChk', 'value': lastCheck!.millisecondsSinceEpoch ~/ 60000}); } catch (_) {}
    try {
      final j = await fetchJson(Uri.parse(kUpdateUrl)).timeout(const Duration(seconds: 15));
      final r = parseRelease(j);
      if (r == null) { state = UpdateState.error; message = 'La respuesta no tiene el formato esperado.'; }
      else { info = r; state = isNewer(installed, r.build) ? UpdateState.available : UpdateState.upToDate; }
    } on HttpException catch (e) {
      // 401/403/404: repositorio privado o sin release publicada. No es un fallo del usuario.
      state = UpdateState.unavailable; message = 'No se puede comprobar ahora (${e.message}).';
    } catch (_) {
      state = UpdateState.error; message = 'Sin conexión o sin respuesta del servidor.';
    }
    if (silent && (state == UpdateState.unavailable || state == UpdateState.error)) { state = before == UpdateState.available ? before : UpdateState.unknown; message = null; }
    notifyListeners();
  }

  void dismiss() { dismissed = true; notifyListeners(); }
  void cancelDownload() { _cancel = true; }

  /// Descarga, verifica y abre el instalador del sistema. Nada se ejecuta sin la confirmación del instalador de Android.
  Future<void> install() async {
    final i = info; if (i == null || state == UpdateState.downloading) return;
    final prev = state; state = UpdateState.downloading; progress = 0; message = null; _cancel = false; notifyListeners();
    File? part;
    try {
      final dir = await _m.invokeMethod<String>('updateDir'); if (dir == null) throw const FormatException('sin carpeta');
      part = File('$dir/vigor-update.apk.part'); final fin = File('$dir/vigor-update.apk');
      if (await part.exists()) await part.delete(); if (await fin.exists()) await fin.delete();
      await download(Uri.parse(i.url), part, i.size, (p) { progress = p; notifyListeners(); }, () => _cancel);
      await part.rename(fin.path);
      final r = await _m.invokeMethod<String>('installApk', {'name': 'vigor-update.apk'});
      if (r == 'needsPermission') { state = UpdateState.needsPermission; message = 'Permite instalar desde Vigor en la pantalla que se ha abierto y vuelve a pulsar Actualizar.'; }
      else { state = UpdateState.ready; message = 'Confirma la instalación en la pantalla del sistema.'; }
    } on _Cancelled { state = prev; message = 'Descarga cancelada.'; await _tidy(part); }
    catch (e) { state = UpdateState.error; message = e is FormatException ? e.message : 'No se pudo descargar o abrir el instalador.'; await _tidy(part); }
    notifyListeners();
  }

  Future<void> _tidy(File? f) async { try { if (f != null && await f.exists()) await f.delete(); } catch (_) {} try { await _m.invokeMethod('cleanUpdates'); } catch (_) {} }

  /// Descarga siguiendo redirecciones a mano: cada salto debe ser https y de un host permitido. Verifica tamaño y firma ZIP ("PK").
  @visibleForTesting
  static Future<void> download(Uri url, File out, int expected, void Function(double) onProgress, bool Function() cancelled, {HttpClient? client, bool Function(Uri)? allow}) async {
    final ok = allow ?? allowedUri;
    final c = client ?? HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      var u = url;
      for (var hop = 0; hop < 6; hop++) {
        if (!ok(u)) throw const FormatException('Origen de descarga no permitido.');
        final req = await c.getUrl(u); req.followRedirects = false; req.headers.set('Accept', 'application/octet-stream');
        final rs = await req.close().timeout(const Duration(seconds: 20));
        if (rs.isRedirect) {
          final loc = rs.headers.value('location'); await rs.drain<void>();
          if (loc == null) throw const FormatException('Redirección sin destino.');
          u = u.resolve(loc); continue;
        }
        if (rs.statusCode != 200) { await rs.drain<void>(); throw HttpException('HTTP ${rs.statusCode}'); }
        if (rs.contentLength > 0 && rs.contentLength != expected) throw const FormatException('El tamaño anunciado no coincide.');
        final sink = out.openWrite(); var got = 0; List<int>? head;
        try {
          await for (final ch in rs.timeout(const Duration(seconds: 30))) {
            if (cancelled()) throw _Cancelled();
            got += ch.length; if (got > expected) throw const FormatException('La descarga es mayor de lo anunciado.');
            head ??= ch.take(2).toList(); sink.add(ch); onProgress(got / expected);
          }
        } finally { await sink.close(); }
        if (got != expected) throw const FormatException('Descarga incompleta (tamaño distinto del anunciado).');
        if (head == null || head.length < 2 || head[0] != 0x50 || head[1] != 0x4b) throw const FormatException('El archivo no es un APK.');
        return;
      }
      throw const FormatException('Demasiadas redirecciones.');
    } finally { if (client == null) c.close(force: true); }
  }

  static Future<dynamic> _httpJson(Uri u) async {
    if (!allowedUri(u)) throw const FormatException('URL no permitida');
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await c.getUrl(u); req.headers.set('Accept', 'application/vnd.github+json'); req.headers.set('User-Agent', 'vigor-app');
      final rs = await req.close();
      if (rs.statusCode != 200) { await rs.drain<void>(); throw HttpException('HTTP ${rs.statusCode}'); }
      final b = await rs.transform(utf8.decoder).join();
      return jsonDecode(b);
    } finally { c.close(force: true); }
  }
}

class _Cancelled implements Exception {}
