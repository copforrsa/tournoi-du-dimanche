# SWÉ V41.04 — migration co-gestionnaires compatible

Cette version corrige la migration V41.03 pour la structure réellement présente en production.

## Ordre recommandé
1. Dans Supabase > SQL Editor, exécuter **SQL_V41_04_COORGANIZER_BILLING_COMPAT.sql**.
2. Vérifier que le résultat est `Success. No rows returned`.
3. Déployer / redéployer les Edge Functions :
   - `stripe-create-coorganizer-checkout`
   - `stripe-coorganizer-webhook`
4. Vérifier les secrets Edge Functions : `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `SWE_APP_URL`, `SWE_ALLOWED_ORIGINS`.
5. Dans GitHub Pages, remplacer `index.html`, `app.js`, `styles.css`, `sw.js` (et conserver `CNAME`).

## Compatibilité
- `max_coorganizers_cap` est conservé pour compatibilité avec l'ancien code.
- Il n'est plus utilisé comme plafond commercial pour les accès payants.
- `base_max_coorganizers` = accès inclus/offerts.
- `max_coorganizers` = accès inclus/offerts + abonnements Stripe actifs.
