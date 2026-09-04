-- SWÉ TOURNAMENT 5/5 — V40.07
-- Abonnements / options / autorisation spéciale de démonstration
-- À exécuter une seule fois dans Supabase SQL Editor.

create table if not exists public.workspace_commercial_access (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  subscription_plan text not null default 'free' check (subscription_plan in ('free','standard','pro')),
  special_access_enabled boolean not null default false,
  upgrade_requested_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.workspace_commercial_access enable row level security;
revoke all on public.workspace_commercial_access from anon, authenticated;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname='trg_workspace_commercial_access_updated_at') then
    create function public.touch_workspace_commercial_access() returns trigger language plpgsql as $f$
    begin new.updated_at=now(); return new; end $f$;
    create trigger trg_workspace_commercial_access_updated_at before update on public.workspace_commercial_access
    for each row execute function public.touch_workspace_commercial_access();
  end if;
end $$;

create or replace function public.get_workspace_commercial_access(p_workspace_id uuid)
returns table(subscription_plan text,special_access_enabled boolean,upgrade_requested_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id=p_workspace_id and wm.user_id=auth.uid() and wm.active=true
  ) then raise exception 'Accès refusé'; end if;

  insert into public.workspace_commercial_access(workspace_id) values(p_workspace_id)
  on conflict (workspace_id) do nothing;

  return query select c.subscription_plan,c.special_access_enabled,c.upgrade_requested_at
  from public.workspace_commercial_access c where c.workspace_id=p_workspace_id;
end $$;

grant execute on function public.get_workspace_commercial_access(uuid) to authenticated;

create or replace function public.request_workspace_upgrade(p_workspace_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id=p_workspace_id and wm.user_id=auth.uid() and wm.active=true and wm.role='admin'
  ) then raise exception 'Réservé à l’administrateur'; end if;

  insert into public.workspace_commercial_access(workspace_id,upgrade_requested_at)
  values(p_workspace_id,now())
  on conflict(workspace_id) do update set upgrade_requested_at=excluded.upgrade_requested_at,updated_at=now();
end $$;

grant execute on function public.request_workspace_upgrade(uuid) to authenticated;

create or replace function public.super_admin_get_commercial_access()
returns table(workspace_id uuid,subscription_plan text,special_access_enabled boolean,upgrade_requested_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Super Admin requis'; end if;
  insert into public.workspace_commercial_access(workspace_id)
  select w.id from public.workspaces w on conflict(workspace_id) do nothing;
  return query select c.workspace_id,c.subscription_plan,c.special_access_enabled,c.upgrade_requested_at
  from public.workspace_commercial_access c;
end $$;

grant execute on function public.super_admin_get_commercial_access() to authenticated;

create or replace function public.super_admin_set_commercial_access(
  p_workspace_id uuid,
  p_subscription_plan text,
  p_special_access_enabled boolean
) returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Super Admin requis'; end if;
  if p_subscription_plan not in ('free','standard','pro') then raise exception 'Abonnement invalide'; end if;

  insert into public.workspace_commercial_access(workspace_id,subscription_plan,special_access_enabled,upgrade_requested_at)
  values(p_workspace_id,p_subscription_plan,coalesce(p_special_access_enabled,false),null)
  on conflict(workspace_id) do update set
    subscription_plan=excluded.subscription_plan,
    special_access_enabled=excluded.special_access_enabled,
    upgrade_requested_at=null,
    updated_at=now();

  -- Une autorisation spéciale doit réellement débloquer les modules côté backend.
  -- On met à TRUE uniquement les colonnes présentes dans workspace_entitlements.
  if coalesce(p_special_access_enabled,false) then
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='tournaments_enabled') then
      execute 'update public.workspace_entitlements set tournaments_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='league_enabled') then
      execute 'update public.workspace_entitlements set league_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='rankings_enabled') then
      execute 'update public.workspace_entitlements set rankings_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='player_ratings_enabled') then
      execute 'update public.workspace_entitlements set player_ratings_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='third_half_enabled') then
      execute 'update public.workspace_entitlements set third_half_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='top_player_enabled') then
      execute 'update public.workspace_entitlements set top_player_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='workspace_entitlements' and column_name='match_ratings_enabled') then
      execute 'update public.workspace_entitlements set match_ratings_enabled=true where workspace_id=$1' using p_workspace_id;
    end if;
  end if;
end $$;

grant execute on function public.super_admin_set_commercial_access(uuid,text,boolean) to authenticated;

-- Autorisation spéciale initiale pour l'espace administré par Louison.
insert into public.workspace_commercial_access(workspace_id,special_access_enabled)
select distinct wap.workspace_id,true
from public.workspace_admin_profiles wap
where lower(coalesce(wap.last_name,''))='louison'
on conflict(workspace_id) do update set special_access_enabled=true,updated_at=now();

-- Force également les modules disponibles pour Louison via la fonction Super Admin-like n'est pas possible
-- sans connaître son workspace à l'avance ; l'app applique l'accès spécial immédiatement côté interface.
