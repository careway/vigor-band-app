# Investigación CARDIO: aprovechamiento de sensores cardio, respiratorios y de temperatura

Fecha: 2026-11-20. Autor: Investigador cardio. Alcance: auditoría de datos del SDK y de la pulsera real + evidencia científica + recomendaciones. No se ha modificado código.

**Convención de fuentes.** Cada enlace aparece en una búsqueda o lectura real de esta sesión. Marco la profundidad: **[leído]** = abrí la página y leí el contenido; **[resumen]** = solo vi el resumen/fragmento que devolvió el buscador (no verifiqué el texto completo). Las cifras provienen de esas lecturas/resúmenes; si no, lo digo.

## 1. Resumen

- La pulsera entrega mucho menos de lo que el SDK describe. En los datos reales (≈ 8 h, 89 registros de 5 min, 445 de 1 min) **respiración, apneas, hipoxia, carga cardiaca, `hRVariation`, ECG, `rateValue`, `sportStatus` valen siempre 0**. Lo que sí tiene datos: pulso (`ppgs`), SpO₂ (`oxygens`, `oxygenValue`), intervalos RR (`rrValue`), `hrvValue`, estrés (`pressure`), MET, temperatura corporal y de piel, glucosa/componentes (no fiables).
- **No hay respiración, desaturaciones ni apnea que recuperar**: los campos existen pero esta VIGOR no los rellena (en esta muestra). La literatura tampoco respalda que un reloj de consumo detecte apnea de forma fiable; la recomendación es no construir nada ahí.
- Lo que sí merece trabajo: (1) **HRV/pulso nocturno y FC en reposo nocturna** como tendencia personal, usando las lecturas de la noche en lugar de todo el día; (2) **desviación nocturna de temperatura** respecto a línea base propia (experimental); (3) **calidad de datos** (filtrar ceros, `wear`, RR de 10 ms de resolución); (4) **SpO₂ nocturna como tendencia** y número de lecturas bajas como indicador *informativo*, nunca diagnóstico.
- Lo que hay que descartar o dejar rotulado "experimental": glucosa y componentes sanguíneos (FDA: ningún dispositivo no invasivo autorizado), estrés del fabricante (sin validación publicada del algoritmo), presión arterial.

## 2. Tabla de auditoría (SDK → datos reales → app)

Fuente SDK: `/mnt/d/band_app/sdk_ref/api_en.md`. Datos reales: copias de `origin5.json`, `spo2.json`, `hrv.json`, `half.json` del móvil, periodo ≈ 2026-11-19 17:40 a 2026-11-20 01:09. "Con datos" = valores distintos de 0 (y de 255) en esa muestra. Es una sola pulsera y ≈ 8 h: no generaliza.

| Señal / campo del SDK | Qué aporta | ¿Lo recibimos? | ¿Lo usa la app hoy? (`lib/data/repo.dart`, `lib/ui/*`) | ¿Datos reales? |
|---|---|---|---|---|
| `ppgs[5]` (pulso cada min en registro de 5 min) | FC | Sí | Sí (serie `hr`, zonas, tesela) | Sí (87/89) |
| `rateValue` (5 min) | FC antigua | Sí | No (se usa `ppgs`) | No, todo 0 (el SDK dice usar `getPpgs`) |
| `ecgs[5]` | "FC por ECG" | Sí | No | No, todo 0 |
| `halfHourRateDatas` (`ppgCount`, `rateValue`) | FC media 30 min | Sí | Sin comprobar uso detallado | Sí (half.json) |
| `oxygens[5]` / `spo2.json oxygenValue` (1 min) | SpO₂ | Sí | Sí (tesela y detalle, "tendencia") | Sí (88/89; 435/445) |
| `respirationRate` (spo2.json) / `resRates` (5 min) | Frecuencia respiratoria | Sí (campo) | No | **No, 0 en 445/445** |
| `apneaResult`, `hypopnea`, `isHypoxia`, `hypoxiaTime` | Apnea/hipoxia | Sí (campo) | No | **No, 0 en 445/445** |
| `cardiacLoad`, `hRVariation`, `heartValue` (spo2.json) | Carga cardiaca, variación | Sí (campo) | No | **No, 0 en 445/445** |
| `hrv.json rrValue[10]` (por minuto) | Intervalos RR (ms) | Sí | Sí: RMSSD propio (`rmssd()` en repo.dart) | Sí (445/445). En las muestras vistas, múltiplos de 10 ms; 10 RR por minuto |
| `hrvValue` | HRV del fabricante (algoritmo no documentado) | Sí | No (se ignora a propósito: no coincide con RMSSD/SDNN) | Sí (315/445; rango 31–191 en la muestra) |
| `hrv.json rate` (cadena) | Pulso latido a latido | Sí | No | Presente (texto con 10 valores); mi comprobación numérica lo trató como texto, no analizado |
| `pressure` (estrés 0–100) | Índice de estrés | Sí | Sí (tesela/gráfico, sin categorías) | Sí (31/89; solo parte del periodo) |
| `met` | Equivalente metabólico | Sí | Sí (tal cual) | Sí (87/89) |
| `temperature`, `baseTemperature` | Temp. "corporal" y de piel | Sí | Sí (desviación frente a media propia) | Sí (31/89) |
| `bloodGlucose` (+ `bloodGlucoseRiskLevel`) | Glucosa estimada | Sí | Sí, plegado "experimental"; riesgo ignorado | Hay valores (31/89); riesgo siempre "LOW/NONE" |
| `bloodComponent` (ácido úrico, lípidos) | Estimaciones sanguíneas | Sí | Sí, plegado "experimental" | Hay valores (31/31 donde existe) |
| `highValue/lowValue` y `halfHourBps` (presión arterial) | PA estimada | Sí | No visto en `lib/` | Solo 2/89 registros |
| `wear` | Pulsera puesta | Sí | No visto | 1/89 con valor 1 (significado no verificado) |
| `sportStatus`, `gesture`, `sleepStates` | Movimiento/sueño | Sí | Sueño: otra pantalla | `sportStatus` 0; `gesture` y `sleepStates` con valores (fuera de este alcance) |
| ECG (`startEcg…`, `ECG function`) | ECG de una derivación | No | No | No aplica: la ficha de hardware no lista electrodos ECG; `ecgType`/soporte no comprobado |
| Medición HRV desde la app (`startDetectHrv`, `onHrvDetect`) | HRV puntual en reposo | No | No | No probado; requiere `isSupportHrvAppDetect` |
| Medición manual de estrés/MET/emoción/fatiga (SDK ≥1.3.5/1.4.0) | Valores bajo demanda | No | No | No probado; la propia nota del SDK exige soporte del dispositivo |
| PPG crudo (`readPPGRawData`, MODE1/MODE2: verde+acelerómetro; "MODE3") | Señal cruda para algoritmos propios | No | No | **No probado**. El changelog lo asocia a "JH58" (otro modelo); esta VIGOR usa JL7013A7: soporte desconocido |
| QX17 Data Acquisition (IMU 100 Hz, GPS 1 Hz, FC 1 Hz en tiempo real) | Adquisición continua | No | No | No probado; el SDK lo describe como "proyecto QX17": soporte desconocido |
| Alerta de baja SpO₂ / apnea (`lowSpo2hRemain`, `SpoHBreathBreak`) | Avisos en la pulsera | No | No | Sin pantalla; desaconsejado (ver §4) |

Detalle importante de calidad: con 10 RR por minuto y resolución de 10 ms (observada), el RMSSD por minuto es un estimador ruidoso; hay que agregar (§3.2).

## 3. Evidencia por tema

### 3.1 Precisión de la FC por PPG de muñeca
- **Qué dice:** metaanálisis de 44 artículos, 738 tamaños de efecto, 15 marcas: diferencia media pequeña en sueño, reposo y cinta; mayor en entrenamiento de fuerza (−7,26 lpm) y ciclismo (−4,55 lpm); conclusión "validez aceptable para la mayoría de actividades". Autoría y revista: Zhang et al., *J Sports Sci* 2020 (según el resumen del buscador). Fuerza: metaanálisis de validaciones. **[resumen]**
- Un estudio de 2025 con un reloj: sesgo 2,56 lpm y MAE 6,41 lpm en muñeca no dominante frente a ECG, con variación grande por actividad. Validación de un solo dispositivo. **[resumen]**
- Tono de piel: revisión sistemática 2023: evidencia inconclusa, algunos estudios sugieren menor exactitud en pieles oscuras. **[resumen]**
- **Límites:** depende del dispositivo; peor con intensidad y movimiento de brazo; **no hay estudio de este modelo**.
- Enlaces: [Zhang 2020 (peeref)](https://www.peeref.com/works/20651620) · [informahealthcare](https://informahealthcare.com/doi/abs/10.1080/02640414.2020.1767348) · [piel, PubMed 36376641](https://pubmed.ncbi.nlm.nih.gov/36376641/) · [marco INTERLIVE PMC8273688](https://rcastoragev2.blob.core.windows.net/7198118b9a3f922a3033366876df1622/PMC8273688.pdf) · [JMIR mHealth 2026 (alcance)](https://mhealth.jmir.org/2026/1/e87324/PDF)

### 3.2 PRV frente a HRV por ECG y ventanas
- **Qué dice:** Kantrowitz et al., *Frontiers in Physiology* 2025, 931 adultos, brazalete con ECG y PPG, 5–7 min sentados: la FC concuerda (r 0,98–0,99), pero el RMSSD por PPG **subestima** al del ECG (37,49 vs 43,14 ms; diferencia −5,6 ms; r = 0,75) y SDNN y pNN50 también; concluyen que PRV es "un mal sustituto" de HRV por ECG y que deben llamarse distinto. Fuerza: estudio transversal, grande; **4 autores trabajan en la empresa del dispositivo** (declarado en el texto). **[leído]**
- Esco et al., *Sensors* 2025 (revisión narrativa): RMSSD como métrica principal de campo; protocolo ultracorto 1 min de estabilización + 1 min de registro; línea base ≥ 7 días; media semanal y coeficiente de variación; PPG fiable en reposo, pierde exactitud con movimiento; descartar registros con > ≈ 5 % de latidos corregidos; las puntuaciones logarítmicas de las apps no son comparables con ms. **[leído, primeros 100 000 de 188 374 caracteres]**
- Ventanas ultracortas (resumen del buscador): un estudio PPG con 467 voluntarios estimó RMSSD con ≈ 30 s; una validación de Oura nocturna encontró que **el promedio por noche tiene menor error que un solo tramo de 5 min**; un estudio de 2025 con 5 sujetos y 18 noches indica que solo algunas de 48 características HRV son válidas. Fuerza: validaciones pequeñas. **[resumen]**
- **Límites:** los RR de esta pulsera (10 por minuto, 10 ms de resolución observada) no son un registro continuo de 5 min; además, el algoritmo de fabricante no está documentado.
- Enlaces: [Kantrowitz 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12343505/) · [Esco 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12787763/) · [JMIR mHealth 2020 e18761](https://mhealth.jmir.org/2020/7/e18761) · [PMC7428904](https://pmc.ncbi.nlm.nih.gov/articles/PMC7428904) · [PMC8808342](https://pmc.ncbi.nlm.nih.gov/articles/PMC8808342) · [Frontiers 2025.1707318](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2025.1707318/full)
  (Para los tres últimos solo vi el título en la lista de resultados, no su contenido: no los uso como respaldo de cifras.)

### 3.3 HRV y FC nocturna como recuperación/carga
- **Qué dice:** la revisión de Esco (arriba): lo útil son los patrones longitudinales (semanas), no el dato de un día; HRV refleja también estresores externos, no solo la carga. Una revisión de medidas de FC sostiene que las de reposo a partir de registros de ~5 min son de las más útiles, y que muchas contradicciones vienen de metodología ([PubMed 24578692](https://pubmed.ncbi.nlm.nih.gov/24578692/), **[resumen]**).
- **Límites:** no encontré estudios que validen la **HRV nocturna por PPG de muñeca barata** como marcador de carga; la evidencia es de atletas, con mediciones matutinas controladas. En consecuencia: tendencia personal, sin "puntuación de recuperación".
- Enlaces: [Esco 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12787763/) · [PubMed 24578692](https://pubmed.ncbi.nlm.nih.gov/24578692/) · [Sensors 26/1/3](https://www.mdpi.com/1424-8220/26/1/3) (este último es la misma revisión de Esco, vista solo como resultado de búsqueda).

### 3.4 SpO₂ de muñeca
- **Qué dice:** *Frontiers in Digital Health* 2023: señal más débil en muñeca; referencia regulatoria ARMS ≤ 3,5 %; un oxímetro de muñeca validado midió 2,4 % ([PMC10726006](https://pmc.ncbi.nlm.nih.gov/articles/PMC10726006), citado en `ANALISIS.md` §6; **no reabierto en esta sesión**).
- JMIR Formative Research 2026: en hipoxia controlada, reloj y oxímetro sobreestimaron SpO₂ y la exactitud empeoró en hipoxemia; muestra pequeña y poco diversa. **[resumen]** ([enlace](https://formative.jmir.org/2026/1/e85253); al abrirlo, la página no devolvió contenido).
- Piel: PLOS Digital Health 2023, 49 personas, sin diferencias significativas en MAE (estudio pequeño). **[resumen]** ([Duke](https://scholars.duke.edu/publication/1709502))
- Desaturaciones nocturnas/apnea: Galaxy Watch 4 en 97 pacientes: RMSE 2,3 %; ODI ≥ 5/h predice AHI ≥ 15/h con sensibilidad 89,7 % y especificidad 64,1 % (**[resumen]**, [PMC7954003](https://pmc.ncbi.nlm.nih.gov/articles/PMC7954003) y [JMIR 2021 e24171](https://www.jmir.org/2021/7/e24171)); preprint arXiv de reflectancia: ODI en brazo mejor que en muñeca ([arXiv 2507.08399](https://arxiv.org/pdf/2507.08399), [arXiv 2505.20846](https://arxiv.org/pdf/2505.20846), **preprints, [resumen]**).
- **Qué NO está validado:** no hay validación de esta pulsera; la detección de apnea por muñeca es inconsistente entre estudios; el promedio de ventanas retrasa la caída real.

### 3.5 Frecuencia respiratoria por PPG
- **Qué dice:** más de 100 algoritmos propuestos y, en una comparación sistemática, rindieron mejor con ECG que con PPG ([revisión IEEE RBME 2018, PubMed 29990026](https://pubmed.ncbi.nlm.nih.gov/29990026/), [comparación PMC5390977](https://pmc.ncbi.nlm.nih.gov/articles/PMC5390977), **[resumen]**). Un estudio postoperatorio con pulsera PPG ([PMC9989911](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9989911/), **[resumen]**) y un informe breve con un dispositivo dedicado (r 0,884–0,991, **[resumen]**, solo título y fragmento).
- **En nuestra pulsera:** `respirationRate` = 0. Podría derivarse del RR en reposo (arritmia sinusal respiratoria) pero con 10 RR/min es inviable; con PPG crudo habría que probarlo. **Laguna.**

### 3.6 Temperatura de piel/muñeca
- **Qué dice:** el formato estándar de los fabricantes es la **desviación nocturna respecto a línea base personal**; ciclo menstrual: aumento posovulatorio observado con anillo Oura (piloto, *BMC Women's Health* 2019, [DOAJ](https://doaj.org/article/c13fc1b658874f0abfe65595566d828a)) y con pulsera Ava en 437 ciclos ([PMC7575238 tabla](https://pmc.ncbi.nlm.nih.gov/articles/PMC7575238/table/t0003)), ambos **[resumen]**. Para enfermedad: no encontré validación revisada por pares (solo blogs/fabricantes), así que no se afirma.
- Precisión: ya en `ANALISIS.md` §9: sesgo absoluto de 1,51 °C en un dispositivo de muñeca, repetibilidad alta ([PMC7904403](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7904403/), citado, no reabierto).
- **Límites:** ambiente, ropa y postura; variación noche a noche del orden de 0,2–0,5 °C según una fuente no revisada por pares ([SanoLabs](https://www.sanolabs.eu/blog/skin-temperature-deviation-overnight/), blog, **débil**).

### 3.7 Estrés por HRV/EDA en relojes de consumo
- **Qué dice:** Hickey et al., *Sensors* 2021: la FC media (lo que usan muchos comerciales) detecta peor estrés/ansiedad que HRV o EDA; la fiabilidad del EDA es discutible ([PMC8156923](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8156923/), **[resumen]**). Revisiones posteriores señalan problemas de etiquetado y generalización fuera del laboratorio ([arXiv 2209.15137](https://arxiv.org/pdf/2209.15137v3.pdf), [JMIR mHealth 2026 e64144](https://mhealth.jmir.org/2026/1/e64144), **[resumen]**).
- **Nuestra pulsera:** no tiene sensor EDA según la ficha; `pressure` es un índice del fabricante sin algoritmo documentado.

### 3.8 Glucosa no invasiva por PPG
- **Qué dice:** la FDA avisó el 21-02-2024 de que no ha autorizado ningún reloj/anillo que mida glucosa sin atravesar la piel; el riesgo es dosificar insulina con lecturas erróneas. Visto vía prensa ([Fierce Biotech](https://www.fiercebiotech.com/medtech/fda-reminds-world-it-has-yet-ok-smartwatches-noninvasive-glucose-monitoring), [CBS News](https://www.cbsnews.com/amp/news/fda-warns-against-smartwatches-rings-claim-measure-blood-sugar-without-needles), [HLTH](https://hlth.com/insights/news/fda-issues-warning-about-glucose-monitoring-with-smart-devices-2024-02-26)), **[resumen]**; **no abrí la comunicación original de la FDA** (laguna).
- **Estado de la evidencia:** no encontré en esta sesión ningún estudio que valide glucosa por PPG de muñeca; tampoco busqué a fondo estudios de pequeña escala (laguna).

## 4. Recomendaciones priorizadas

Leyenda: **[Mejora]** = mejora algo existente; **[Nuevo]** = función nueva. Todas sin diagnóstico ni alertas.

1. **[Mejora] HRV nocturna robusta (implementar).** Calcular RMSSD agregando todas las lecturas `hrv.json` de la ventana de sueño o de 00:00–06:00 (≥ 30 lecturas de minuto, mediana de los RMSSD de cada minuto, o RMSSD sobre RR concatenados dentro del mismo minuto); descartar minutos con RR fuera de 300–2000 ms o con diferencias > 20 % entre latidos consecutivos y minutos con ceros; mostrar solo si hay ≥ 60 % de minutos válidos. Comparar con la mediana personal de ≥ 7 noches (Esco 2025), y mostrar media semanal y variabilidad semanal. Texto: "Variabilidad del pulso (PPG), no HRV por ECG. Tiende a dar valores más bajos que el ECG. Útil solo para comparar contigo mismo; se afectan por alcohol, sueño, enfermedad y estrés."
2. **[Nuevo] FC mínima/en reposo nocturna (implementar).** Percentil 5 o mediana de las 30 lecturas más bajas de `ppgs` en la noche y tendencia frente a 14 noches. Sustento: FC en reposo en registros de ~5 min entre las medidas más útiles ([PubMed 24578692](https://pubmed.ncbi.nlm.nih.gov/24578692/), resumen); la FC por PPG en reposo/sueño es precisa (Zhang 2020, resumen). Texto: "Tendencia personal; no es una puntuación de recuperación."
3. **[Nuevo] Desviación nocturna de temperatura de piel (experimental).** Media nocturna de `baseTemperature` frente a la mediana de ≥ 5–7 noches propias; mostrar ± °C sin umbrales ni "fiebre". Si el usuario lo activa, mostrar la fase del ciclo solo como curva sin predicción. Texto: "Valores absolutos poco exactos (sesgo ≈ 1,5 °C en un dispositivo validado); solo cambios relativos. No detecta enfermedad."
4. **[Mejora] SpO₂ nocturna como tendencia (implementar con límites).** Mediana nocturna y percentil 5; mostrar el "tiempo bajo 90 %" **solo como dato informativo** con aviso "la pulsera de muñeca tiende a sobreestimar en hipoxia y no valida apnea". No ofrecer ODI ni etiqueta de apnea; los campos `apneaResult/hypoxiaTime` no se muestran porque están a 0.
5. **[Mejora] Calidad de señal y cobertura (implementar).** Mostrar "% de lecturas válidas" y ocultar métricas con poca cobertura; filtrar ceros (ya se hace en parte); documentar `wear` tras comprobar su significado (laguna). Registrar las lecturas con valor 0 como "sin dato", no como cero.
6. **[Nuevo] Prueba de PPG crudo / medición HRV desde la app (investigación en el móvil, no en producción).** Comprobar con la pulsera si `readPPGRawData` y `startDetectHrv` responden (el SDK las vincula a JH58 y a `isSupportHrvAppDetect`). Si respondiera, el PPG crudo permitiría HRV por tramos de 1–5 min y frecuencia respiratoria experimental; si no, descartar.
7. **Estrés (`pressure`): mantener como "experimental"/índice relativo**, sin categorías (sin validación del algoritmo; evidencia general débil).
8. **Glucosa/componentes: mantener plegado y gris; considerar ocultarlo por defecto.** La FDA no autoriza nada equivalente. No mostrar rangos ni riesgo.
9. **Descartar:** frecuencia respiratoria del SDK (todo 0), apnea/hipoxia/carga cardiaca del SDK (todo 0), ECG, alertas de baja SpO₂ en la pulsera, presión arterial como dato de salud (2/89 registros y sin validación aportada aquí).

### Datos que estamos tirando y que la literatura respaldaría usar
- **`rrValue`/ `hrv.json` en ventana nocturna** (hoy se promedia por día; mejor nocturna y con filtro).
- **`ppgs` nocturna** para FC en reposo.
- **`baseTemperature` nocturna** para desviación (hoy se compara con la media del día).
- **Cobertura/calidad** (conteo de lecturas válidas).
- Respiración, desaturaciones y carga cardiaca: **no hay datos que tirar**.

## 5. No verificado / lagunas
- Ningún estudio es de **esta pulsera** (JL7013A7 + RA2325/HX3917). Todas las cifras son de otros dispositivos.
- Muchas fuentes se vieron solo como **resumen del buscador** (marcadas). Solo leí completos (hasta donde permitió el extractor) Kantrowitz 2025 y la primera parte de Esco 2025. La página de JMIR Formative 2026 y el PMC7954003/JMIR e24171 no se abrieron.
- Autoría/años solo se dan cuando aparecen en lo leído; en el resto se describe el estudio sin autor.
- Los enlaces PMC7428904, PMC8808342 y Frontiers 1707318 los vi como títulos; no sé qué dicen exactamente.
- La comunicación original de la FDA (2024) no se abrió; PMC10726006 y PMC7904403 se citan de `ANALISIS.md` sin reabrirlos.
- No busqué: calidad/validez de la FC en ejercicio con acelerómetro de esta pulsera, MET/Emoción/Fatiga (el SDK menciona APIs pero sin datos), alertas de FC alta, ni validez de "carga cardiaca" del fabricante.
- Significado de `wear`, `gesture`, `hrvType`, el campo `rate` de `hrv.json` y la unidad real de `hrvValue`: no verificado.
- Los 31 registros con `pressure`/`temperature`/glucosa distintos de 0 parecen coincidir en el tiempo, pero no lo comprobé; podrían ser solo un tramo (p. ej. cuando se lleva puesta).
- Soporte real en esta pulsera de PPG crudo, QX17 y medición HRV desde la app: no probado.
- Mi muestra es de ≈ 8 h y de un solo usuario; los "siempre 0" podrían cambiar con noches completas o con configuración de la pulsera (por ejemplo, activar `SpoHBreathBreak` o el interruptor PPG), cosa que no probé.
