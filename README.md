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
