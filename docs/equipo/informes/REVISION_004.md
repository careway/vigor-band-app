# REVISION_004 — Revisión final del Supervisor (ronda 4, cierre v1.0)

Fecha: 2026-11-20. Leído: EQUIPO, PROCESO, BACKLOG, ESTADO, ANALISIS, GUIA_DE_ESTILOS, REVISION_003, QA_003, DEV_003 (no QA_004). No ejecuté flutter, ADB ni la app: lo técnico lo cito de DEV_003. Intento de abrir OMS 2020 en PMC y en bjsm.bmj.com: bloqueado (verificación de navegador / HTTP 403); **no se verificó ninguna cita nueva**. Sin coordenadas, MAC ni datos personales.

## (a) Definición de «terminada v1.0» (REVISION_003 §4), criterio por criterio
Leyenda: CC = cumplido en código; CT = cumplido y verificado por tests; PH = pendiente de verificación humana; NC = no cumplido.
| # | Criterio | Estado |
|---|---|---|
| 1 | Release sin avisos; analyze limpio; tests verdes incl. JVM de `JsonStore`, `looksValid`, `BandClient` | **CT parcial**: analyze limpio, 168 Flutter + 19 JVM (`JsonStore`, `Pure.kt`). **NC**: `BandClient`/`Worker` sin test JVM; **no se compiló en release** (solo debug). |
| 2 | Sincroniza y muestra las 4 pantallas, visto en pantalla | **PH**: nada visto en pantalla desde la ronda 1. |
| 3 | Cada cifra con método/fuente o «aprox./propio», límite y cobertura | **CC + CT** (textos y Semantics probados con datos sintéticos); visual PH. Fuentes mayormente solo-resumen (ANALISIS §20.8). |
| 4 | Sueño: duración real o «sin datos» honesto | **PH**: la decisión depende de las 2 noches (E6 sin ejecutar). Pantalla lista, campos solo de documentación. |
| 5 | Sin alertas clínicas, glucosa oculta, sin puntuaciones | **CC + CT** (oculta por defecto, test de QA_003). Visual PH. |
| 6 | Privacidad: borrar y exportar; sin copias de seguridad; sin log en release | **CC + CT** para borrar/exportar (JVM `JsonStore`) y manifiesto fusionado; **PH**: panel en pantalla, ruta de exportación visible, log en release no probado. |
| 7 | Accesibilidad: ×2 sin desbordes, contraste medido, TalkBack en 4 pantallas | **Parcial**: contraste CT por cálculo (fondo sólido); ×2 CT limitado (Ahem oculta overflow); TalkBack **PH**. No cumplido como verificado. |
| 8 | Efemérides con app cerrada y caída de conexión recuperada | **PH** (Worker y listener solo en código). |
| 9 | Documentación v1.0 completa y textos científicos abiertos | **NC**: README, ARQUITECTURA, MANUAL, GLOSARIO, BASES_CIENTIFICAS no existen; solo ANALISIS/ESTADO/GUIA actualizados. Citas: PMC inaccesible, siguen marcadas. |
**Veredicto:** la v1.0 es «candidata»: funcional en código y bien testeada con datos sintéticos y agregados reales, pero **no se puede declarar terminada** hasta cumplir 2, 4, 8 y 9 y el resto de PH. Ninguna cifra se declara verificada en pantalla.

### Ronda de descubrimiento (paso 6, resumen)
- **Sensores:** PPG (pulso, HRV ultracorta) usado; `hrvValue` del fabricante, `oxygens` de 5 min, `wear`, `sportValue`, `gesture`, `half.json` sin usar; SpO₂/temperatura nocturnas (E8/E9) aplazadas; respiración, apnea, ECG, presión: descartados.
- **Estudios 2020–2026:** sin cambios; cuello de botella = abrir textos completos (PMC/BMJ bloqueados). Nuevo: la HRV de 10 latidos por minuto es ultracorta y no está validada con esta pulsera (punto 55).
- **Fuentes y límites:** todo análisis tiene fuente o «propio, sin fuente» (ANALISIS §17, §20).
- **Deuda:** tests de `BandClient`/`Worker`; reconexión automática; `reload()` y batería sin medir; integridad de efemérides mínima.
- **Accesibilidad y privacidad:** ver criterios 6 y 7. **G Band:** buscar pulsera, cámara, notificaciones, alarmas, sedentarismo → v1.1. **Documentación:** pendiente (criterio 9).
- Nuevos puntos del backlog: 54–61.

## (b) GUÍA DE PRUEBAS PARA EL USUARIO (mañana)
**Antes de empezar (5 min)**
1. Desbloquea el móvil y, solo para las pruebas, quita el bloqueo de pantalla o pon «Tiempo de pantalla» alto (así nada se queda a medias). Vuelve a ponerlo al acabar.
2. Cierra la app G Band (solo una app puede usar la pulsera a la vez). Ten la pulsera cargada y puesta.
3. Abre **Vigor** (la versión de depuración ya está instalada). Ten a mano un papel o un bloc de notas para apuntar.

**Parte 1: ¿se ve bien? (10 min)**
1. Abre Vigor y espera a que sincronice. Apunta: ¿conectó sola? ¿cuánto tardó (aprox.)?
2. **Hoy:** mira el reloj del día (arrastra el dedo), la cinta de días y las teselas. Apunta si hay cifras en 0, textos cortados o «Sin datos» donde esperabas datos. Pulsa Pulso y HRV: ¿hay un texto que diga que la HRV es de unos 10 latidos por minuto? ¿Aparece «aprox.»?
3. **Actividad:** abre la tarjeta semanal y una sesión. Las calorías pueden salir «—» (es lo esperado).
4. **Sueño:** puede salir vacía; es normal antes de la prueba de la noche.
5. **Dispositivo:** mira Perfil (pon tu edad real: afecta a las zonas), Efemérides GPS y el apartado **Privacidad y datos**.
6. Haz capturas de cada pantalla **solo si no muestran datos personales**; si dudas, descríbelas con palabras.

**Parte 2: sincronización (5 min)**
1. Pulsa sincronizar y comprueba que termina sin errores. Si aparece un aviso, apunta el texto exacto.
2. Opcional: durante la sincronización aleja la pulsera o apaga el Bluetooth 10 s. Debe avisar y recuperarse al volver. Apunta qué pasó.

**Parte 3: sueño (2 noches)**
1. Duerme con la pulsera apretada. Por la mañana, **antes de abrir Vigor**, abre G Band, sincroniza y apunta: hora de acostarte y levantarte, duración total y minutos profundo/ligero/despierto.
2. Cierra G Band, abre Vigor, sincroniza y mira Sueño. Apunta si aparece la noche y con qué duración.
3. En Dispositivo → Avanzado (depuración) lanza el volcado de sueño. No envíes los ficheros: solo tus notas.
4. Repite una segunda noche. Importante: si miras Hoy **antes de las 06:00** de una noche, debe decir «Noche en curso».

**Parte 4: grabar actividad sin el móvil (30 min)**
1. Inicia una actividad desde Vigor. Desconecta el Bluetooth del móvil. Camina 15 minutos.
2. Reconecta, sincroniza y mira Actividad: ¿aparece la sesión? Apunta duración y distancia (sin ruta ni lugares).
3. Opcional (E5): camina un tramo que conozcas (p. ej. 400 m) y compara distancia con G Band; cuenta 100 pasos a mano y compara.

**Parte 5: efemérides con la app cerrada (24 h)**
1. Cierra Vigor del todo (deslízala fuera de recientes). Deja el móvil con internet y la pulsera cerca durante un día.
2. Abre Dispositivo → Efemérides GPS y mira «Último envío» y si hay un error. Apunta lo que diga.

**Parte 6: exportar y borrar datos**
1. Dispositivo → Privacidad y datos → **Exportar mis datos**. Se abre el selector de compartir de Android (no hay carpeta que ver por USB). Elige una opción de bajo riesgo (p. ej. guardar en el móvil o enviártelo a ti) y apunta: ¿se abrió el selector? ¿la app elegida recibió los ficheros? Los ficheros contienen tus datos de salud: no los compartas con nadie más. Ten en cuenta que lo que elijas queda fuera del control de Vigor.
2. Sal de la pantalla y vuelve a entrar en Privacidad: la copia privada se borra sola. Apunta si el texto lo explica.
3. **Borrar todos mis datos** (haz esto el último): debe pedir confirmación, vaciar Hoy/Actividad/Sueño y decir que no borra la pulsera emparejada ni tu edad. Con la sincronización en curso el botón debe estar desactivado o avisar de «ocupado». Vuelve a sincronizar: los datos de la pulsera (hasta unas 7 h) reaparecen.
4. Borrar también elimina la copia privada de la exportación. La copia ya enviada a otra app hay que borrarla desde esa app.

**Parte 7: TalkBack (opcional, 15 min)**
1. Ajustes → Accesibilidad → TalkBack. En cada una de las 4 pantallas desliza a la derecha y apunta: ¿cada cifra se lee con su unidad y «aprox.»? ¿hay elementos sin nombre? ¿el orden es confuso? ¿se lee el aviso de «noche en curso» o de calidad baja? Desactívalo al acabar (en TalkBack, pulsa dos veces con dos dedos lo habitual es salir por Ajustes si te pierdes).
2. Texto grande: Ajustes → Pantalla → tamaño de fuente al máximo; apunta cortes o solapes por pantalla.

**Al acabar:** restaura el bloqueo de pantalla y desactiva «Depuración USB (ajustes de seguridad)».

**Cómo reportar si algo falla**
Para cada problema apunta: (1) pantalla; (2) qué hiciste; (3) qué esperabas; (4) qué pasó (texto exacto del aviso); (5) hora aproximada; (6) si se repite. Una captura sin datos personales ayuda; si no, descríbela. **No** envíes MAC, ubicaciones, rutas ni ficheros exportados. Si la app se cierra sola, dilo y la hora: el desarrollador mirará `logcat -s VIGORLOG`. Clasifica: crítico (se cierra o pierde datos), alto (cifra claramente mal), medio (texto/diseño), bajo (cosmético).

## (c) Lista priorizada v1.1+ (con motivo)
1. **P1 Documentación de usuario** (README, MANUAL, GLOSARIO, ARQUITECTURA, BASES_CIENTIFICAS) con las salvedades: sin ella la v1.0 no está completa.
2. **P1 Resultados de la guía** (pantallas, sueño, sin móvil, efemérides, borrado): desbloquean todo lo «verificado».
3. **P1 Decisión de sueño** tras las 2 noches (E6): es el mayor valor pendiente.
4. **P1 Tests de `BandClient`/`Worker`** y compilación release: riesgo en la ruta más crítica.
5. **P2 HRV ultracorta** (agregar ventanas, literatura): la medición de 10 latidos/min limita la fiabilidad (55).
6. **P2 Reconexión automática y compartir exportación** (si la ruta no es visible).
7. **P2 Textos completos de citas** (OMS ≥ 6 MET, Paluch, Chinoy…) por otra vía (36, 45, 60).
8. **P2 Contraste sobre Aurora/Glass y tema claro** (57).
9. **P2 SpO₂ y temperatura nocturnas** (E8/E9), uso de `oxygens`/`wear`.
10. **P2/P3 Alarmas, sedentarismo, buscar pulsera, cámara, notificaciones**: escriben en la pulsera, no verificables sin pantalla; sin valor de salud.
11. **P3** E11 (PPG crudo), iOS, esferas. Descartado: ECG, presión, glucosa, puntuaciones.

## (d) Riesgos residuales
- **Ningún comportamiento visual verificado desde la ronda 1:** posible fallo de UI o recorte no detectado por tests (Ahem oculta overflow).
- **Muestra mínima:** los supuestos de datos salen de una persona, una pulsera y ~2 días; `ppgs` 1/min solo es consistente.
- **HRV ultracorta, PPG, línea base propia:** cifras orientativas; 26,7 % de RR sin dato (origen desconocido) puede sesgar las noches con poca cobertura.
- **Efemérides y conexión:** Worker, backoff y caída de conexión solo en código; `BandClient` sin test.
- **Sueño:** sin estructura real confirmada; puede quedar «sin datos».
- **Privacidad:** el almacenamiento exportado queda sin cifrar y quizá inaccesible; el borrado no elimina la MAC ni la edad; el volcado de depuración no se ha comprobado ausente en release.
- **Ciencia:** casi todas las citas a nivel de resumen; umbrales propios (30 días, 300–2000 ms, 20 %, 70 % FCmáx, 20 % de cobertura) sin fuente; edad por defecto 35 distorsiona E4B si no se cambia.
- **Documentación de usuario ausente.**

---
## Corrección del coordinador (2026-11-20)
La afirmación de que "la documentación de usuario (README, ARQUITECTURA, MANUAL, GLOSARIO, BASES_CIENTIFICAS) sigue sin existir" y el criterio "documentación de usuario: no cumplido" son **incorrectos**: los cinco archivos existen (README.md, docs/ARQUITECTURA.md, docs/MANUAL_USUARIO.md, docs/GLOSARIO.md, docs/BASES_CIENTIFICAS.md) desde la ronda 1 y fueron actualizados en las rondas 3 y 4 por el Documentador. El supervisor los leyó mientras se reescribían. Estado correcto de ese criterio: **cumplido en código/documentación; pendiente de verificación humana** (descripciones de pantallas deducidas del código, no vistas en el móvil).

---
## Qué reportarme (checklist final)
- [ ] ¿Conectó sola y sincronizó sin errores? (texto exacto de cualquier aviso)
- [ ] Hoy/Actividad/Sueño/Dispositivo: cifras en 0, textos cortados o «Sin datos» inesperados; ¿aparece «aprox.» y el rótulo «índice del fabricante» en Estrés?
- [ ] Sueño: ¿aparece la noche? Duración frente a G Band (2 noches)
- [ ] Grabar sin móvil: ¿apareció la sesión? Duración y distancia
- [ ] Efemérides tras 24 h con la app cerrada: «Último envío» y errores
- [ ] Exportar: ¿se abrió el selector de compartir? ¿la app destino recibió los ficheros?
- [ ] Privacidad: ¿la copia se borra al reabrir la pantalla? ¿«Borrar todos» funciona y vuelve a llenarse al sincronizar?
- [ ] Opcional: TalkBack y texto grande (qué falla y en qué pantalla)
- [ ] Cualquier cierre inesperado (hora aproximada)

## Estado final v1.0 (candidata)
**Hecho (código y tests, sin verlo en pantalla):** `flutter analyze` limpio; 183 tests Flutter y 27 JVM en verde; release compila firmado con clave de depuración. Cerrados H1-H8 (DEV_004): carrera de borrado, exportación privada con selector de compartir y borrado de la copia, tiempo máximo de permisos, receptor Nordic no exportado, Estrés rotulado. Privacidad: sin copia de seguridad de Android, registro técnico en release con MAC enmascaradas, logcat solo en depuración. Documentación de usuario existente (ver corrección del coordinador).
**Lo verificará el usuario (§b):** todo lo visual desde la ronda 1, el selector de compartir y el borrado, sincronización y caída de conexión, sueño (2 noches), grabar sin móvil, efemérides con la app cerrada, TalkBack y texto grande. Antes de distribuir: firma de release propia y `applicationId` definitivo (backlog 62-63); regenerar el release (66).
**Queda para v1.1+:** lo de §c (decisión de sueño tras E6, tests de `BandClient`/`Worker`, HRV ultracorta, reconexión automática, textos completos de citas, contraste sobre Aurora/Glass, SpO₂ y temperatura nocturnas, alarmas/notificaciones, PPG crudo, iOS). Descartado: ECG, presión, glucosa, puntuaciones.
