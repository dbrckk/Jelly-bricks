# Jelly Bricks

Jeu de puzzle mobile-first : reproduire un modèle en assemblant des briques gélatineuses.

## Jouer localement

Aucune dépendance de production. Démarrer un serveur statique à la racine du dépôt :

```bash
python3 -m http.server 5173
```

Ouvrir http://localhost:5173 dans un navigateur. Sur Android, le jeu peut être publié sur GitHub Pages puis installé comme PWA.

## Tests

```bash
npm test
npm run check
npm run smoke   # Chromium / Chrome requis
```

## Gameplay

- Observer le modèle coloré.
- Sélectionner une brique dans le plateau puis toucher une case pour la placer (coin supérieur gauche de la pièce).
- Faire pivoter avec **Tourner**, ou utiliser le glisser-déposer tactile.
- Remplir les cases pour reproduire exactement le modèle.
- **Indice** montre l'emplacement réel de la pièce sélectionnée.
- **Retirer**, **Annuler**, **Recommencer** et **Vérifier** permettent de progresser.
- Progression et meilleurs scores conservés localement sur l'appareil.

## Architecture

- `index.html` : écran accessible, sans framework.
- `styles.css` : interface responsive et rendu visuel jelly.
- `src/game.js` : niveaux, rotations et règles pures.
- `src/main.js` : interactions tactiles, clavier, interface et sauvegarde.
- `tests/game.test.js` : contrôle des invariants de jeu.
- `manifest.webmanifest` et `sw.js` : installation / cache hors ligne.

## Déploiement

Le workflow `.github/workflows/pages.yml` est prévu pour GitHub Pages. Dans **Settings → Pages → Build and deployment**, choisir **GitHub Actions**. Le workflow publie ensuite automatiquement la branche principale.

## Choix techniques

Pas de service distant, compte obligatoire, traceur ou clé API. Modules JavaScript natifs, Web Audio facultatif et stockage local. Priorité à une version testable depuis Android.

## Sauvegarde des parties

Les parties inachevées sont automatiquement sauvegardées sur cet appareil (localStorage) à chaque action et régulièrement pendant le jeu. Le dernier niveau en cours reprend après un rechargement. Les sauvegardes sont validées avec les règles réelles de placement avant restauration ; le bouton **Recommencer** réinitialise volontairement le niveau actif. La progression de chaque niveau déjà ouvert reste conservée séparément. Aucun compte ni synchronisation serveur.

## Collection de puzzles

21 modèles à difficulté progressive : les 6 niveaux d'origine plus 15 pictogrammes colorés (cœur, fleur, fusée, papillon, couronne, poisson, gâteau, fantôme, champignon, château, tortue, diamant, renard, maison et alien). Les six identifiants d'origine sont inchangés pour préserver les sauvegardes. Sur téléphone, le modèle miniature reste juste au-dessus de la grille et le bouton **Agrandir le modèle** affiche une référence détaillée sans modifier la partie.
