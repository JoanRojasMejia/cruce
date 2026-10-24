# Tasks

## 1. Comparar contra el diseño

- [x] 1.1 Comparar cada pantalla con su captura en `docs/design/screens/` y anotar las diferencias en este archivo (verificado: 20 capturas tomadas con `-screen <nombre>` en Debug y comparadas contra su PNG; lista abajo)

## 2. Corregir diferencias visuales

- [x] 2.1 Inicio: "Ver todo" subrayado (el `.underline()` no llega al texto del `Button`), subtítulo de las filas en una línea, "Pagarle a Jesús" sin desbordarse, estado vacío con el botón abajo y `$0` más pequeño (verificado: capturas de `homeTheyOwe`, `homeYouOwe` y `homeEmpty` contra 03, 04 y 02; el subtítulo con fecha sigue en dos líneas, igual que en el diseño 04)
- [x] 2.2 Agregar movimiento: la vista previa "Ahora: …" visible y el teclado numérico oculto mientras se escribe el concepto (verificado: en iPhone 16 todo entra sin scroll, como `05-Agregar.png`; al escribir el concepto solo queda el teclado del sistema. Las teclas se ven de 40 pt y conservan 44 pt de área táctil)
- [x] 2.3 A paz y salvo: corregir el texto para compartir "el hoy" (verificado: `DateTextTests` en rojo y luego en verde; el texto queda "… $20.000 el vie 23 oct.")
- [x] 2.4 Tipografía y fechas en toda la app: interlineado de unos 22 pt en párrafos `body`/`bodyLarge`; fechas "14 oct" sin "de" (verificado: `DateTextTests` y capturas)
- [x] 2.5 Botones: estilo de texto configurable (16/800 cuando van lado a lado: "Compartir"/"Copiar", "Agregar gasto"/"Pagarle a Jesús"), una sola línea con escala mínima, color de sombra configurable (Apple con sombra amarilla) y estado deshabilitado sin aclarar borde ni sombra (verificado: capturas de `invite`, `homeYouOwe`, `signUp`, `add`)
- [ ] 2.6 Gasto guardado: hoja más baja con fondo oscurecido, agarrador negro grueso y borde superior; cajas "Antes/Ahora" de igual altura y con relleno blanco cuando el diseño lo pide (verificado: capturas de `saved`, `delete`, `settle`, `offline`)
- [ ] 2.7 Historial: subtítulo "Pagó Joan · $36.000 · 50/50", filtros de quién pagó con mini avatar, sin check en "Todas" (verificado: captura de `history` contra 07)
- [ ] 2.8 Detalle, Eliminar, Saldar, Éxito y Sin conexión: pie con hora ("Lo anotó Joan hoy a la 1:16 p. m."), "¿Cómo te pagó?", chips de medio de pago a lo ancho del contenido, confeti y formas de Éxito (verificado: capturas contra 17, 18, 08, 09 y 10)
- [ ] 2.9 Onboarding, registro, invitar, unirse y conectados: posición de los círculos, texto legal subrayado, conector punteado, saltos de línea de los títulos, confeti y forma verde (verificado: capturas contra 01, 11, 12, 13, 14, 15 y 16)
- [ ] 2.10 Ajustes: ícono de "Desvincular" (cuadro rosa con borde y X negra), íconos de ancho fijo, "desde 14 oct" (verificado: captura de `settings` contra 19)

## 3. Navegación

- [x] 3.1 Recuperar el gesto de deslizar para volver con la barra de navegación oculta (verificado en el simulador: deslizar desde el borde en el historial vuelve al inicio; el gesto se activa en la raíz y en cada destino de la pila)

## 4. Tamaños de pantalla y texto

- [ ] 4.1 Revisar en iPhone SE y iPhone Pro Max: nada cortado y con scroll donde haga falta (verificado: capturas en los dos simuladores)
- [ ] 4.2 Limitar Dynamic Type a `.accessibility1` (decidido por Joan el 23 oct 2026) y probarlo (verificado: capturas con el tamaño máximo)

## 5. Botones

- [ ] 5.1 Animación de presionar (la sombra baja a 0), verificada en un dispositivo físico

## Diferencias encontradas (1.1)

Alta = se nota a simple vista; Baja = matiz de espacio o forma.

- **Transversal:** párrafos con interlineado de 17 pt contra 22 pt del diseño (Alta); fechas "14 de oct" contra "14 oct" (Alta); íconos de categoría con SF Symbols gruesos contra contorno fino (Baja).
- **Onboarding 1 y 3:** círculo rosa unos 35 pt más arriba (Baja); círculo verde desplazado unos 80 pt a la derecha (Alta).
- **Registro:** "Continuar con Apple" sin sombra amarilla (Alta); "Términos" y "Política de privacidad" sin subrayar ni en tinta (Alta).
- **Invitar:** "Compartir" más grande que "Copiar" (Alta); conector Jo–? sólido en vez de punteado (Baja).
- **Unirse:** el título parte "Únete con / un código" (Baja); botón deshabilitado con borde y sombra aclarados (Baja).
- **Conectados:** falta el confeti rosa y la forma verde va más abajo (Baja).
- **Inicio vacío:** el botón no va abajo y "$0" es más grande (Alta).
- **Inicio:** "Ver todo" sin subrayar (Alta); la fecha del subtítulo baja de línea (Alta); "Pagarle a Jesús" se desborda (Alta).
- **Agregar:** el teclado tapa la vista previa (Alta); el título es más grande (Baja).
- **Gasto guardado:** hoja más alta, sin fondo oscurecido, agarrador y borde distintos (Alta); cajas "Antes/Ahora" de alturas distintas (Baja).
- **Historial:** subtítulo "Pagaste …" contra "Pagó Joan · …" (Alta); filtros con cuadritos en vez de mini avatares (Alta); check en "Todas" (Baja).
- **Detalle:** el pie no dice la hora (Alta).
- **Eliminar:** caja "Ahora" sin relleno blanco; diálogo unos 45 pt más abajo (Baja).
- **Saldar:** "¿Cómo se pagó?" contra "¿Cómo te pagó?" (Alta); chips de igual ancho (Baja).
- **Éxito:** falta el confeti blanco y el polígono violeta va más abajo (Baja).
- **Sin conexión:** caja de pendientes sin relleno blanco (Baja).
- **Ajustes:** ícono de "Desvincular" distinto (Alta); íconos de ancho variable y "desde el 13 de oct" (Baja).

Fuera del CP1:
- "Jesús ya lo vio" en el detalle necesita confirmación de lectura desde el backend.
- Íconos de categoría con el estilo de contorno del diseño: requieren un set de íconos propio. Por ahora se mantienen los SF Symbols.

Pendiente de decisión de Joan: el botón de ajustes del inicio. El diseño muestra un sol en la vista de Joan (03 y 04) y el avatar en la vista de Jesús (20); la app usa un engranaje en las dos.
