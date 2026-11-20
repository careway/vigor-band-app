# REVISION_001 — Revisión del Supervisor (ronda 1)

Fecha: 2026-11-20. Alcance: lectura de `docs/equipo/*`, `ESTADO.md`, `ANALISIS.md`, `GUIA_DE_ESTILOS.md`, todo `lib/`, los 4 ficheros Kotlin, `AndroidManifest.xml`, `test/analysis_test.dart` y contraste con `sdk_ref/api_en.md`. No se ejecutó la app, ni ADB, ni `flutter analyze/test` (todo lo que dependa de ello figura como "no verificado" salvo que sea lectura de código). No se incluyen coordenadas, MAC ni datos personales.

## 1. Resumen ejecutivo
- La base es sólida y mayormente honesta: glucosa/componentes sanguíneos tratados como experimentales, sin umbrales clínicos, sin alertas, HRV contra línea base propia. Las afirmaciones de ESTADO.md sobre lo implementado concuerdan con el código.
- Mayores riesgos: (a) **privacidad**: datos de salud y rutas GPS en `files/vigor/*.json` sin cifrar y sin `allowBackup="false"` declarado (por defecto es `true`, entra en copias de seguridad); log técnico con volcados de objetos del SDK; (b) **fiabilidad técnica**: lectura de sueño sin validar y probablemente incompleta; sesiones sin GPS probablemente muestran 0 kcal; fallos de ciclo de vida/hilos en el trabajo de fondo; (c) **honestidad en la UI**: varias afirmaciones de la Guía de estilos (Semantics en cada cifra, 200 % de escala de texto, contraste verificado) no tienen respaldo en el código/pruebas.
- Hay **mucho dato del SDK recibido y descartado** (respiración, estados de sueño de 5 min, SpO₂ y apnea de 5 min, carga cardiaca, indicador de uso de la pulsera, curva de sueño) y bastantes funciones de G Band sin cubrir (medición manual, alarmas, notificaciones, ECG...).
- Los análisis de la UI cuya fuente no está o es parcial en ANALISIS.md se listan en H-07.

## 2. Hallazgos (severidad: Crítica / Alta / Media / Baja)

### Privacidad y seguridad
- **H-01 (Alta) Copia de seguridad y datos sin cifrar.** `AndroidManifest.xml` no declara `android:allowBackup` (por defecto true) ni reglas de exclusión. `JsonStore` escribe en `filesDir/vigor/` pulso, SpO₂, temperatura, sueño y las rutas GPS completas de cada sesión en JSON plano. Riesgo: copia en la nube/`adb backup` y lectura con `run-as` en builds debug. Además las efemérides y SharedPreferences (`mac`, edad) van en claro. Estado real de las copias en el móvil: no verificado.
- **H-02 (Media) Log con datos de la pulsera.** `BandClient.log` envía a logcat (`VIGORLOG`) y a la UI (hasta 200 líneas, "Registro técnico") volcados completos de `PwdData`, `FunctionDeviceSupportData`, paquetes 1-5 y `UIDataAGPS`. Pueden incluir identificadores del dispositivo; contenido exacto no verificado. Recomendado: log solo en debug y sin `toString()` de objetos.
- **H-03 (Media) La MAC se muestra en pantalla** (`device_page.dart`: `Note(r.savedMac!)`) y la lista de escaneo; si el usuario hace capturas de pantalla para informes se filtra. Mostrarla enmascarada.
- **H-04 (Media) Contraseña de la pulsera fija "0000"** en `MainActivity`/`BandClient`/`Repo` (valor por defecto del SDK). Cualquier móvil cercano que conozca la MAC podría conectar si la pulsera lo acepta. Impacto real: no verificado; propuesta: investigar si el SDK permite cambiarla.
- **H-05 (Media) Descarga de efemérides por una vía opaca.** `UiServerHttpUtil.downLoadAGpsFile` descarga de un servidor del fabricante; el host y si es HTTPS no están verificados. El fichero solo se comprueba por tamaño (> 1000 bytes), sin integridad. No hay `networkSecurityConfig` visible. Está declarado `INTERNET`; es el único uso verificado.
- **H-06 (Baja) Permisos de ubicación declarados** (`ACCESS_FINE/COARSE_LOCATION`, sin `maxSdkVersion`) aunque en Android 12+ se usa `BLUETOOTH_SCAN` con `neverForLocation`. La ubicación solo hace falta ≤ 11; añadir `maxSdkVersion="30"` reduce lo que ve el usuario en tienda/ajustes. No se pide permiso de notificaciones (no hay notificaciones: correcto).

### Honestidad / análisis sin fuente
- **H-07 (Alta) Cálculos de la app sin fuente o con fuente parcial en ANALISIS.md:**
  1. `baselineOf` (mediana de ≤ 14 días de medias diarias, ≥ 3 días) se aplica a **todas** las métricas (pulso, SpO₂, estrés, MET, temperatura...), pero ANALISIS.md solo la justifica para HRV (§3) y temperatura (§9). La diferencia "hoy ±x" se presenta sin intervalo ni nota de variabilidad.
  2. Filtros de plausibilidad (pulso 30-220, SpO₂ 70-100, temperatura 30-43 / piel 15-43, estrés 1-100, glucosa > 0) son decisiones propias no documentadas; sirven para descartar ceros del SDK pero no se explican.
  3. RMSSD: descarta RR ≥ 2500 ms o ≤ 0 pero no filtra latidos ectópicos/artefactos y acepta solo 5 intervalos; la ventana del SDK no se documenta (ya rotulado "aprox." en §3, pero el mínimo de 5 es arbitrario y está sin fuente).
  4. Pulso en reposo "media del 10 % más bajo" (§13 lo admite). Pero conviene verificar que la UI siempre lo rotula "aprox.": no verificado en todas las pantallas.
  5. "Resumen en una frase" (`today_page.dart:_summary`) se limita a pasos/pulso/SpO₂ (correcto, sin juicios).
  6. Distancia GPS vs pulsera (Haversine) y deriva en interior: documentado en §8.
  7. Zonas de pulso y TRIMP: documentados (§1-2), pero TRIMP se calcula con muestras `rate` por minuto del SDK sin comprobar que sean 1/min; el cálculo de minutos por zona asume lo mismo (no verificado).
- **H-08 (Alta) Unidad y escala de glucosa y de calorías sin verificar.** El SDK define `bloodGlucose` como Int; la app lo trata como mmol/L con 2 decimales (`kGlucose`). ESTADO.md solo dice que "proviene del mismo campo" que la app oficial. `calValue` ya figura sin verificar (#7). `disValue` en km (SDK dice km, ok).
- **H-09 (Media) Sesiones sin GPS: calorías probablemente 0.** `repo.dart` lee `o['calories']/1000` (campo de `SportModelGPSWatchOriginHeadData`, en cal); el encabezado no-GPS (`SportModelOriginHeadData`) usa `kcals` (kcal) y `peisu` para el ritmo. El código no lee `kcals`/`peisu`; solo `avgPace`, campo que **no figura** en las tablas del SDK (solo se vio en datos reales según ESTADO; no lo verifiqué). Verificar con una sesión no-GPS.
- **H-10 (Media) Verificación de "verificado con pulsera real".** Todo lo de la tabla de ESTADO.md depende de pruebas anteriores que no puedo repetir; los campos `latArray`, `lngArray`, `signalArray`, `avgPace` no aparecen en `api_en.md` (se leen por reflexión Gson). Coherente con el código, no verificado por mí contra datos reales.

### Salud
- **H-11 (Media) Texto que podría sonar a recomendación clínica.** En `metrics.dart` el banner experimental dice "No las uses para decidir medicación ni tratamientos" (correcto, prudente). Riesgo contrario: el valor de glucosa se muestra con 2 decimales y unidad clínica (cifra grande de 40 pt), lo que le da apariencia de medida. Ya está plegado y en gris; recomendado: ocultarlo por defecto y no mostrar el valor como `display`. No hay categorías de riesgo ni alertas: **sin hallazgos de diagnóstico explícito**.
- **H-12 (Baja) El campo de apnea/hipoxia del SDK** (`apneaResults`, `isHypoxias`, `hypoxiaTimes`) no se usa; correcto por ahora. Si se añade, debe seguir sin alertas clínicas (principio 3 de EQUIPO.md).
- **H-13 (Media) SpO₂ "70-100" y eje 85-100:** valores bajos reales se recortan/ocultan silenciosamente (filtro < 70 y eje mínimo 85); un usuario no ve datos fuera de rango sin explicación. Mostrar "lecturas descartadas: n".

### Técnico
- **H-14 (Alta) Sueño sin validar y posible mala fuente.** `readSleepData` no devolvió nada. El SDK de protocolo 5 entrega además `sleepStates` por tramo de 5 min en `OriginData3`, y `sleepLine`/`sleepQulity` en `SleepData`; la app no usa ninguno. Hipótesis (no verificada): en esta pulsera el sueño llega por `origin5.sleepStates` y no por `readSleepData`. Parte de P0 #1.
- **H-15 (Alta) Ciclo de vida del trabajo en segundo plano.** `AgpsWorker.doWork` hace `BandClient.init`, y `runSessionBlocking` publica en el hilo principal y espera con `CountDownLatch(240 s)`: dentro del proceso del Worker, el `Handler(Looper.getMainLooper())` funciona, pero (a) `doWork` devuelve `Result.success()` aunque falle (nunca reintenta: no hay `Result.retry()`), (b) WorkManager puede matar el worker a los ~10 min y en Android 12+ el arranque de conexión BLE desde segundo plano exige que la app no esté en estado restringido (Doze/ahorro); no se pidió exención de batería, (c) `connect` desde el worker no pide permisos: si el usuario revoca `BLUETOOTH_CONNECT`, falla en silencio, (d) el worker llama `BandClient.listener` que puede apuntar a una `MainActivity` destruida (sigue referenciada en `listener` tras `onDestroy`, fuga de actividad/engine; `listener` nunca se limpia). Es la causa probable de que nunca se haya visto correr solo (#2).
- **H-16 (Media) Condiciones de carrera.** `syncing`, `connected` son `@Volatile` pero `readyCbs`, `autoSync`, `weConnectedHeadless`, `seenItems`, `lastHeadKey` son estado mutable tocado desde varios hilos (Worker, hilo principal, hilo creado en `Agps.onConnected`). `Agps.onConnected` lanza un `Thread` sin control (varios sincros → varios hilos) y descarga mientras en paralelo programa `transfer` a los 500 ms (la transferencia puede ejecutarse antes de que acabe la descarga).
- **H-17 (Media) Pérdida silenciosa de datos en `JsonStore`.** `flush` escribe a `.tmp` y `renameTo` sin comprobar el resultado ni sincronizar a disco; si el JSON está corrupto `load` lo sustituye por `{}` y el siguiente `flush` **borra el historial**. No hay límite de crecimiento ni purga (≈ 288 registros/día × tipos); lectura con `getData` devuelve todo el histórico a Dart en cada `reload` (rendimiento y memoria crecientes).
- **H-18 (Media) `reload()` pesado en el hilo de UI** (decodifica y recorre todo el JSON en Dart tras cada sincro, y también en el evento `sync end`). Perfilar.
- **H-19 (Media) Timeout genérico de `stage` de 180 s para salud/deportes** y `readOrigin` no pasa `fin` en `onReadTimeout` si luego llega `onReadOriginComplete` (doble llamada protegida por `done`, ok). Si una etapa no responde, el log solo dice "timeout"; la UI no informa de sincronización parcial.
- **H-20 (Baja) Reconexión:** sin reconexión automática tras desconexión BLE; solo al abrir la app. Si el usuario va con el móvil y pierde enlace, no hay recuperación hasta reabrirla.
- **H-21 (Baja) Zona horaria / cambio de día:** `watchday = 3` por defecto; cómo se comporta al pasar > 3 días sin sincronizar (pérdida de datos de la pulsera) no está comunicado al usuario.
- **H-22 (Baja) Aviso de `flutter analyze` conocido** (`charts.dart:94`).

### Pruebas
- **H-23 (Alta) Cobertura de pruebas mínima:** 7 pruebas, todas de funciones puras de `analysis.dart` (confirmado: 7 `test(`). Sin pruebas de `repo.dart` (parseo JSON → modelos), `baselineOf`, filtros, ni widgets; el parseo del repo es la zona con más riesgo de regresión (H-09, H-08).

### Accesibilidad
- **H-24 (Media) Afirmaciones de la Guía no respaldadas.** `GUIA_DE_ESTILOS.md` §7 dice que "cada cifra lleva Semantics". Conteo en código: Semantics en `charts.dart` (1), `fx.dart` (2, navegación y corazón excluido), `today_page.dart` (1, cinta de días), `widgets.dart` (1, `BigValue`); **0** en `metrics.dart` (teselas Bento y detalle), `activity_page.dart`, `sleep_page.dart`, `device_page.dart`. El "Reloj del día" arrastrable no tiene alternativa no táctil comprobada. La escala de texto 200 % "sin recortes" no está comprobada (hay alturas y anchos fijos: 240 dp de ruta, 72 dp de stepper, 64 dp etiquetas de zona). El contraste "verificado" se declara pero no hay prueba ni herramienta registrada. `disableAnimations` se respeta en 4 sitios (fx.dart y today_page.dart), el resto no verificado.
- **H-25 (Baja) Color como único canal en rutas/zonas** (zonas de pulso y mapa de ruta coloreado): hay etiqueta de texto en zonas; ruta no.
- **H-26 (Baja) Tema claro apenas revisado** (ya en backlog #6).

### Documentación
- **H-27 (Media)** No existe README ni ARQUITECTURA ni MANUAL (EQUIPO.md los asigna al Documentador). `ESTADO.md` mezcla "estado" y "decisiones"; algunos datos de ESTADO.md (p. ej. "12 puntos/min") dependen de pruebas no reproducibles.
- **H-28 (Baja)** `ANALISIS.md` cita una página de Wikipedia para MET y un resumen de editor (`informahealthcare.com`) para Tanaka en jóvenes; fuentes secundarias, mejor sustituir por la original. Enlaces no re-verificados por mí en esta ronda.

## 3. Verificado vs no verificado
| Tema | Verificado (lectura de código/documentos) | No verificado |
|---|---|---|
| ESTADO.md: funciones implementadas (métricas nuevas, Dial, bento, sección experimental, WorkManager 6 h, batería ≥ 30 %, 20 h) | Sí, coincide con el código | Comportamiento en el móvil |
| 7 pruebas | Sí (7 `test(`) | Que estén en verde ahora |
| Ninguna alerta clínica ni categorías de riesgo | Sí (revisados metrics, today, sleep, activity, device) | Revisión de `charts.dart`/`widgets.dart` línea a línea |
| Glucosa en gris y plegada; campo de riesgo ignorado | Sí, el repo no lee `bloodGlucoseRiskLevel` | Aspecto visual real |
| Permisos Android 12+ (SCAN `neverForLocation`, CONNECT) | Sí | Comportamiento en dispositivos concretos |
| Datos reales GPS/sesiones, validez de efemérides | No | Todo |
| Unidades de glucosa, calorías 5 min | No | Todo |
| Fuente web de cada cita de ANALISIS.md | No (no se re-abrieron) | Todo |
| Contraste, escala 200 %, lector de pantalla | No | Todo |

## 4. Ronda de descubrimiento (PROCESO.md paso 6)

### 4.1 Sensores y campos del SDK recibidos y no usados
Guardado en `files/vigor/*.json` (Gson vuelca el objeto completo) vs lo que usa el repo.
| Origen | Campos del SDK | Uso actual |
|---|---|---|
| `OriginData3` (5 min) | `ppgs`, `met`, `pressure`, `temperature`, `baseTemperature`, `bloodGlucose`, `bloodComponent`, `stepValue/calValue/disValue` | Usados |
| `OriginData3` | `resRates` (respiración 5 min), `oxygens` (SpO₂ 5 min), `sleepStates`, `apneaResults`, `hypoxiaTimes`, `isHypoxias`, `cardiacLoads`, `gesture`, `ecgs`, `corrects` | **No usados** (guardados, no mostrados) |
| `OriginData` (heredado) | `wear` (indicador de uso), `sportValue` (intensidad 5 niveles), `highValue/lowValue` (presión arterial), `calcType`, `rateValue` | No usados |
| `OriginHalfHourData` | frecuencia, presión arterial, deporte por 30 min | Guardado en `half.json`, **nunca cargado** por el repo |
| `HRVOriginData` | solo `rrValue` (RR) | El `hrvValue` del fabricante descartado a propósito (ver ESTADO) |
| `Spo2hOriginData` | solo `oxygenValue` | Otros campos (apnea, hipoxia, respiración) no usados |
| `SleepData` | `sleepLine`, `sleepQulity`, `cali_flag` | No usados; `sleepLine` daría fases minuto a minuto |
| Cabeceras de deporte | `oxsporttimes/oxSportDuration`, `pauseCount/pauseTime`, `sportCount`, `dataType`, `kcals` (no-GPS), `peisu` | No usados |
| Ítems de deporte | `stepCount`, `sportCount`, `distance`, `kcal`, `beathPause`, `signalArray` (GPS, por datos reales) | Solo `rate`, `latArray`, `lngArray` |
| Funciones del dispositivo | paquetes 1-5 de funciones (qué sensores admite) | Solo logueados; la UI no se adapta a lo que la pulsera dice soportar |

Sensores/funciones de la pulsera sin aprovechar (según índice de `api_en.md`): ECG manual con diagnóstico, medición manual de pulso/SpO₂/HRV/estrés/MET/glucosa/temperatura ("Reading Device Manual Measurement Data", "Automatic Measurement Function"), respiración y apnea, presión arterial, GSR (respuesta galvánica), fatiga y emoción (`Fatigue`, `Emotion`), mini-chequeo, "AI function", composición corporal, luz de salud, función de mujeres, sedentarismo ("Long-sit"), recordatorios de salud, alarmas, clima, cámara remota ("Photo"), música, llamadas/contactos, esferas, nombre BLE, vibración, gestos de muñeca y pantalla (aún no leídos en detalle). Para cada una, la compatibilidad de esta pulsera concreta es **no verificada** (depende de los paquetes de funciones).

### 4.2 Funciones de G Band que faltan (todas "con sentido" salvo las marcadas)
Medición rápida bajo demanda (con SDK soportado), alarmas, notificaciones del móvil, cámara remota, recordatorios (sedentarismo, beber, etc.), ajustes de pantalla/gesto/brillo, esferas, sueño con curva, exportación de datos del usuario, buscar móvil desde la pulsera (hay `findBand` inverso), clima, música. Dudoso por salud/regulación: puntuaciones de "salud" y presión arterial/glucosa/ECG con diagnóstico (no recomendado sin validación; ver EQUIPO.md principio 3). No he comparado línea a línea con G Band instalada en el móvil.

### 4.3 Checklist
- [ ] **Sensores aprovechados / campos no usados:** No. Ver 4.1 (respiración, sueño por 5 min, SpO₂ 5 min, `wear`, presión, medias de 30 min, etc.).
- [ ] **Estudios 2020-2026:** No revisado por el Supervisor en esta ronda (pendiente al Investigador cardio y movimiento): validación de SpO₂ en muñeca en distintas pigmentaciones, HRV ultracorta, sueño con wearables, calorías por MET, temperatura. ANALISIS.md ya usa fuentes 2017-2024.
- [ ] **Cada análisis con fuente y limitación:** Parcial. Ver H-07, H-08, H-28.
- [ ] **Deuda técnica / QA / rendimiento / batería:** Abierto. H-15 a H-23. Batería: el trabajo de 6 h con conexión BLE y descarga (≈ 161 KB) es razonable; no medido. QA no ha emitido informe todavía.
- [ ] **Accesibilidad y privacidad:** Abierto. H-01 a H-06 y H-24 a H-26.
- [ ] **Funciones de G Band:** 4.2.
- [ ] **Documentación al día:** No. H-27; ESTADO.md fusiona el estado con la actualización posterior; falta README/ARQUITECTURA/MANUAL/GLOSARIO/BASES_CIENTIFICAS.
- Resultado: backlog ampliado (secciones 5 y BACKLOG.md); la siguiente ronda empieza por P0.

## 5. Propuesta de backlog priorizado
(Los números "N" de BACKLOG.md empiezan en 8, tras los heredados.)

**P0**
1. (N8) Privacidad: `allowBackup="false"` + `dataExtractionRules`/`fullBackupContent`; log solo en debug y sin volcar objetos; enmascarar MAC en UI. Responsable: Desarrollador. (H-01, H-02, H-03)
2. (N9) Sueño: volcar (en local, sin compartir) la estructura real de `origin5.sleepStates`/`SleepData` tras una noche con la pulsera puesta y decidir la fuente; usar `sleepLine` si llega. Responsable: Investigador movimiento + Desarrollador. (H-14)
3. (N10) Robustez de `AgpsWorker`/`BandClient`: limpiar `listener` en `onDestroy`, `Result.retry()` en fallo, evitar `Thread` sueltos, ordenar descarga → transferencia, hilo seguro del estado compartido, registro de resultado visible. Responsable: Desarrollador, revisión QA. (H-15, H-16)
4. (N11) `JsonStore`: no vaciar si está corrupto (conservar copia `.bad`), comprobar `renameTo`, límite/purga de histórico (p. ej. 90 días) y lectura por rango. Responsable: Desarrollador. (H-17)
5. (N12) Pruebas de `VigorRepo.reload` con JSON de ejemplo (anónimo, sintético) incluida una sesión sin GPS y calorías; pruebas de `baselineOf`. Responsable: QA. (H-23, H-09)

**P1**
6. (N13) Corregir campos de deporte sin GPS (`kcals`, `peisu`) y verificar `avgPace`. Responsable: Desarrollador. (H-09, H-10)
7. (N14) Aprovechar respiración (`resRates`) y SpO₂ de 5 min (`oxygens`) con la misma política honesta (tendencia, sin alertas); indicador `wear` para excluir tramos sin pulsera. Responsable: Investigador cardio (evidencia) + Desarrollador. (4.1)
8. (N15) Documentar cada filtro de plausibilidad, el uso de `baselineOf` en todas las métricas y la fórmula/ventana de RMSSD en ANALISIS.md con fuente o rótulo "heurística propia"; mostrar "lecturas descartadas". Responsable: Investigador cardio (propuesta) / Supervisor (ANALISIS.md). (H-07, H-13)
9. (N16) Accesibilidad real: Semantics en teselas, detalle, actividad, sueño, dispositivo; alternativa accesible al Reloj del día; prueba con escala de texto 200 % y con TalkBack; medir contraste. Corregir lo que diga la Guía si no se cumple. Responsable: Desarrollador + QA. (H-24)
10. (N17) Unidades: validar glucosa, `calValue` y `bloodComponent` frente a la app oficial en la misma hora (sin guardar capturas con datos personales). Responsable: Investigador cardio. (H-08)
11. (N18) Reconexión automática y estado de sincronización parcial/errores en la UI. Responsable: Desarrollador. (H-19, H-20)
12. (N19) Investigar compatibilidad real de la pulsera: parsear y mostrar de forma legible los paquetes de funciones soportadas y adaptar la UI. Responsable: Investigador movimiento + Desarrollador. (4.1)
13. (N20) Revisión de estudios 2020-2026 por sensor y sustitución de fuentes secundarias (Wikipedia, resumen de editor). Responsable: Investigadores. (H-28)

**P2**
14. (N21) Cargar `half.json` (medias de 30 min) como respaldo si falta `origin5`; presión arterial: solo evaluar, no mostrar. Responsable: Investigador cardio. 
15. (N22) Permisos: `maxSdkVersion="30"` en ubicación; evaluar cambio de contraseña de la pulsera. Responsable: Desarrollador. (H-04, H-06)
16. (N23) Rendimiento de `reload()` (aislar o cachear), perfil de memoria y batería. Responsable: QA + Desarrollador. (H-18)
17. (N24) README, ARQUITECTURA, MANUAL_USUARIO, GLOSARIO, BASES_CIENTIFICAS. Responsable: Documentador. (H-27)
18. (N25) Exportar datos del usuario (CSV/JSON, con aviso de privacidad) y borrar datos locales. Responsable: Desarrollador.
19. (N26) Verificar integridad/origen de las efemérides (HTTPS, host, tamaño/CRC). Responsable: Desarrollador. (H-05)
20. (N27) ECG/medición manual: **solo** estudio de viabilidad y de la política de salud antes de implementar (sin diagnóstico). Responsable: Investigador cardio.
