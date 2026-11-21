# Estado del proyecto (actualizado 2026-11-20, ronda 2 del Supervisor; las secciones anteriores son de la sesión inicial)

## Cómo compilar e instalar
- Proyecto: `D:\band_app\vigor_app` (desde WSL: `/mnt/d/band_app/vigor_app`).
- Compilar: `D:\ProgramFiles\flutter\bin\flutter.bat build apk --debug` (desde PowerShell). Tests: `flutter test`.
- Instalar: `adb install -r build\app\outputs\flutter-apk\app-debug.apk` (adb en `D:\Carlos\Documents\platform-tools`).
- SDK de Veepoo: `.aar` en `android/app/libs/`; documentación en `D:\band_app\sdk_ref\`.

## Verificado con la pulsera real
| Qué | Resultado |
|---|---|
| Conexión por MAC guardada, sin escanear | OK (reconecta sola al abrir) |
| Sincronización: pulso/pasos/calorías (5 min), HRV, SpO₂, medias de 30 min | OK (≈ 7 h de histórico en la pulsera) |
| Deportes guardados con ruta GPS | OK (3 sesiones; coordenadas en grados decimales; 12 puntos/min) |
| Descarga de efemérides (≈ 161 KB) | OK |
| Transferencia de efemérides a la pulsera | OK: la validez en G Band pasó de 6 d 12 h a 6 d 20 h |
| Trabajo periódico de efemérides programado (WorkManager, cada 6 h, con red) | Programado y visible en `jobscheduler` |
| Tests de cálculos (Tanaka, zonas, TRIMP, RMSSD, mediana, Haversine) | 7/7 |

## NO verificado (hacer mañana)
1. **Sueño:** la pulsera no devolvió ninguna noche (`sleep.json` vacío). Puede ser que no se la pusieras al dormir; la pantalla Sueño ya está lista pero sus campos (`allSleepTime`, `deepSleepTime`…) vienen de la documentación, no de datos reales.
2. **Efemérides sin la app abierta:** el trabajo de fondo (con la app cerrada) no se ha visto ejecutarse solo. La vía "app abierta → transferir si hay pendiente" sí funciona. Prueba: cierra la app, espera a mañana y mira *Dispositivo → Efemérides GPS* ("Último envío").
3. **Iniciar actividad desde el móvil y que siga grabando sin conexión** (la prueba de los 15 minutos): sin hacer.
4. **Calorías de 5 min** (`calValue`): se asume kcal; no verificado.

## Decisiones tomadas por mi cuenta (revisa si no te cuadran)
- Efemérides: "cuando el GPS esté disponible" lo interpreté como **cuando hay red para descargar el fichero** y **cuando la pulsera está a mano** para enviarlo. Se descarga como máximo cada 20 h y se envía solo si la batería de la pulsera ≥ 30 %.
- HRV: se calcula **RMSSD propio** desde los intervalos RR, porque el `hrvValue` del fabricante no coincide con RMSSD ni con SDNN.
- Sin puntuación de sueño ni alertas clínicas (ver `ANALISIS.md`).
- Ruta GPS: sin suavizado; se corta en los tramos sin señal.
- Edad por defecto 35 años (para FCmáx); cámbiala en *Dispositivo → Perfil*.

## No implementado todavía
Alarmas, notificaciones del móvil a la pulsera, cámara remota, calibraciones (presión, glucosa), recordatorios de salud, medición manual de pulso/SpO₂, iOS, firmware.

## Cosas del móvil que cambié (puedes revertirlas)
- Activé en el Mi 9 **"Depuración USB (ajustes de seguridad)"** (tú) para poder simular toques. **Desactívala** si ya no la necesitas.
- Concedí ubicación "solo en uso" a **G Band** (app oficial instalada desde el `.xapk`).


---
## Actualización: nuevas métricas e interfaz "Aurora" (01:15)

### Qué se añadió
- **Métricas nuevas** (todas salen de los datos de 5 min que ya se sincronizaban; el protocolo 5 de la VIGOR las incluye): estrés (`pressure`, 0–100), MET (`met`), temperatura corporal (`temperature`) y de la piel (`baseTemperature`), glucosa (`bloodGlucose`, mmol/L) y componentes sanguíneos (`bloodComponent`: ácido úrico, colesterol total, triglicéridos, HDL, LDL).
- **Interfaz nueva** (`docs/GUIA_DE_ESTILOS.md` v2): tema oscuro con resplandor Aurora que toma el color de la zona de pulso; **Reloj del día** (24 h) con cursor táctil que muestra todas las métricas de cada hora; cinta de días; teselas "bento" con transición Hero a páginas de detalle con gráfico de 24 h táctil; corazón que late al ritmo del último pulso; navegación flotante.
- Todo respeta "reducir animaciones" del sistema.

### Decisiones de honestidad (basadas en la investigación, ver `ANALISIS.md` §9–12)
- **Glucosa y componentes sanguíneos:** FDA (21‑02‑2024): ningún reloj/anillo está autorizado para medir glucosa sin pinchar. Van en una sección plegada "Experimental · no fiable", en gris, con aviso fijo y **sin rangos, colores de riesgo ni alertas**. La pulsera envía un campo de riesgo (`bloodGlucoseRiskLevel`) y la app lo ignora a propósito.
- **Estrés:** índice relativo del fabricante, sin categorías (los algoritmos de estrés por HRV en relojes de consumo tienen precisión pobre).
- **Temperatura:** se muestra con su limitación (sesgo absoluto ≈ 1,5 °C en un dispositivo validado) y se compara con tu propia media cuando hay ≥ 3 días.
- **MET:** se muestra tal cual; no se clasifica por intensidad (los cortes habituales no se pudieron verificar).

### Comprobado en el móvil
Arrastrar el reloj del día (18:02 y 20:16 dan lecturas distintas y coherentes), scroll sin bloqueo tras soltar, páginas de detalle (temperatura con piel), sección experimental, tema oscuro, 7/7 tests.

### Sin verificar / pendiente
1. **Tema claro:** existe pero el móvil lo forzó a oscuro por defecto; el claro apenas se ha revisado.
2. **Valores de glucosa/estrés/temperatura en reposo:** la app oficial mostraba 36,0 °C y glucosa 4,31 a las 00:40; las mías provienen del mismo campo pero no se comparó hora a hora.
3. **Medición manual** (estrés, MET, glucosa, temperatura "Medición rápida" de la app oficial): no implementada (el SDK tiene `startDetectPressure`, `startDetectMet`, etc.).
4. **Sueño, efemérides con la app cerrada, prueba de grabar actividad sin móvil:** siguen pendientes (ver arriba).
5. Hay **un aviso de análisis** menor (`charts.dart:94`, `!` innecesario) sin efecto.


---
## Actualización ronda 2 (tras DEV_001; Supervisor)

### Implementado por DEV_001 (según su informe)
- **Privacidad:** copia de seguridad de Android desactivada y excluida; log técnico solo en compilaciones de depuración y sin volcar objetos del SDK; MAC enmascarada (solo 2 últimos bytes) en pantalla y logs.
- **Almacén:** escritura atómica; un JSON corrupto se renombra y no se pierde; retención de 60 días (origin5/hrv/spo2/half/live) y topes de entradas.
- **Conexión/efemérides:** control de permiso BLUETOOTH_CONNECT, listener de desconexión que aborta la sincronización, temporizadores cancelables, trabajo de efemérides con éxito/reintento/fallo, descarga con integridad mínima (≥ 1 000 bytes, no HTML/JSON) y espera de 24 h si la pulsera no lo admite.
- **Parseo:** lectura segura de tipos, un registro malo no aborta, sesión sin hora descartada, día basura por `mTime` vacío descartado.
- **UI:** el reloj del día reconstruye solo lo necesario; accesibilidad mínima (ver `GUIA_DE_ESTILOS.md` §7, que dice también lo que NO se ha hecho).
- **Calidad:** `flutter analyze` sin avisos, 65 pruebas en verde (antes 7), APK de depuración compilado e instalado.

### Verificado en el móvil por DEV_001 (limitado)
La app arrancó, reconectó sola por la MAC guardada, recibió contraseña y funciones y sincronizó; los JSON se reescribieron sin ficheros temporales. Sin excepciones propias en logcat.

### NO verificado (DEV_001 lo dice expresamente o no consta)
- Pantallas Hoy/Actividad/Dispositivo (el móvil estaba bloqueado; sin capturas).
- Caída real de la conexión, trabajo de efemérides con la app cerrada, espera de 24 h, retención/corrupción en el dispositivo, TalkBack, escala de texto, contraste, tema claro.
- No hay pruebas Kotlin (el proyecto no tiene infraestructura JVM).
- Sueño real, prueba de grabar sin móvil, unidad de `calValue` de 5 min.

### Verificado contra la app oficial (dato del encargo del jefe de proyecto)
Distancia en metros, calorías de sesión (`calories` / 1000 = kcal) y ritmo en s/km. **No** verificados: velocidad (`avgSpeed`…), cadencia, pausas.

### Cambios en la documentación científica (ronda 2)
`ANALISIS.md` corregido: Chinoy (identificador PMC), sesgo de temperatura (reformulado), cadencia de Paluch (retirada), MET/OMS (cortes hallados a nivel de resumen), RMSSD con PPG, FDA (leída), filtros documentados (§14–16).

### Siguiente
Ronda 3: `docs/equipo/ESPECIFICACION_RONDA3.md` (E1–E5, herramienta de sueño E6, sondeo E7). Backlog actualizado en `docs/equipo/BACKLOG.md`. Para E6 hace falta que el usuario duerma dos noches con la pulsera.


---
## Actualización ronda 3 (tras DEV_002; Supervisor, 2026-11-20)
### Implementado en código (DEV_002)
`flutter analyze` sin avisos; 112/112 tests; APK de depuración compilado e instalado; la app arranca y completa el handshake con la pulsera sin `FATAL`. E1 calidad y cobertura, E2 pulso en reposo nocturno, E3 HRV nocturna robusta, E4 minutos de actividad semanales, E5 sesiones con ritmo/velocidad calculados; herramientas de depuración E6 (volcado de sueño) y E7 (sondeo de mediciones rápidas); glucosa y componentes ocultos por defecto; correcciones de QA_002 (M2, M5, M6, M7, M10, N1–N4, N6–N8). Detalle: `ANALISIS.md` §17.
### NO verificado
Nada se vio en pantalla (móvil bloqueado); ni sincronización completa con los cambios, ni `.tmp`/`.corrupt-*` en el móvil, ni E6/E7 con la pulsera. Los cambios de Kotlin (M2, N1–N4, N6–N8, M5, M7) no tienen test automático. Siguen sin verificar: sueño real, efemérides con la app cerrada, grabar sin móvil, TalkBack, texto 200 %, contraste, tema claro.
### Dónde queda el volcado de sueño (solo build de depuración)
`files/debug/sleep_dump_<ms>.json` en el directorio privado de la app; se borra con «Borrar volcados».
### Siguiente
Ronda 4 y definición de «terminada» v1.0: `docs/equipo/informes/REVISION_003.md`.


---
## Actualización ronda 4 (tras DEV_003; Supervisor, 2026-11-20)
### Hecho (código y tests)
`flutter analyze` limpio; **183/183** tests Flutter; **27/27** tests JVM de Kotlin (`JsonStore`, `Pure.kt`: máscara MAC, `Agps.looksValid`/reintentos, cola de permisos); APK de depuración instalado, datos del móvil intactos. Hallazgos de QA_003 N1–N7 y K3 cerrados en código (centinela 2550 = sin dato, línea base de 30 días, noche en curso, calorías 0 = «—», tres estados sin datos). Nueva sección Dispositivo → «Privacidad y datos» (exportar y borrar). `maxSdkVersion=30` en ubicación. `lastError` de efemérides siempre visible y limpiado. Contraste medido por cálculo; tests de texto ×2.
### Verificado con datos reales (agregados, 1 móvil, ~2 días)
`sportTime` en segundos (contra cabecera); `hrv` = 1 registro/min de ~10 RR (≈ 9 s, ultracorto); `rate` = RR/10; 26,7 % de RR = 2550; `ppgs` 5 valores por registro de 5 min (consistente con 1/min, **no probado**).
### NO verificado (la pantalla estuvo bloqueada desde la ronda 2)
Nada se ha visto en pantalla tras la ronda 1: ni Hoy/Actividad/Sueño/Dispositivo, ni exportar/borrar reales, ni TalkBack, texto 200 %, tema claro, permisos con diálogo, caída de conexión, Worker de efemérides con la app cerrada, grabar sin móvil, sueño real (2 noches), volcado de sueño E6 y sondeo E7. `BandClient`, `Worker` y conexión sin test JVM. Ruta de exportación quizá no visible por USB en Android 11+.
### Siguiente
`docs/equipo/informes/REVISION_004.md` (criterios de v1.0, guía de pruebas del usuario, v1.1+). Documentación de usuario (README/ARQUITECTURA/MANUAL/GLOSARIO/BASES_CIENTIFICAS) sigue sin existir.


---
## Actualización final v1.0 candidata (tras DEV_004; Supervisor, 2026-11-20)
### Hecho (código y tests)
`flutter analyze` limpio; **183/183** tests Flutter; **27/27** tests JVM (`JsonStoreTest` 14 + `PureTest` 13). El build release compila (comprobado en QA_004, antes de DEV_004), **firmado con la clave de depuración**: sirve para probar, no para distribuir. DEV_004 cerró H1 (carrera borrado/escritura), H2 (exportación privada + selector de compartir), H3 (tiempo máximo de la cola de permisos), H4, H6 (Estrés rotulado «índice del fabricante · aprox.»), H7 y H8 (receptor de Nordic no exportado). El registro técnico se ve también en release con MAC enmascaradas; logcat solo en depuración. El APK de depuración está instalado (la autoridad del FileProvider está registrada).
### NO verificado
Nada se ha visto en pantalla desde la ronda 1 (el móvil estuvo bloqueado): ni el selector de compartir, ni el borrado real de la copia, ni los permisos con diálogo, ni TalkBack, texto 200 %, tema claro, caída de conexión, Worker con la app cerrada, grabar sin móvil, sueño real. Release no regenerado tras DEV_004.
### Antes de distribuir (tareas del usuario)
Firma de release propia y `applicationId` definitivo (los dos TODO de `build.gradle.kts`).
### Siguiente
Guía de pruebas: `docs/equipo/informes/REVISION_004.md` §b y «Estado final v1.0 (candidata)».


## Ronda DEV_005 (modos deportivos, rediseño de Actividad, cadencia y submenús de Ajustes)
- Hecho en código (ver `equipo/informes/DEV_005.md`): tabla de ~187 modos (`lib/data/sports.dart`, nombres leídos de la enum del AAR), selector en rejilla con buscador y filtro recorrido/interior, tarjetas y detalle por tipo, lectura/escritura de la medición automática (`readAutoMeasureSettingData`/`setAutoMeasureSettingData`), Ajustes en 8 submenús (pestaña «Dispositivo» renombrada «Ajustes»), tema oscuro/claro/sistema.
- NO verificado: iniciar un modo concreto en la pulsera, qué modos admite la VIGOR, cambio real de cadencia en la pulsera, 15 ids de modo deducidos (no están en la documentación), tema claro, TalkBack, instalación en el móvil (no se instaló).


## DEV_006 (2026-11-20): actualizaciones y pulso en vivo
- **Actualizaciones automáticas:** implementadas y con tests (Dart y JVM). No verificadas de extremo a extremo: el repositorio es privado, así que la comprobación da 404 y la app lo trata en silencio como "no se puede comprobar". No se ha probado la instalación real en el móvil.
- **Pulso en el círculo de Hoy:** implementado, **no probado en hardware** (la pulsera no está disponible). Solo hay tests con fakes. La SDK solo ofrece medición manual (`startDetectHeart`); no hay pulso continuo, así que el valor "en vivo" existe solo mientras dura la medición que pide el usuario. Nombres de la SDK comprobados en el AAR (`IHeartDataListener.onDataChange(HeartData)`, `EHeartStatus`, `startDetectHeart`, `stopDetectHeart`).
- Detalle: `docs/equipo/informes/DEV_006.md`.
- **Pulso en vivo automático (cada 10 s por defecto, con la app abierta en Hoy):** implementado, **no probado en hardware**; cubierto con fakes y reloj simulado. Consumo de batería de la pulsera sin medir. Criterio de estabilidad propio (2 lecturas con diferencia <= 8 lpm o mediana de 3), no validado.

## DEV_007 (2026-11-20): Salud y compartir (Health Connect / Apple Salud)
- **Implementado:** Ajustes > «Salud y compartir» (maestro apagado de serie, 7 categorías, estado, último envío, abrir ajustes de Health Connect, dejar de compartir, borrar lo enviado). Solo escribe; nunca lee. No exporta glucosa, componentes sanguíneos, estrés, MET ni temperatura de piel. minSdk sube de 23 a 26.
- **Verificado:** compila (`flutter build apk --debug`), `flutter analyze` limpio, tests Dart (fake) y JVM en verde.
- **NO probado:** nada de esto se ha visto en un móvil con Health Connect; el lado iPhone (HealthKit) está escrito pero no compilado ni probado (no hay Mac; no existe la carpeta `ios/`). Detalle y tabla de mapeo: `docs/equipo/informes/DEV_007.md`.
- **Sueño y Health Connect (informe del usuario):** no se ha podido determinar la causa sin el móvil; con la muestra real el código envía bien. Se añadió diagnóstico por categoría y «Reintentar sueño». Ver adenda de `DEV_007.md`.

- **DEV_008:** se pueden borrar noches, sesiones (una o varias) y los datos de un día, con tumbas para que la pulsera no los resucite y borrado opcional en Health Connect. Implementado con tests; no probado en el móvil. Ver `informes/DEV_008.md`.

**Actualización 2026-11-21 (DEV_009):** ya hay noches reales guardadas en el móvil de pruebas y la pestaña Sueño muestra el hipnograma por minuto, tendencia 7/14/30 noches y métricas derivadas (ver informes/DEV_009.md). Lo anterior sobre «sleep.json vacío» queda superado; sigue sin probarse una noche nueva entregada por la pulsera.
