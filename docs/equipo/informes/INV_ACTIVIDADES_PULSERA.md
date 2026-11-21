# Cómo se inician y se recogen las actividades (móvil y pulsera)

Fuente: documentación del SDK Veepoo, en el submódulo `android/third_party/Android_Ble_SDK` y en GitHub:
- Español/chino (la más completa; sección «设置运动控制» y «设置运动控制主动上报监听»): https://github.com/HBandSDK/Android_Ble_SDK/blob/26ebb0f/android_sdk_source/sdkdoc/VeepooSDK%20Android%20Api.md
- Inglés (sección «Sports function»; no incluye el control de deporte): https://github.com/HBandSDK/Android_Ble_SDK/blob/26ebb0f/android_sdk_source/sdkdoc/VeepooSDK%20Android%20Api%20-%20English.md

## Quién puede iniciar una actividad
1. **La pulsera**, pero **la VIGOR no tiene pantalla**: no hay menú donde elegir un deporte ni cronómetro que mirar. La documentación del SDK no explica cómo arrancaría una actividad la propia pulsera sin pantalla; lo único que podría hacerlo es un botón físico o una detección automática de actividad (la VIGOR declara `daSport`, cuyo significado exacto el SDK no explica). **No está comprobado.** Si una actividad arranca así, graba sola (pulso, pasos y GPS si el modo lo usa) y guarda la sesión en su memoria sin necesitar el móvil.
2. **El móvil**, con una orden por Bluetooth. Hay dos APIs: `startSportModel`/`startMultSportModel` (las que usa Vigor ahora; «multSportMode» está soportado por la VIGOR) y, solo si el dispositivo lo admite (`isSupportAppOpenSport`), `setSportControlInfo` con `ESportControlType` START, PAUSE, RESUME y STOP. Para el modo, ver `ESportType` (187 modos, los de `lib/data/sports.dart`).

## Consecuencia: el móvil es la pantalla
Sin pantalla en la pulsera, la forma práctica de iniciar, ver y parar una actividad es el móvil: «Iniciar nueva actividad», la isla de actividad en curso y la pantalla de entreno de Vigor.

## Qué sabe el móvil mientras dura (solo con la sesión Bluetooth abierta)
- `readSportModelState`/`ISportModelStateListener`: estado del reloj: libre, ocupado o «ya empezada antes» (una actividad que ya estaba en marcha en la pulsera).
- `setSportControlReportListener` (`IDeviceSportReportListener`): **la pulsera informa por su cuenta** mientras hay una actividad, también si no la empezó la app (si es que puede empezar una sola). Cada informe (`SportControlDataInfo`) trae: tipo de deporte, código de operación (START, PAUSE, RESUME, STOP), estado (`NOT_STARTED`, `RUNNING`, `PAUSED`, `RESUMING`, `FINISHED`), estado del dispositivo (normal, batería baja, cargando, tiempo máximo alcanzado), duración (s), distancia (m), pulso (lpm), calorías (**calorías, ÷1000 para kcal**), ritmo (s/km) y velocidad (**m/h**).
- No hay ruta en directo: el GPS se descarga al terminar.

## Cómo llega la sesión al móvil
Al sincronizar, `readSportModelOrigin` (`ISportModelOriginListener`) entrega la cabecera de cada sesión (fecha, inicio, fin, duración, pasos, calorías, distancia, pausas, ritmo, pulso medio, tipo) y los detalles por minuto (12 puntos de GPS con su señal, pulso, estado). Así aparecen en «Historial», con o sin móvil durante la actividad.

## Lo que hace Vigor hoy
- Inicia la actividad con `startMultSportModel` y la para con `stopSportModel`.
- Escucha el informe en vivo (isla de actividad en curso y pantalla de entreno), incluida cualquier actividad que ya estuviera en marcha en la pulsera.
- Recoge las sesiones al sincronizar.

## Sin verificar con la VIGOR
Que mande informes en vivo, y si admite `setSportControlInfo` (pausa y reanudación desde el móvil): `sportStatus` figura como no soportado y no apareció ningún indicador `appOpenSport` entre las funciones que declara.
