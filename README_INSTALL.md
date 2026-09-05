# SWÉ TOURNAMENT 5/5 — V41.01 HOTFIX VISUELS

## Important
Cette version nécessite que **index.html, styles.css, app.js, sw.js et manifest.webmanifest** soient tous présents **à la racine du dépôt GitHub Pages**.

Si `styles.css` manque, l'application s'affiche sans design (police serif, boutons HTML bruts).
Si `app.js` manque, les fonctions interactives ne se chargent plus.

Après upload des fichiers, faire un rafraîchissement forcé (Ctrl+F5).
Le Service Worker utilise maintenant le cache `swe-tournament-5v5-v41-01`.

Les dossiers SQL et `supabase/functions` restent séparés du déploiement GitHub Pages et servent aux migrations / Edge Functions Supabase.
