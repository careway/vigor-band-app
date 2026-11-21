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

> Nota: la VIGOR **no tiene pantalla**. Donde esta investigación hable de «menú» o «pantalla» de la pulsera (p. ej. «cámara», «música» o «buscar móvil» en su menú), no aplica: los eventos solo podrían salir de botones físicos o gestos.

## Adenda: prueba real con la VIGOR vinculada (2026-11-21)
**Cómo:** una sonda SOLO de depuración (`src/debug/.../EventProbe.kt`, no existe en release) registra todos los oyentes del SDK (buscar móvil, golpecito, SOS, llamadas, música, control de deporte, estado de deporte, cámara) y escribe «EVENTO …» en el registro; se grabó el registro completo durante 150 s mientras el usuario pulsaba botones, daba golpecitos y levantaba la muñeca. Para el modo foto hay un disparador de depuración (`am broadcast … --es probe camera`).

**Ajustes de personalización que declara la pulsera** (`readCustomSetting`): `SOS`, `autoIncall`, `findPhoneUi`, `longClickLockScreen`, `musicControl` y `sportOverRemain` = **UNSUPPORT**. Es decir, la VIGOR NO ofrece esos interruptores. (Esto contradice la lectura optimista de `musicStyle=1` de la sección anterior: ese indicador no significa que haya control de música configurable.)

**Resultado de la prueba:**
- Llegaron **0 eventos** por los oyentes del SDK (ningún «EVENTO …»).
- Sí llegaron, por Bluetooth, paquetes que el SDK etiqueta así (97 en total):
  - `heart_read_oprate` `D0 00 …` (88): flujo de pulso en vivo, sin lectura; `D0 3B`, `D0 3E`, `D0 40` (6): lecturas con el valor en el segundo byte (59, 62 y 64 lpm), no botones.
  - **`find_phone_by_watch_operate` `B5 0B 02 …` ×2** (19:10:57 y 19:10:58): la pulsera pidió «buscar el móvil», pero el oyente `findPhone()` del SDK **no se disparó**. El SDK etiqueta el paquete pero no lo traduce a la llamada (el subcódigo 02 parece no estar asociado a ella).
  - `bt_operate` `BD 03 01 00 02 00 01 01` (1, 19:10:54): evento de Bluetooth/estado, sin identificar.
- No se vio ningún paquete distinto para pulsaciones de botón, golpecito ni levantar la muñeca.

**Conclusión provisional:** con esta pulsera y este SDK, los botones físicos y los gestos **no generan eventos que la app pueda escuchar**, salvo una acción de «buscar el móvil» (`find_phone_by_watch`), que llegó como paquete pero sin pasar por el oyente del SDK. **La VIGOR no tiene pantalla**, así que esa acción no sale de un menú: lo más probable es que la dispare un botón físico o un gesto durante la prueba, pero no se identificó cuál (y el usuario no lo recordó). Aprovecharla exigiría interpretar el paquete en bruto, que el SDK no expone (habría que enganchar la notificación de la característica `0xf0080002`, no probado).

**Pendiente:** el modo foto (obturador) no se pudo probar en esta ronda; la reconexión y la identificación exacta de qué acción hizo el usuario en cada momento.

