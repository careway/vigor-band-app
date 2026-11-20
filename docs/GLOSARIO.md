# Glosario

| Término | Qué es (unidad) | Cómo lo usa Vigor |
|---|---|---|
| **PPG** (fotopletismografía) | Señal óptica del pulso en la piel | La pulsera la usa para pulso y SpO₂; Vigor muestra el pulso por minuto (bpm) |
| **bpm** | latidos por minuto | Pulso; se aceptan lecturas de 30 a 220 |
| **FCmáx** | frecuencia cardiaca máxima estimada (bpm) | 208 − 0,7 × edad (Tanaka 2001), ± 10 bpm |
| **Zonas de pulso** | Tramos de % de FCmáx | 1: 50–60, 2: 60–70, 3: 70–80, 4: 80–90, 5: 90–100 %; zona 0 por debajo de 50 % |
| **TRIMP (Edwards)** | Carga de entrenamiento (sin unidad) | Σ minutos en zona × número de zona; índice relativo personal |
| **FC en reposo (aprox.)** | bpm | De noche (00:00–06:00): mediana de las 30 lecturas más bajas (≥ 60 lecturas válidas). Respaldo: media del 10 % más bajo del día. Heurística propia |
| **RR / intervalo RR** | Tiempo entre latidos (ms) | Dato de la pulsera para calcular la variabilidad |
| **RMSSD** | Raíz cuadrática media de diferencias sucesivas de RR (ms) | Se calcula en la app por minuto (RR 300–2000 ms, diferencias ≤ 20 %, ≥ 5 diferencias) y se resume con la mediana |
| **HRV / PRV** | Variabilidad del pulso/cardiaca; PRV es la medida con pulso óptico en lugar de ECG | En la app se rotula "Variabilidad del pulso", aprox. |
| **SpO₂** | Saturación de oxígeno en sangre (%) | Valores 70–100 %; tendencia, no médico |
| **MET** | Equivalente metabólico; 1 MET ≈ reposo sentado ≈ 3,5 mL O₂/kg/min ≈ 1 kcal/kg/h | Dato del fabricante, sin clasificar |
| **Estrés (índice)** | 0–100, algoritmo no documentado del fabricante; en la tesela: «índice del fabricante · aprox.» | Tendencia relativa, sin categorías |
| **Temperatura corporal / de la piel** | °C | Dos campos de la pulsera; se ve la desviación frente a tu media |
| **Glucosa / componentes sanguíneos** | Estimaciones del fabricante (mmol/L, etc.) | Solo en "Experimental", sin rangos |
| **Cadencia / ritmo (pace)** | Pasos/min; segundos por km | El ritmo lo da la pulsera |
| **kcal** | Kilocalorías | Calculadas por la pulsera |
| **Haversine** | Distancia entre dos puntos de la Tierra (m) | Calculada para comprobar la distancia del GPS |
| **GPS / fix** | Posición por satélite; "fix" = posición obtenida | Sin fix la ruta se corta |
| **Efemérides / AGPS** | Datos de órbitas de satélites que aceleran el primer fix | Se descargan y se envían a la pulsera (≥ 30 % batería) |
| **BLE** | Bluetooth de bajo consumo | Enlace móvil–pulsera; solo una app a la vez |
| **MAC** | Dirección de la pulsera | Se guarda para reconectar sin escanear |
| **SDK Veepoo** | Biblioteca del fabricante | Acceso a la pulsera desde Kotlin |
| **MethodChannel / EventChannel** | Comunicación Flutter–Kotlin | `vigor/methods` y `vigor/events` |
| **WorkManager** | Tareas periódicas de Android | Efemérides cada 6 h |
| **ARMS** | Error cuadrático medio de exactitud de SpO₂ (%) | Se cita en ANALISIS §6 como listón regulatorio |
| **Cobertura** | % de lecturas válidas sobre las posibles del día | Se muestra bajo el gráfico de cada métrica; 1 440 posibles para pulso, SpO₂ y HRV (una por minuto) y 288 para el resto (cada 5 min); hoy, las transcurridas |
| **Lecturas válidas** | Lecturas que pasan el filtro de plausibilidad | Excluye "sin dato" (0 o 255) y las fuera de rango; se muestra "X de Y posibles" |
| **Sin dato** | Valor 0 o 255 que envía la pulsera cuando no mide | No cuenta como fuera de rango ni como cero real |
| **Descartadas por fuera de rango** | Lecturas por debajo o por encima del rango plausible | Se cuentan y se dicen; en SpO₂, por debajo de 70 % |
| **Pocos datos hoy** | Aviso en una tesela | Hay datos pero la cobertura es < 20 % |
| **Línea base propia** | Tu mediana de hasta 14 noches válidas anteriores | Exige ≥ 7 noches; la comparación "± frente a tu mediana" se hace solo contra ti |
| **Mediana** | Valor central de una lista ordenada | Más estable que la media ante lecturas raras |
| **Percentil** | Valor bajo el cual queda un % de los datos | Las fuentes de investigación proponen el percentil 5 para el pulso en reposo; la app usa la mediana de las 30 lecturas más bajas (no es un percentil exacto) |
| **Noche (provisional)** | Ventana 00:00–06:00 (no es la noche de sueño real) | Mientras no se decodifica el sueño real, "reposo" y "variabilidad nocturna" usan esta ventana (aprox.) |
| **CV (coeficiente de variación)** | Desviación típica entre media, en % | Variación de la variabilidad nocturna en las últimas noches |
| **Minutos de actividad moderada-vigorosa** | Minutos de esfuerzo ≥ moderado; guía OMS 2020: 150–300 min/semana moderada o 75–150 vigorosa | Dos estimaciones "aprox.": por MET ≥ 3 (5 min por registro) y por pulso ≥ 70 % de FCmáx (umbral propio) |
| **MVPA** | Siglas en inglés de los minutos de actividad moderada-vigorosa | Nombre interno en el código (`weeklyMvpa`) |
| **Calidad baja (HRV)** | Noche con > 5 % de diferencias entre latidos corregidas o descartadas | Se avisa en la tarjeta de variabilidad nocturna |
| **Experimental** | Métrica sin validación suficiente | Glucosa y componentes; ocultas de serie (interruptor "Mostrar métricas experimentales") |
| **Aprox.** | Rótulo de cálculo propio o poco validado | Variabilidad, pulso en reposo, minutos de actividad, fases de sueño, calorías |
| **Efemérides: *backoff*** | Espera antes de reintentar | 24 h si la pulsera no admite el envío |
| **Volcado de sueño / sondeo** | Herramientas de depuración | Solo en compilaciones de depuración; sin datos personales ni MAC |
| **Semantics / TalkBack** | Descripciones habladas de la interfaz / lector de pantalla de Android | Implementado; sin probar con TalkBack real |
| **Medición ultracorta (HRV)** | Cada registro de variabilidad del SDK trae ≈ 10 intervalos RR (≈ 10 s), uno por minuto de reloj | El RMSSD sale de ≈ 9 diferencias por medición, no de un minuto continuo; "30 minutos válidos" = 30 mediciones. Shaffer & Ginsberg avisan de que las ventanas no son intercambiables (ANALISIS §3) |
| **Centinela (2550)** | Valor de RR = 2550 ms (0xFF·10) que la pulsera envía cuando no mide; también 0 o no numérico | Es "sin dato": ni cuenta como par ni como corrección. En un móvil, 26,7 % de los RR |
| **Registro todo-centinela** | Medición HRV cuyos RR son todos "sin dato" | No cuenta como registro de la noche |
| **Línea base de 30 días** | Mediana de las hasta 14 noches válidas más recientes dentro de los 30 días naturales anteriores | Mínimo 7 noches; si no, "Aún sin línea base: k de 7 noches" |
| **Noche en curso** | La noche de hoy antes de las 06:00 | Se rotula, el dato puede cambiar y no entra en la línea base, el historial ni la media semanal; las teselas añaden "(en curso)" |
| **Calidad baja** | > 5 % de los pares de RR reales (sin centinelas) corregidos o descartados | Aviso en la tarjeta de variabilidad nocturna |
| **Sin datos / Sin datos suficientes** | Sin registros / con registros pero sin lecturas válidas suficientes | Estados de teselas y tarjetas; "n de 30 lecturas" o "n de N registros válidos (mínimo 60 %)" |
| **Pocos datos hoy / este día** | Punto de aviso con cobertura < 20 % | "hoy" solo en el día en curso; no se aplica a SpO₂ ni HRV |
| **Calorías "—"** | La pulsera informó `calories` = 0 en la actividad | No se muestra 0 kcal |
| **Exportar mis datos** | Crea una copia temporal privada de los `*.json` (`files/export`) y la entrega por el selector de compartir de Android | El destino elegido queda fuera del control de Vigor; ya no hay carpeta por USB |
| **FileProvider / `file_paths.xml`** | Componente de Android que da un acceso temporal de lectura a un fichero de la app; `file_paths.xml` solo expone `export/` | `exported=false`; permiso de lectura temporal por URI |
| **`clearExport`** | Método del canal que borra la copia privada de exportación | Se llama al abrir Privacidad; también al arrancar y en «Borrar todos» |
| **`wiping` / `tryWipe`** | Estado y operación de `JsonStore`: el borrado evalúa «¿puedo empezar?» dentro del cerrojo y, mientras dura, se rechazan escrituras | Evita la carrera borrado/sincronización; `BUSY` si se está sincronizando |
| **Lista blanca de tipos** | `JsonStore.KINDS`: los 8 tipos válidos (`origin5`, `hrv`, `spo2`, `half`, `live`, `sleep`, `sports`, `sportItems`) | Otro tipo lanza error (`STORE` en el canal) |
| **Borrar todos mis datos** | Elimina datos, efemérides, volcados y la copia temporal de exportación del móvil | Con confirmación; conserva emparejamiento, edad y meta; no alcanza lo ya compartido fuera de Vigor |
| **PermissionQueue** | Cola de peticiones de permisos (`Pure.kt`) | Las lanza en rondas; una denegada resuelve `false` sin bucle; **tiempo máximo de 60 s** (`TIMEOUT_MS`): pasado ese plazo resuelve lo pendiente y libera la cola |
| **Pure.kt** | Lógica sin Android: `Mac`, `AgpsRules`, `PermissionQueue` | Probada con JUnit en la JVM (`gradlew testDebugUnitTest`) |
| **Prueba JVM** | Test que corre en el ordenador sin móvil | 27 de Kotlin (JsonStoreTest 14, PureTest 13); 183 de Flutter |

