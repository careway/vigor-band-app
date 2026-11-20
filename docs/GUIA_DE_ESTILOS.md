# Guía de estilos — Vigor "Aurora" (v2)

Diseño propio (no replica la marca ni los gráficos de G Band). Tokens implementados en `lib/theme/tokens.dart`; si algo cambia aquí, cambia allí.

## 1. Principios
1. **El dato primero.** Cada pantalla responde a una pregunta ("¿cómo dormí?"); la cifra principal es lo más grande.
2. **Honestidad.** Estimaciones se rotulan "aprox."; sin datos → estado vacío explicado, nunca ceros inventados.
3. **Silencioso.** Tareas de fondo (efemérides, sincronización) no muestran avisos ni notificaciones.
4. **Calma visual.** Superficies planas, sin sombras; el color solo codifica la métrica.

## 2. Color (oscuro primero; objetivo WCAG AA: texto ≥ 4,5:1, gráficos ≥ 3:1 — texto medido por cálculo en DEV_003 sobre fondo sólido, ver §7; gráficos y translúcidos no medidos)
Identidad **Aurora**: fondo tinta profundo con un resplandor lento que cambia de tono según la zona de pulso actual; superficies de cristal (relleno translúcido + borde de 1 px, sin desenfoque para no gastar batería).
| Token | Oscuro (principal) | Claro | Uso |
|---|---|---|---|
| `bg` | #0A0E13 | #F4F6FB | fondo |
| `surface` | #141A21 | #FFFFFF | tarjetas de cristal |
| `surfaceHi` | #1D2630 | #E8EDF6 | chips, pistas |
| `text` | #F2F6F8 | #0F172A | principal |
| `muted` | #9AA9B5 | #475569 | secundario (≥ 4,5:1) |
| `accent` | #5EEAD4 | #0F766E | acción, selección |
| `accent2` | #A78BFA | #6D28D9 | segundo tono del resplandor |
| `danger` | #FDA4AF | #B3261E | errores, desconexión |

Color por métrica (siempre con icono **y** etiqueta):
| Métrica | Oscuro | Claro |
|---|---|---|
| Pasos | #4ADE80 | #15803D |
| Pulso | #FB7185 | #BE123C |
| SpO₂ | #38BDF8 | #0369A1 |
| Variabilidad (HRV) | #E879F9 | #A21CAF |
| Estrés (índice fabricante) | #FBBF24 | #B45309 |
| MET / energía | #FB923C | #C2410C |
| Temperatura | #2DD4BF | #0F766E |
| Sueño | #818CF8 | #4338CA |
| Experimental (glucosa, componentes) | #94A3B8 (gris a propósito) | #475569 |

**Regla de honestidad visual:** las métricas experimentales usan gris neutro, nunca rojo/verde, y nunca llevan rangos de "normal/alto/bajo".

## 3. Tipografía (fuente del sistema, Roboto en Android)
| Rol | Tamaño / peso | Uso |
|---|---|---|
| `display` | 40 / 700 | cifra principal de una tarjeta |
| `title` | 22 / 600 | título de pantalla |
| `heading` | 16 / 600 | título de sección |
| `body` | 14 / 400 | texto |
| `caption` | 12 / 400 | notas, fuentes, unidades |
Cifras con `tabularFigures` para que no "bailen" al cambiar.

## 4. Espaciado y forma
- Rejilla de **4 dp**: 4 · 8 · 12 · 16 · 24 · 32. Margen lateral de pantalla 16.
- Radios: tarjeta 24, chip/botón 14, barras de gráfico 4.
- Sin sombras; cristal = relleno translúcido + borde de 1 px al 8 % de blanco.
- Zonas táctiles ≥ 48 × 48 dp.

## 5. Componentes
- **Reloj del día (Dial 24 h):** anillo exterior = actividad por franjas de 30 min; anillo medio = pulso en polar; marcador de "ahora". **Arrastrar el dedo** por el dial mueve un cursor de hora y abre una cápsula con *todas* las métricas de ese minuto (pulso, SpO₂, HRV, estrés, MET, temperatura…). Vibración suave al cambiar de franja.
- **Cinta de días:** 7 mini‑anillos (progreso de pasos); tocar cambia el día.
- **Bento:** rejilla de teselas de dos tamaños; cada tesela = icono + etiqueta, cifra con *count‑up*, mini‑visualización propia (sparkline, medidor, barras) y se abre con transición *Hero* a su detalle.
- **Detalle de métrica:** cifra grande, gráfico de 24 h con cursor táctil, mín/media/máx, línea base personal cuando existe, nota de fuente.
- **Corazón vivo:** el icono de pulso late al ritmo de la última lectura (se desactiva con "reducir animaciones").
- **Resumen en una frase** bajo el título, generado por reglas locales a partir de los datos.
- **Experimental:** sección plegada con aviso fijo; sin colores de juicio.
- **Navegación:** píldora flotante de 4 destinos.
- **Estado vacío / conexión / notas de fuente:** como en la v1.

## 6. Movimiento
Resplandor Aurora: bucle de 24 s, muy lento. Count‑up 600 ms, transiciones Hero 350 ms, `easeOutCubic`. Todo se desactiva con "reducir animaciones" del sistema.

## 7. Accesibilidad (estado real tras DEV_003, 2026-11-20; nada probado en pantalla)
**Hecho (código y tests; no probado con TalkBack):**
- `Semantics` con etiqueta completa en: teselas, cinta de días, cifra de pasos y de pulso, y gráficos (`describeSeries`: "Pulso: mín X, media Y, máx Z unidad").
- Reloj del día: control ajustable (aumentar/disminuir por franjas de 30 min) y botón "Ver datos del día por franjas" con una tabla por horas (alternativa no táctil).
- "Reducir animaciones" respetado en Aurora, count‑up, corazón, transiciones, `AnimatedSwitcher` y cinta de días.
- Zonas táctiles: objetivo ≥ 48 dp.

**Añadido en DEV_002 (solo tests de widget mínimos y análisis estático):** Semantics con la frase completa en las tarjetas de noche (pulso en reposo, HRV), la tarjeta semanal, el pie de cobertura y el punto «Pocos datos hoy». Componentes nuevos con tokens existentes (`Glass`, `Panel`, `MetricHeader`, `BigValue`), sin colores de juicio, sin animaciones nuevas. Menú «Avanzado (depuración)» solo en `kDebugMode`.

**No hecho / no verificado (no afirmar más):**
- No es cierto aún que *cada* cifra tenga `Semantics`: QA_001 contó cero en detalle de métricas, Actividad, Sueño y Dispositivo antes de DEV_001, y DEV_001 solo declara las superficies de arriba. DEV_002 añade las tarjetas nuevas; sigue sin declararse para Actividad (resto), Sueño y Dispositivo.
- **Escala de texto del sistema (hasta 200 %): no verificada.** Hay alturas y anchos fijos (ruta 240 dp, stepper 72 dp, etiquetas de zona 64 dp) y etiquetas de gráfico fijas a 10 px que no escalan. Hasta probarlo, no se declara compatible.
- **Contraste: no medido.** Los colores de las tablas de §2 son el diseño; no hay medición ni herramienta que lo confirme.
- **TalkBack real: no probado.** Tampoco se ha comprobado el orden de lectura.
- Tema claro: existe, sin revisar (ESTADO.md). El tema está fijado en oscuro.
- El encabezado plegable "Experimental" mide ≈ 40 dp (por cálculo de QA_001): menos que el mínimo de 48 dp.

**Añadido en DEV_003 (tests y cálculo; móvil bloqueado, sin pantalla):**
- Tests de widget a texto ×1,0 y ×2,0 en 360×640, 360×780 y 412×915 (Hoy, Actividad, Sueño, Dispositivo, sesión, detalles de pulso y HRV): sin excepciones salvo overflow. **Límite:** flutter_test usa la fuente Ahem (más ancha que Roboto) y los overflow se ignoran; **no hay evidencia de ausencia de recortes reales**.
- `androidTapTargetGuideline` y `labeledTapTargetGuideline` pasan en Hoy y Dispositivo. El encabezado «Experimental» tiene ahora `minHeight: 48`.
- **Contraste medido por cálculo WCAG** (comprobado con negro/blanco = 21): en ambos temas, tokens de texto y métrica ≥ 4,5:1 sobre `bg` y `surface` y ≥ 3:1 sobre `surfaceHi`; botón relleno ≥ 4,5:1 sobre `accent`. No hizo falta cambiar colores. **Límite:** se supone fondo sólido; Glass/Aurora translúcidos y degradados no medidos. Esto sustituye al «contraste no medido» anterior solo en ese alcance.
- Semantics: etiqueta de la tarjeta HRV incluye el aviso de calidad y la noche en curso; panel de privacidad con botones con nombre y resultado como región viva.
- **Sigue sin probar:** TalkBack real y orden de lectura, texto 200 % real, tema claro (existe, sin revisar), Semantics completo en Actividad/Sueño/Dispositivo, diálogo de borrado en pantalla.

## 8. Voz (ES)
Frases cortas, tú. Unidades SI (km, kcal, bpm, %). Fechas "lun 18 nov". Sin jerga ("HRV" se explica como "variabilidad cardiaca").

## 9. Navegación
Barra inferior con 4 destinos: **Hoy · Actividad · Sueño · Dispositivo**. Una acción primaria por pantalla.

## 10. Estado real tras DEV_004 (2026-11-20)
- 183 tests Flutter y 27 JVM en verde; `flutter analyze` limpio; release compila (firmado con clave de depuración, solo para pruebas).
- **Nada verificado en pantalla desde la ronda 1** (móvil bloqueado): todo lo de esta guía (colores, componentes, accesibilidad §7) es diseño y código, no observación.
- Cambios de UI en DEV_004: tesela de Estrés con rótulo visible «índice del fabricante · aprox.» (y Semantics equivalente); panel «Privacidad y datos» con textos nuevos (selector de compartir de Android; el destino elegido queda fuera del control de la app).
- Sin cambio en §7: siguen sin probar TalkBack, texto 200 % real, tema claro y contraste sobre fondos translúcidos.
