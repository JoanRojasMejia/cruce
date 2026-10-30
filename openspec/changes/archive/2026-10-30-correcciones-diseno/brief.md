# Brief · correcciones de la revisión de diseño

Rama `fix/correcciones-diseno`. Un commit por corrección, en este orden, con mensaje en español y sin atribución de IA.
Pruebas al final de cada corrección: `cd ios/Packages/CruceCore && swift test`, `supabase test db` (desde la raíz),
`swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore` y `xcodebuild … build` si toca la app
(la app no tiene target de pruebas). `go test ./...` solo si toca `backend/`.

## Decisiones de Joan (29 oct 2026)

- D1. "si solo el que crea el parche lo cierra" → solo quien creó el parche puede cerrarlo.
- D2. "El formato sigamoslo manejando asi" → los códigos se quedan como hoy: `CRZ-` + 4 dígitos (vence en 24 h);
  `PCH-` y `SOY-` + 6 caracteres del alfabeto sin ambiguos. No se cambia la generación.
- D3. "El tercer punto si me parece que esta bien" → con un solo cruce, el engrane abre "Ajustes del cruce", que
  termina con una fila "Tu cuenta" que abre los Ajustes de la cuenta. "Invitar a alguien" va en Ajustes de la cuenta.
- D4. "sigamos con esa misma decision del 27 de octubre" → un cruce cerrado sigue sin aceptar gastos NI pagos
  ("nadie anota ni salda"). De la corrección 2 solo se implementa "Saldar primero" en la confirmación de desvincular
  (cuando el saldo no es $0). Un parche cerrado sigue aceptando pagos, como hoy. No se cambia `enforce_open_cruce`.
- D5. Enlace universal: necesita la membresía paga de Apple y un dominio. En su lugar, esquema propio
  `cruce://codigo/<CÓDIGO>` que abre "Tengo un código" con el campo lleno. El enlace universal queda para el CP13.
- D6. Deshacer al borrar un gasto del parche: la app espera 5 s antes de enviar el borrado (sin función SQL nueva).
- D7. Colores: paleta de 6 (amarillo, violeta, verde, durazno, rosado, lima). Perfiles existentes: el color que hoy
  tienen en su cruce más reciente (o amarillo si no tienen). Perfiles nuevos: uno al azar de la paleta. Personas sin
  la app: el siguiente color libre dentro del parche. El color se cambia en Tu perfil.
- D8. Con un solo cruce, el inicio (que es ese cruce) sigue mostrando "Tus parches"; la sección se quita solo cuando
  el cruce se abre desde "Tus cruces".

## Reglas que no se negocian

Pesos enteros (`$30.000`), signo menos `−` (U+2212), redondeo `(monto*pct+50)/100`, el saldo se calcula y nunca se
guarda, la dirección de una deuda nunca solo con color. Textos en español de Colombia, mismo tono. Solo tokens de
`ios/Cruce/DesignSystem/`. Sin dependencias nuevas. Migraciones nuevas y aditivas (nunca editar una aplicada). Las
reglas de negocio van en la base o en el dominio (CruceCore), nunca solo en la vista.

## Correcciones (texto de Joan)

### Reglas de negocio

**1. "Pasar al cruce" al cerrar un parche (pantallas 39 y 46)**
- Hoy: muestra "Le debes $35.000 a Jesús" aunque Joan tiene +$47.000 en el parche y en "Para saldar" no hay ningún pago entre Joan y Jesús.
- Debe pasar:
  - La oferta sale **solo** de las transferencias del plan "Para saldar" entre dos personas que además comparten un cruce activo. El monto y la dirección son los de esa transferencia.
  - Si no hay ninguna, la pregunta no aparece.
  - Pasar la deuda crea un movimiento en el cruce y salda esa transferencia en el parche, en una sola operación atómica (función SQL).
  - La otra persona debe aceptarlo. Mientras no acepta, queda como "por confirmar" en los dos lados. Si lo rechaza, la deuda sigue en el parche.
- Hecho cuando: hay pruebas SQL con el ejemplo de Santa Marta (no se ofrece nada entre Joan y Jesús) y con un caso que sí aplica, incluyendo aceptar y rechazar.

**2. Misma regla para cruce cerrado y parche cerrado (27, 32, 45)** — ver D4: solo "Saldar primero" en desvincular (32).

**3. Color fijo por persona (24, 33, 37)**
- Hoy: el color del avatar depende del rol en cada cuenta. Por eso Ana sale amarilla en un lado y verde en otro, y Joan amarillo en uno y violeta en otro.
- Debe pasar:
  - Cada persona tiene un color fijo guardado en `profiles`, que se asigna una vez al crear el perfil y se puede cambiar en Tu perfil (30).
  - Las personas sin la app también tienen color fijo dentro del parche.
  - La regla rosa/verde se queda **solo** para el Tike: quien creó el cruce ve rosa y quien se unió ve verde.
- Hecho cuando: la misma persona se ve del mismo color en Tus cruces, en un cruce, en un parche y en los tickets.

**4. Varios pagadores con monto por cada uno (41, 42)**
- Hoy: se puede marcar "Jesús y tú" como pagadores, pero no hay dónde decir cuánto puso cada uno.
- Debe pasar:
  - Si hay más de un pagador, aparece "¿Cuánto puso cada uno?", con un campo por pagador.
  - Por defecto el monto se reparte en partes iguales.
  - No se puede guardar hasta que la suma dé el total, y se muestra "Faltan $X" o "Sobran $X".
  - El modelo guarda los montos por pagador.
- Hecho cuando: el Hospedaje de Santa Marta ($600.000, Jesús $400.000 y Joan $200.000) produce los saldos +47.000 / +125.000 / 0 / −172.000, con prueba.

**5. Tope o aviso en pagos del parche (37, 44)**
- Hoy: se puede anotar que Carlos le pagó $50.000 a Joan cuando el plan solo dice $47.000. Al confirmarlo, Joan queda debiendo $3.000.
- Debe pasar:
  - Si el pago supera lo que el plan dice entre esas dos personas, se muestra un aviso: "Carlos te debe $47.000 en el parche. Anotaste $50.000". Se puede corregir o seguir de todas formas.
  - En "¿A quién le pagó?" no aparece quien pagó.
- Hecho cuando: el aviso aparece en anotar y en confirmar.

**6. Quién puede cerrar un parche (45)** — ver D1.
- Solo quien creó el parche puede cerrarlo. Los demás ven "Pídele a <nombre> que lo cierre".
- Cerrar queda en la actividad.

### Pantallas

**7. Ajustes separados (19, 25)** — ver D3.
- Hoy: Ajustes mezcla cosas de la cuenta con cosas de un solo cruce, y solo conoce a Jesús.
- **Ajustes** (desde el engrane de Tus cruces) tiene: perfil, notificaciones, recordatorios, cerrar sesión y versión.
- **Ajustes del cruce** (desde el engrane de cada cruce) tiene: con quién es y desde cuándo, moneda, reparto por defecto, exportar CSV y desvincular.

**8. Detalle del parche más corto (37, 38)**
- Hoy: la pantalla mide unos 1.900 px y tiene siete secciones.
- Arriba, en este orden: saldo, acciones, pagos por confirmar, "Para saldar" y saldos.
- Gastos va debajo.
- "Los del parche" y el código del parche pasan a una hoja que se abre con el botón de compartir del encabezado.
- La actividad se mueve a su propia vista, con el indicador "sin ver" en el encabezado.

**9. Llegada con código PCH y SOY (36)**
- Hoy: no hay pantalla después de entrar con esos códigos.
- **PCH:** pantalla "Entraste a <parche>", con las personas, tu saldo y un botón "Ver el parche".
- **SOY:** pantalla "Ahora eres <nombre> en <parche>", donde el avatar punteado pasa a sólido. Indica que tus gastos y pagos te siguen.
- Las dos llevan ilustración (il-12 y il-13).

**10. Una sola pantalla de código (15, 23, 36)** — ver D2 y D5.
- Queda solo "Tengo un código" (36), que detecta el prefijo mientras se escribe.
- La lista de prefijos no se muestra hasta que hay un error.
- Errores separados para código vencido, ya usado, tuyo e inexistente.
- Abrir un enlace con el código llena el campo solo.

**11. Cruces cerrados aparte (26)**
- Hoy: "Con J…" se corta por la etiqueta "Cerrado".
- Los cruces cerrados van en una sección "Cerrados" al final de Tus cruces, en tono gris, y el nombre no se corta.

**12. Sin la lista de parches dentro de un cruce (25)** — ver D8.
- El detalle de un cruce no repite "Tus parches", que ya está en Tus cruces.

### Detalles

**13. Sin conexión en el parche (40)**
- Hay un solo aviso en vez de dos.
- Los movimientos sin enviar llevan el ícono de reloj y el texto "Sin enviar".
- "Por confirmar" se queda con su estilo propio. Hoy los dos estados usan el mismo borde punteado.

**14. Editar gasto por consumo (41, 42)**
- El título "Lo que paga cada quien" cambia a "Lo que le toca a cada quien".
- Cada ítem puede tener un nombre opcional, que aparece en el ticket.
- Se muestra "Faltan $X por repartir" mientras los ítems no sumen el monto.
- "Borrar el gasto" pasa a ser un botón de texto, debajo de "Guardar cambios".

**15. Formas de reparto (41)**
- Se ven "Iguales entre todos" y "Otra forma de repartir".
- "Otra forma de repartir" abre las demás opciones, cada una con un ejemplo de una línea. "Por partes" en especial necesita el suyo.

**16. Borrar gasto (43)** — ver D6.
- Después de borrar aparece un aviso con "Deshacer" durante unos 5 segundos.

**17. Código por correo (21)**
- `textContentType(.oneTimeCode)` para que el código se llene solo desde Mail (ya existe).
- "Pedir otro código" queda desactivado con cuenta regresiva de 30 s.

**18. Tickets (47–49)**
- "Compartir el ticket" comparte una imagen PNG del ticket (con `ImageRenderer`) y además el texto (ya existe).
- El ticket de Carlos incluye el enlace para entrar con su código SOY (`cruce://codigo/SOY-…`, ver D5).
- Cómo pagarle a cada quien (Nequi o llave): el dato no existe; queda anotado en el ROADMAP.

### Ilustraciones

1. Espacios en `Assets.xcassets/Illustrations` con nombre fijo: `il-09-revisa-correo`, `il-10-nuevo-parche`,
   `il-11-parches-vacio`, `il-12-llegaste-parche`, `il-13-lugar-tuyo`, `il-13-lugar-tuyo-mini`, `il-14-cerrar-parche`,
   `il-15-ticket-pendiente`, `il-16-pasar-cruce`, `il-17-cruce-cerrado`, `il-18-parche-saldado`,
   `il-19a-grupo-te-deben`, `il-19b-grupo-debes`, `il-20-pago-por-confirmar`, `il-21-codigo-invalido`.
2. Cada nombre en el enum `Illustration`. Si el asset todavía no existe, se usa la ilustración que hoy usa esa pantalla.
3. Uso y tamaño:

| Ilustración | Pantalla y tamaño |
|---|---|
| il-09 | Escribe el código, entre las casillas y "Entrar" · 180 pt |
| il-10 | Nuevo parche · 200 pt |
| il-11 | Parches vacío · 260 pt |
| il-12 | Llegada con PCH · 260 pt |
| il-13 | Llegada con SOY · 260 pt. La versión mini va en el bloque SOY del ticket · 64 pt |
| il-14 | Cerrar el parche · 200 pt |
| il-15 | Esquina del ticket pendiente, individual y de grupo · 72 pt. El ticket a paz y salvo sigue con il-07 |
| il-16 | Pasar al cruce · 200 pt. Versión de 72 pt en la tarjeta de la pantalla de parche cerrado |
| il-17 | Tarjeta de saldo del cruce cerrado · 140 pt, y confirmación de desvincular · 120 pt |
| il-18 | Tarjeta de saldo del parche cuando todos quedan en $0 · 140 pt |
| il-19a / il-19b | Tarjeta de saldo del parche (te deben / debes) · 140 pt |
| il-20 | Tarjeta "Pagos por confirmar" · 48 pt |
| il-21 | Error de código · 120 pt |

4. Los tickets y todo lo de parches usan ilustraciones neutrales. La regla rosa/verde aplica solo a los cruces entre dos personas.

## Log

- L1 (29 oct 2026): pedido original de Joan con las 18 correcciones y las ilustraciones (texto de arriba).
- L2 (29 oct 2026): decisiones D1–D4 de Joan; D5–D8 propuestas en el plan y aceptadas con "Con eso empecemos a implementarlo".
