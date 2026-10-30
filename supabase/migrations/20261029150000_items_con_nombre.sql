-- Cruce · ítems con nombre en el reparto por consumo (corrección 14 de la revisión de diseño)
-- Cada ítem de un gasto "Por consumo" puede tener un nombre opcional ("Mojarra", "Limonada") que sale en el ticket.
-- Ahora:
--   - parche_expense_items.name: texto opcional de 1 a 40 caracteres (null si no tiene).
--   - save_parche_expense lee "name" de cada ítem de p_items (sin espacios a los lados; vacío cuenta como null). La
--     firma no cambia: una versión anterior de la app, que no manda "name", sigue funcionando (sus ítems quedan sin
--     nombre; si edita un gasto que tenía nombres, los ítems se reemplazan sin ellos).
--   - parche_expense_snapshot incluye el nombre, así cambiar solo un nombre cuenta como edición.
-- Aditiva: no borra datos.

alter table public.parche_expense_items
  add column name text null check (name is null or char_length(name) between 1 and 40);

-- Lo esencial de un gasto como jsonb (para saber si un reenvío trae cambios): campos, pagadores y partes
-- ordenados por participante, e ítems en orden con su nombre. Si el gasto no existe, null.
create or replace function public.parche_expense_snapshot(p_expense uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'concept', e.concept, 'base_amount', e.base_amount, 'tip_percent', e.tip_percent, 'amount', e.amount,
    'spent_on', e.spent_on, 'split_method', e.split_method::text,
    'payers', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', p.participant_id, 'amount', p.amount)
                 order by p.participant_id), '[]'::jsonb)
               from public.parche_expense_payers p where p.expense_id = e.id),
    'shares', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', s.participant_id, 'amount', s.amount,
                 'input', s.input) order by s.participant_id), '[]'::jsonb)
               from public.parche_expense_shares s where s.expense_id = e.id),
    'items', (select coalesce(jsonb_agg(jsonb_build_object('amount', i.amount, 'name', i.name,
                'participant_ids', to_jsonb(i.participant_ids))
                order by i.position), '[]'::jsonb)
              from public.parche_expense_items i where i.expense_id = e.id))
  from public.parche_expenses e where e.id = p_expense;
$$;


-- save_parche_expense(...) → uuid del gasto. Igual que antes, y cada ítem de p_items puede traer "name":
--   p_items: [{"amount": int, "participant_ids": [uuid, …], "name": text|null}]  (solo 'items'; suman p_base_amount)
-- Un nombre de más de 40 caracteres da invalidData.
create or replace function public.save_parche_expense(
  p_id uuid, p_parche_id uuid, p_concept text, p_base_amount bigint, p_tip_percent integer, p_amount bigint,
  p_spent_on timestamptz, p_split_method text, p_payers jsonb, p_shares jsonb, p_items jsonb default '[]'::jsonb
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_concept  text := btrim(coalesce(p_concept, ''));
  v_existing public.parche_expenses%rowtype;
  v_incoming jsonb;
begin
  perform public.require_session();
  if not public.is_parche_member(p_parche_id) then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  perform public.require_open_parche(p_parche_id);

  select * into v_existing from public.parche_expenses where id = p_id for update;
  if found then
    if v_existing.parche_id <> p_parche_id then
      raise exception 'Ese gasto no existe' using hint = 'notFound';
    end if;
    if v_existing.deleted_at is not null then
      return p_id;
    end if;
  end if;
  if char_length(v_concept) not between 1 and 80 then
    raise exception 'El concepto debe tener entre 1 y 80 caracteres' using hint = 'invalidData';
  end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) as x(item)
             where char_length(btrim(coalesce(x.item ->> 'name', ''))) > 40) then
    raise exception 'El nombre de un ítem puede tener hasta 40 caracteres' using hint = 'invalidData';
  end if;

  -- Lo que llega, con la misma forma que parche_expense_snapshot.
  v_incoming := jsonb_build_object(
    'concept', v_concept, 'base_amount', p_base_amount, 'tip_percent', p_tip_percent, 'amount', p_amount,
    'spent_on', coalesce(p_spent_on, v_existing.spent_on, now()), 'split_method', p_split_method,
    'payers', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', x.participant_id, 'amount', x.amount)
                 order by x.participant_id), '[]'::jsonb)
               from jsonb_to_recordset(coalesce(p_payers, '[]'::jsonb)) as x(participant_id uuid, amount bigint)),
    'shares', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', x.participant_id, 'amount', x.amount,
                 'input', x.input) order by x.participant_id), '[]'::jsonb)
               from jsonb_to_recordset(coalesce(p_shares, '[]'::jsonb)) as x(participant_id uuid, amount bigint, input integer)),
    'items', (select coalesce(jsonb_agg(jsonb_build_object('amount', (x.item ->> 'amount')::bigint,
                'name', nullif(btrim(coalesce(x.item ->> 'name', '')), ''),
                'participant_ids', to_jsonb(array(
                  select distinct v::uuid from jsonb_array_elements_text(x.item -> 'participant_ids') as v order by 1)))
                order by x.n), '[]'::jsonb)
              from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as x(item, n)));

  if v_existing.id is not null then
    if public.parche_expense_snapshot(p_id) = v_incoming then
      return p_id;
    end if;
    update public.parche_expenses
      set concept = v_concept, base_amount = p_base_amount, tip_percent = p_tip_percent, amount = p_amount,
          spent_on = coalesce(p_spent_on, spent_on), split_method = p_split_method::public.parche_split_method
      where id = p_id;
    delete from public.parche_expense_payers where expense_id = p_id;
    delete from public.parche_expense_shares where expense_id = p_id;
    delete from public.parche_expense_items where expense_id = p_id;
  else
    insert into public.parche_expenses
      (id, parche_id, concept, base_amount, tip_percent, amount, spent_on, split_method, recorded_by)
      values (p_id, p_parche_id, v_concept, p_base_amount, p_tip_percent, p_amount, coalesce(p_spent_on, now()),
              p_split_method::public.parche_split_method, public.my_parche_participant_id(p_parche_id));
  end if;

  insert into public.parche_expense_payers (expense_id, participant_id, amount)
    select p_id, x.participant_id, x.amount
    from jsonb_to_recordset(coalesce(p_payers, '[]'::jsonb)) as x(participant_id uuid, amount bigint);
  insert into public.parche_expense_shares (expense_id, participant_id, amount, input)
    select p_id, x.participant_id, x.amount, x.input
    from jsonb_to_recordset(coalesce(p_shares, '[]'::jsonb)) as x(participant_id uuid, amount bigint, input integer);
  insert into public.parche_expense_items (expense_id, position, amount, name, participant_ids)
    select p_id, (x.n - 1)::smallint, (x.item ->> 'amount')::bigint, nullif(btrim(coalesce(x.item ->> 'name', '')), ''),
           array(select distinct v::uuid from jsonb_array_elements_text(x.item -> 'participant_ids') as v order by 1)
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as x(item, n);

  -- Revisa las sumas ya (y no al final de la transacción) para que el error salga de esta llamada.
  set constraints public.parche_expenses_valid, public.parche_expense_payers_valid,
    public.parche_expense_shares_valid, public.parche_expense_items_valid immediate;
  set constraints public.parche_expenses_valid, public.parche_expense_payers_valid,
    public.parche_expense_shares_valid, public.parche_expense_items_valid deferred;
  return p_id;
end $$;
