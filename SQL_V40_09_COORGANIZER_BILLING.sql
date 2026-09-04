-- SWÉ TOURNAMENT 5/5 — V40.09
-- Achat automatique de co-gestionnaires supplémentaires après paiement Stripe.
-- À exécuter après SQL_V40_07_COMMERCIAL_ACCESS.sql.

create table if not exists public.workspace_coorganizer_subscriptions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  stripe_subscription_id text not null unique,
  stripe_checkout_session_id text unique,
  quantity integer not null check (quantity > 0),
  unit_amount_cents integer not null check (unit_amount_cents > 0),
  status text not null default 'active' check (status in ('active','cancelled')),
  created_at timestamptz not null default now(),
  cancelled_at timestamptz
);

alter table public.workspace_coorganizer_subscriptions enable row level security;
revoke all on public.workspace_coorganizer_subscriptions from anon, authenticated;

-- Fonction appelée uniquement par les Edge Functions avec la service_role.
create or replace function public.apply_paid_coorganizer_subscription(
  p_workspace_id uuid,
  p_stripe_subscription_id text,
  p_stripe_checkout_session_id text,
  p_quantity integer,
  p_unit_amount_cents integer
) returns table(new_limit integer, activated_quantity integer)
language plpgsql security definer set search_path=public as $$
declare
  v_existing public.workspace_coorganizer_subscriptions%rowtype;
  v_cap integer;
  v_new integer;
begin
  if p_quantity is null or p_quantity < 1 then raise exception 'Quantité invalide'; end if;
  if p_stripe_subscription_id is null or length(trim(p_stripe_subscription_id))=0 then raise exception 'Subscription Stripe manquante'; end if;

  select * into v_existing from public.workspace_coorganizer_subscriptions
  where stripe_subscription_id=p_stripe_subscription_id;

  -- Idempotence : un même abonnement Stripe ne peut augmenter le quota qu'une fois.
  if found then
    select max_coorganizers into v_new from public.workspace_entitlements where workspace_id=p_workspace_id;
    return query select coalesce(v_new,0),0;
    return;
  end if;

  insert into public.workspace_entitlements(workspace_id)
  values(p_workspace_id) on conflict(workspace_id) do nothing;

  select coalesce(max_coorganizers_cap,100) into v_cap
  from public.workspace_entitlements where workspace_id=p_workspace_id for update;

  update public.workspace_entitlements
  set max_coorganizers=least(coalesce(v_cap,100),coalesce(max_coorganizers,0)+p_quantity)
  where workspace_id=p_workspace_id
  returning max_coorganizers into v_new;

  insert into public.workspace_coorganizer_subscriptions(
    workspace_id,stripe_subscription_id,stripe_checkout_session_id,quantity,unit_amount_cents,status
  ) values(
    p_workspace_id,p_stripe_subscription_id,p_stripe_checkout_session_id,p_quantity,p_unit_amount_cents,'active'
  );

  return query select v_new,p_quantity;
end $$;

revoke all on function public.apply_paid_coorganizer_subscription(uuid,text,text,integer,integer) from public, anon, authenticated;
grant execute on function public.apply_paid_coorganizer_subscription(uuid,text,text,integer,integer) to service_role;

create or replace function public.cancel_coorganizer_subscription(
  p_stripe_subscription_id text
) returns void
language plpgsql security definer set search_path=public as $$
declare
  v_sub public.workspace_coorganizer_subscriptions%rowtype;
  v_active_count integer;
begin
  select * into v_sub from public.workspace_coorganizer_subscriptions
  where stripe_subscription_id=p_stripe_subscription_id for update;
  if not found or v_sub.status='cancelled' then return; end if;

  select count(*)::integer into v_active_count
  from public.workspace_members wm
  where wm.workspace_id=v_sub.workspace_id and wm.active=true and wm.role='coorganizer';

  update public.workspace_entitlements
  set max_coorganizers=greatest(v_active_count,coalesce(max_coorganizers,0)-v_sub.quantity)
  where workspace_id=v_sub.workspace_id;

  update public.workspace_coorganizer_subscriptions
  set status='cancelled',cancelled_at=now()
  where id=v_sub.id;
end $$;

revoke all on function public.cancel_coorganizer_subscription(text) from public, anon, authenticated;
grant execute on function public.cancel_coorganizer_subscription(text) to service_role;
