# Tasks

## 1. Supabase en local

- [x] 1.1 Instalar la CLI de Supabase y correr `supabase init` (verificado: existe `supabase/config.toml`)
- [x] 1.2 `supabase start` levanta Postgres, Auth y Realtime en Docker (verificado: `supabase status` muestra los servicios)
- [x] 1.3 `supabase db reset` aplica la migración sin errores (verificado: salida sin errores y tablas creadas)

## 2. Pruebas SQL (pgTAP, `supabase test db`)

- [x] 2.1 `owed_by_other` con 50/50, porcentaje y "todo es del otro", incluido el redondeo de impares (verificado: pruebas en verde)
- [x] 2.2 `ledger_balances` con el ejemplo canónico: −20.000 para Joan y +20.000 para Jesús; un movimiento borrado no cuenta (verificado: pruebas en verde)
- [x] 2.3 Máximo dos miembros por cuenta y que quien paga sea miembro (verificado: pruebas en verde)
- [x] 2.4 RLS: un tercero no ve cuentas, miembros, movimientos, saldos, perfiles ni invitaciones ajenas; nadie escribe en cuentas ajenas ni a nombre de otro (verificado: pruebas en verde)
- [x] 2.5 `create_ledger_with_invite` devuelve `CRZ-####` y deja a quien crea en rosa y amarillo; falla sin sesión (verificado: pruebas en verde)
- [x] 2.6 `redeem_invite` une a la segunda persona en verde y violeta, y rechaza códigos inexistentes, vencidos, usados y propios (verificado: pruebas en verde)
- [x] 2.7 Generar un código nuevo no borra invitaciones ya canjeadas (verificado: prueba en rojo antes de corregir la migración y en verde después)

## 3. Revisión

- [ ] 3.1 Revisión independiente de las políticas RLS y de las funciones `security definer` (verificado: hallazgos resueltos o anotados)

## 4. Nube

- [ ] 4.1 Joan crea el proyecto en supabase.com y corre `supabase login` y `supabase link` (verificado: `supabase projects list` muestra el proyecto enlazado)
- [ ] 4.2 `supabase db push` aplica la migración en la nube (verificado: `supabase migration list` muestra la migración en local y remoto)

## 5. Documentación

- [ ] 5.1 `supabase/README.md` explica cómo correr las pruebas; `ROADMAP.md` y `CLAUDE.md` actualizados

## Workflow follow-up

- Archivar con `openspec archive base-de-datos`.
