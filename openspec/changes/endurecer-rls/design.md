# Design

## Context

Ver `proposal.md` (Why). Estado actual comprobado en `supabase/migrations/20261024000000_init.sql` (aplicada en local y en la nube; no se edita):

- RLS activado en `profiles`, `ledgers`, `ledger_members`, `movements` e `invites` (líneas 176-180). `invite_attempts` no tiene políticas: la app no tiene ningún permiso sobre ella (línea 320) y queda fuera de este cambio.
- Las 10 políticas (líneas 182-213) se crean sin `to`, así que aplican a `public` (todos los roles, incluido `anon`):

  | Tabla | Política | Comando | Línea | Usa `auth.uid()` directo |
  |---|---|---|---|---|
  | `profiles` | `perfil propio o de mi pareja de cuenta` | select | 182 | sí (184, 188) |
  | `profiles` | `crear mi perfil` | insert | 191 | sí (192) |
  | `profiles` | `editar mi perfil` | update | 193 | sí (194, dos veces) |
  | `ledgers` | `ver mis cuentas` | select | 196 | no (`is_ledger_member`) |
  | `ledgers` | `editar mis cuentas` | update | 198 | no |
  | `ledger_members` | `ver miembros de mis cuentas` | select | 201 | no |
  | `movements` | `ver movimientos de mis cuentas` | select | 204 | no |
  | `movements` | `crear movimientos en mis cuentas` | insert | 206 | sí (207) |
  | `movements` | `editar movimientos de mis cuentas` | update | 209 | no |
  | `invites` | `ver mis invitaciones` | select | 212 | sí (213) |

- `is_ledger_member(p_ledger)` (líneas 169-174) es `language sql stable security definer set search_path = ''` y filtra `ledger_members` por `ledger_id = p_ledger and user_id = auth.uid()`.
- Índices existentes: la llave primaria de `ledger_members` es `(ledger_id, user_id)` (línea 39); `movements_ledger_occurred_idx` sobre `movements (ledger_id, occurred_at desc) where deleted_at is null` (línea 70); `invites` solo tiene la llave primaria `code` (línea 73).
- `ledger_balances` (línea 152) es `security_invoker = true`, así que hereda las políticas de `ledger_members` y `movements`.
- La app de iOS siempre habla con una sesión (rol `authenticated`); el backend en Go usa la llave `service_role`, que se salta RLS. Nadie lee datos con `anon`.
- Pruebas: 54 pgTAP en `supabase/tests/01_saldo.sql` a `04_rls.sql`; `04_rls.sql` (23) actúa como `authenticated` con `request.jwt.claims`. Ninguna prueba actúa como `anon`.
- Con unas 1.000 personas y dos miembros por cuenta, las tablas son pequeñas: este cambio es higiene, no la respuesta a un problema de rendimiento medido.

## Goals / Non-Goals

**Goals:**
- Seguir las tres recomendaciones de la guía de Supabase que aplican hoy: `(select auth.uid())`, `to authenticated` e índices en las columnas que filtran las políticas.
- Ningún cambio en lo que ve o escribe cada persona: las 54 pruebas actuales siguen en verde sin tocarlas.
- Que las pruebas nuevas fallen hoy y pasen con la migración, para que una regresión futura (por ejemplo, una política nueva sin `to authenticated`) se note.

**Non-Goals:**
- Cambiar permisos (`grant`/`revoke`), el comportamiento de cualquier función, la vista `ledger_balances` o los contratos de `create_ledger_with_invite` y `redeem_invite`.
- Políticas nuevas (por ejemplo, borrar perfiles o invitaciones) o reglas de negocio nuevas.
- Medir rendimiento con `explain analyze` sobre datos sintéticos grandes: con el volumen actual no aporta.
- Tocar la app de iOS, el backend o la CI.

## Decisions

### 1. `alter policy` en vez de borrar y crear

Cada política se cambia con un solo `alter policy "<nombre>" on public.<tabla> to authenticated [using (...)] [with check (...)];`. Postgres permite cambiar con `alter policy` los roles y las expresiones, pero no el comando (`for select`, `insert`…); aquí el comando no cambia, así que `alter policy` cubre todo.

**Por qué:**
- Se conservan los nombres y los comandos exactos, sin riesgo de escribir mal un `for`.
- La migración corre en una transacción (`supabase db push` y `supabase db reset` aplican cada archivo así): si algo falla, no queda nada a medias, y en ningún momento existe una tabla con RLS activado y sin su política (con `drop`/`create` tampoco lo habría dentro de la transacción, pero `alter` ni siquiera abre esa ventana).
- El diff de la migración muestra solo lo que cambia.

**Alternativas:**
- *`drop policy` + `create policy`* (rechazada): reescribe el comando y el nombre a mano, más superficie para un error sin ninguna ganancia.
- *Editar `20261024000000_init.sql`* (prohibida): ya está aplicada en la nube (§7 de `CLAUDE.md`).

### 2. `(select auth.uid())` en las expresiones de las políticas

En las 5 políticas que usan `auth.uid()` directo, se reemplaza por `(select auth.uid())`. Postgres lo convierte en un `InitPlan`: se evalúa una vez por consulta en lugar de una vez por fila. El resultado es el mismo valor, así que el comportamiento no cambia.

Las expresiones que solo llaman a `public.is_ledger_member(<columna>)` no se envuelven en `select`: el argumento depende de la fila, así que no puede evaluarse una sola vez y envolverla no cambiaría nada.

En la política de `profiles` se mantiene el mismo `exists` con el `join` entre `mine` y `theirs`; solo cambia `auth.uid()`.

### 3. No se reescribe `is_ledger_member`

Dentro de la función, `auth.uid()` se queda igual.

**Por qué:** la función es `security definer`, así que Postgres no la incrusta (no hace *inlining*) en la consulta que la llama: cada llamada ejecuta su propia consulta de una fila sobre la llave primaria `(ledger_id, user_id)`. Envolver `auth.uid()` ahí lo evaluaría una vez por llamada, que es lo mismo que pasa hoy. Reescribirla exigiría `create or replace function` sobre una función `security definer` que ya usan 6 políticas, más riesgo sin ganancia.

**Alternativa:** *`create or replace` con `(select auth.uid())`* (rechazada por lo anterior; se puede hacer después si se cambia la función por otro motivo).

### 4. Índices: solo los que una política filtra y no tienen índice

- `create index ledger_members_user_id_idx on public.ledger_members (user_id);` — la política de `profiles` filtra `mine.user_id = (select auth.uid())`, y la llave primaria empieza por `ledger_id`, así que hoy no hay índice que sirva.
- `create index invites_created_by_idx on public.invites (created_by);` — la política `ver mis invitaciones` filtra `created_by = (select auth.uid())` y `invites` solo tiene índice en `code`.

**Revisados y descartados:**
- `ledger_members (ledger_id, user_id)` en `is_ledger_member` y en el `join` de `theirs`: ya los cubre la llave primaria.
- `movements (ledger_id)`: las políticas de `movements` solo llaman a `is_ledger_member(ledger_id)`, una función opaca que ningún índice puede servir. Las consultas de la app filtran por `ledger_id` y `deleted_at is null`, que ya cubre `movements_ledger_occurred_idx`.
- `ledgers (id)` y `profiles (id)`: son llaves primarias.

`create index` (sin `concurrently`, que no se puede usar dentro de una transacción) bloquea las escrituras de la tabla mientras se construye; con tablas de cientos de filas dura milisegundos.

### 5. Pruebas en `supabase/tests/05_rls_endurecido.sql`

Un archivo nuevo (sigue la numeración de `01` a `04`) en lugar de ampliar `04_rls.sql`, para que las 54 pruebas actuales sigan intactas y demuestren que no cambia el comportamiento:

- `policy_roles_are('public', <tabla>, <política>, array['authenticated'], ...)` para las 10 políticas (rojo hoy: dicen `public`).
- Una prueba sobre `pg_policies` que cuente las políticas de `public` cuyo `qual` o `with_check` todavía tengan `auth.uid()` fuera de `( SELECT auth.uid() AS uid)` (la forma en que Postgres guarda `(select auth.uid())`); espera 0 (rojo hoy: 5).
- `has_index('public', 'ledger_members', 'ledger_members_user_id_idx', array['user_id'], ...)` y lo mismo para `invites_created_by_idx` (rojo hoy).
- Como `anon` (`set local role anon` y `request.jwt.claims` con `"role":"anon"`): 0 filas en `ledgers`, `ledger_members`, `movements`, `ledger_balances`, `profiles` e `invites`, y `throws_ok` al insertar un movimiento. Estas 7 ya pasan hoy (por `auth.uid()` nulo) y quedan como regresión del requisito `Sin sesión no hay acceso`.

Total: 20 pruebas nuevas, 74 en la suite.

## Risks / Trade-offs

- [Una expresión reescrita mal puede dejar a alguien sin acceso a su cuenta o abrir datos ajenos] → las expresiones se copian de `init.sql` cambiando solo `auth.uid()`; las 23 pruebas de `04_rls.sql` (ver, crear y editar como miembro, como pareja y como tercero) y las 19 de `03_vinculacion.sql` tienen que seguir en verde sin modificarlas; las pruebas nuevas comprueban roles y forma de las expresiones.
- [`to authenticated` deja fuera a un cliente que hoy lea con `anon`] → no existe ese cliente: la app usa sesión y el backend `service_role` (que se salta RLS). Además, con `anon` las políticas ya daban falso, así que `anon` no veía nada antes ni después.
- [La nube difiere de la base local] → `supabase db push --dry-run` muestra que solo falta esta migración antes de aplicarla; antes se toma un respaldo con `scripts/backup-db.sh`.
- [Índice que no se usa] → costo mínimo de escritura en tablas de dos filas por cuenta; se acepta como higiene.

## Migration Plan

1. Local (Colima prendido, sin simulador, según `CLAUDE.local.md`): `supabase db reset` aplica `init.sql` y la migración nueva; `supabase test db` pasa las 74 pruebas.
2. Commit y, cuando el usuario haga push, el trabajo `supabase` de `ci.yml` en verde.
3. Nube, solo con aprobación del usuario: `scripts/backup-db.sh` (respaldo nuevo en `backups/`), `supabase db push --dry-run` (lista solo `<timestamp>_endurecer_rls.sql`) y `supabase db push`. Después, `supabase migration list` muestra la migración en local y en la nube.

**Rollback:** nunca se edita una migración aplicada. Si hace falta volver atrás, una migración nueva hace `alter policy ... to public using (...) with check (...)` con las expresiones originales de `init.sql` (líneas 182-213) y `drop index` de los dos índices. La migración no toca datos, así que el respaldo es una red adicional, no el plan de vuelta atrás.
