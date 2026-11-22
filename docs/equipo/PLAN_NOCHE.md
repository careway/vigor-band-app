# Plan de la noche (Supervisor, 2026-11-22)

Auditoria sobre codigo y tests actuales, sin pulsera ni movil. Regla: nada de lo que dependa de la pulsera se marca como verificado; solo "codigo + test con fakes".
Base: `repo.dart` (538 lin.), `auto_sync.dart`, `BandClient.kt`, `test/` (36 ficheros). Commit local `_syncAfterWorkout` ya hecho y con test (`dev022_postworkout_test.dart`).

## Hallazgos reales (por que estas tareas)
1. `sync()`, `startSport()`, `stopSport()`, `readAutoMeasure()`, `findBand()`, `connect()`, `disconnect()` y `setPref/setExperimental/setMapStyle/...` en `repo.dart` hacen `invokeMethod` SIN try/catch: un `PlatformException` llega sin gestionar desde `onPressed` (botones de Hoy, Dispositivo, Actividad) y no hay mensaje.
2. Kotlin emite `sync end ok:false` y Dart solo no actualiza `lastSync`: el usuario no ve que la sincronizacion fallo ni por que (no hay `syncError`). Una caida a mitad (`disconnected` durante sync) tampoco se avisa.
3. Tras reconectar no se hace nada especifico: `AutoSync` sincroniza solo si pasaron >= intervalo (o 5 min al reanudar). Una reconexion tras una desconexion larga (p. ej. entreno sin movil) puede esperar hasta 30 min. Misma familia que `_syncAfterWorkout`.
4. Tras reconectar no se relee la cadencia automatica (`readAutoMeasure`): `autoMeasures` puede quedar obsoleto si la pulsera la cambio.
5. `setAutoMeasure`: si la pulsera no responde no hay timeout; `autoMsg` queda sin resultado (sin "no respondio").
6. `setAutoSync`, `setPref` (edad, meta) y similares: el `catch (_) {}` traga el fallo y la UI muestra el valor nuevo aunque no se guardara.
7. `_syncAfterWorkout`: si la pulsera esta desconectada al terminar (entreno sin movil) no se reintenta al reconectar; se pierde el disparo. Ademas `sync().catchError` oculta el error.
8. Los `catch (_) {}` de `reload()` (6 bloques, lineas ~412-466) dejan secciones a medias sin rastro (`loadError` solo cubre init).
9. Tests: no hay test de reconexion->sync, de fallo de `sync()` ni de `syncing` colgado si Kotlin no emite `end`. `syncing` puede quedar `true` para siempre (bloquea borrar, medir y auto-sync) si se pierde el evento `end`: no hay watchdog en Dart.
10. Docs: `MANUAL_USUARIO.md` y `ESTADO.md` ya separan "no verificado", pero no mencionan la sincronizacion tras actividad ni el estado de BACKLOG 18 (reconexion: ya existe con espera creciente, el backlog dice "sin reconexion automatica", desactualizado).

## Area A. Sincronizacion y flujos (archivos: `lib/data/repo.dart`, `lib/data/auto_sync.dart`, tests nuevos `test/noche_a_*_test.dart`)
- **A1 (P0)** Envolver las llamadas de canal de usuario (`sync`, `startSport`, `stopSport`, `connect`, `disconnect`, `findBand`, `readAutoMeasure`) en try/catch que fije `repo.notice` (texto corto) en vez de dejar escapar `PlatformException`. Si `startSport` falla, revertir `sportActive`/`workout`. Test: mock de canal que lanza.
- **A2 (P0)** Resultado de sincronizacion visible: guardar `lastSyncOk` y `syncError` ("No se pudo sincronizar; reintentando") cuando `sync end ok:false` o cae la conexion durante la sync; limpiar al exito. Solo propiedad + test (la UI la pinta B1).
- **A3 (P1)** Watchdog de `syncing`: si no llega `end` en N min (p. ej. 5), poner `syncing=false` y `syncError`. Reloj inyectable `clock`. Test con reloj simulado.
- **A4 (P1)** Al pasar a `connected` tras estar desconectado (no al primer arranque): programar una sincronizacion corta (6 s, una vez) si la ultima correcta tiene > 2 min; cubre "reconectar tras entreno sin movil" y reutiliza la guarda `!syncing && !sportActive`. Test analogo a `dev022`.
- **A5 (P1)** Si una actividad termina estando desconectado, marcar `pendingPostWorkoutSync` y dispararlo en A4 al reconectar. Test.
- **A6 (P2)** Tras reconectar, `readAutoMeasure()` una vez (solo si la pantalla de cadencia es relevante: barato) y timeout de 8 s para `setAutoMeasure` con `autoMsg` = "La pulsera no respondio". Test con fakes.
- **A7 (P2)** `setPref/setAutoSync/setExperimental/setMapStyle...`: no cambiar el valor en memoria si el canal falla; `notice` corto. Test.

## Area B. UI/UX y textos (archivos: `lib/ui/*`, excepto lo que toque C; NO `repo.dart`)
- **B1 (P1)** Mostrar `repo.notice` y `repo.syncError` (de A1/A2) como una linea corta bajo "Sincronizado hace X" en Hoy y Dispositivo, con `Semantics(liveRegion)`, texto en una frase ("No se pudo sincronizar. Reintentando."). Depende de A1/A2: B espera a que A fije los nombres (`notice`, `syncError`, `lastSyncOk`); acordar en el prompt.
- **B2 (P2)** Pasada de textos: acortar diálogos de confirmacion y etiquetas de accesibilidad largas (BACKLOG 105); voz uniforme, sin referencias a ficheros, sin decir "pulsera" 3 veces. Con tests de `dev020_clean_ui_test.dart` actualizados.
- **B3 (P2)** Estado vacio/desconectado coherente: Hoy con boton unico segun estado (conectar / buscar / sincronizar), sin duplicar el aviso de bateria baja; revisar que "midiendo pulso..." no coexista con "Sincronizando...".

## Area C. Robustez/QA (archivos: `test/**`, `android/app/src/test/**`, `lib/ui/*_a11y*` solo tests; NO tocar `lib/` salvo bug confirmado, que se informa a A/B)
- **C1 (P1)** Test de widget a `textScaleFactor` 2.0 y 320 px de Actividad, Sueño y Dispositivo (hoy solo Hoy/Ahem parcial; BACKLOG 16/52).
- **C2 (P1)** Tests de estados limite de `reload()`: JSON corrupto por tipo, dia sin datos, noche sin `sleepLine`, sesion sin GPS, fechas fuera de orden. Sin datos reales (sinteticos).
- **C3 (P2)** Tests Kotlin JVM de logica pura nueva (si A/Kotlin la toca) y `AutoSync` con fallos encadenados (backoff hasta el tope, `onResume` reinicia).
- **C4 (P2)** Revision de lectura (solo informe a `informes/QA_005.md`): carreras entre `sync`, `deleteRecords`, `wipeData` y el `_exportThenClear`; riesgos de `notifyListeners` tras `dispose`.

## Area D. Documentacion honesta (archivos: `docs/**`, `README.md`; NO codigo)
- **D1 (P1)** Tabla "implementado / con test / probado con pulsera" en `docs/ESTADO.md`: sincronizacion automatica, post-entreno, pulso en vivo, informe en vivo (sondeo verificado en hardware segun BACKLOG 108), Health Connect (verificado en Mi 9), mapa. Cada fila con fecha y fuente; lo no probado dice "no verificado".
- **D2 (P1)** Corregir BACKLOG-18 (obsoleto: hay reconexion con espera creciente en `auto_sync.dart`, no probada con caida real) y el recuento de tests (ejecutar `flutter test` y anotar el numero real). Solo en `BACKLOG.md` (Supervisor).
- **D3 (P2)** `MANUAL_USUARIO.md`: sincronizacion tras actividad (6 s y 45 s), aviso de fallo (cuando B1 exista), y que sin movil durante un entreno los datos se leen al reconectar.

## Orden y paralelismo
Ola 1 (a la vez, disjuntas): A1-A3, B2/B3 (sin depender de nombres), C1/C2, D1/D2.
Ola 2: A4-A7, B1 (tras A1/A2), C3/C4, D3.
Cada agente corre `flutter analyze` y `flutter test` (via powershell, ver EQUIPO.md); A y B comparten solo los nombres `notice`/`syncError`/`lastSyncOk` (A los define, B los consume).
Fuera de alcance esta noche (necesitan pulsera o usuario): firma release/`applicationId` (62-63), sueño real, Worker con app cerrada, TalkBack real, modos deportivos, GPS al aire libre.

## Ola 3 (desde QA_005; verificar cada punto en el código antes de arreglar)
- **A8 (P0, R1):** `_exportThenClear` no debe limpiar la marca `dirty` si `health.run()` no exportó nada (ya en curso, Health Connect no disponible o sin permisos). Test con pasarela falsa.
- **A9 (P0, R2):** `wipeData` debe cancelar y esperar un `run()` en vuelo; `afterWipe` debe activar la cancelación; el envío no debe volver a guardar datos borrados. Test con `run` en vuelo.
- **A10 (P1, R3/R5):** `deleteFromHealth` respeta `_running`; si el fin de sync llega sin `ok`, no exportar parcial. R4 (reentrada de `reload`) solo si se demuestra con test.
- Dependen de que termine la ola 2 en `lib/data/repo.dart` (no editar a la vez).

## Estado (2026-11-22, madrugada)
- Olas 1, 2 y 3 hechas y subidas (R1, R2, R3 y R5 de QA_005 arreglados; R4 sin demostrar, descartado). Analisis limpio y 553 tests verdes.
- Pendiente: D3 (manual de usuario); test de wipeData/_exportThenClear a nivel de VigorRepo (hace falta poder inyectar la pasarela de Health Connect); todo lo que requiere pulsera sigue SIN verificar.

## Estado (2026-11-22, 04:00)
- D3 (manual) hecho; VigorRepo admite inyectar la pasarela de Health Connect y hay tests de wipeData/_exportThenClear (sin fallos nuevos). Analisis limpio y 558 tests verdes.
- Plan agotado salvo lo que necesita pulsera (sin verificar). La proxima ronda pedira una auditoria nueva al supervisor solo si hay algo valioso; no se inventa trabajo.

## Ola 4 (descubrimiento real del Supervisor, 2026-11-22; solo codigo y tests, sin pulsera)
Revisados BandClient.kt (syncAll/stage/runSessionBlocking/poll), SyncWorker.kt, JsonStore.kt, workout.dart, workout_ui.dart. Descartado por ya cubierto o correcto: `syncing` colgado en Kotlin (BandClient.kt:180 lo cierra y emite `end` al caer la conexion), watchdog Dart (A3), carreras de Health Connect (A8-A10), desbordes a 320 px/x2 de WorkoutPage (dev019_workout_test.dart:229).

- **E1 (P1, archivos: `lib/ui/workout_ui.dart`, `test/dev019_workout_test.dart`)** Accesibilidad y coste del cronometro.
  Evidencia: `workout_ui.dart` (WorkoutPage, bloque `Semantics(liveRegion: true ... label: 'Tiempo ${clockText(w.elapsed())}...')`) lleva `liveRegion` sobre una etiqueta que cambia CADA segundo (el `_Tick` reconstruye 1 Hz): TalkBack anunciaria el tiempo continuamente durante todo el entreno (no hay ningun test de `liveRegion`, solo hay un `grep` vacio en `test/`). Ademas `_Tick` envuelve el `ListView` entero, asi que `RouteMap` (mapa de 230 px), grafica de pulso y tiles se reconstruyen cada segundo.
  Hacer: quitar `liveRegion` del cronometro (dejarlo solo en el texto de estado: En curso / En pausa / Sin datos / Terminada, que cambia pocas veces); reconstruir cada segundo solo el widget del tiempo (y el de la isla), no el `ListView` ni `_LiveMapCard`. Tests: el arbol semantico del tiempo no es liveRegion y el de estado si; contar reconstrucciones de un hijo pesado (builder con contador) tras 3 s de `pump`.
- **E2 (P1, archivos: `android/app/src/main/kotlin/com/careway/vigor_app/JsonStore.kt`, `android/app/src/test/kotlin/com/careway/vigor_app/JsonStoreTest.kt`)** Dos perdidas silenciosas de datos.
  (a) `JsonStore.kt` `load()`: ante `IOException` al leer devuelve `JSONObject()` SIN cachear; `put/putItems` escriben en ese objeto desechable, `flush` se niega (no esta en cache) y `syncAll` aun asi marca la sincronizacion como correcta (`BandClient.kt:299-303`): los datos recien leidos de la pulsera se pierden sin aviso. Hacer: cachear un estado "no legible" por tipo (los `put` se acumulan en memoria y no se vuelcan hasta que una relectura funcione, fusionando) o hacer que `flush` devuelva false de forma observable y que `syncAll` no cuente `ok` si fallo algun flush (`flushAsync` hoy traga el resultado: `BandClient.kt:75`).
  (b) `flush()`: la serializacion es bajo el cerrojo del almacen y la escritura fuera, con `gen` solo para wipes; dos flush del mismo tipo desde hilos distintos (ioFlush y `deleteRecords`/`exportTo`) pueden escribir en orden inverso y dejar en disco la version vieja (p. ej. un registro borrado reaparece en el fichero; la tumba lo oculta en la app pero `exportTo` lo copia). Hacer: contador de version por tipo asignado al serializar; bajo `writeLock` descartar la escritura si ya se escribio una version posterior. Tests JVM con `beforeWrite` (ya existe el gancho) para forzar el orden inverso, y con un directorio que simule fallo de lectura.
- Disjuntas: E1 solo UI Dart; E2 solo Kotlin. Cada agente corre analyze/test (EQUIPO.md). No requieren pulsera.
- Opcional P2 no asignado: `LiveWorkout.track` (workout.dart `onGpsPoint`) crece sin tope y `setTrack` re-filtra todo en cada punto (O(n) cada ~5 s); acotar solo si se demuestra con un test de 4 h sinteticas.

## Estado (2026-11-22, madrugada, tras ola 4)
- E1 (cronometro del entreno sin anuncio continuo y sin redibujar el mapa cada segundo) y E2 (JsonStore: no se pierden datos si falla una lectura, la sincronizacion no se da por buena si falla el volcado, orden de escrituras) hechos. Analisis limpio, 560 tests Dart y 81 Kotlin verdes. Sin probar en el movil ni con la pulsera.
- E2 cambia renameTo por Files.move atomico en JsonStore: comprobar en el movil en la proxima sesion con adb que la sincronizacion sigue guardando.
- Sin asignar (P2): LiveWorkout.track crece sin tope; solo si un test de 4 h sintetico lo demuestra.
