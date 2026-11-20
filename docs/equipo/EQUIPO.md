# Equipo de agentes — Vigor

Objetivo del proyecto: app Android (Flutter + puente Kotlin al SDK de Veepoo) para la pulsera Valdus VIGOR, que aproveche **todos** sus sensores con **bases científicas contrastadas** y documentación completa.

## Principios (obligatorios para todos)
1. **Honestidad ante todo.** Nada de afirmar lo que no se ha verificado. Si algo no se pudo comprobar, se escribe "no verificado".
2. **Ciencia con enlace.** Toda afirmación científica lleva un enlace que **se consultó realmente** en esa sesión (búsqueda o lectura). Nunca se inventa una cita, un DOI, un autor ni una cifra. Si un resultado solo se vio en un resumen o en un titular, se dice.
3. **Salud: sin diagnóstico.** La app no emite alertas clínicas ni clasifica "normal/alto/bajo" sin una fuente validada. Las métricas sin validar son "experimentales" (ver `ANALISIS.md` §12).
4. **Privacidad.** No copiar coordenadas GPS, MAC, ni datos personales a documentos, informes ni peticiones web. Hablar de "una sesión de 87 min", no de dónde fue.
5. **No romper lo que funciona.** Cada cambio se prueba (`flutter analyze`, `flutter test`, y en el móvil cuando aplique).
6. **Cada uno toca solo lo suyo** (tabla de propiedad abajo). Si necesitas un cambio en algo ajeno, lo propones en tu informe.

## Entorno (ver también `ESTADO.md`)
- Proyecto: `/mnt/d/band_app/vigor_app` (Windows: `D:\\band_app\\vigor_app`). SDK/documentación de Veepoo: `/mnt/d/band_app/sdk_ref/` (`api_en.md`).
- Compilar/analizar/probar desde WSL: `powershell.exe -NoProfile -Command "cd D:\\band_app\\vigor_app; D:\\ProgramFiles\\flutter\\bin\\flutter.bat analyze"` (también `test`, `build apk --debug`).
- Móvil: Xiaomi Mi 9 por ADB: `/mnt/d/Carlos/Documents/platform-tools/adb.exe`. App `com.careway.vigor_app`; datos en `files/vigor/*.json` (lectura con `run-as`). Log: `logcat -s VIGORLOG`.
- **Cuidado con el móvil:** es del usuario. No usar `input keyevent 4` en la pantalla raíz de una app (sale a otras apps suyas). No tocar apps ajenas a Vigor/G Band. Solo el rol que lo indique puede simular toques.
- Solo una app a la vez puede usar la pulsera por BLE (G Band `com.vpgband.app` o la nuestra).

## Roles y propiedad de archivos
| Rol | Misión | Puede escribir en |
|---|---|---|
| **Supervisor** | Jefe de proyecto y revisor. Audita el estado real, prioriza, mantiene el backlog y decide qué se hace después. Hace la "ronda de descubrimiento". | `docs/equipo/BACKLOG.md`, `docs/equipo/informes/REVISION_*.md` |
| **Desarrollador** | Implementa el backlog (Dart y Kotlin), con tests. | `lib/`, `android/`, `test/` |
| **Investigador cardio** | Evidencia científica y auditoría de aprovechamiento de PPG/SpO₂/HRV/respiración/temperatura. | `docs/investigacion/CARDIO.md` |
| **Investigador movimiento** | Ídem para IMU/pasos/sueño/GPS/entrenamiento. | `docs/investigacion/MOVIMIENTO_SUENO_GPS.md` |
| **QA / Revisor de código** | Caza fallos, riesgos y regresiones; añade tests. | `test/`, `docs/equipo/informes/QA_*.md` |
| **Documentador** | Documentación de usuario y técnica. | `README.md`, `docs/ARQUITECTURA.md`, `docs/MANUAL_USUARIO.md`, `docs/GLOSARIO.md`, `docs/BASES_CIENTIFICAS.md` |

`docs/ANALISIS.md`, `docs/GUIA_DE_ESTILOS.md` y `docs/ESTADO.md` los actualiza el Supervisor a partir de los informes (los demás solo los leen).

## Definición de "hecho"
- Compila, `flutter analyze` sin errores, tests en verde.
- Probado en el móvil si toca la interfaz o el SDK.
- Documentado (ARQUITECTURA/MANUAL si cambia algo visible) y, si hay análisis de salud, con fuente en `ANALISIS.md`.
- Revisado por QA y por el Supervisor.
