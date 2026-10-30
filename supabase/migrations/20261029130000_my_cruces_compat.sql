-- Cruce · my_cruces() compatible con las versiones anteriores de la app
-- 20261029110000_colores.sql hizo que my_avatar y partner_avatar devolvieran el color del perfil (6 colores). Las
-- versiones de la app que ya están instaladas leen esos dos campos como un enum cerrado {yellow, violet} y, si una sola
-- fila trae green, peach, pink o lime, no cargan NINGÚN cruce.
-- Ahora:
--   - my_avatar y partner_avatar vuelven a ser el color del rol en ese cruce (ledger_members.avatar_color: quien lo
--     creó, amarillo; quien se unió, violeta), como antes de colores. create_ledger_with_invite y redeem_invite lo
--     siguen llenando.
--   - my_color y partner_color (nuevas) traen el color del perfil de cada uno. La app nueva lee estas.
-- Cambia la forma del resultado: hay que borrarla y crearla otra vez (dentro de la transacción de la migración).

drop function public.my_cruces();

-- Solo cruces completos (de dos personas): primero los abiertos y después los cerrados, cada grupo del que se
-- completó más recientemente al más viejo. security invoker: RLS sigue decidiendo qué filas se ven.
create function public.my_cruces()
returns table (
  ledger_id             uuid,
  partner_id            uuid,
  partner_name          text,
  my_tike               text,
  my_avatar             text,
  partner_tike          text,
  partner_avatar        text,
  linked_at             timestamptz,
  closed_at             timestamptz,
  default_other_percent smallint,
  my_color              text,
  partner_color         text
)
language sql stable security invoker set search_path = '' as $$
  select me.ledger_id,
         other.user_id,
         p.display_name,
         me.tike_variant::text,
         me.avatar_color::text,
         other.tike_variant::text,
         other.avatar_color::text,
         greatest(me.joined_at, other.joined_at),
         l.closed_at,
         l.default_other_percent,
         mp.avatar_color::text,
         p.avatar_color::text
  from public.ledger_members me
  join public.ledger_members other on other.ledger_id = me.ledger_id and other.user_id <> me.user_id
  join public.profiles p on p.id = other.user_id
  join public.profiles mp on mp.id = me.user_id
  join public.ledgers l on l.id = me.ledger_id
  where me.user_id = (select auth.uid())
  order by l.closed_at is not null, greatest(me.joined_at, other.joined_at) desc, me.ledger_id
$$;

-- ─────────────────────────────────────────────────────────────
-- Permisos (los mismos de antes: se pierden al borrarla)
-- ─────────────────────────────────────────────────────────────
revoke all on function public.my_cruces() from public, anon;
grant execute on function public.my_cruces() to authenticated;
