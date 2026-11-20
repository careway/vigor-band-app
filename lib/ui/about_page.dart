import 'package:flutter/material.dart';
import '../data/repo.dart';
import '../data/updater.dart';
import '../theme/tokens.dart';
import 'device_page.dart';
import 'widgets.dart';

String _when(DateTime? t) => t == null ? 'nunca' : '${t.day}/${t.month}/${t.year} ${hm(t)}';

/// Tarjeta discreta "Hay una versión nueva" (se oculta si no hay ninguna, si se descarta o si no se pudo comprobar).
class UpdateBanner extends StatelessWidget {
  final VigorRepo repo; const UpdateBanner(this.repo, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo.updater, builder: (context, _) {
        final u = repo.updater; final c = VC.of(context);
        if (!u.available || u.dismissed) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x2), child: Panel(padding: const EdgeInsets.all(Sp.x3), child: Row(children: [
          Icon(Icons.system_update_outlined, color: c.accent), const SizedBox(width: Sp.x3),
          Expanded(child: Semantics(liveRegion: true, child: Text('Hay una versión nueva (compilación ${u.info!.build})', style: VT.body(c)))),
          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutPage(repo))), child: const Text('Actualizar')),
          IconButton(tooltip: 'Ocultar aviso', onPressed: u.dismiss, icon: const Icon(Icons.close, size: 20)),
        ])));
      });
}

/// Versión instalada, última comprobación y actualización manual.
class AboutPage extends StatelessWidget {
  final VigorRepo repo; const AboutPage(this.repo, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: repo.updater, builder: (context, _) {
        final u = repo.updater; final c = VC.of(context);
        final busy = u.state == UpdateState.checking || u.state == UpdateState.downloading;
        final status = switch (u.state) {
          UpdateState.checking => 'Comprobando…',
          UpdateState.upToDate => 'Tienes la última versión.',
          UpdateState.available => 'Hay una versión nueva: compilación ${u.info?.build}.',
          UpdateState.unavailable => u.message ?? 'No se puede comprobar ahora.',
          UpdateState.error => u.message ?? 'Error al comprobar.',
          UpdateState.downloading => 'Descargando ${(u.progress * 100).round()} %…',
          UpdateState.ready || UpdateState.needsPermission => u.message ?? '',
          UpdateState.unknown => 'Aún no se ha comprobado en esta sesión.',
        };
        return SettingsScaffold('Acerca de y actualizaciones', [
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vigor ${u.versionName ?? ''}', style: VT.heading(c)),
            Text('Compilación instalada: ${u.installed ?? 'desconocida'}', style: VT.body(c)),
            Text('Última comprobación: ${_when(u.lastCheck)}', style: VT.body(c)),
            const SizedBox(height: Sp.x2),
            Semantics(liveRegion: true, child: Text(status, style: VT.body(c))),
            if (u.state == UpdateState.downloading) ...[const SizedBox(height: Sp.x2), LinearProgressIndicator(value: u.progress, minHeight: 8)],
            const SizedBox(height: Sp.x3),
            Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
              SizedBox(height: 48, child: OutlinedButton(onPressed: busy ? null : () => u.check(), child: const Text('Buscar actualizaciones'))),
              if (u.available && u.state != UpdateState.downloading) SizedBox(height: 48, child: FilledButton(onPressed: u.install, child: const Text('Actualizar'))),
              if (u.state == UpdateState.downloading) SizedBox(height: 48, child: OutlinedButton(onPressed: u.cancelDownload, child: const Text('Cancelar'))),
            ]),
          ])),
          const Note('La descarga solo se acepta por https desde github.com. La instalación siempre la confirma el instalador de Android; Vigor no instala nada por su cuenta y borra el archivo descargado después.'),
          const Note('Las versiones de prueba van firmadas con la clave de depuración: solo se pueden instalar encima de una instalación firmada con la misma clave; si no, Android la rechaza y habría que desinstalar antes (se pierden los datos locales; exporta antes en Privacidad y datos).'),
          const Note('Mientras el repositorio sea privado la comprobación no puede funcionar y no se muestra ningún error.'),
        ]);
      });
}
