# Análisis de datos: método y fuentes

Cada cálculo de la app se apoya en una fuente que **se consultó** (búsqueda del 2026‑11‑20; revisión del Supervisor en la ronda 2, misma fecha, que abrió de nuevo FDA, Shaffer & Ginsberg y Yeh et al. y comprobó por búsqueda Paluch, OMS y Chinoy; las correcciones están marcadas «corregido en ronda 2»). Si una fuente no se pudo verificar, se dice. Donde no hay fuente, el cálculo es una heurística propia y la app lo rotula "aprox.".

## 1. Frecuencia cardiaca máxima y zonas
- **Fórmula:** FCmáx = 208 − 0,7 × edad (Tanaka, Monahan & Seals, *J Am Coll Cardiol* 2001; metaanálisis de 351 estudios, 18 712 sujetos, r = −0,90; sin diferencia por sexo ni nivel de actividad). [PubMed](https://pubmed.ncbi.nlm.nih.gov/11153730/)
- **Límite declarado:** error típico ≈ 10 bpm por persona ([validación PMC3935487](https://pmc.ncbi.nlm.nih.gov/articles/PMC3935487)); en niños y adolescentes subestima ≈ 2,7 bpm ([metaanálisis](https://informahealthcare.com/doi/epub/10.1080/02701367.2019.1615605)).
- **Uso en la app:** zonas por % de FCmáx (50–60, 60–70, 70–80, 80–90, 90–100). La edad la introduce el usuario (Perfil). La app muestra "FCmáx estimada ± 10".

## 2. Carga de entrenamiento (TRIMP de Edwards)
- **Método:** suma de (minutos en cada zona × número de zona 1–5). Se prefiere sobre el TRIMP de Banister porque este no distingue ejercicio de reposo y tuvo mala fiabilidad test‑retest (CV 15,6 %), mientras que Edwards correlacionó mejor con el esfuerzo percibido en squash (r = 0,79 vs 0,68). [Impellizzeri et al.](https://www.bisp-surf.de/Record/PU201411010171), [estudio de squash](https://www.jssm.org/jssm-20-101.xml-Fulltext)
- **Límite:** no se encontró una validación independiente de las zonas de Edwards por sí solas; se presenta como **índice relativo personal**, no como valor absoluto.
- **Uso:** por sesión con pulso (cada punto de actividad trae `rate`).

## 3. Variabilidad cardiaca (HRV)
- **Métrica:** RMSSD (ms), raíz cuadrática media de diferencias sucesivas entre intervalos RR. definición literal en [Shaffer & Ginsberg 2017, *Front Public Health* 5:258](https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/) (leído en ronda 2: «raíz cuadrada de la media de los cuadrados de las diferencias sucesivas entre latidos normales»)
- **Advertencia de la fuente (leída):** los valores de 24 h, corto plazo y ultracorto «no son intercambiables» y no deben sustituirse entre sí.
- **RMSSD con PPG (variabilidad del pulso, PRV):** la definición vale para intervalos entre latidos del ECG. Con PPG de muñeca se mide la variabilidad del pulso, que en un estudio de 931 adultos dio un RMSSD menor que el del ECG (37,49 frente a 43,14 ms; Kantrowitz et al., *Front Physiol* 2025, [PMC12343505](https://pmc.ncbi.nlm.nih.gov/articles/PMC12343505/), leído en la investigación cardio; 4 autores de la empresa del dispositivo). Por eso la app la llama «variabilidad del pulso (PPG), aprox.». No hay estudio de esta pulsera.
- **Decisión:** **no se compara con valores "normales" poblacionales.** Solo se muestra la **tendencia contra la línea base personal** del propio usuario (mediana de sus últimos 14 días). El SDK no documenta la ventana de medida de la pulsera, así que se rotula "aprox.".

## 4. Pasos diarios
- **Evidencia:** en 15 cohortes (47 471 adultos) el riesgo de mortalidad por todas las causas baja al subir los pasos y se estabiliza: ≈ 6 000–8 000 pasos/día en ≥ 60 años y ≈ 8 000–10 000 en < 60. No hubo asociación independiente con la cadencia. [Paluch et al., *Lancet Public Health* 2022](https://doi.org/10.1016/S2468-2667(21)00302-9)
- **Verificado en ronda 2 (resumen de búsqueda, no el texto completo; la página del editor y el PDF no se pudieron leer):** 15 cohortes, 47 471 adultos, 3 013 muertes; medianas de pasos por cuartil 3 553 / 5 801 / 7 842 / 10 901; cociente de riesgo ajustado frente al cuartil más bajo 0,60 (IC 95 % 0,51–0,71) en el 2.º y 0,55 (0,49–0,62) en el 3.º; el valor del 4.º cuartil no se vio y no se cita. Meseta: 6 000–8 000 pasos/día en ≥ 60 años y 8 000–10 000 en < 60. Estudio observacional.
- **No verificado (corregido en ronda 2):** la frase anterior «no hubo asociación independiente con la cadencia» no se pudo comprobar en esta ronda; se retira hasta leer el artículo.
- **Uso:** meta por defecto 8 000 pasos (editable); la app no promete beneficios, solo muestra el avance.

## 5. Sueño
- **Corregido en ronda 2:** el enlace anterior (PMC8343587) no correspondía a este artículo; el correcto es Chinoy et al., *Sleep* 2021;44(5), doi 10.1093/sleep/zsaa291, PMC8120339 (identificado por búsqueda; el texto completo no se pudo abrir: cifras tomadas del resumen).
- **Evidencia:** en 34 adultos jóvenes comparados con polisomnografía, siete dispositivos de consumo detectan **sueño** con sensibilidad > 0,93 pero con especificidad baja (0,18–0,54) y **sobreestiman el sueño ligero**; la clasificación por fases es inconsistente y peor en noches alteradas. [Chinoy et al., *Sleep* 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8120339)
- **Decisión:** la app muestra **duración total y despertares** como dato principal. Las fases (profundo/ligero) se muestran pequeñas y rotuladas "aprox."; no se calcula ninguna "puntuación de sueño" propia.

## 6. Oxígeno en sangre (SpO₂)
- **Evidencia:** en muñeca la señal es más débil (menor perfusión, más dispersión); el listón regulatorio de referencia es ARMS ≤ 3,5 % (guía FDA 2013); un oxímetro de muñeca validado midió 2,4 %. La piel oscura puede afectar más a sensores reflectivos y la validación clínica en muñeca es escasa. [Frontiers Digital Health 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10726006)
- **Decisión:** el valor se muestra como **tendencia**, con el aviso "no sustituye a un oxímetro médico". La app **no emite alertas clínicas**.

## 7. Calorías, distancia y ritmo
- Los calcula la pulsera (algoritmo del fabricante, no documentado en el SDK). La app los muestra tal cual y no los recalcula.

## 8. Ruta GPS
- La ruta viene de `latArray` / `lngArray` de la pulsera (grados decimales, 12 muestras por minuto, una cada 5 s); `signalArray = 0` y posición (0,0) significan **sin fix**.
- **Verificado con datos reales (3 sesiones):** la velocidad implícita entre puntos consecutivos con fix nunca superó 4,6 m/s, así que no hay saltos que filtrar por velocidad. El único artefacto era unir con una recta el último punto antes de perder la señal con el primero tras recuperarla; por eso la app **corta la ruta en los tramos sin fix** y no los une.
- No se aplica ningún suavizado. En una sesión sin movimiento (0 m según la pulsera, interior) el GPS acumuló ≈ 400 m de deriva: la distancia de la pulsera es la que se muestra como principal, y la del GPS solo como comprobación.

## 9. Temperatura (cuerpo y piel)
- La pulsera entrega dos valores por lectura: `temperature` (la app oficial lo llama "temp. corporal") y `baseTemperature` ("temp. de la piel").
- **Evidencia:** el dispositivo de muñeca HEARThermo (sensor infrarrojo; Yeh et al., *JMIR mHealth uHealth* 2021; 66 participantes asiáticos de 10–77 años; 152 881 datos) tuvo un sesgo de 1,51 °C (IC 95 % 1,50–1,51) y límites de acuerdo de −1,34 a +4,35 °C frente a un **termómetro infrarrojo de piel** (no frente a temperatura central). La ICC de 0,96–0,98 es de repetibilidad **en laboratorio** (baño de agua); la validez frente al termómetro de piel fue 0,72 con 20–27,9 °C de ambiente y bajó a 0,45 con ≤ 19,9 °C y 0,49 con ≥ 28 °C. [PMC7904403](https://pmc.ncbi.nlm.nih.gov/articles/PMC7904403/) (leído en ronda 2). **Corregido en ronda 2:** antes se resumía como «fiable para cambios»; lo que se probó es repetibilidad en laboratorio y el desempeño en personas dependió de la temperatura ambiente. Es evidencia de otro dispositivo, no de esta pulsera.
- **Decisión:** se muestra el valor y, sobre todo, la **desviación frente a tu propia media** (cuando hay ≥ 3 días). Sin umbrales de fiebre.
- **No verificado:** no se encontró un estudio que valide la *desviación nocturna respecto a la línea base* en muñeca; no se afirma.

## 10. Estrés (índice 0–100 del fabricante)
- Campo `pressure` de los datos de 5 min. El SDK documenta el rango [0, 100] pero **no el algoritmo**.
- **Evidencia:** el pulso medio es peor indicador de estrés que la HRV, y los algoritmos de estrés por HRV en dispositivos de consumo siguen teniendo precisión y fiabilidad pobres. [Hickey et al. 2021, Sensors (PMC8156923)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8156923/)
- **Decisión:** se muestra como **tendencia relativa** ("más alto / más bajo que tu media"); **sin categorías** tipo "relajado / alto". No es una medida clínica.

## 11. MET
- **Definición (fuente secundaria; Wikipedia, no es una fuente primaria y debe sustituirse por el Compendio):** 1 MET ≈ 3,5 mL O₂·kg⁻¹·min⁻¹ ≈ 1 kcal·kg⁻¹·h⁻¹ (reposo sentado). El Compendio de Actividades Físicas clasifica la intensidad por MET pero **no está pensado para calcular calorías exactas**. [Metabolic equivalent of task](https://www.wikipedia.org/wiki/Metabolic_equivalent)
- **Cortes de intensidad (ronda 2, nivel resumen de búsqueda):** la guía de la OMS 2020 (Bull et al., *Br J Sports Med* 54:1451, [PMC7719906](https://pmc.ncbi.nlm.nih.gov/articles/7719906/)) define en escala absoluta moderada = 3 a < 6 MET y vigorosa = ≥ 6 MET (y en escala relativa 5–6 y 7–8 sobre 0–10). **Nivel de lectura: lo devolvió un resumen del buscador; las páginas completas (PMC, BJSM) no se pudieron abrir** (anti‑robot, 403). Se mantiene «no verificado con el texto completo».
- **Decisión:** la tesela de MET sigue mostrando el valor sin clasificar. La clasificación solo se usa en el cómputo de minutos de actividad semanales (`ESPECIFICACION_RONDA3.md` E4), rotulado «aprox.» porque el MET de la pulsera no está validado.

## 12. Glucosa y componentes sanguíneos (ácido úrico, colesterol, triglicéridos…)
- **Evidencia regulatoria (comunicación original leída en ronda 2):** la FDA (comunicado de seguridad, 21‑02‑2024) indica que no ha autorizado, aprobado ni cleared ningún reloj o anillo inteligente para medir la glucosa por sí solo sin pinchar la piel, que estos dispositivos «no miden directamente» la glucosa, que no deben comprarse ni usarse y que un valor erróneo puede llevar a errores de medicación (insulina u otros). [FDA](https://www.fda.gov/medical-devices/safety-communications/do-not-use-smartwatches-or-smart-rings-measure-blood-glucose-levels-fda-safety-communication)
- **Decisión:** se muestran **solo como "estimación experimental del fabricante"**, en una sección plegada con aviso permanente, en gris, **sin rangos, sin colores de riesgo y sin alertas** (aunque la pulsera envíe un campo de "nivel de riesgo", la app lo ignora). Lo mismo para los componentes sanguíneos, para los que no se encontró evidencia de validación en muñeca.

## 13. FC en reposo (actual)
- Se estima como la **media del 10 % más bajo** de las lecturas del día (mínimo 20 lecturas; mínimo 3 en el decil); heurística propia sin fuente validada. Se rotula "aprox.". **Implementada en la ronda 3 (DEV_002, E2):** cuando hay noche válida la tesela muestra la versión nocturna (§17.2); si no, este cálculo como respaldo «reposo aprox., todo el día».

## 14. Filtros de plausibilidad, línea base y RMSSD (documentación de H-07 / N15)
Ninguno de estos filtros tiene fuente científica: son decisiones propias para descartar ceros y valores imposibles del SDK. Se rotulan «aprox.» y la ronda 3 (E1) mostrará cuántas lecturas se descartan.
| Métrica | Filtro actual (`repo.dart`) | Fuente |
|---|---|---|
| Pulso (`ppgs`, sesiones `rate`) | 30–220 lpm | propia |
| SpO₂ (`oxygenValue`) | 70–100 % | propia (lo inferior se oculta; DEV_001 recorta al eje del gráfico) |
| Temperatura / piel | 30–43 °C / 15–43 °C | propia |
| Estrés | 1–100 | rango del SDK; el 0 se trata como «sin dato» |
| MET, glucosa | > 0 | propia |
- **Línea base (`baselineOf`):** mediana de hasta 14 medias diarias, mínimo 3 días con datos. Se aplica a todas las métricas con comparación «hoy ±x». Fuente: ninguna específica; para HRV la bibliografía consultada (Esco et al., *Sensors* 2025, leído parcialmente) pide ≥ 7 días, por lo que la ronda 3 exige ≥ 7 noches para HRV, pulso en reposo y las siguientes.
- **RMSSD antiguo (`rmssd()`; en la ronda 3 ya no se usa en pantalla, solo por sus tests; el diario usa el algoritmo robusto, §17.3):** descarta RR ≤ 0 o ≥ 2 500 ms, exige ≥ 5 intervalos válidos en el minuto, une los vecinos tras un descarte y no filtra latidos ectópicos. La versión nocturna robusta está especificada en la ronda 3 (E3).
- **Lecturas descartadas:** implementado en la ronda 3 (E1, §17.1): recuento por día y métrica bajo el gráfico. **Ajuste DEV_002:** los valores 0/255 cuentan como «sin dato», no como «fuera de rango».

## 15. Estado de la verificación en la ronda 2
| Afirmación | Resultado |
|---|---|
| Definición de RMSSD y no intercambiabilidad de ventanas | Verificada (Shaffer & Ginsberg leído) |
| FDA 2024, glucosa | Verificada (comunicación original leída) |
| Sesgo de temperatura de muñeca (1,51 °C) | Verificada, pero el resumen anterior era engañoso: corregido (§9) |
| Pasos Paluch 2022 | Verificada a nivel de resumen de búsqueda (§4); la afirmación de cadencia, retirada |
| Chinoy 2021 (sueño) | Corregido el identificador PMC; cifras a nivel de resumen |
| Cortes MET de la OMS | Encontrados a nivel de resumen; sin texto completo (§11) |
| Tanaka, TRIMP de Edwards, Hickey 2021, Frontiers Digital Health 2023 (SpO₂) | **No reabiertas en esta ronda**; se mantienen según la ronda 1 |

## 16. Pendiente de verificar (actualizado en la ronda 3, ver también §18)
- Texto completo de la guía OMS 2020 (cortes MET y minutos), de Paluch 2022 y de Chinoy 2021.
- Banda de FC del ACSM para intensidad moderada (se cree 64–76 % de FCmáx; **no verificado**, no se usa como dato científico).
- Significado de `wear`, `gesture`, la unidad de `hrvValue` y de `calValue` de 5 min.

## 17. Análisis implementados en la ronda 3 (DEV_002, E1–E5)
**Aviso de estado:** todo lo de esta sección está implementado en código y cubierto por 112 tests con datos sintéticos; **ninguno se ha visto en pantalla ni con la pulsera** (móvil bloqueado). Donde no hay fuente, se dice «propio, sin fuente».

### 17.1 Calidad y cobertura (E1)
- **Método:** por día y métrica: crudas, válidas, sin dato (0/255), descartadas por rango, posibles. Cobertura = válidas/posibles. Cada lectura de `ppgs` se asigna al día de su propia hora.
- **Posibles:** 1 440 (minuto) o 288 (5 min) por día pasado; para hoy, solo las transcurridas (decisión propia).
- **Filtros (todos propios, sin fuente):** pulso 30–220; SpO₂ 70–100; temperatura 30–43, piel 15–43; estrés 1–100; glucosa > 0.
- **Aviso:** punto «Pocos datos hoy» si hay datos y cobertura < 20 % (umbral propio, sin fuente).
- **Límite:** el supuesto de 1 lectura/min en `ppgs` no está verificado con la pulsera.

### 17.2 Pulso en reposo nocturno (E2)
- **Método:** mediana de las 30 lecturas válidas más bajas de la noche, con ≥ 60 lecturas; tendencia frente a la mediana de hasta 14 noches válidas anteriores, con ≥ 7.
- **Ventana:** 00:00–06:00 locales (aproximación propia; falla con turnos o siestas; las lecturas de un registro que empieza a las 23:xx pero cae tras medianoche se asignan al día siguiente).
- **Fuente:** ninguna valida este estimador (propio, sin fuente). Contexto: FC en reposo medida en ventanas cortas ([PubMed 24578692](https://pubmed.ncbi.nlm.nih.gov/24578692/), solo resumen) y precisión del PPG en reposo (Zhang et al. 2020, solo resumen del buscador, sin enlace reabierto: **no verificado**).
- **Límites:** no es puntuación de recuperación ni dato médico; la «noche» no es la de sueño real.

### 17.3 HRV nocturna robusta (E3) y RMSSD diario
- **Método por minuto:** RR 300–2000 ms; diferencias solo entre RR consecutivos válidos; se descarta el par con |Δ| > 20 % del RR anterior; minuto válido con ≥ 5 diferencias; RMSSD_min = raíz(media(Δ²)). Noche = mediana de minutos, con ≥ 30 min y ≥ 60 % de los minutos con registro; «calidad baja» si > 5 % de diferencias corregidas en la noche. Media semanal y CV como secundarios; línea base ≥ 7 noches.
- **Fuentes:** definición de RMSSD, Shaffer & Ginsberg 2017 (leída, [PMC5624990](https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/)). El 5 % de latidos corregidos y ≥ 7 días: Esco 2025 (leído parcialmente, no a texto completo). Los umbrales 300–2000 ms, 20 %, 30 min y 60 %: **propios, sin fuente**.
- **Cambio respecto al ajuste pedido:** el RMSSD diario ahora usa también este algoritmo (rotulado «todo el día, aprox.»); `rmssd()` antiguo solo en tests; con huecos (`null`) ya no se unen latidos vecinos.
- **Supuesto (corregido en la ronda 4, ver §20):** un registro de `hrv` = 1 por minuto de reloj, pero cada uno es una medición ultracorta de ~10 latidos (≈ 9 s), no un minuto continuo.
- **Límites:** PPG, no ECG; tiende a dar menos que el ECG (Kantrowitz 2025, [PMC12343505](https://pmc.ncbi.nlm.nih.gov/articles/PMC12343505/); cifras de la ronda 1: 931 adultos, 37,49 vs 43,14 ms; autores de la empresa del dispositivo; otro dispositivo). RR con resolución de ~10 ms. Sin comparación con normas poblacionales.

### 17.4 Minutos de actividad semanales (E4)
- **Método:** semana lunes–domingo. A: registros de 5 min con `met` ≥ 3 suman 5 min (corte OMS; MET del fabricante sin validar). B: minutos con pulso ≥ 70 % de la FCmáx (constante `kMvpaHrFraction`; **umbral propio, sin fuente**; usa la edad del perfil, 35 por defecto, lo que se indica en pantalla). Las dos cifras se muestran por separado; los vigorosos no se ponderan; sin «meta cumplida».
- **Datos ausentes:** días con < 70 % de registros se anotan «Faltan datos en k días» y no se cuentan como 0; los minutos de un día parcial sí se suman; los días futuros no cuentan.
- **Fuente:** OMS 2020, Bull et al., *Br J Sports Med* 54:1451 ([PMC7719906](https://pmc.ncbi.nlm.nih.gov/articles/PMC7719906/)). Ronda 3: una búsqueda devolvió la frase «150–300 min moderada, o 75–150 vigorosa, o combinación» y moderada = 3 a < 6 MET; **≥ 6 MET para vigorosa no se confirmó** en esta búsqueda (se había visto en la ronda 2). Todo a nivel de resumen; texto completo no abierto (el lector web bloquea PMC).
- **Límite:** la guía se basa en cuestionarios y acelerómetros, no en esta pulsera.

### 17.5 Sesiones (E5)
- Ritmo calculado = `sportTime`/(`distance`/1000) y velocidad media = `distance`/`sportTime`, rotuladas «calculada»; aviso si el ritmo calculado difiere > 5 % del de la pulsera (umbral propio). `sportTime` en segundos **sin constancia escrita de verificación**. `sportType` ya no se traduce a deporte. Campos no mostrados hasta verificar: velocidad, cadencia, pausas, `kcals`, `peisu`, fracción de `signalArray`.

### 17.6 Herramientas de depuración (E6, E7)
No son análisis. Volcado de sueño (decodificador de `sleepLine` modo normal verificado solo con el ejemplo del SDK) y sondeo de mediciones rápidas: solo en compilación de depuración, **sin ejecutar con la pulsera**.

### 17.7 Glucosa y componentes
Ocultos por defecto (interruptor «Mostrar métricas experimentales», con aviso FDA al activarlo; FDA, §12).

## 18. Verificación científica de la ronda 3 (2026-11-20)
| Afirmación | Nivel |
|---|---|
| OMS 2020: 150–300 min moderada / 75–150 vigorosa; moderada 3 a < 6 MET | Resumen de búsqueda (reconfirmado); texto completo **no abierto** |
| OMS 2020: vigorosa ≥ 6 MET | Visto en la ronda 2 a nivel de resumen; **no reconfirmado** hoy |
| Kantrowitz 2025, Esco 2025, Paluch 2022, Chinoy 2021, Tanaka, Hickey 2021, Frontiers 2023 | Sin cambios: **no se abrieron a texto completo**; el lector web no pudo acceder a PMC («no se pudo verificar el dominio») |
| FDA 2024, Shaffer & Ginsberg 2017, Yeh 2021 | Leídos a texto completo en la ronda 2 |
Acción pendiente: abrir PMC por otra vía (el usuario, o descarga manual) para el punto 36.

## 19. Ajustes de DEV_002 §6 aplicados
0/255 = sin dato (§14, §17.1); RMSSD diario robusto (§17.3); `kMvpaHrFraction` (§17.4); `Day.hr` por la hora de cada lectura (§17.1).

## 20. Ronda 4 (DEV_003, cierre v1.0; Supervisor, 2026-11-20)
**Aviso de estado:** 183 tests de Flutter y 27 JVM de Kotlin en verde, con datos sintéticos y con agregados de un solo móvil/pulsera (~2 días). **Nada se vio en pantalla** (móvil bloqueado desde la ronda 1/2). Lo que sigue refleja lo implementado según DEV_003, no lo observado por el Supervisor.

### 20.1 Línea base: ventana de 30 días y mínimo de 7 noches
Pulso en reposo y HRV nocturna comparan con las hasta 14 noches válidas más recientes **dentro de los 30 días naturales anteriores** a la noche (borde: −30 d entra, −31 no; `kBaselineWindowDays = 30`), con **mínimo 7**; con menos, «Aún sin línea base: k de 7». La ventana de 30 días y el 14 son **propios, sin fuente**; el mínimo de 7 viene de Esco 2025 (solo resumen, §17.3).

### 20.2 `rrValue` = 2550 ms es «sin dato»
En los datos reales, 1 348 de 5 050 RR (26,7 %) valen 2550; 130 registros enteros y 17 mixtos; el 100 % de los de una hora concreta. Se trata como ausencia de medición: **no forma par ni cuenta como corrección** (tampoco 0 ni no numérico) y un registro todo-centinela no cuenta como registro de la noche. Un RR numérico fuera de 300–2000 ms sí es ruido y sí cuenta. Sin fuente (observación empírica de un dispositivo); no se sabe si el valor es un código del firmware.

### 20.3 HRV = medición ultracorta
Cada registro `hrv` llega 1 por minuto y trae 10 RR (suma mediana ≈ 9,1 s en 358 registros completos). Es **~10 latidos una vez por minuto, no un minuto continuo**: el RMSSD por registro se calcula con ~9 diferencias (mínimo 5) y «30 minutos válidos» significa 30 mediciones. Es una ventana mucho más corta que las de referencia de Shaffer & Ginsberg (PMC5624990, leída); la app lo avisa en la tarjeta (`hrvSampleText`). No hay validación de este método ultracorto con esta pulsera: **sin fuente, aprox.** `rate` del registro es RR/10 (p. ej. 990 → 99), no bpm, y no se usa. `hrvValue` del fabricante existe y no se usa.

### 20.4 `sportTime` en segundos y `ppgs`
- `sportTime` = `stopTime − startTime − pauseTime` en 3 sesiones con cabecera completa (diferencias de 2–4 s): **segundos, verificado contra la cabecera**. `recordCount` de `sportItems` = 1 por minuto, de modo que el pulso por minuto es correcto. `calories` = 0 en las 4 sesiones reales (se muestra «—»).
- `ppgs`: 101 registros de `origin5`, todos con 5 valores, separados 5 min (99) o 10 min (1); **consistente con 1 lectura/min, no probado** (no hay marca de tiempo por lectura). Una persona, ~2 días.

### 20.5 Noche en curso
Si es hoy y < 06:00, la noche se rotula «Noche en curso: el dato puede cambiar hasta las 06:00 y no entra en la línea base» y sale del historial, gráfico y media semanal. Decisión de diseño propia.

### 20.6 Calidad y cobertura: cambios
SpO₂ y HRV (se miden por tandas) ya no activan «Pocos datos hoy» (que solo aplica a métricas continuas, y en días pasados dice «este día»). SpO₂ < 70 cuenta también las > 100. Tres estados en tesela: «Sin datos» / «Sin datos suficientes» / cifra.

### 20.7 Privacidad y datos del usuario
Todos los datos están en el almacenamiento privado de la app (`files/vigor`); la app no los envía a internet (solo descarga efemérides, sin datos del usuario). Copia de seguridad de Android desactivada y excluida; permisos de ubicación con `maxSdkVersion=30`. **Registro técnico (H5, corregido):** el registro técnico de la pantalla se muestra también en release, con las MAC enmascaradas; los logs de logcat solo existen en builds depurables.

Dispositivo → «Privacidad y datos»:
- **Exportar mis datos:** crea una copia en una carpeta privada de la app (`files/export`) y abre el selector de compartir de Android (`FileProvider`, no exportado, solo expone `export/`). **El destino que el usuario elija queda fuera del control de la app** (otra app o servicio recibe los ficheros, que contienen datos de salud sin cifrar). Ya no hay carpeta accesible por USB.
- **Borrado de la copia privada (DEV_004):** al abrir la pantalla de Privacidad, al arrancar el motor, al exportar de nuevo (se regenera) y en «Borrar todos mis datos». No se borra justo tras compartir (no se sabe cuándo la app destino termina de leer).
- **Borrar todos mis datos:** con confirmación; no borra la MAC emparejada ni edad/meta; la sincronización y el borrado no pueden solaparse (H1).

Probado por tests JVM (`JsonStore`, 14) y Flutter; **no en pantalla ni con un selector de compartir real**. No es una base legal/RGPD: es una función mínima.

### 20.8 Citas: nivel de verificación al cierre
En la ronda 4 se intentó abrir OMS 2020 en PMC (verificación de navegador) y en bjsm.bmj.com (HTTP 403): **no accesible**. Por tanto siguen solo-resumen: OMS 2020 (≥ 6 MET vigorosa **sin reconfirmar**), Kantrowitz 2025, Esco 2025, Paluch 2022, Chinoy 2021, Hickey 2021, Frontiers 2023, Tanaka. Leídos a texto completo solo FDA 2024, Shaffer & Ginsberg 2017 y Yeh 2021 (ronda 2). No se añadió ninguna cita nueva en esta ronda.
