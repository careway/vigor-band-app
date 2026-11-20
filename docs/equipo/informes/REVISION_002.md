# REVISION_002 — Revisión del Supervisor (ronda 2)

Fecha: 2026-11-20. Alcance: lectura de EQUIPO, PROCESO, BACKLOG, ESTADO, ANALISIS, GUIA_DE_ESTILOS, REVISION_001, QA_001, DEV_001, CARDIO y MOVIMIENTO_SUENO_GPS; lectura puntual de `lib/data/repo.dart` y `lib/data/analysis.dart` y de `sdk_ref/api_en.md` para nombres de campos. **No leí QA_002** (lo escribe otro agente en paralelo) y **no ejecuté** `flutter`, ni ADB, ni la app: todo lo que dice DEV_001 sobre compilación, tests y móvil lo cito de su informe, sin repetirlo. Sin coordenadas, MAC ni datos personales.

## 1. Revisión de DEV_001 contra el backlog
Detalle punto a punto en `BACKLOG.md`. Resumen:
- **Hecho en código** (con límites declarados por DEV_001): 8 privacidad, 10 robustez de efemérides/conexión, 11 almacén. Ninguno probado en el dispositivo en sus partes de riesgo (caída de conexión, Worker con app cerrada, corrupción, retención, reglas de copia de seguridad).
- **Parcial:** 12 (65 tests; falta confirmar `baselineOf` y sesión sin GPS), 15, 16, 17, 18, 20, 23, 26.
- **Pendiente:** 1, 2, 3, 4, 5, 6, 7, 9, 13, 14, 19, 21, 22, 24, 25, 27.
- Nada marcado "verificado" que DEV_001 declare "no verificado": pantallas Hoy/Actividad/Dispositivo (móvil bloqueado), TalkBack, caída de conexión, Worker, backoff, retención/corrupción.
- Observaciones críticas: (a) DEV_001 corrigió los 4 tests "BUG QA_001" cambiándolos al comportamiento correcto; es una buena práctica, pero QA_002 debe confirmarlo. (b) Seis puntos del backlog (13, 19, 22, 14, 21, 27) no se tocaron y no se explica por qué: no es un fallo, simplemente no estaban en su lote.

## 2. Verificación científica de esta ronda (ver `ANALISIS.md` §15)
- **Leído y confirmado:** FDA 21‑02‑2024 (página original abierta); definición de RMSSD y no intercambiabilidad de ventanas (Shaffer & Ginsberg, *Front Public Health* 2017, PMC5624990).
- **Corregido:** (1) sesgo de temperatura (Yeh et al., *JMIR mHealth uHealth* 2021, PMC7904403): la referencia era un termómetro infrarrojo de piel, el sesgo de 1,51 °C es frente a esa referencia, la ICC 0,96–0,98 era de repetibilidad en laboratorio y la validez en personas bajó con ambiente frío (0,45) o cálido (0,49); el texto de ANALISIS ("fiable para cambios") era demasiado optimista. (2) Identificador PMC de Chinoy 2021 (estaba PMC8343587; el correcto por búsqueda es PMC8120339). (3) Se retiró la frase sobre la cadencia de Paluch 2022 (no comprobable). (4) Wikipedia para MET marcada como fuente secundaria.
- **Encontrado a nivel de resumen (no leído completo):** Paluch 2022 (15 cohortes, 47 471 adultos, 3 013 muertes, medianas de cuartil, mesetas por edad); cortes de la OMS 2020 (moderada 3 a < 6 MET, vigorosa ≥ 6 MET; relativa 5–6 y 7–8 sobre 0–10; 150–300 min moderados o 75–150 vigorosos). Las páginas completas de PMC/BJSM bloquearon la lectura (anti‑robot / 403).
- **No encontrado:** las bandas de FC del ACSM (64–76 % de FCmáx para moderada). No se usan como dato; el umbral de pulso en E4 es una constante propia rotulada "aprox.".
- **No reabiertas:** Tanaka, Edwards/Impellizzeri, Hickey 2021, Frontiers Digital Health 2023.

## 3. Checklist del paso 6 de PROCESO.md
- [ ] **Sensores aprovechados / campos no usados.** Parcial. Con datos reales y sin uso: `oxygens` de 5 min, `half.json`, `sportValue`, `wear` (significado no verificado). Con datos reales pero fuera de alcance por falta de validación: `gesture`, `sleepStates`, `sleepStatusQuantity` (sin decodificar; E6). Sin datos (siempre 0) y a descartar: respiración, apnea/hipoxia, carga cardiaca, `hRVariation`, ECG, altitud/desnivel. Lo más valioso que se tira: ventana nocturna de `rrValue`, `ppgs` y `baseTemperature` (E2, E3, E9) y la cobertura de datos (E1).
- [ ] **Estudios 2020‑2026.** Hecho por los investigadores (CARDIO, MOVIMIENTO), pero casi todo a nivel de resumen. Cambios al análisis: la HRV por PPG se rotula PRV y sub‑estima al ECG (Kantrowitz 2025); la línea base de HRV pasa a ≥ 7 noches (Esco 2025); ACWR y VO₂máx descartados. Pendiente abrir textos completos (N36).
- [ ] **Análisis con fuente y limitación.** Parcial → mejorado: filtros, línea base y RMSSD documentados como "propios, sin fuente" (`ANALISIS.md` §14); temperatura, Chinoy y Paluch corregidos. Siguen sin fuente validada: FC en reposo (decil bajo), minutos de actividad por pulso, MET del fabricante, estrés del fabricante.
- [ ] **Deuda técnica / QA / rendimiento / batería.** Mejorada (DEV_001). Abierto: tests Kotlin (N39), `lastError` (N40), reconexión automática (18), `reload()` y batería sin medir (23), verificación en el móvil (N41). QA_002 aportará lo que encuentre.
- [ ] **Accesibilidad y privacidad.** Privacidad: hecho en código, parcialmente verificado. Accesibilidad: **parcial**; la Guía de estilos se reescribió (§7) con lo hecho y no hecho (200 % de texto, contraste, TalkBack y Semantics completos sin verificar).
- [ ] **Funciones de G Band que faltan.** Medición rápida (E7: sondeo en ronda 3), alarmas/recordatorios/sedentarismo (E10, ronda 4), notificaciones y cámara remota (heredado 5, sin fecha), sueño con curva (E6), exportar/borrar (25), buscar móvil desde la pulsera (hay `findBand`), esferas, clima, música (sin evaluar, bajo valor). No se recomienda: ECG, presión, glucosa, puntuaciones de salud.
- [ ] **Documentación al día.** Parcial: ANALISIS, GUIA y ESTADO actualizados hoy; README, ARQUITECTURA, MANUAL, GLOSARIO y BASES_CIENTIFICAS siguen sin existir (24).
- **Resultado.** Se añadieron N28–N41 al backlog. La ronda 3 la define `ESPECIFICACION_RONDA3.md`.

## 4. Puntos nuevos al backlog (sección "Puntos nuevos de la ronda 2")
28 calidad y cobertura (E1) · 29 FC en reposo nocturna (E2) · 30 HRV nocturna (E3) · 31 minutos de actividad OMS (E4) · 32 sesiones ampliadas verificadas (E5) · 33 herramienta y experimento de sueño (E6) · 34 sondeo de medición rápida (E7) · 35 ocultar glucosa por defecto y sin tipografía grande · 36 abrir textos completos de las fuentes · 37 PPG crudo/QX17 (laboratorio) · 38 aplazados E8/E9/E10 · 39 tests JVM de Kotlin · 40 limpiar `lastError` · 41 verificación en el móvil de lo que DEV_001 no pudo.

## 5. Riesgos que veo para la ronda 3
1. Con 10 RR por minuto y resolución de 10 ms, la HRV nocturna será ruidosa; la mediana de la noche mitiga, no elimina. Se mostrará siempre rotulada y sin "puntuaciones".
2. "Noche = 00:00–06:00" es una aproximación; falla con horarios distintos. Se corrige cuando se decodifique el sueño.
3. El supuesto de `ppgs` = 1 lectura por minuto (QA_001 B3) no está verificado y E2/E4B dependen de él; el desarrollador debe comprobarlo con la hora de los registros y el número de valores no nulos antes de implementar.
4. Las pruebas con la pulsera (E5, E6, E7) no pueden solaparse: una sola app a la vez por BLE (G Band o Vigor).
