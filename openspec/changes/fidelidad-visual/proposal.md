# Proposal

## Why

La app ya corre (CP0), pero varias pantallas no coinciden con el diseño cerrado de la opción A y hay huecos de usabilidad: no se puede deslizar para volver y no se ha probado en pantallas pequeñas ni grandes. El CP1 deja cada pantalla igual a su captura en `docs/design/screens/` antes de conectar el backend.

## What Changes

- Comparar cada pantalla con su captura y corregir espaciados, tamaños, colores e íconos usando solo los tokens de `DesignSystem`.
- Diferencias ya encontradas en el recorrido del CP0:
  - Inicio: el botón de ajustes usa un engranaje y el diseño un sol; "Ver todo" va subrayado; "Domicilio Rappi" usa el ícono de comida y el diseño una bolsa en durazno; el subtítulo de las filas parte la fecha en dos líneas.
  - Agregar movimiento: la vista previa "Ahora: …" queda tapada por el teclado numérico; con el teclado del sistema abierto el teclado numérico sigue visible y la pantalla se comprime.
  - A paz y salvo: el texto para compartir dice "$20.000 el hoy, vie 23 de oct".
- Recuperar el gesto de deslizar para volver con la barra de navegación oculta.
- Revisar en iPhone SE y iPhone Pro Max, con scroll donde haga falta.
- Definir y probar el límite de Dynamic Type.
- Animación de presionar en los botones (la sombra baja a 0), verificada en un dispositivo.

## Capabilities

### New Capabilities
- `navegacion`: cómo se vuelve a la pantalla anterior.
- `adaptacion-pantalla`: comportamiento en tamaños de pantalla y tamaños de texto distintos.

### Modified Capabilities

## Impact

- Código: vistas en `ios/Cruce/Screens/` y componentes en `ios/Cruce/Components/`; tokens en `ios/Cruce/DesignSystem/` solo si el diseño lo pide (y entonces también `docs/diseno.md`).
- Sin cambios en el backend, la base de datos ni las dependencias.
