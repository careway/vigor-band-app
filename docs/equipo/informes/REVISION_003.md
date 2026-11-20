# REVISION_003 — Revisión del Supervisor (ronda 3)

Fecha: 2026-11-20. Leído: EQUIPO, PROCESO, BACKLOG, ESPECIFICACION_RONDA3, ESTADO, ANALISIS, GUIA_DE_ESTILOS, DEV_002, REVISION_002. **No leí QA_003 ni QA_002 completo** (los estados de QA_002 salen de DEV_002), no ejecuté flutter, ADB ni la app: todo lo técnico lo cito de DEV_002. Sin coordenadas, MAC ni datos personales.

## 1. DEV_002 frente a la especificación
- E1–E5: implementadas en código con 38 tests nuevos (112/112, analyze limpio). **Ninguna vista en pantalla ni con la pulsera** (móvil bloqueado). Estado en `BACKLOG.md`: «hecho en código», nunca «verificado».
- E5 parcial: no hay campos nuevos de la pulsera (correcto), falta la prueba de distancia conocida.
- E6 y E7: solo herramientas de depuración, compiladas, sin ejecutar. Hay un menú «Avanzado (depuración)» visible en `kDebugMode`; aceptable (no existe en release), pero conviene que el test confirme que el lado Kotlin lo ignora en release.
- Desviaciones razonables de DEV_002 (aceptadas): 0 = «sin dato», no «fuera de rango»; posibles de hoy = transcurridas; 14 noches válidas en vez de 14 días naturales.
- Riesgos que veo: (a) supuestos sin verificar de los que cuelgan E2/E3/E4B: `ppgs` 1/min, 1 registro `hrv` = 1 min; (b) la noche 00:00–06:00 asigna al día siguiente lo posterior a medianoche de registros que empiezan a las 23:xx; (c) Kotlin sin tests: M2, N1–N4, N6–N8, M5, M7; (d) E4B usa 70 % de FCmáx con edad por defecto 35: cifra poco fiable para quien no haya puesto su edad (se avisa en pantalla); (e) mantener `rmssd()` antiguo «solo por tests» es deuda menor.

## 2. Documentación científica (ANALISIS.md §17–19)
Actualizada con lo realmente implementado, filtros propios marcados «sin fuente» y los ajustes de DEV_002 §6. Verificación de esta ronda:
- **Reconfirmado a nivel de resumen de búsqueda:** OMS 2020 (Bull, *Br J Sports Med* 2020;54:1451): 150–300 min moderada o 75–150 vigorosa; moderada = 3 a < 6 MET. **No reconfirmado:** vigorosa ≥ 6 MET (visto en la ronda 2 también solo en resumen).
- **No se pudo abrir a texto completo** Kantrowitz 2025, Esco 2025, Paluch 2022, Chinoy 2021 ni la propia guía OMS: el lector web respondió «no se pudo verificar el dominio» para PMC. Por tanto nada nuevo queda «leído a texto completo» esta ronda; siguen leídos completos solo FDA 2024, Shaffer & Ginsberg 2017 y Yeh 2021 (ronda 2). Se deja en el backlog (45) abrirlos por otra vía.
- Ningún enlace nuevo sin consultar: Zhang 2020 se cita sin enlace y marcado «no verificado».

## 3. Ronda de descubrimiento (PROCESO paso 6)
**(a) Sensores.** PPG: usado (pulso, HRV, E2/E3). SpO₂: 5 min y nocturna sin usar (E8 aplazada); `oxygens` de 5 min sin usar. IMU: `gesture`, `sportValue`, `sleepStates`, `sleepStatusQuantity` sin decodificar (depende de E6); `wear` sin significado. GPS: ruta y efemérides usados; sin fix/deriva documentados. Temperatura: valor y piel mostrados; nocturna (E9) aplazada. Respiración, apnea, carga cardiaca, ECG, presión: sin datos útiles, descartados. Mayor valor pendiente: sueño (cuando el usuario aporte noches).
**(b) Estudios 2020-2026.** No cambia nada con lo disponible; el cuello de botella es abrir los textos (45). Ninguna búsqueda nueva ha alterado las decisiones: HRV PPG = PRV, línea base ≥ 7, SpO₂ muñeca solo tendencia, glucosa excluida (FDA).
**(c) Funciones G Band.** Con sentido y bajo riesgo de salud: buscar pulsera (`findBand` existe en el SDK), cámara remota, notificaciones (permiso especial de acceso a notificaciones), alarmas, sedentarismo, medición rápida (E7). Todas escriben en la pulsera o dependen del SO y **no se pueden verificar sin móvil desbloqueado**: v1.1. Sin sentido: ECG, presión, glucosa, puntuaciones.
**(d) Deuda técnica.** Tests JVM de Kotlin (39/44); `lastError` (40); `reload()` y batería sin medir (23); reconexión automática (18); sin `maxSdkVersion` (22); integridad de efemérides mínima (26).
**(e) Accesibilidad y privacidad.** Semantics ampliados pero sin probar; 200 % de texto, contraste y TalkBack sin verificar; hay alturas fijas y etiquetas de 10 px; encabezado «Experimental» < 48 dp. Parte es comprobable por tests de widget a `textScale` 2.0 y por cálculo de contraste (52, 53). Privacidad: copia de seguridad desactivada y MAC enmascarada (hecho, no verificado en el móvil); falta exportar/borrar datos (50) y confirmar que los volcados de depuración no salen en release (51).
**(g) Documentación.** README, ARQUITECTURA, MANUAL, GLOSARIO y BASES_CIENTIFICAS no existen (49).

## 4. Definición de «terminada» (v1.0)
Una versión 1.0 es aceptable cuando se cumplen TODAS:
1. Compila en release sin avisos; analyze limpio; tests verdes, incluidos tests JVM de `JsonStore`, `Agps.looksValid` y la lógica de `BandClient` (44).
2. Sincroniza, muestra Hoy/Actividad/Sueño/Dispositivo y se ha visto en pantalla por el usuario o QA con el móvil desbloqueado (guion §5, sin esto ningún análisis nuevo se declara «verificado»).
3. Cada cifra tiene método, fuente o rótulo «aprox./propio», límite escrito y cobertura (hecho en código, a verificar).
4. Sueño: duración real (si la pulsera la entrega) o texto honesto «sin datos de sueño» (decisión E6 tras 2 noches).
5. Sin alertas clínicas, sin glucosa por defecto, sin puntuaciones.
6. Privacidad: borrar todos los datos y exportar; sin copias de seguridad; sin datos en log de release.
7. Accesibilidad: textScale 2.0 sin desbordes (test), contraste medido, TalkBack probado en las 4 pantallas.
8. Efemérides con la app cerrada confirmadas y una caída de conexión recuperada.
9. Documentación v1.0 completa con sus salvedades y textos científicos abiertos a texto completo o marcados.
**Queda para v1.1+:** alarmas, sedentarismo, buscar pulsera, cámara remota, notificaciones, medición rápida pública (según E7), SpO₂ nocturna (E8), temperatura nocturna (E9), PPG crudo (E11), tema claro revisado, esferas/clima/música, iOS.
Nuevos puntos al backlog: 42–53.

## 5. Guion para el usuario (lo único que solo tú puedes hacer)
**Preparación:** desbloquea el móvil y desactiva el bloqueo de pantalla por unos minutos; instala el APK de depuración; cierra G Band (una sola app por BLE).
1. **Capturas:** abre Vigor, sincroniza, captura Hoy, un detalle (Pulso), Actividad (tarjeta semanal) y Dispositivo. Revisa que no aparezca nada raro (cifras en 0, textos cortados) y apunta lo que veas; no compartas capturas con datos personales.
2. **Sueño (2 noches):** duerme con la pulsera puesta y apretada. Por la mañana, antes de abrir Vigor: abre G Band, sincroniza y apunta a mano hora de acostarte y de levantarte, duración total y minutos profundo/ligero/despierto. Cierra G Band, abre Vigor, sincroniza, entra en Dispositivo → Avanzado → volcado de sueño. Repite una segunda noche. Entrega solo las notas (no los ficheros del volcado) al desarrollador.
3. **Grabar sin móvil:** inicia una actividad desde Vigor, desconecta el Bluetooth del móvil, camina 15 min, reconecta y sincroniza; apunta si la sesión aparece y con qué duración/distancia.
4. **Distancia conocida (E5):** camina un tramo medido (p. ej. 400 m) con la pulsera grabando; compara distancia, ritmo y cadencia con G Band y cuenta 100 pasos a mano.
5. **Efemérides con la app cerrada:** cierra la app (no solo minimizar), deja el móvil con red y la pulsera a mano 24 h; luego mira Dispositivo → Efemérides GPS → «Último envío».
6. **Caída de conexión:** durante una sincronización, aleja la pulsera o apaga el Bluetooth 10 s; comprueba que Vigor avisa y se recupera.
7. **TalkBack:** actívalo (Ajustes → Accesibilidad); en cada pantalla desliza a la derecha y anota si cada cifra se lee con su unidad y su «aprox.», si hay elementos sin nombre o si el orden es confuso.
8. **Texto 200 %:** Ajustes → Pantalla → tamaño de fuente al máximo; anota cortes o solapes por pantalla.
9. **Sondeo E7 (opcional):** con la pulsera en reposo, pulsa cada botón de Avanzado una vez y apunta cuáles responden.
Al acabar: restaura el bloqueo y desactiva «Depuración USB (ajustes de seguridad)».

## 6. Qué se hará en la ronda 4 (sin móvil desbloqueado y sin el usuario)
Solo cosas verificables por tests, analyze o logcat:
1. **Tests JVM de Kotlin** (44): `JsonStore` (corrupción, E/S, retención con reloj adelantado), `Agps.looksValid`, lógica de `BandClient` extraíble (headless, latch, interrupción).
2. **Test de ficheros reales anonimizados** que confirmen los supuestos de `ppgs`/`hrv`/`sportTime` (43), o un log de ventanas por `VIGORLOG` si la pulsera sincroniza sola.
3. **Accesibilidad estática** (52): tests de widget con `textScale` 2.0 y búsqueda de etiquetas/Semantics; arreglar alturas fijas y el encabezado < 48 dp. **Contraste por script** (53) y corregir la paleta si no llega a AA.
4. **Exportar y borrar datos** (50, versión mínima, probada por test) y `maxSdkVersion` (22/51); `lastError` (40).
5. **Documentación v1.0** (49): README, ARQUITECTURA, MANUAL, GLOSARIO, BASES_CIENTIFICAS, con las salvedades «no verificado».
6. **Supervisor:** abrir los textos científicos por otra vía si se consigue (45); si no, mantener los rótulos.
7. **No se recomienda** en esta ronda: alarmas, recordatorios, sedentarismo, notificaciones, cámara remota, E8, E9, E11 (no se pueden probar sin pantalla y pulsera). Tampoco quitar las herramientas E6/E7 hasta que el usuario haga el guion.
