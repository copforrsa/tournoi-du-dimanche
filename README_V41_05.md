# SWÉ V41.05 — migration co-gestionnaires compatible production

Cette version remplace le SQL V41.04 qui ne doit pas être relancé.

## Script à exécuter

`SQL_V41_05_COORGANIZER_BILLING_COMPAT_SAFE.sql`

Il est adapté à la structure actuellement observée en production :
- `workspace_entitlements.max_coorganizers_cap` existe encore ;
- `workspaces.max_coorganizers` reste utilisé par plusieurs RPC historiques ;
- `workspace_billing.extra_coorganizers` reste utilisé par l’interface ;
- la table `workspace_coorganizer_subscriptions` n’existait pas encore.

La nouvelle source de vérité calcule : **accès inclus/offerts + accès Stripe actifs = capacité totale**. Le résultat est synchronisé dans les champs historiques afin de ne pas casser l’application existante.

## Après succès SQL

Déployer / mettre à jour les Edge Functions :
- `stripe-create-coorganizer-checkout`
- `stripe-coorganizer-webhook`

Ne pas supprimer les Edge Functions de paiement tournoi existantes.
