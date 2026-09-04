# Module 3e mi-temps — plan d'intégration

Le module est conçu comme une option payante indépendante et désactivée par défaut afin de ne pas modifier le fonctionnement actuel.

## Périmètre prévu
- Activation par le Super Admin au niveau de l'espace.
- Prix du tournoi / Swé défini par l'administrateur.
- Deux modes pour le prix de participation : paiement en ligne ou paiement direct à l'Arena.
- Deux modes pour la glacière : participation en ligne ou remise main à main.
- État admin : à payer / payé / paiera sur place / annulé / remboursé.
- Classement public des meilleurs donateurs à la glacière lorsque le module est actif.
- Stripe sera raccordé ultérieurement côté serveur ; aucune clé secrète ne doit être placée dans index.html.

## Règle de non-régression
Si third_half_enabled = false ou si le backend n'a pas encore reçu la migration, l'application conserve exactement le flux actuel : inscription gratuite, aucune étape de paiement, aucun bloc glacière.
