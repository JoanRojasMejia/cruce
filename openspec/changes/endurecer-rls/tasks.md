# Tasks

Cada tarea termina en un commit (Conventional Commits, descripción en español) directo en `main`; `git push` solo cuando el usuario lo pida. Las tareas 1.x y 2.x se hacen en el modo “Base de datos / backend” de `CLAUDE.local.md` (Colima y Supabase mínimo prendidos, sin simulador); al terminar: `supabase stop && colima stop`. Requisito de cada commit que toque `supabase/`: `supabase db reset && supabase test db` en verde (salvo la 1.1, que deja la suite en rojo a propósito y se confirma junto con la 1.2).

`20261024000000_init.sql` no se edita en ninguna tarea.

## 1. Pruebas y migración

- [x] 1.1 Crear `supabase/tests/05_rls_endurecido.sql` con `plan(20)` y las pruebas de la decisión 5 de `design.md`: `policy_roles_are` con `array['authenticated']` para las 10 políticas; una prueba sobre `pg_policies` que espera 0 políticas de `public` con `auth.uid()` fuera de `( SELECT auth.uid() AS uid)` en `qual` o `with_check`; `has_index` para `ledger_members_user_id_idx (user_id)` e `invites_created_by_idx (created_by)`; y como `anon`, 0 filas en `ledgers`, `ledger_members`, `movements`, `ledger_balances`, `profiles` e `invites` más `throws_ok` al insertar un movimiento (datos de prueba como en `04_rls.sql`, todo dentro de `begin` … `rollback`). Verificado en RED: `supabase db reset && supabase test db` reporta que fallan exactamente las 13 pruebas estructurales (10 de roles, 1 de expresiones, 2 de índices), pasan las 7 de `anon` y siguen pasando las 54 anteriores. Sin commit propio. Observado: fallan las 13 estructurales y siguen pasando las 54 anteriores, pero las 7 de `anon` no llegan a correr (`permission denied for function is_ledger_member` aborta el archivo; ver la corrección en la decisión 5 de `design.md`)
- [x] 1.2 Crear la migración con `supabase migration new endurecer_rls` y escribir en ella, con comentarios en español: un `alter policy … to authenticated` por cada una de las 10 políticas de `init.sql` (líneas 182-213), con `using`/`with check` reescritos solo en las 5 que usan `auth.uid()` directo (cambiando `auth.uid()` por `(select auth.uid())` y nada más), y los dos `create index` de la decisión 4. Sin `grant`, `revoke`, `create function` ni cambios a `ledger_balances`. Verificado en GREEN: `supabase db reset && supabase test db` pasa las 74 pruebas (54 anteriores sin modificar + 20 nuevas); `rg -n "grant|revoke|function|view" supabase/migrations/*_endurecer_rls.sql` solo encuentra comentarios; `git diff --stat` no muestra `20261024000000_init.sql`. Commit (con la 1.1): `fix(supabase): aplicar las políticas RLS solo a authenticated con auth.uid() evaluado una vez`

## 2. Documentación

- [x] 2.1 Actualizar `CLAUDE.md`: en §2, la fila de base de datos pasa a “74 pruebas pgTAP” y menciona la migración nueva (en la nube: pendiente hasta la 3.1); en §4 (“Supabase (local)”), “54 pruebas” pasa a “74 pruebas”; en §9 (Historial), agregar `endurecer-rls` como el segundo cambio de herramientas. Verificado: `rg -n "54 pruebas" CLAUDE.md` no encuentra nada y `rg -n "74 pruebas|endurecer-rls" CLAUDE.md` encuentra las tres menciones. Commit: `docs: documentar el endurecimiento de RLS en CLAUDE.md`

## 3. Nube

- [ ] 3.1 Paso aprobado por el usuario (el agente solo lo corre cuando el usuario lo diga, con Colima prendido y el proyecto ya vinculado): `scripts/backup-db.sh` deja una carpeta nueva en `backups/` con `schema.sql` y `data.sql` no vacíos; `supabase db push --dry-run` lista solo `<timestamp>_endurecer_rls.sql`; `supabase db push` termina sin errores. Verificado: `supabase migration list` muestra la migración en las columnas local y remota; en la nube, `select policyname, roles from pg_policies where schemaname = 'public'` (desde el SQL Editor del panel o `psql`) devuelve las 10 políticas con `{authenticated}`. Si `CLAUDE.md` §2 decía “pendiente”, se actualiza en un commit `docs: marcar la migración de RLS como aplicada en la nube`
- [ ] 3.2 Después del push que pida el usuario, `gh run list --workflow ci.yml` muestra la corrida en verde con el trabajo `supabase` ejecutado (no “skipped”). Verificado: salida de `gh run view <id>`. Sin commit

## Workflow follow-up

- Archivar con `OPENSPEC_TELEMETRY=0 npx -y @fission-ai/openspec@1.15.0 archive endurecer-rls` solo cuando la 3.1 y la 3.2 estén verificadas.
- Verificar que `openspec/specs/privacidad-datos/spec.md` tiene el requisito `Sin sesión no hay acceso` y que `openspec validate --all --strict` pasa.
- Siguiente cambio de herramientas antes del CP3: separar `AppState` y agregar borrado suave en la app de iOS.
