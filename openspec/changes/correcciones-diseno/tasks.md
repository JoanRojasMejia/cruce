## 1. Reglas de negocio

- [x] 1.1 Pasar al cruce desde "Para saldar", con propuesta, aceptar y rechazar (migración, pgTAP `10_pasar_al_cruce`, CruceCore y pantallas 39/46). Ruta: escritor delegado.
- [x] 1.2 "Saldar primero" en la confirmación de desvincular cuando el saldo no es $0 (D4). Ruta: escritor delegado.
- [x] 1.3 Color fijo por persona en `profiles` y en quien está sin la app; rosa o verde solo para el Tike (migración, pgTAP `11_colores`). Ruta: escritor delegado.
- [x] 1.4 Varios pagadores: "¿Cuánto puso cada uno?", partes iguales por defecto, "Faltan $X"/"Sobran $X" y prueba de Santa Marta. Ruta: escritor delegado.
- [x] 1.5 Aviso de pago de más al anotar y al confirmar; quien pagó no aparece en "¿A quién le pagó?". Ruta: escritor delegado.
- [x] 1.6 Solo quien creó el parche lo cierra; "Pídele a <nombre> que lo cierre" (migración, pgTAP `12_cerrar_parche`). Ruta: escritor delegado.

## 2. Ilustraciones

- [x] 2.1 Quince espacios en el catálogo, casos en `Illustration` con respaldo a la ilustración actual, y uso por pantalla.

## 3. Pantallas

- [x] 3.1 Ajustes de la cuenta y Ajustes del cruce (D3).
- [x] 3.2 Detalle del parche más corto: hoja de "Los del parche" y código, actividad en su propia vista.
- [x] 3.3 Llegada con `PCH-` y `SOY-`.
- [x] 3.4 Una sola pantalla "Tengo un código", errores separados y enlace `cruce://codigo/…` (D2, D5).
- [ ] 3.5 Cruces cerrados en la sección "Cerrados".
- [ ] 3.6 El cruce abierto desde la lista no repite "Tus parches" (D8).

## 4. Detalles

- [ ] 4.1 Un solo aviso sin conexión y "Sin enviar" con reloj; "Por confirmar" con estilo propio.
- [ ] 4.2 Gasto por consumo: título, nombre del ítem (migración), "Faltan $X por repartir" y "Borrar el gasto" como texto.
- [ ] 4.3 Formas de reparto: "Iguales entre todos" y "Otra forma de repartir" con ejemplos.
- [ ] 4.4 Deshacer al borrar un gasto durante 5 s (D6).
- [ ] 4.5 Cuenta regresiva de 30 s para "Pedir otro código".
- [ ] 4.6 Enlace del código `SOY-` en el ticket; Nequi o llave anotado en el ROADMAP.

## 5. Cierre

- [ ] 5.1 Recorrido en el simulador de los flujos pedidos.
- [ ] 5.2 `CLAUDE.md`, `docs/ROADMAP.md` y specs; archivar el cambio.
