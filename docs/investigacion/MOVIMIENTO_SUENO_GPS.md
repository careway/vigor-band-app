# Investigación: movimiento, sueño y GPS (pulsera Valdus VIGOR / SDK Veepoo)

Fecha: 2026-11-20. Rol: investigador de movimiento. Reglas: `docs/equipo/EQUIPO.md`. Todos los enlaces de este documento aparecieron en búsquedas realizadas en esta sesión. **Importante sobre el nivel de lectura:** las búsquedas devuelven resúmenes/fragmentos; **no abrí los textos completos**. En cada tema se indica "visto solo en resumen/fragmento". Ninguna cifra de este documento procede de memoria; las que no están respaldadas se marcan como no verificadas. No hay coordenadas ni datos personales.

## 1. Resumen

- La pulsera entrega mucho más de lo que usamos. Hoy la app usa: pasos, kcal, km (suma de 5 min), MET, y de las sesiones deportivas: duración, distancia, pasos, FC media, ritmo medio, ruta y FC por minuto. **Tiramos**: `sleepStates`, `sleepStatusQuantity`, `gesture`, `sportStatus`, `sportValue`, `wear`, cadencia, velocidad/ritmo máx., `signalArray`, `sportStateArray` (pausas) y la distinción de modos deportivos (`sportType`).
- Datos reales vistos en esta pulsera: pasos, calorías, `sportValue`, MET, gesture (valores 61–74, significado no documentado), rutas GPS con huecos, cadencia de sesión. **Vacíos (0)**: altitud, desnivel (coherente: la pulsera no tiene barómetro), `sportStatus`, `calcType`, `wear` casi siempre 0 (1 de 89 registros, no fiable).
- Sueño: `sleep.json` está vacío (la pulsera no ha devuelto noches). Las filas de `origin5` de la madrugada traen `sleepStates` (6 bytes por registro de 5 min) y `sleepStatusQuantity` con contenido, pero **su codificación no está documentada con claridad** (ver tabla). No se debe implementar sueño por fases con eso hasta decodificarlo.
- La evidencia respalda: pasos con cautela (válidos en laboratorio, peor en vida libre), distancia GPS con ±1 % aprox. y suavizado conservador, sueño: **tiempo total y despertar/dormido sí con reservas; fases solo como orientativas**; carga por TRIMP (Edwards) como índice personal y **sin ACWR** (muy controvertido); VO2max estimado **solo experimental**; guías OMS 2020 para minutos de actividad.

## 2. Tabla de auditoría

Leyenda "¿datos reales?": lo observado en el JSON del móvil (89 registros de 5 min, 4 sesiones de las cuales 3 reales).

| Señal / campo | Qué aporta | ¿Lo recibimos? | ¿Lo usamos hoy? | ¿Datos reales no 0/255? |
|---|---|---|---|---|
| `stepValue` (5 min) y `allStep` (half) | Pasos | Sí | Sí (suma diaria, gráfico 5 min) | Sí (40 valores distintos) |
| `calValue`, `disValue` | kcal y km por 5 min | Sí | Sí (suma) | Sí; unidad kcal no verificada (ESTADO.md) |
| `sportValue` (0–65535, 5 niveles por umbrales del SDK) | Intensidad de movimiento | Sí | No | Sí (45 valores distintos) |
| `gesture` (IntArray) | Postura/gesto de muñeca (sin definición en el SDK) | Sí | No | Valores 61–74; **significado desconocido** |
| `wear` | Detección de uso | Sí | No | Casi siempre 0: no fiable |
| `met` (float) | Equivalente metabólico | Sí | Sí (gráfico, rotulado "del fabricante") | Sí (0,9 a >4) |
| `sleepStates` (6 elementos por 5 min) | "Estado de sueño por 5 min" | Sí | No | En 3 registros de la madrugada hay valores (p. ej. 144, 208, 136...) y 24 registros traen `0,0,0,0,0,255`; formato **no documentado** |
| `sleepStatusQuantity` | Vector largo (≈55 bytes) de sueño preciso | Sí | No | Contiene valores variables; formato no verificado |
| Sueño agregado (`allSleepTime`, `deepSleepTime`, `sleepLine`...) | Noche resumida; con PPG activado ("sueño preciso": 0 profundo, 1 ligero, 2 REM, 3 insomnio, 4 despierto por minuto) | Previsto | Pantalla Sueño lista | **No: `sleep.json` vacío** |
| `sportStatus`, `sportStatusVersion` | Estado deportivo del dispositivo | Sí | No | Todo 0 |
| Cabecera deportiva: `distance`, `sportDuration`, `stepCount`, `avgHeartRate/max/min`, `avgPace` | Resumen de sesión | Sí | Sí | Sí |
| `avgSpeed`, `maxSpeed`, `maxPace`, `minPace/minSpeed` | Velocidad/ritmo extremos | Sí | No | Sí en sesiones GPS (unidades por verificar: p. ej. 4483 y 5600 parecen centésimas de km/h, no confirmado) |
| `avgCadence`, `maxCadence`, `minCadence` | Cadencia (pasos/min) | Sí | No | Sí (una sesión: media 110, máx. 127); en la sesión de tipo 78 sin GPS aparece máx. 233 y media 16: **ruidosa** |
| `avgAltitude/max/min`, `cumulativeClimb/Decline` | Altitud/desnivel | Sí | No | **Todo 0** (sin barómetro) |
| `pauseCount`, `pauseTime`, `sportStateArray` | Pausas dentro de la sesión | Sí | No | Sí |
| `latArray/lngArray` (12 puntos/min), `signalArray` | Ruta y calidad de fix | Sí | Ruta sí; `signalArray` no | Parcial: en las 2 sesiones con ruta, ~29 % y ~58 % de los puntos tienen fix (signal=2); el resto son 0 |
| `sportType` / `a7ProtectSportType` | Tipo de deporte | Sí | No se distingue | Sí (5 y 78; significado de los códigos no verificado en esta auditoría) |
| `calories` (cabecera) | kcal de sesión | Sí | Sí (/1000) | Sí; coherencia por verificar |
| 'QX17 Data Acquisition' (IMU 100 Hz, GPS 1 Hz, HR en tiempo real) | Crudo de IMU/GPS | Existe en el SDK desde 1.2.9 (según historial de cambios) | No | No probado; nota: la tabla de versiones es lo único que leí; **no verifiqué que esta pulsera lo soporte** |
| Efemérides GPS (SDK 1.3.8) | Acelera el primer fix | Sí | Sí (descarga y envío) | Verificado en ESTADO.md |
| Sedentarismo, fatiga, MET, caída (`FALL_DETECTION`) | Funciones de dispositivo (activar/leer) | Función aparece en el SDK | No | No probado |

## 3. Evidencia por tema

### 3.1 Pasos y distancia en pulseras de muñeca
- Revisión sistemática (JMIR 2022) de exactitud y aceptabilidad de rastreadores de muñeca: la heterogeneidad impidió un metaanálisis; la investigación va por detrás del mercado. Fuerza: revisión sistemática; visto solo en resumen/fragmento. [PubMed 35060915](https://pubmed.ncbi.nlm.nih.gov/35060915/)
- Revisiones sobre Garmin/Fitbit: pasos "buenos" en general, distancia con menos estudios y errores en ambos sentidos; Fitbit tiende a infraestimar en laboratorio y sobrestimar en vida libre (según el resumen de búsqueda; no abrí los textos). Enlaces vistos: [PMC8817215](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8817215/), [PMC7323940](https://pmc.ncbi.nlm.nih.gov/articles/PMC7323940).
- Declaración INTERLIVE (2021) propone protocolos de validación (fragmento). Útil para probar nuestra pulsera: contar 100 pasos a mano en varias velocidades.
- **Límite:** ningún estudio localizado valida la pulsera VIGOR/JieLi. Hay que hacer validación propia (caminata de 100 y 500 pasos, a paso lento y rápido).

### 3.2 Estadificación del sueño con acelerómetro + PPG
- Birrer et al., *npj Digital Medicine* 2024, revisión: los dispositivos solo con acelerómetro sirven para sueño/vigilia pero no para varias fases; añadir PPG mejora. Solo el 11 % de los estudios evaluaron también a personas con trastornos del sueño. Visto en resumen. [artículo](https://www.nature.com/articles/s41746-024-01016-9.pdf)
- Chinoy et al., *Sleep* 2021 (34 adultos jóvenes sanos, 3 noches, siete dispositivos frente a PSG): sensibilidad sueño/vigilia ≥ 0,93, **especificidad 0,18–0,54** (detectan mal la vigilia), y los seis dispositivos sobrestimaron el sueño ligero. Fuerza: validación frente a PSG en muestra pequeña. Visto en resumen de búsqueda. [PMC8120339](https://pmc.ncbi.nlm.nih.gov/articles/PMC8120339)
- Schyvens et al., JMIR mHealth 2024 (revisión PRISMA de Fitbit Charge 4, Garmin Vivosmart 4, WHOOP): los de mayor concordancia (Fitbit, WHOOP) son razonables para estimar parámetros de sueño. Resumen. [enlace](https://mhealth.jmir.org/2024/1/e52192/)
- Revisión de 2016: los rastreadores de consumo tienden a infraestimar las interrupciones y sobrestimar el tiempo total y la eficiencia. [PubMed 27043070](https://pubmed.ncbi.nlm.nih.gov/27043070/)
- Hay dos preprints de 2026 en preprints.org que no leí (no se usan).
- **Conclusión:** tiempo total y hora de dormir/despertar son lo más fiable; latencia y WASO tienden a ser sesgadas (vigilia poco detectada); las fases son orientativas. No existe validación de este algoritmo de Veepoo frente a PSG (no encontrada).
- **Duración recomendada:** consenso AASM/SRS 2015 (panel de 15 expertos, método RAND modificado): adultos ≥ 7 h regulares; sin límite superior establecido; la necesidad individual varía. Visto en resumen. [PMC4434546](https://pmc.ncbi.nlm.nih.gov/articles/PMC4434546/), [AASM](https://aasm.org/aasm-and-srs-publish-new-sleep-duration-consensus-statement/). No comprobé si se ha actualizado.

### 3.3 GPS de muñeca, filtrado, constelaciones y AGPS
- Fuentes de divulgación/pruebas de aficionados: error de posición típico ±2–3 m a cielo abierto, sesgo de distancia del orden de +0,65 a +1 % y atajo en curvas (efecto de "cuerda") [the5krunner](https://the5krunner.com/gps-accuracy/), [Triathlete](https://www.triathlete.com/gear/tech-wearables/why-your-gps-lies/?scope=anon). Fuerza: **no revisadas por pares**; cifra orientativa.
- Estudio transversal de 2022 en rastreadores multideporte: diferencias de distancia sin relevancia práctica. Visto solo en fragmento. [MDPI Sensors 22(1):180](https://www.mdpi.com/1424-8220/22/1/180)
- No encontré ninguna fuente que documente o mida un filtro de Kalman en relojes comerciales. El compromiso suavizado/respuesta en giros sí aparece descrito en [Sports Performance Bulletin](https://sportsperformancebulletin.com/training/gps-technology-is-your-watch-lying-to-you) (divulgación).
- AGPS: la asistencia por efemérides acorta el tiempo hasta el primer fix (arranque en frío vs. caliente; sin asistencia puede tardar del orden de 36 s en L1 C/A según una fuente), pero **no mejora la precisión una vez fijado**. Multi-constelación: ventaja citada en entornos urbanos; sin cifras en relojes. Fuentes técnicas/fabricante: [Wikipedia TTFF](https://en.wikipedia.org/wiki/Time_to_first_fix), [u-blox AssistNow](https://www.u-blox.com/en/technologies/agnss-assistnow).
- **Dato propio:** en dos rutas reales el 29 % y el 58 % de los puntos tienen fix. Un solo dato de "distancia" incluye por tanto tramos sin fix; hay que tratar los 0 como huecos (ya lo hace el código) y no interpolar.

### 3.4 Altitud/desnivel sin barómetro
- Comparación de dispositivos (Chile, 202 esfuerzos, 2020): GPS sin barómetro infraestima el desnivel, el barómetro lo sobrestima; post-procesar con información secundaria reduce el error de ≈ −5 % a ≈ −1 %. Otro estudio de 2023 en carrera cuesta arriba: la mayoría infraestima (−3,8 % media), mejores los que llevan barómetro. Vistos en resumen. [enlace Chile](https://investigadores.anid.cl//en/public_search/work?id=629227), [springer 2023](https://rd.springer.com/content/pdf/10.1007%2Fs12283-023-00443-3.pdf)
- Una guía indica que la precisión vertical del GPS es mucho peor que la horizontal (valores ±100 m citados en un documento de carrera) [Fjällmaraton](https://stag3.fjallmaraton.se/wp-content/uploads/2021/09/fjm_elevation_gain_explained_ENG_v1.pdf), no revisado por pares.
- **Conclusión:** sin barómetro y con altitud 0 de la pulsera, descartar desnivel. Un modelo digital de elevación (DEM) por coordenadas requeriría enviar coordenadas a un servicio externo: choca con la regla de privacidad; no lo recomiendo salvo cálculo local con datos descargados.

### 3.5 Carga de entrenamiento, ACWR, zonas, VO2max, recuperación
- TRIMP de Edwards y zonas Tanaka ya documentados en `ANALISIS.md` (no repito enlaces).
- ACWR: controvertido. Acoplamiento matemático entre numerador y denominador, correlación negativa con la carga crónica (r = −0,50 según una de las fuentes), el "punto óptimo" criticado, y los propios autores matizaron el uso de "predecir". Fuerza: críticas metodológicas y revisiones con resultados mixtos. Vistos en resumen. [Lolli 2018 (PDF)](https://unleash.catapult.com/wp-content/uploads/research//Football%20(Soccer)/Lolli%20(2018)%20The%20acute-to-chronic%20workload%20ratio%20an%20inaccurate%20scaling%20index%20for%20an%20unnecessary%20normalisation%20process.pdf), [Sports Med 2020](https://link.springer.com/article/10.1007%2Fs40279-020-01280-1), [PMC7534938](https://pmc.ncbi.nlm.nih.gov/articles/PMC7534938). **No implementar ACWR ni umbrales de riesgo de lesión.** Sí se puede mostrar carga semanal absoluta y su tendencia.
- VO2max con FC y velocidad: no encontré revisión sistemática con cifras agrupadas. Hay estudios aislados (Apple Watch, PLOS ONE 2025, infraestima en muestra muy en forma, error medio absoluto ≈ 13 % según un resumen secundario con discrepancia en el tamaño de muestra) y el método de Firstbeat (FC + velocidad) con afirmación del fabricante de 95 % de exactitud (no independiente). Una fuente señala que si la FCmáx está subestimada 15 lpm el error es ≈ 9 %. Fuentes de calidad baja (blogs, vendedores): [PNOĒ](https://pnoe.com/blog/vo2-max/wearable-vo2-max-accuracy/), [AFY](https://afasteryou.com/blog/en/watch-vo2max-accuracy/). **Veredicto: no hay base sólida; solo "experimental", o descartar.**
- Recuperación: no busqué evidencia específica de recuperación más allá del HRV (ver informe cardio). Laguna.

### 3.6 Reconocimiento automático de actividad con IMU
- Revisiones: Wang et al. (reconocimiento de actividad con aprendizaje profundo), Nweke 2018, Gao 2021 (acelerómetro de muñeca: no hay consenso sobre buenas prácticas), y un dato de una encuesta de 2024 (caída detectada en reloj de muñeca con aprendizaje profundo: ≈ 86 % exactitud en un estudio previo). Vistos en resumen. [arXiv 1707.03502](https://arxiv.org/pdf/1707.03502v2.pdf), [PMC8706489](https://pmc.ncbi.nlm.nih.gov/articles/PMC8706489), [arXiv 2404.15349](https://arxiv.org/html/2404.15349v1).
- **Conclusión:** exige datos crudos (100 Hz, QX17) y entrenamiento propio; sin validación en esta pulsera; no es prioridad.

### 3.7 Actividad física y salud
- OMS 2020 (Bull et al., *BJSM*): adultos 150–300 min/semana moderada, o 75–150 vigorosa, o equivalente; fortalecimiento muscular; reducir sedentarismo sin umbral cuantificado. [PMC7719906](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/) (guía; vista en resumen).
- Pasos: metaanálisis de 15 cohortes (Paluch 2022, *Lancet Public Health*): menor mortalidad con más pasos y meseta distinta según edad (≈ 6000–8000 mayores, 8000–10 000 jóvenes según nota de prensa). Observacional. Una cifra de un medio (3500 pasos) no la pude confirmar. [DOAJ](https://doaj.org/article/c3639c468b4348958202e52793ab979d), [UCL PDF](https://discovery.ucl.ac.uk/id/eprint/10170017/1/1-s2.0-S2468266721003029-main.pdf).

## 4. Recomendaciones priorizadas

| # | Señal | Decisión | Cómo | Texto de limitación |
|---|---|---|---|---|
| 1 | Minutos de actividad (OMS) | **Implementar (nuevo)** | Minutos con FC ≥ 64 % FCmáx (zona 2 en adelante) o MET ≥ 3 (MET del fabricante, validar) sumados por semana; barra frente a 150 min. Preferir FC, que ya tenemos | "Estimación con tu pulsera; la guía OMS 2020 se basa en cuestionarios y acelerometría. No es un diagnóstico" |
| 2 | Cabecera deportiva ampliada | **Implementar (mejora)** | Mostrar velocidad/ritmo máx., cadencia media/máx., pausas (`pauseTime`) y tiempo en movimiento vs. total. Convertir unidades **tras verificar** con una carrera de distancia conocida | "Cadencia y velocidad máxima son del fabricante; la cadencia máxima puede ser ruidosa" (se vio 233 en sesión sin GPS) |
| 3 | Ruta GPS | **Implementar (mejora)** | Descartar puntos sin fix (ya), marcar `signalArray`, y calcular distancia propia con Haversine solo entre puntos con fix consecutivos; suavizado ligero (media móvil o filtro que no corte esquinas). Comparar con `distance` de la pulsera | "La distancia puede variar ±1–2 %; los tramos sin señal se omiten" (1 % es cifra de divulgación) |
| 4 | Sueño con `sleepStates`/`sleepStatusQuantity` | **Primero decodificar; luego experimental** | Dormir con la pulsera 2 noches, comparar con la lectura en G Band; no inventar la codificación. Mostrar solo tiempo total, hora de acostarse y de levantarse; fases como "orientativas"; objetivo ≥ 7 h (AASM/SRS) | "Las fases son estimaciones sin validación frente a polisomnografía; no es diagnóstico" |
| 5 | Pasos | **Mantener; validar** | Calibración manual de 100 pasos; objetivo diario del usuario; mostrar tendencia 7 días, no "10 000" fijo | "Los contadores de muñeca difieren entre marcas; el recuento puede variar" |
| 6 | Carga | **Mantener TRIMP (Edwards)**; **descartar ACWR** | Carga semanal y tendencia personal | "Índice personal, no predice lesiones" |
| 7 | `sportValue` | **Experimental** | Nivel (5 umbrales del SDK) como intensidad de movimiento horaria; no hay validación externa | "Valor del fabricante, sin validar" |
| 8 | `gesture`, `sportStatus`, `wear` | **Descartar de momento** | Sin definición ni datos útiles (gesture sin significado; sportStatus 0; wear casi 0) | — |
| 9 | Altitud, desnivel | **Descartar** | Sin barómetro; valores 0 | Ocultar o rotular "no disponible" |
| 10 | VO2max | **Experimental o descartar** | Solo si hay carreras con FC y GPS; rotular con rango amplio | "Estimación sin validación en esta pulsera; error posible > 10 %" |
| 11 | Datos crudos QX17 (IMU/GPS) | **Descartar por ahora** | Requeriría validar soporte y entrenar modelos; ver 3.6 | — |
| 12 | Sedentarismo (recordatorio) | **Evaluar** | Función del SDK; la OMS recomienda reducirlo pero sin umbral cuantificado | Sin umbral clínico |

Lo existente que mejoraría: #2, #3, #5. Lo nuevo: #1, #4, #7.

## 5. No verificado / lagunas

- Formato de `sleepStates` (6 bytes) y `sleepStatusQuantity`: sin decodificar; sueño nocturno real sin probar.
- Unidades de `avgSpeed/maxSpeed/avgPace/maxPace` y escala de `calories` de cabecera (en una sesión 284 475 → ¿cal?); significado de los códigos `sportType` y de `gesture`.
- Soporte real de esta pulsera para QX17, MET, fatiga, sedentarismo y detección de caída: solo leí la lista de cambios y las funciones del SDK, no probé.
- Constelaciones GNSS del CC1165: no documentado; no hay cifras de precisión de esta pulsera.
- Validación de pasos y del algoritmo de sueño de Veepoo/JieLi: no existe en lo encontrado.
- Evidencia de recuperación (más allá de HRV) y de zonas de FC individualizadas no investigada aquí.
- Todos los estudios se vieron como resumen/fragmento de búsqueda; las cifras deben contrastarse con los textos completos antes de ponerlas en `BASES_CIENTIFICAS.md`. Los datos de GPS y VO2max proceden en parte de sitios divulgativos/comerciales (marcados).
- Los preprints 2026 de sueño aparecieron en resultados y no se leyeron.
