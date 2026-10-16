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

## Contrôles rapides sur Android

La barre **BRIQUES RAPIDES** reste accessible en bas de l'écran mobile. Touchez une pièce disponible, puis la grille pour la placer. Le bouton ↻ tourne la pièce sélectionnée et × la retire lorsqu'elle a été posée. Les briques se mettent à jour en même temps que la boîte principale. La barre est repliable via **Réduire** pour dégager la vue et elle n'apparaît pas sur PC. Aucune dépendance externe n'est nécessaire.

## Matériaux jelly (v0.5.0)

Les faces de briques connectées forment maintenant une silhouette sans interstice. Les surfaces utilisent un dégradé translucide, des reflets et des microbulles CSS sans WebGL ni textures téléchargées. Le calcul des jointures est indépendant des règles du puzzle et couvert par des tests sur toutes les rotations des 21 niveaux. Les animations de rebond se déclenchent uniquement sur la pièce modifiée ; le mode « réduire les animations » les désactive. Sur les petits écrans, les reflets évitent les filtres de flou coûteux.

## Performance sur mobile (0.5.1)

Le rendu ne reconstruit plus le modèle, les cases du plateau ni les briques inchangées à chaque sélection. Les pièces de la boîte et de la barre rapide sont réutilisées et seules leurs rotations modifiées redessinent les aperçus. Le plateau bénéficie aussi d'une lumière statique et d'un encadrement plus profond, sans boucle d'animation 3D. `npm run smoke` vérifie la persistance des nœuds DOM et mesure 48 interactions sur une grille 7×7 dans Chromium émulant un viewport Android de 390×844. Cette mesure CI n'est pas une mesure sur téléphone physique et ne permet pas de conclure aux FPS du Redmi.

## Prise en main guidée (v0.5.2)

Au premier lancement, un guide compact près du plateau indique comment sélectionner une jelly brick et comment la placer. Le texte change après une sélection, un indice ou les premiers placements. Après deux pièces posées, le tutoriel se ferme et ce choix est conservé sur l'appareil. La touche **? Aide** permet de le rouvrir à tout moment, même sur les niveaux suivants. Le guide ne bloque jamais l'écran de jeu. Le parcours de prise en main et sa persistance sont contrôlés dans Chromium mobile.
