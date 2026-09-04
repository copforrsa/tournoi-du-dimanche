-- SWÉ TOURNAMENT 5/5 • V40.01
-- Paiement en ligne OU sur place + lien privé d'encaissement pour le complexe.
-- À exécuter une fois dans Supabase SQL Editor avant de publier la V40.01.

create extension if not exists pgcrypto;

alter table public.tournaments
  add column if not exists payment_validation_token uuid default gen_random_uuid();

update public.tournaments
set payment_validation_token = gen_random_uuid()
where payment_validation_token is null;

alter table public.tournaments
  alter column payment_validation_token set default gen_random_uuid();

create unique index if not exists tournaments_payment_validation_token_uidx
  on public.tournaments(payment_validation_token);

alter table public.tournament_players
  add column if not exists payment_preference text,
  add column if not exists manual_paid_at timestamptz,
  add column if not exists manual_paid_source text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname='tournament_players_payment_preference_chk'
  ) then
    alter table public.tournament_players
      add constraint tournament_players_payment_preference_chk
      check (payment_preference is null or payment_preference in ('online','onsite'));
  end if;
end $$;

create or replace function public.public_tournament_payment_choice_status(
  p_token text,
  p_tournament_id uuid,
  p_player_id uuid
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  r public.tournament_players%rowtype;
begin
  if not exists (
    select 1
    from public.tournaments t
    join public.workspaces w on w.id=t.workspace_id
    where t.id=p_tournament_id and w.public_token::text=p_token
  ) then
    raise exception 'Lien public invalide';
  end if;

  select * into r
  from public.tournament_players
  where tournament_id=p_tournament_id and player_id=p_player_id and present=true
  limit 1;

  if not found then
    return jsonb_build_object('registered',false);
  end if;

  return jsonb_build_object(
    'registered',true,
    'payment_preference',r.payment_preference,
    'manual_paid_at',r.manual_paid_at,
    'manual_paid_source',r.manual_paid_source
  );
end;
$$;

create or replace function public.public_set_tournament_payment_preference(
  p_token text,
  p_tournament_id uuid,
  p_player_id uuid,
  p_preference text
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if p_preference not in ('online','onsite') then
    raise exception 'Mode de paiement invalide';
  end if;

  if not exists (
    select 1
    from public.tournaments t
    join public.workspaces w on w.id=t.workspace_id
    where t.id=p_tournament_id and w.public_token::text=p_token
  ) then
    raise exception 'Lien public invalide';
  end if;

  update public.tournament_players
  set payment_preference=p_preference
  where tournament_id=p_tournament_id
    and player_id=p_player_id
    and present=true;

  if not found then raise exception 'Inscription introuvable'; end if;

  return jsonb_build_object('ok',true,'payment_preference',p_preference);
end;
$$;

create or replace function public.payment_desk_snapshot(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  t record;
  result jsonb;
begin
  select t.id, t.name, t.tournament_date, t.entry_fee_cents, t.payment_validation_token,
         w.public_token
  into t
  from public.tournaments t
  join public.workspaces w on w.id=t.workspace_id
  where t.payment_validation_token::text=p_token
  limit 1;

  if not found then raise exception 'Lien encaissement invalide'; end if;

  select jsonb_build_object(
    'tournament_id',t.id,
    'tournament_name',t.name,
    'tournament_date',t.tournament_date,
    'entry_fee_cents',coalesce(t.entry_fee_cents,0),
    'public_token',t.public_token,
    'players',coalesce((
      select jsonb_agg(jsonb_build_object(
        'player_id',tp.player_id,
        'player_name',p.name,
        'present',tp.present,
        'registration_status',tp.registration_status,
        'is_substitute',tp.is_substitute,
        'payment_preference',tp.payment_preference,
        'manual_paid_at',tp.manual_paid_at,
        'manual_paid_source',tp.manual_paid_source
      ) order by p.name)
      from public.tournament_players tp
      join public.players p on p.id=tp.player_id
      where tp.tournament_id=t.id and tp.present=true
    ),'[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.payment_desk_set_paid(
  p_token text,
  p_player_id uuid,
  p_paid boolean
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_tournament_id uuid;
begin
  select id into v_tournament_id
  from public.tournaments
  where payment_validation_token::text=p_token
  limit 1;
  if v_tournament_id is null then raise exception 'Lien encaissement invalide'; end if;

  update public.tournament_players
  set manual_paid_at=case when p_paid then now() else null end,
      manual_paid_source=case when p_paid then 'complex' else null end,
      payment_preference=case when p_paid then 'onsite' else payment_preference end
  where tournament_id=v_tournament_id
    and player_id=p_player_id
    and present=true
    and coalesce(registration_status,'confirmed')<>'waitlist';

  if not found then raise exception 'Joueur introuvable ou non payable'; end if;
  return jsonb_build_object('ok',true,'paid',p_paid);
end;
$$;

grant execute on function public.public_tournament_payment_choice_status(text,uuid,uuid) to anon, authenticated;
grant execute on function public.public_set_tournament_payment_preference(text,uuid,uuid,text) to anon, authenticated;
grant execute on function public.payment_desk_snapshot(text) to anon, authenticated;
grant execute on function public.payment_desk_set_paid(text,uuid,boolean) to anon, authenticated;
