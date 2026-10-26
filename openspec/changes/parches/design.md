# Design

## Context

El cruce de dos (`ledgers`, `ledger_members` con máximo 2, `movements`, `SplitRule` con un solo porcentaje) no se toca. Los parches son un modelo aparte, con las mismas reglas de producto: el saldo nunca se guarda (se calcula), dinero en enteros (`Int`/`bigint`), borrado suave y texto en español con "tú" y el vocabulario de `CLAUDE.md` §1. Depende de `inicio-sesion-correo` para la sesión real.

## Goals / Non-Goals

**Goals:** todo lo de la propuesta en un solo cambio, construido por tareas con su commit y sus pruebas.

**Non-Goals:** otras monedas, cruces de más de dos, push, web, tiempo real y el CP5 del cruce.

## Decisions

### 1. Un solo algoritmo de reparto: proporcional por pesos con mayor residuo
`Allocation.split(total: Int, weights: [Int]) -> [Int]` reparte `total` en proporción a `weights` con el método del **mayor residuo**: a cada uno `total * w / Σw` (división entera) y los pesos que sobran van de a uno a los residuos más grandes; los empates los gana quien va primero en el orden de participantes (orden de unión al parche). Siempre suma exactamente `total`. Pesos todos en cero → error.

Cada tipo de reparto solo produce pesos:
- **Iguales** (entre todos o entre algunos): peso 1 para los seleccionados.
- **Por partes**: el número de partes de cada uno (≥ 0, al menos uno > 0).
- **Por porcentaje**: el porcentaje de cada uno (suma 100).
- **Por consumo**: ítems `{monto, participantes}`; cada ítem se reparte en partes iguales entre sus participantes (con `split`), y el subtotal de cada persona es su peso.
- **Propina** (cualquier tipo, opcional, 0–100 %): `total = base + base * propina / 100` (entero, redondeo hacia abajo); el total con propina se reparte con los mismos pesos, así la propina queda proporcional a lo consumido.

Alternativa descartada: una fórmula por tipo. Más código y más casos de redondeo distintos.

### 2. Lo que se guarda de cada gasto
`parche_expenses` guarda el método, la propina y el total; `parche_expense_payers` cuánto pagó cada pagador (suman el total); `parche_expense_shares` cuánto le toca a cada persona en pesos ya resuelto más el dato de entrada (partes, porcentaje o 1); `parche_expense_items` los ítems del reparto por consumo. La app calcula el reparto y la base valida que pagos y partes sumen el total (función de validación usada por un trigger diferido `constraint trigger ... deferrable initially deferred`). Guardar lo resuelto hace que el saldo no cambie si mañana cambia el algoritmo.

### 3. Saldos
Saldo de cada persona = lo que pagó en gastos vigentes − lo que le toca en gastos vigentes + pagos confirmados que hizo − pagos confirmados que recibió + deudas pasadas al cruce como pagador − como receptor. Positivo: le deben; negativo: debe. Siempre suma cero. Se calcula en `ParcheCalculator` (CruceCore) y nunca se guarda.

**A paz y salvo** = parche cerrado y todos los saldos en cero (calculado, no es un estado guardado). En la base, `parches.status` solo tiene `open` y `closed`.

### 4. Mínimo de transferencias
Voraz: el que más debe le paga al que más le deben, el menor de los dos montos; se repite. Da a lo sumo n − 1 transferencias; empates por orden de participantes. Determinista y probado.

### 5. Deuda entre dos que pasa al cruce
Deuda directa entre A y B: por cada gasto vigente, lo que le toca a A multiplicado por la fracción que pagó B (`share_A * paid_B / total`, entero) menos lo recíproco, más/menos los pagos confirmados entre ellos. Al aceptar, la función `move_parche_debt_to_cruce(parche, otro)` inserta en `movements` del cruce que comparten un movimiento `expense` con `split_type = 'full_other'` (paga quien recibe, concepto "Parche <nombre>") y guarda `parche_cruce_transfers` (de, a, monto, `movement_id`). En el parche esa transferencia cuenta como un pago confirmado de A a B, así los saldos del grupo cuadran. Solo con el parche cerrado, una vez por par, y lo acepta cualquiera de los dos. La app pregunta en la pantalla de cerrar y después en el detalle mientras no se haya decidido; "No, se salda en el parche" se guarda en el dispositivo (no hace falta en la base).

### 6. Pagos y confirmación
`parche_payments`: de, a, monto, anotado por, `confirmed_at`. Se confirma solo al anotarlo si quien lo anota es quien recibe o si quien recibe no tiene la app; si no, queda pendiente hasta que quien recibió llame a `confirm_parche_payment`. Los pendientes no cuentan en el saldo y se muestran aparte.

### 7. Códigos
`PCH-` + 6 caracteres para unirse al parche y `SOY-` + 6 para quedarse con un lugar; alfabeto sin caracteres ambiguos (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`), generados en la base. El campo "Tengo un código" de la app decide por el prefijo (`CRZ-` cruce, `PCH-` parche, `SOY-` lugar). Al reclamar un lugar se borra su `SOY-` y no se puede reclamar si la persona ya está en el parche.

### 8. Base de datos y seguridad
Tablas `parches`, `parche_participants` (`user_id` opcional, único por parche; `display_name` 1–40; `claim_code` solo si no hay `user_id`; `last_seen_at`), `parche_expenses` (id generado en el cliente para reintentos idempotentes; `concept` 1–80; `amount > 0`; `spent_on`; `split_method`; `tip_percent`; `created_by`; `updated_at`; `deleted_at`/`deleted_by`), `parche_expense_payers`, `parche_expense_shares`, `parche_expense_items`, `parche_payments`, `parche_cruce_transfers` y `parche_activity` (escrita por triggers: gasto creado/editado/borrado, pago anotado/confirmado, persona agregada/se unió/reclamó lugar, parche cerrado).

RLS solo para `authenticated` con `(select auth.uid())` y una función `is_parche_member(parche_id)` `security definer stable`, igual que `endurecer-rls`. Los miembros ven todo su parche. Gastos se insertan/editan solo con el parche abierto; pagos con el parche abierto o cerrado. Las funciones de la propuesta son `security definer set search_path = ''`. Nadie fuera del parche ve nada, y `anon` no tiene acceso.

### 9. Sin conexión
El cliente genera los `id`; `ParcheStore` guarda en una cola local (persistida en disco) lo que no pudo enviar y reintenta al volver la conexión o al abrir la app; el envío es idempotente (`upsert` por `id`). El aviso de duplicado es del cliente, antes de guardar: mismo monto y mismo pagador principal en las últimas 3 horas en un gasto vigente; se puede guardar igual.

### 10. App
`ParcheStore` (`@Observable @MainActor`, en CruceCore) con un `ParcheRepository` (protocolo; `InMemoryParcheRepository` para pruebas, vistas previas y Debug; `SupabaseParcheRepository` en la app). Pantallas con los componentes existentes (no hay diseño de Joan): lista "Tus parches" en el inicio, nuevo parche, detalle (saldos, gastos, pagos, actividad), anotar gasto (pagadores, monto, concepto, reparto, propina), anotar pago, cerrar (con la pregunta del cruce), tickets (personal y del parche) y "Tengo un código". Quien no tiene cruce también llega a sus parches desde la pantalla de invitar ("Tengo un código" y "Mis parches"). Rutas nuevas en `Route`; pantallas nuevas en `DebugScreen`.

## Risks / Trade-offs

- **Tamaño** → tareas cortas con pruebas y commits por tarea.
- **Redondeo** → un solo algoritmo, con pruebas de que siempre suma el total.
- **Sin diseño** → componentes existentes; Joan puede pedir cambios después.
- **El movimiento que pasa al cruce** solo se verá en la app con el CP5.
- **Sin tiempo real** → recargar al abrir y al deslizar.

## Migration Plan

Migración nueva en `supabase/migrations/`; se prueba con `supabase test db` en local y se aplica en la nube con `supabase db push --linked --dry-run` primero (debe listar solo esta migración) y luego `supabase db push --linked`.
