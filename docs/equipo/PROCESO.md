# Ciclo de trabajo

Cada ronda sigue estos pasos. **Al cerrar cada ronda el Supervisor hace la "ronda de descubrimiento"** (paso 6): comprobar si hay más cosas que hacer.

1. **Planificar.** El Supervisor lee `BACKLOG.md` y `ESTADO.md` y elige el siguiente lote (P0 → P1 → P2).
2. **Investigar.** Los investigadores auditan sensores y literatura para los puntos del lote (con enlaces verificados) y proponen qué implementar y qué descartar.
3. **Desarrollar.** El Desarrollador implementa con tests, sin tocar documentos de otros.
4. **QA.** QA revisa el código y la app, y reporta con severidad (crítico/alto/medio/bajo).
5. **Documentar.** El Documentador actualiza README, arquitectura, manual y glosario; el Supervisor actualiza `ANALISIS.md` con las fuentes nuevas.
6. **Revisión del Supervisor + ronda de descubrimiento.** Checklist obligatorio:
   - [ ] ¿Cada sensor de la pulsera (PPG, SpO₂, IMU 6 ejes, GPS, temperatura, etc.) está aprovechado al máximo? ¿Qué campos del SDK recibimos y **no** usamos?
   - [ ] ¿Hay estudios más recientes (2020–2026) sobre las mediciones con estos sensores? ¿Cambian algún análisis?
   - [ ] ¿Cada análisis de la app tiene fuente verificada y su limitación escrita?
   - [ ] Deuda técnica, errores de QA abiertos, rendimiento, batería.
   - [ ] Accesibilidad (Semantics, contraste, escala de texto) y privacidad.
   - [ ] Funciones de G Band u otras apps del sector que aún no tenemos y tienen sentido.
   - [ ] Documentación al día.
   - Resultado: se **añaden** al backlog los puntos nuevos y se decide la siguiente ronda.

Los informes de cada ronda van en `docs/equipo/informes/` con numeración (`REVISION_001.md`, `QA_001.md`, …).
