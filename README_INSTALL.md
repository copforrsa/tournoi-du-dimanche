# Tournoi du Dimanche — PWA

Ce dossier est prêt à être publié tel quel.

## Publication GitHub Pages
1. Crée un nouveau dépôt GitHub, par exemple `tournoi-du-dimanche`.
2. Ajoute à la racine tous les fichiers de ce dossier.
3. Dans GitHub : Settings > Pages.
4. Source : Deploy from a branch.
5. Branch : `main` / dossier `/root`.
6. Enregistre.
7. GitHub te donnera une URL publique en HTTPS.

## Installation iPhone
Ouvre l’URL dans Safari > Partager > Sur l’écran d’accueil.

## Installation Android
Ouvre l’URL dans Chrome > menu > Installer l’application / Ajouter à l’écran d’accueil.

## Backend
L’application est déjà configurée avec le projet Supabase `tournoi-dimanche`.
La clé utilisée est une clé publishable prévue pour le frontend. Les données sont protégées par RLS.


## Mise à jour mot de passe oublié
- Bouton « Mot de passe oublié ? » sur l'écran de connexion.
- Envoi du lien Supabase vers l'URL GitHub Pages.
- Écran intégré pour saisir et confirmer le nouveau mot de passe après le clic sur le lien reçu.
- Cache PWA passé en v2 pour récupérer correctement les mises à jour.
