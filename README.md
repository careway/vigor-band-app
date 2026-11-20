# Vigor

App Android (Flutter + puente Kotlin al SDK de Veepoo) para la pulsera **Valdus VIGOR**. Lee los datos que la pulsera guarda (pulso, pasos, SpO₂, variabilidad, temperatura, estrés, MET, sueño, deportes con ruta GPS), los guarda **solo en el móvil** y los muestra con sus límites explicados. No hace diagnóstico ni emite alertas clínicas.

> **Aviso:** Vigor no es un dispositivo médico. Varias métricas son **experimentales o aproximadas** (rotuladas "aprox."): variabilidad por luz en la muñeca (PPG), pulso en reposo, minutos de actividad, estrés, temperatura, y glucosa y componentes sanguíneos (estos últimos, ocultos de serie; la FDA no autoriza ningún reloj para medir glucosa sin pinchar). No tomes decisiones de salud ni de medicación con ellas. Fuentes y límites: [`docs/ANALISIS.md`](docs/ANALISIS.md).

## Estado actual
Versión 1.0 (candidata), probada con una pulsera real en un Xiaomi Mi 9. Solo Android; iOS no está implementado. Tras la ronda 5 (informe `DEV_004`): `flutter analyze` sin avisos, **183 pruebas de Flutter** y **27 pruebas JVM de Kotlin** (`JsonStoreTest` 14, `PureTest` 13) en verde; APK de depuración compilado e instalado con `adb install -r`. El APK de release **no** se regeneró en esta ronda.

**Importante:** en las rondas 2 a 5 el móvil estaba bloqueado, así que las pantallas nuevas (incluida "Privacidad y datos") y exportar/borrar (incluido el selector de compartir de Android) **no se han visto ni probado en el móvil**; tampoco TalkBack, escala de texto real, ni los permisos con diálogo real ni el límite de 60 s de la cola de permisos (solo probado en JVM); en la ronda 5 el móvil estaba bloqueado (pantalla apagada con reloj) y no se desbloqueó ni se tocó. Los supuestos sobre los datos reales (p. ej. el formato de la variabilidad) se comprobaron leyendo los ficheros de un solo móvil y ~2 días de datos: no se generalizan. Lo verificado y lo pendiente está en [`docs/ESTADO.md`](docs/ESTADO.md) y en los informes de `docs/equipo/informes/`.

## Funciones (verificadas en el código)
- **Hoy:** "Reloj del día" de 24 h (se explora arrastrando; es un control ajustable por franjas de 30 min) y botón "Ver datos del día por franjas"; cinta de 7 días; teselas de pulso, SpO₂, estrés, MET, variabilidad, temperatura y movimiento con detalle de 24 h; cobertura de datos bajo cada gráfico y punto de aviso "Pocos datos hoy"; sección plegada "Experimental · no fiable" (solo si se activa el interruptor).
- **Detalle de Pulso:** pulso en reposo nocturno (aprox.) con tendencia frente a tu mediana. **Detalle de Variabilidad:** variabilidad nocturna (PPG, aprox.) con línea base propia, aviso "Calidad baja" y una nota de que cada medición es de ≈ 10 latidos (ventana ultracorta). La noche de hoy antes de las 06:00 se marca "Noche en curso" y no entra en la línea base. La línea base usa hasta 14 noches válidas de los últimos 30 días (mínimo 7).
- **Actividad:** minutos de actividad semanales frente a la guía de la OMS 2020 (dos estimaciones separadas, "aprox."); actividades guardadas con zonas de pulso, TRIMP, ruta GPS y velocidad calculada; iniciar actividad desde el móvil. Las calorías de una actividad salen "—" cuando la pulsera trae 0.
- **Sueño:** noches registradas (duración, despertares, fases aproximadas). Sin comprobar con una noche real.
- **Dispositivo:** conexión, batería, sincronizar, hacer vibrar, perfil (edad, meta de pasos), interruptor "Mostrar métricas experimentales", efemérides GPS, registro técnico y, **solo en compilaciones de depuración**, "Avanzado (depuración)" (volcado de sueño y sondeos de medición rápida; no probados con la pulsera).
- **Dispositivo → Privacidad y datos:** **Exportar mis datos**: Vigor prepara una copia temporal **privada** de los `*.json` (en `files/export`, dentro de la app) y abre el **selector de compartir de Android** para que tú elijas dónde guardarla o a qué app enviarla. **Ya no hay carpeta accesible por USB.** Lo que elijas en el selector queda **fuera del control de Vigor**: otra app o carpeta puede conservarlo o leerlo. La copia temporal se borra al volver a abrir la pantalla Privacidad, al arrancar la app, al exportar de nuevo y con **Borrar todos mis datos** (con confirmación; se desactiva durante una sincronización). Borrar **no** quita el emparejamiento, la edad ni la meta de pasos, ni las copias que ya hayas guardado o enviado fuera de Vigor. Vigor no envía nada a internet por su cuenta. **No verificado en el móvil** (selector real, lectura por la app destino, borrado al reabrir).
- **Privacidad:** copia de seguridad de Android desactivada, MAC enmascarada, registro del sistema solo en depuración.

## Requisitos
- Windows con Flutter (en este proyecto: `D:\ProgramFiles\flutter`), Android SDK y `adb` (`D:\Carlos\Documents\platform-tools`).
- Móvil Android con Bluetooth LE. Solo una app a la vez puede usar la pulsera (cierra G Band, `com.vpgband.app`, antes de usar Vigor).
- El SDK de Veepoo (Apache-2.0) es un submódulo git en `android/third_party/Android_Ble_SDK`: clona con `git clone --recurse-submodules` o ejecuta `git submodule update --init --depth 1`.

## Compilar, probar e instalar
Desde WSL, usando el Flutter de Windows:
```
powershell.exe -NoProfile -Command "cd D:\band_app\vigor_app; D:\ProgramFiles\flutter\bin\flutter.bat analyze"
powershell.exe -NoProfile -Command "cd D:\band_app\vigor_app; D:\ProgramFiles\flutter\bin\flutter.bat test"
powershell.exe -NoProfile -Command "cd D:\band_app\vigor_app; D:\ProgramFiles\flutter\bin\flutter.bat build apk --debug"
```
Instalar (PowerShell, en la carpeta del proyecto):
```
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```
Pruebas de Kotlin (JVM, sin móvil; junit 4.13.2 y `org.json:json:20231013`), desde `android/`:
```
gradlew testDebugUnitTest
```
(En Windows: `gradlew.bat testDebugUnitTest`.) Son 27: `JsonStoreTest` 14 y `PureTest` 13. Cubren `JsonStore` (incluidos `tryWipe`, estado `wiping`, lista blanca de tipos y regenerado de la exportación) y la lógica pura de `Pure.kt` (incluido el tiempo máximo de `PermissionQueue`); **no** cubren `BandClient` (SDK), el Worker ni la conexión.

**Antes de distribuir (tareas del usuario):** `android/app/build.gradle.kts` conserva 2 `TODO` de la plantilla de Flutter: (1) el `applicationId` (hoy `com.careway.vigor_app`; confirma que es el definitivo, porque no se puede cambiar una vez publicada la app) y (2) la **firma de release**, que ahora usa las claves de depuración; hay que crear una firma propia. No se han tocado. Fuera de eso no quedan `TODO` ni código muerto en `lib/` ni en Kotlin.

Registro técnico del móvil (solo compilaciones de depuración): `adb logcat -s VIGORLOG`. Con el móvil bloqueado no se puede comprobar la interfaz: desbloquéalo antes de probar pantallas.

## Estructura
```
lib/main.dart             arranque, navegación de 4 pestañas (Hoy, Actividad, Sueño, Dispositivo)
lib/data/repo.dart        VigorRepo: canal con Kotlin, carga, parseo seguro y modelo de datos
lib/data/analysis.dart    cálculos puros (FCmáx, zonas, TRIMP, RMSSD, calidad de datos, reposo y HRV nocturnos, minutos de actividad, sesión derivada)
lib/theme/tokens.dart     colores y tipografía (ver GUIA_DE_ESTILOS)
lib/ui/                   pantallas y componentes (today, activity, sleep, device, night_cards, metrics, charts, fx, widgets)
android/app/src/main/kotlin/com/careway/vigor_app/
  MainActivity.kt         adaptador Flutter <-> BandClient
  BandClient.kt           único acceso al SDK de Veepoo
  JsonStore.kt            almacén JSON local (incluye exportar a carpeta privada, borrar y `tryWipe`)
  Pure.kt                 lógica pura sin Android, probada en JVM: Mac, AgpsRules, PermissionQueue
  Agps.kt                 efemérides GPS y trabajo periódico
  DebugTools.kt           herramientas solo de depuración (volcado de sueño, sondeos)
android/app/src/main/res/xml/   reglas de copia de seguridad y extracción
test/                     pruebas de Flutter (cálculos, parseo, accesibilidad, rondas 3 y 4)
android/app/src/test/kotlin/com/careway/vigor_app/   pruebas JVM de Kotlin (JsonStoreTest, PureTest)
docs/                     documentación; docs/equipo/ (equipo, backlog, informes); docs/investigacion/
```

## Documentación
- [Arquitectura](docs/ARQUITECTURA.md) · [Manual de usuario](docs/MANUAL_USUARIO.md) · [Glosario](docs/GLOSARIO.md) · [Bases científicas](docs/BASES_CIENTIFICAS.md)
- [Análisis y fuentes](docs/ANALISIS.md) · [Guía de estilos](docs/GUIA_DE_ESTILOS.md) · [Estado](docs/ESTADO.md) · [Equipo](docs/equipo/EQUIPO.md)
- Investigación: [Cardio](docs/investigacion/CARDIO.md) · [Movimiento, sueño y GPS](docs/investigacion/MOVIMIENTO_SUENO_GPS.md)
