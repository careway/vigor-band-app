# Backlog (lo mantiene el Supervisor)

Prioridad: P0 = bloquea o es un riesgo; P1 = alto valor; P2 = mejora. Estado: pendiente · en curso · parcial · hecho. «Hecho» significa implementado según `DEV_001.md`; entre paréntesis lo que **no** está verificado. Actualizado en la ronda 2 (2026-11-20). QA_002 puede cambiar estados.

## Heredado de `ESTADO.md`
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| 1 | P0 | Verificar sueño con una noche real (`readSleepData` no devolvió nada) | Desarrollador + usuario | pendiente → E6 de la especificación (herramienta en ronda 3; el usuario duerme 2 noches) |
| 2 | P0 | Confirmar que el trabajo de efemérides se ejecuta solo con la app cerrada | Desarrollador | pendiente (DEV_001 reescribió el Worker; no se vio ejecutarse con la app cerrada) |
| 3 | P1 | Prueba de grabar actividad sin móvil (iniciar → desconectar → 15 min → leer) | Usuario | pendiente |
| 4 | P1 | Medición rápida bajo demanda (estrés, MET, temperatura) con `startDetectPressure`, `startDetectMet`, `startDetectTempture`, `startDetectHrv` | Desarrollador | pendiente → E7 (sondeo de soporte en ronda 3). Glucosa excluida (FDA) |
| 5 | P1 | Alarmas, notificaciones del móvil, cámara remota, recordatorios de salud | Desarrollador | pendiente → alarmas/recordatorios aplazados (E10, ronda 4) |
| 6 | P2 | Revisar el tema claro | Desarrollador | pendiente |
| 7 | P2 | Verificar `calValue` de 5 min (¿kcal?) | Desarrollador | pendiente (solo está verificada la caloría de sesión: `calories`/1000) |

## Nuevos (las rondas añaden aquí)
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| 8 | P0 | Privacidad: `allowBackup="false"` + reglas de exclusión; log solo en debug sin volcar objetos del SDK; enmascarar MAC en la UI (H-01..03) | Desarrollador | hecho (no verificado en el móvil que las reglas de exclusión actúen; tampoco el log en una versión de lanzamiento) |
| 9 | P0 | Sueño: inspeccionar la estructura real (`origin5.sleepStates`, `SleepData.sleepLine`) tras una noche y decidir la fuente (H-14) | Investigador movimiento + Desarrollador | pendiente → E6 |
| 10 | P0 | Robustez de `AgpsWorker`/`BandClient` (H-15, H-16) | Desarrollador | hecho en código (no probado: Worker con app cerrada, reintento/backoff, caída de conexión) |
| 11 | P0 | `JsonStore`: no vaciar si está corrupto, `renameTo` comprobado, purga/límite (H-17) | Desarrollador | hecho en código (sin pruebas Kotlin; corrupción y retención no probadas en el dispositivo) |
| 12 | P0 | Pruebas de `VigorRepo.reload` y `baselineOf` con JSON sintético (incluida sesión sin GPS) (H-23) | QA | parcial (65 pruebas; QA_002 dirá si cubren `baselineOf` y sesión sin GPS) |
| 13 | P1 | Sesiones sin GPS: leer `kcals`/`peisu`; verificar `avgPace` (H-09, H-10) | Desarrollador | pendiente (DEV_001 no lo menciona; `avgPace` en s/km ya verificado con la app oficial; `kcals`/`peisu` siguen sin verificar) |
| 14 | P1 | Aprovechar `oxygens` de 5 min y `wear`; `resRates` solo si la pulsera los rellena | Investigador cardio + Desarrollador | pendiente (reformulado: `resRates`/apnea/hipoxia/carga son 0 en los datos reales → descartar; `wear` sin significado verificado; SpO₂ nocturna → E8 aplazada) |
| 15 | P1 | Documentar filtros de plausibilidad, uso de `baselineOf` y RMSSD; mostrar lecturas descartadas (H-07, H-13) | Investigador cardio + Supervisor | parcial (documentado en `ANALISIS.md` §14 en la ronda 2; falta la UI de «lecturas descartadas» → E1) |
| 16 | P1 | Accesibilidad real: Semantics, alternativa al Reloj del día, texto 200 %, TalkBack, contraste (H-24) | Desarrollador + QA | parcial (Semantics en teselas/cinta/cifras/gráficos; reloj ajustable + tabla por franjas; NO probados TalkBack, 200 %, contraste; Semantics en Actividad/Sueño/Dispositivo no declarado) |
| 17 | P1 | Validar unidades de glucosa, `calValue` y `bloodComponent` frente a la app oficial (H-08) | Investigador cardio | parcial (verificadas con la app oficial: distancia en m, calorías de sesión, ritmo en s/km; pendientes glucosa, `calValue`, `bloodComponent`, velocidad, cadencia) |
| 18 | P1 | Reconexión automática y aviso de sincronización parcial/errores (H-19, H-20) | Desarrollador | parcial (listener de desconexión que aborta la sincronización y emite `disconnected`; sin reconexión automática; caída real no provocada) |
| 19 | P1 | Interpretar los paquetes de funciones soportadas y adaptar la UI (4.1) | Investigador movimiento + Desarrollador | pendiente (DEV_001 solo los redujo a resúmenes en el log) |
| 20 | P1 | Revisar estudios 2020-2026 por sensor; sustituir fuentes secundarias (H-28) | Investigador cardio + Investigador movimiento | parcial (CARDIO.md y MOVIMIENTO hechos, casi todo a nivel de resumen; en la ronda 2 se leyeron FDA, Shaffer, Yeh; queda Wikipedia en MET y abrir textos completos: ver 36) |
| 21 | P2 | Cargar `half.json` como respaldo; evaluar presión arterial sin mostrarla | Investigador cardio | pendiente (presión: 2/89 registros y sin validación → descartar) |
| 22 | P2 | `maxSdkVersion="30"` en permisos de ubicación; cambio de contraseña de la pulsera (H-04, H-06) | Desarrollador | pendiente (DEV_001 no lo menciona) |
| 23 | P2 | Rendimiento de `reload()`, memoria y batería (H-18) | QA + Desarrollador | parcial (arrastre del reloj optimizado, `getData` en segundo plano; `reload()` y batería sin medir) |
| 24 | P2 | README, ARQUITECTURA, MANUAL_USUARIO, GLOSARIO, BASES_CIENTIFICAS (H-27) | Documentador | pendiente |
| 25 | P2 | Exportar y borrar datos del usuario | Desarrollador | pendiente (la retención de 60 días no es borrado a petición) |
| 26 | P2 | Origen/integridad de las efemérides (HTTPS, tamaño/CRC) (H-05) | Desarrollador | parcial (comprobación mínima: ≥ 1 000 bytes y no HTML/JSON; sin CRC ni verificación de origen documentada) |
| 27 | P2 | ECG/medición manual: viabilidad y política de salud | Investigador cardio | pendiente → recomendación: descartar (la ficha no lista electrodos; sin validación) |

### Puntos nuevos de la ronda 2 (numeración correlativa)
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| 28 | P1 | E1 Calidad y cobertura de datos + recuento de lecturas descartadas (`ESPECIFICACION_RONDA3.md`) | Desarrollador | hecho en código (E1; DEV_002; sin verificar en pantalla) |
| 29 | P1 | E2 FC en reposo nocturna con tendencia (≥ 7 noches) | Desarrollador | hecho en código (E2; sin verificar en pantalla) |
| 30 | P1 | E3 HRV nocturna robusta con línea base propia (≥ 7 noches), rotulada «PPG, aprox.» | Desarrollador | hecho en código (E3; supuesto 1 registro = 1 min sin verificar) |
| 31 | P1 | E4 Minutos de actividad semanales frente a OMS 2020 (MET ≥ 3 del fabricante y pulso, ambos «aprox.») | Desarrollador | hecho en código (E4; umbral de pulso propio; sin verificar en pantalla) |
| 32 | P1 | E5 Sesiones ampliadas solo con campos de unidad verificada + prueba de distancia conocida para verificar velocidad/cadencia/pausas | Desarrollador + usuario | parcial (derivados hechos; falta la prueba de distancia conocida del usuario; velocidad/cadencia/pausas siguen sin mostrarse) |
| 33 | P0 | E6 Herramienta de volcado local de sueño (solo depuración) y experimento de 2 noches con criterio de decisión | Desarrollador + usuario | parcial (herramienta hecha y compilada; no ejecutada con la pulsera; faltan las 2 noches del usuario) |
| 34 | P2 | E7 Sondeo de soporte de las mediciones rápidas (sin UI pública) | Desarrollador | parcial (sondeo hecho solo en debug; no probado con la pulsera) |
| 35 | P1 | Glucosa y componentes: ocultar por defecto y no mostrar la cifra con tipografía `display` (H-11, CARDIO §4.8); aviso fijo junto a la cifra, no solo en el banner (QA_001 §3) | Desarrollador | hecho en código (interruptor «métricas experimentales», apagado de serie; aviso fijo junto a la cifra: sin confirmar) |
| 36 | P1 | Abrir los textos completos de OMS 2020, Paluch 2022, Chinoy 2021, Hickey 2021, Frontiers Digital Health 2023 (SpO₂), Tanaka y Edwards y sustituir Wikipedia en MET por el Compendio; confirmar en el texto el cociente del 4.º cuartil de Paluch | Documentador + Supervisor | pendiente |
| 37 | P2 | Experimento de laboratorio: PPG crudo, QX17, `startDetectHrv` (soporte en esta pulsera) | Investigador cardio + Desarrollador | pendiente (E11, aplazado) |
| 38 | P2 | Aplazados de la ronda 3: SpO₂ nocturna como tendencia (E8), temperatura de piel nocturna experimental (E9), alarmas/sedentarismo (E10) | Desarrollador | pendiente (ronda 4) |
| 39 | P2 | Infraestructura de pruebas JVM para Kotlin (`JsonStore`, `Agps.looksValid`) | Desarrollador | pendiente (DEV_002 lo confirma: M2, N1–N4, N6–N8, M5, M7 sin test automático) |
| 40 | P2 | Limpiar `lastError` antiguo de efemérides persistente en preferencias | Desarrollador | pendiente |
| 41 | P1 | Verificación visual en el móvil de Hoy/Actividad/Dispositivo y prueba real de caída de conexión, Worker con app cerrada, TalkBack y texto 200 % (DEV_001 no pudo: móvil bloqueado) | QA + usuario | pendiente |

Detalle y justificación: `docs/equipo/informes/REVISION_001.md` (H-xx) y `REVISION_002.md`.


### Estado de E1–E11 y de QA_002 tras DEV_002 (ronda 3, Supervisor)
Fuente: `DEV_002.md`. «Hecho en código» = compila, analyze limpio y tests sintéticos; **nada figura como verificado** (móvil bloqueado, ninguna prueba en pantalla ni con la pulsera).
| Punto | Estado |
|---|---|
| E1–E5 | hecho en código (ver 28–32; E5 parcial) |
| E6 | parcial: herramienta sí, experimento de 2 noches pendiente |
| E7 | parcial: sondeo en debug, sin probar |
| E8, E9, E10, E11 | aplazados (38, 37) |
| QA_002 M2, M5, M6, M7, M10, N1, N2, N3, N4, N6, N7, N8, B13 | hecho en código; sin tests Kotlin ni prueba real (M10 solo análisis estático) |
| QA_002: puntos no citados por DEV_002 | no consta: pendiente de lo que diga QA_003 |
| Heredados 1, 2, 3, 9 | pendientes (dependen del usuario) |
| 4 | parcial (= E7) |
| 13, 14, 19, 21, 22 | pendientes (sin tocar) |

## Nuevos de la ronda 3 (descubrimiento; numeración correlativa)
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| 42 | P1 | Guion de verificación del usuario (sueño 2 noches, grabar sin móvil, efemérides con app cerrada, TalkBack, 200 %, capturas) — REVISION_003 §5 | Usuario | pendiente |
| 43 | P1 | Verificar con una lectura real: `ppgs` 1/min, `hrv` 1 registro = 1 min, `sportTime` en segundos (log de ventanas/horas, sin guardar datos personales) | Desarrollador | pendiente (ronda 4, por logcat/tests con JSON real anonimizado) |
| 44 | P1 | Test JVM de Kotlin: `JsonStore`, `BandClient` latch/headless, `Agps.looksValid` (ampliación de 39) | Desarrollador | pendiente (ronda 4) |
| 45 | P2 | Abrir por otra vía el texto completo de OMS 2020 (≥ 6 MET), Kantrowitz, Esco, Paluch (amplía 36; el lector web no accede a PMC) | Supervisor + usuario | pendiente |
| 46 | P2 | Campos del SDK sin usar con datos reales: `oxygens` 5 min, `wear`, `sportValue`, `half.json` (amplía 14, 21) | Desarrollador | pendiente (solo con datos que lo justifiquen) |
| 47 | P2 | Buscar pulsera / cámara remota / notificaciones: evaluar `findBand` y cámara como funciones sin dato de salud; notificaciones requieren permiso especial | Desarrollador | aplazado a v1.1 (no probable sin móvil) |
| 48 | P2 | Alarmas y sedentarismo (E10) | Desarrollador | aplazado a v1.1: escritura en la pulsera, no verificable sin pantalla |
| 49 | P2 | Documentación v1.0: README, ARQUITECTURA, MANUAL, GLOSARIO, BASES_CIENTIFICAS (= 24) con las salvedades | Documentador | pendiente (ronda 4) |
| 50 | P1 | Exportar y borrar datos (= 25), en versión mínima: borrar todo y exportar JSON por compartir | Desarrollador | pendiente; borrar es verificable por test |
| 51 | P2 | Privacidad: permisos `maxSdkVersion=30` en ubicación (= 22); revisar que el volcado de depuración no entra en release | Desarrollador | pendiente |
| 52 | P2 | Accesibilidad estática: tamaños fijos/etiquetas 10 px/encabezado experimental < 48 dp, con tests de widget a textScale 2.0 (verificable sin móvil) | Desarrollador | pendiente (ronda 4) |
| 53 | P2 | Medición de contraste de la paleta por script (cálculo WCAG, sin pantalla) | Supervisor/Desarrollador | pendiente (ronda 4) |


## Estado tras DEV_003 (ronda 4, Supervisor)
Leyenda: **código** = implementado; **test** = cubierto por test automático (sintético o JVM); **móvil** = pendiente de verificación en el dispositivo/usuario. Nada figura como verificado en pantalla.
| Punto | Estado |
|---|---|
| 22, 51 (`maxSdkVersion` ubicación) | hecho en código; manifiesto fusionado comprobado; test: no; móvil: API 29 conserva el permiso, sin comprobar en 30+ |
| 25, 50 (exportar/borrar) | hecho en código; borrar y exportar cubiertos por test JVM de `JsonStore`; móvil: pendiente (diálogo, ruta de exportación) |
| 39, 44 (tests JVM Kotlin) | parcial: `JsonStore`, `Pure.kt` (19 tests); sigue sin test `BandClient`, `Worker`, M2/N1–N4 |
| 40 (`lastError`) | hecho en código; sin test de Kotlin; móvil: pendiente |
| 43 (supuestos de datos) | hecho: `sportTime` segundos verificado; `hrv` 1/min con 10 RR; `ppgs` solo consistente. Una persona, ~2 días |
| 52 (accesibilidad estática) | parcial: tests ×2 (limitados por Ahem), guidelines de toque, encabezado 48 dp; móvil: pendiente |
| 53 (contraste) | hecho por cálculo (texto, fondo sólido); degradados/translúcidos sin medir |
| 16 (accesibilidad) | parcial: TalkBack, 200 % real y Semantics de Actividad/Sueño/Dispositivo pendientes |
| 15 | parcial: contador de descartadas en código; sin ver en pantalla |
| 49, 24 (documentación de usuario) | hecho (README, ARQUITECTURA, MANUAL, GLOSARIO, BASES_CIENTIFICAS existen y se actualizaron en rondas 3-4; corrección del coordinador); pendiente de verificación humana de las descripciones de pantallas |
| 36, 45 (textos completos de citas) | pendiente: PMC y bjsm.bmj.com inaccesibles el 2026-11-20 |
| 1, 2, 3, 9, 32, 33, 41, 42 | pendientes de verificación humana (REVISION_004 §b) |
| 8, 10, 11, 18, 26, 28–31, 35 | sin cambio: hecho en código / parcial, no verificado en móvil |
| N8, K1, K2 de QA_003 | aceptados / cosméticos |

## Nuevos de la ronda 4 (descubrimiento)
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| 54 | P1 | Verificar en el móvil el panel «Privacidad y datos»: exportar (¿ruta visible?) y borrar | Usuario + QA | pendiente; si la ruta no es visible, usar `Intent` de compartir (v1.1) |
| 55 | P2 | HRV ultracorta (~10 latidos/min): valorar agregar ventanas (p. ej. 5 min) o limitar a reposo; buscar literatura sobre RMSSD ultracorto con PPG | Investigador cardio | pendiente v1.1 |
| 56 | P2 | Investigar el 2550 ms (26,7 %): ¿código de firmware o movimiento? Contrastar con otra pulsera/otro día | Desarrollador | pendiente; muestra de 1 persona |
| 57 | P2 | Contraste sobre el fondo Aurora/Glass translúcido (muestreo de píxeles de capturas) | QA | pendiente (requiere pantalla) |
| 58 | P2 | Tests de `BandClient` con interfaz del SDK simulada y `Worker` (WorkManager test) | Desarrollador | pendiente v1.1 |
| 59 | P2 | Nota de privacidad en pantalla/primer arranque (qué se guarda, dónde, cómo borrarlo) y manual | Documentador | pendiente |
| 60 | P2 | Reconfirmar con el texto completo el corte ≥ 6 MET (OMS) y las cifras de Paluch/Chinoy | Supervisor + usuario | pendiente (= 36, 45) |
| 61 | P2 | Ampliar la muestra de datos (más noches/personas) antes de tratar `ppgs` 1/min como confirmado | Usuario | pendiente |


## Cierre de la ronda 4 (tras DEV_004; Supervisor, 2026-11-20)
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| H1 | P0 | Carrera borrado/escritura en `JsonStore` y sincronización | Desarrollador | hecho en código (hook determinista; sin hilos reales) |
| H2 | P0 | Exportación privada + selector de compartir; borrado de la copia | Desarrollador | hecho en código (no verificado en pantalla) |
| H3 | P1 | Tiempo máximo de 60 s en la cola de permisos | Desarrollador | hecho (solo JVM; sin diálogo real) |
| H4 | P2 | `exportTo` regenera la carpeta | Desarrollador | hecho |
| H5 | P1 | Registro técnico en release con MAC enmascaradas; logcat solo en depuración (`ANALISIS.md` §20.7) | Supervisor | hecho (documentación corregida) |
| H6 | P2 | Estrés rotulado «índice del fabricante · aprox.» | Desarrollador | hecho (no visto en pantalla) |
| H7 | P2 | `JsonStore.KINDS`: tipos validados | Desarrollador | hecho |
| H8 | P2 | Receptor de Nordic `exported=false` | Desarrollador | hecho (uso de escaneo por Nordic no verificado) |
| 62 | P0 | Firma de release propia (hoy usa la clave de depuración) antes de distribuir | Usuario | pendiente |
| 63 | P0 | `applicationId` definitivo antes de distribuir | Usuario | pendiente |
| 64 | P1 | Verificar en el móvil el selector de compartir (exportar), la lectura por la app destino y el borrado de la copia privada | Usuario + QA | pendiente (sustituye al 54: ya no hay carpeta por USB) |
| 65 | P1 | Verificar en el móvil la privacidad: sin registro técnico con datos en release, MAC enmascarada, borrado total | Usuario + QA | pendiente |
| 66 | P2 | Regenerar y probar el APK release tras DEV_004 | QA | pendiente |
| 67 | P1 | DEV_005: modos deportivos (selector, recorrido/interior, nombres en histórico), cadencia de medición automática y Ajustes en submenús | Desarrollador | hecho en código (sin instalar; sin probar con la pulsera: arranque de cada modo, qué modos admite, escritura de intervalos) |
| 68 | P1 | Verificar en el móvil con la VIGOR: iniciar 3 modos (recorrido, interior, uno raro) y leer/cambiar cadencia de pulso y SpO₂; comprobar ids deducidos (48, 50, 75, 77, 82, 122, 139, 146, 158, 164, 167, 171, 174, 177) | Usuario + QA | pendiente |
| 69 | P2 | Series/repeticiones en modos de gimnasio: la SDK usada no los expone (no verificado si algún paquete los trae) | Investigador movimiento | pendiente |
| 70 | P1 | DEV_006-A: actualizaciones desde la app (CI publica `build: N`, la app compara versionCode, descarga https de GitHub, instalador del sistema) | Desarrollador | hecho en código y con tests (no probado de extremo a extremo: el repositorio es privado y la API da 404; la instalación real no se ha probado en el móvil) |
| 71 | P1 | DEV_006-B: medición de pulso bajo demanda en el círculo de Hoy (`startDetectHeart`/`stopDetectHeart`) | Desarrollador | implementada, NO probada en hardware (la pulsera no está disponible; solo tests con fakes: estados, tiempo máximo, cancelación, valores inválidos). Pendiente feedback del usuario en remoto |
| 72 | P2 | Decisión del usuario: hacer público el repositorio para que funcione la comprobación de versiones (sin token en la app); revisar la firma: las versiones de prueba usan la clave de depuración | Usuario | pendiente |
| 73 | P1 | DEV_006-C: pulso en vivo automático con la app abierta (bucle de mediciones cortas, intervalo 5/10/30/60 s en Ajustes) | Desarrollador | implementada, NO probada en hardware (la pulsera no está disponible; tests con fakes y reloj simulado: temporización, backoff, cancelación, solapes, valores inválidos). Falta medir el gasto de batería real y la fiabilidad de la lectura corta |


## DEV_007: Salud y compartir (Health Connect / Apple Salud)
| # | Prioridad | Tarea | Responsable | Estado |
|---|---|---|---|---|
| 74 | P1 | Sincronización unidireccional con Health Connect y Apple Salud, por categorías, opt-in, con borrado y racionalidad de permisos (`DEV_007.md`) | Desarrollador | hecho en código (Android compila y hay tests con fakes; **no probado en un móvil con Health Connect**; iPhone **no compilado ni probado**) |
| 75 | P1 | Probar en el móvil: permisos, registros en Health Connect, idempotencia, borrado, ruta GPS, pantalla de racionalidad | Usuario + QA | pendiente |
| 76 | P1 | Con Mac: generar `ios/`, capacidad HealthKit, `Info.plist` (NSHealthShareUsageDescription/UpdateUsageDescription), iOS 15+, compilar y probar | Usuario | pendiente |
| 77 | P2 | `clientRecordId` para sesiones de ejercicio (hoy se evitan duplicados solo con el libro local) y agrupar muestras de pulso | Desarrollador | pendiente (puede exigir canal nativo) |
| 78 | P2 | Si se publica en Google Play: declaración de tipos de datos de Health Connect y política de privacidad pública | Usuario | pendiente |
| 80 | P1 | DEV_006-D: mensajes claros al fallar la comprobación manual (sin conexión / no accesible o privado / límite de API / respuesta inválida) con botón a la página de versiones; aviso "Más tarde" por versión; punto en Ajustes | Desarrollador | hecho en código y con tests de fakes (no probado en el móvil ni contra GitHub real) |
| 79 | P1 | El sueño no llega a Health Connect (informe del usuario): leer en «Salud y compartir» el estado de Sueño y devolver el texto exacto (ver adenda de DEV_007) | Usuario + Desarrollador | pendiente (diagnóstico añadido; causa sin determinar) |
| 81 | P1 | DEV_006-E: pulso en vivo inmediato al abrir/reanudar (observador de ciclo de vida, sin backoff antiguo, estados "conectando…/midiendo pulso…") y comprobación de versión al iniciar y reanudar (anti-spam 15 min) | Desarrollador | hecho en código y con tests de fakes/reloj simulado; pulso NO probado en hardware |
| 82 | P1 | DEV_008: borrar noches, sesiones y datos de un día (con tumbas y borrado opcional en Health Connect) | Desarrollador | hecho en código y tests; no probado en el móvil ni con la pulsera ni con Health Connect real |
| 83 | P1 | Probar en el móvil: borrar una noche/sesión/día, sincronizar y comprobar que no reaparecen; y el borrado en Health Connect | Usuario + QA | pendiente |
| 84 | P1 | DEV_009: sueño con detalle: hipnograma por minuto (`sleepLine`, 4 carriles con REM) con FC y SpO₂ en el mismo eje de hora, lectura al arrastrar, barra de fases, métricas derivadas y vista de 7/14/30 noches con regularidad y siestas aparte | Desarrollador | hecho en código y tests; visto en el Mi 9 con noches reales (sin pulsera nueva) |
| 85 | P1 | DEV_010: escribir las fases del sueño en Health Connect como UNA sesión con etapas (código Kotlin con el cliente de Health Connect; el plugin escribe una sesión por fase) | Desarrollador | hecho; verificado en el Mi 9 (Health Connect muestra una sola sesión con sus tramos); iPhone sin hacer |
| 87 | P2 | iPhone: escribir las fases del sueño en Apple Salud (categorías de HealthKit); código sin compilar, sin Mac | Desarrollador | pendiente |
| 88 | P1 | DEV_011: escritura por lotes en Health Connect (hasta 500 datos por llamada) para pasos, distancia, calorías, pulso, HRV, pulso en reposo, SpO₂ y temperatura; evita agotar la cuota por llamadas | Desarrollador | hecho; verificado en el Mi 9 (unos 5800 datos en una ronda sin error de cuota) |
| 86 | P2 | Rangos de referencia por fase: solo si se verifica una fuente (Ohayon 2004 solo se vio en resumen, sin porcentajes) | Investigador | pendiente |
