# Spec Delta

## Purpose

Definir cómo la persona vuelve a la pantalla anterior dentro de la app.

## ADDED Requirements

### Requirement: Deslizar para volver
Toda pantalla que se abre encima de otra dentro de la navegación principal SHALL poder cerrarse deslizando desde el borde izquierdo, además de con su botón de volver, aunque la barra de navegación del sistema esté oculta.

#### Scenario: Volver desde el detalle
- **WHEN** la persona está en el detalle de un movimiento y desliza desde el borde izquierdo
- **THEN** vuelve a la pantalla desde la que abrió el detalle
