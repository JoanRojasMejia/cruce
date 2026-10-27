# Design

## Context

- `movements` está en la publicación `supabase_realtime` (`init.sql`). Realtime respeta RLS para el rol `authenticated`: cada persona recibe solo los cambios de sus cruces.
- supabase-swift 2.55.4 trae `RealtimeChannelV2`:
  - `client.channel(nombre)`;
  - `postgresChange(AnyAction.self, schema:, table:, filter: .eq("ledger_id", value:))` → `AsyncStream<AnyAction>`, con `record: [String: AnyJSON]` en inserciones y ediciones;
  - `subscribeWithError()` y `unsubscribe()`.
- Desde el CP5, `LedgerStore` tiene `movementsByCruce` y `load()`. `MainView` carga al cambiar los cruces y al volver a `.active`.
- `MovementRemote` ya traduce las filas de `movements`.

## Goals / Non-Goals

**Goals:**
- Que la lógica de aplicar cambios viva en CruceCore y se pruebe con `swift test`.
- Que la app no dependa de que Realtime funcione: si el canal falla, deslizar y volver a la app siguen recargando.

**Non-Goals:**
- Presencia ("Jesús está escribiendo").
- Notificaciones fuera de la app (CP9).

## Decisions

### D1. `MovementFeed` en CruceCore, `SupabaseMovementFeed` en la app
- **El protocolo:** `MovementFeed.changes(in cruces: [UUID]) -> AsyncStream<MovementChange>`. `MovementChange` es el cruce y el `Movement` (de una inserción o una edición).
- **La implementación:** `SupabaseMovementFeed` abre un canal por cruce, traduce `record` con `MovementRemote` y cierra los canales cuando termina la secuencia (`onTermination`).
- **Para las pruebas:** un doble en memoria, `InMemoryMovementFeed`, deja empujar cambios.
- **Alternativa descartada:** suscribirse desde la vista. Mezcla red y pantalla, y no se puede probar.

### D2. `LedgerStore.apply(_:)` reemplaza por `id`
- **Qué hace:** si el movimiento ya está en ese cruce lo reemplaza; si no, lo agrega. Así el eco de lo propio no duplica, y un borrado suave llega como una edición con `deleted_at`.
- **Lo que no hace:** no abre "Gasto guardado" (`lastSaved`), porque eso es solo para lo que anota uno mismo.
- **Borrados físicos:** la app no los hace (todo es borrado suave), así que los `DELETE` de Realtime se ignoran.

### D3. `LedgerStore.follow(_:)` mientras `MainView` está en pantalla
- **Qué hace:** `follow` recorre `feed.changes(in:)` con los cruces de la sesión y aplica cada cambio.
- **Cuándo:** `MainView` lo llama en la misma `.task` que carga, con un `id` que cambia cuando cambian los cruces o cuando la app vuelve a `.active`. SwiftUI cancela la tarea anterior, la secuencia termina y se cierran los canales.

### D4. Supabase local con Realtime
- **El cambio:** el comando de `ios/README.md` excluía `realtime`. Ahora se levanta sin excluirlo, para poder probar en local.

## Risks / Trade-offs

- **[Cambios perdidos mientras el canal se reconecta]** → Al volver a `.active` se recarga todo antes de escuchar, y deslizar sigue funcionando.
- **[Fechas de Realtime en otro formato]** Realtime puede mandar las fechas sin la `T` o con zona `+00` → `ParcheRemote.parseTimestamp` se amplía para aceptar ese formato, con su prueba.
- **[Batería]** Un canal abierto por cruce mientras la app está en primer plano → En segundo plano iOS suspende la app y la tarea se cancela, así que es poco.
