# INV_BOTONES — ¿Se pueden escuchar los botones de la pulsera y configurarlos?

**Pregunta del usuario:** buscar si se puede escuchar cuando se presionan botones de la pulsera y si esos botones son configurables.

**Fuentes:** documentación del SDK (VeepooSDK Android Api - English.md), lectura de las clases del `vpprotocol-2.3.96.15.aar` y los indicadores de funciones que la pulsera VIGOR envió al conectar (compilación de depuración, 2026-11-21).

## Respuesta corta
- **No hay un evento genérico de «botón pulsado»** en el SDK, ni forma de reasignar los botones físicos o elegir qué acción hacen.
- **Sí hay eventos concretos que dispara la pulsera** (por una acción del usuario en el reloj) y la app puede escuchar mientras está conectada por Bluetooth.
- **Lo configurable** son interruptores de funciones («personalización»), no los botones: `isOpenFindPhoneUI`, `isOpenSOS`, `isOpenMusicControl`, `isOpenLongClickLockScreen`, etc. Se activan o desactivan; no se remapean.

## Eventos que el SDK permite escuchar (dirección pulsera → móvil)
| Evento | API del SDK | Qué ocurre |
|---|---|---|
| Buscar el móvil | `settingFindPhoneListener` → `findPhone()` | La pulsera pide que el móvil suene o vibre |
| Obturador de la cámara | `startCamera` / `setCameraListener` → `ECameraStatus.TAKEPHOTO_CAN` | Con el modo foto activo, pulsar en la pulsera ordena hacer una foto |
| Control de música | `settingMusicControlListener` → siguiente, anterior, reproducir/pausar, volumen +/− | Requiere enviar los datos de la canción (`settingMusicData`) |
| Llamadas | `settingPhoneListener` → `rejectPhone`, `cliencePhone` (silenciar), `appAnswerCall` | Rechazar, silenciar o contestar desde la pulsera |
| SOS | `settingSOSListener` | Aviso de emergencia desde la pulsera |
| Golpecito | `settingKnocknotifyListener` | Gesto de golpe |
| Deporte iniciado o parado en la pulsera | `setSportControlReportListener` (`SportControlDataInfo`), `ISportModelStateListener.onSportStopped`, `setNewSportDataReportListener` | La pulsera avisa de que empezó, paró o dio datos de una actividad |
| Otros | `setReminderEventReportListener`, `settingPttModelListener`, `setAiListener` | Recordatorios, walkie-talkie, asistente |
La dirección contraria (móvil → pulsera) también existe: `startFindDeviceByPhone` hace sonar la pulsera.

## Qué soporta la VIGOR (leído de la pulsera conectada)
- `camera=SUPPORT`: foto remota.
- `findDeviceByPhoneFunction=SUPPORT`: el móvil puede hacer sonar la pulsera (sentido contrario al de arriba).
- `musicStyle=1`: control de música.
- `sportModelFunction`, `multSportMode` (tipo 4), `daSport`, `WeChatSport`, `newCalcSport` = SUPPORT: modos deportivos y su control.
- No soportados: `pttControl`, `sportStatus`, `wearHand`.
- **No aparecieron** (ni como soportados ni como no soportados) `findPhone` (la pulsera busca el móvil), SOS ni golpecito. Se intentó leer los ajustes de personalización para confirmarlo, pero la reconexión posterior agotó el tiempo y no se pudo repetir. Por tanto, para esos tres: **sin confirmar**.

## Límites
- Los eventos solo llegan con la sesión Bluetooth abierta (app abierta o sincronización en segundo plano en curso); no se pueden escuchar con la app cerrada y sin conexión.
- No se ha probado nada pulsando botones reales: lo anterior sale de la documentación, de las clases del SDK y de los indicadores de soporte.
- Qué botón físico dispara cada evento depende del firmware de la VIGOR y el SDK no lo documenta.

## Si se quisiera aprovechar (no implementado)
1. Obturador de cámara remoto: modo foto en la app y disparo con la cámara del móvil cuando llegue `TAKEPHOTO_CAN` (la VIGOR lo soporta).
2. Control de música del móvil desde la pulsera.
3. Buscar el móvil (suena o vibra) si la pulsera lo emite.
4. Mostrar en la app las actividades iniciadas desde la pulsera en cuanto llegue el aviso.
Cada una necesita probarse con la pulsera en la mano.
