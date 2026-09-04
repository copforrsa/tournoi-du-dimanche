-- SWÉ TOURNAMENT 5/5 — préparation du module 3e mi-temps
-- NE PAS EXÉCUTER AVANT VALIDATION. Toutes les valeurs sont désactivées par défaut.
alter table public.workspace_entitlements
  add column if not exists third_half_enabled boolean not null default false;

alter table public.tournaments
  add column if not exists entry_fee_cents integer not null default 0 check (entry_fee_cents >= 0),
  add column if not exists cooler_suggested_cents integer not null default 0 check (cooler_suggested_cents >= 0);

create table if not exists public.tournament_payments (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  event_payment_mode text check (event_payment_mode in ('online','arena')),
  event_payment_status text not null default 'pending' check (event_payment_status in ('pending','paid','pay_on_site','cancelled','refunded')),
  event_amount_cents integer not null default 0 check (event_amount_cents >= 0),
  cooler_payment_mode text check (cooler_payment_mode in ('online','cash')),
  cooler_amount_cents integer not null default 0 check (cooler_amount_cents >= 0),
  stripe_payment_intent_id text,
  event_paid_at timestamptz,
  cooler_paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tournament_id,player_id)
);

create index if not exists tournament_payments_tournament_idx
  on public.tournament_payments(tournament_id);
create index if not exists tournament_payments_player_idx
  on public.tournament_payments(player_id);

-- À prévoir au moment de l'activation :
-- 1. exposer third_half_enabled dans get_workspace_features et le snapshot public ;
-- 2. ajouter un RPC Super Admin dédié pour activer/désactiver le module ;
-- 3. RLS/RPC admin pour état des paiements ;
-- 4. RPC public limité pour choix "payer en ligne / payer à l'Arena" ;
-- 5. Stripe Checkout + webhook sécurisé côté serveur ;
-- 6. classement public des dons = somme cooler_amount_cents payés, sans exposer les données Stripe.
