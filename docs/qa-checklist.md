# Validation de la première version jouable

## Parcours mobile (Android / Chrome)

- [ ] Ouvrir le jeu depuis GitHub Pages sur smartphone.
- [ ] Toucher une brique dans le plateau puis une case valide : la brique se place.
- [ ] Tourner une brique avant de la poser : orientation modifiée de 90°.
- [ ] Glisser une brique du plateau sur la grille : elle se place sans défiler la page.
- [ ] Toucher une brique placée : elle devient sélectionnée.
- [ ] Toucher **Retirer** : la brique revient au plateau.
- [ ] Toucher **Annuler** : le dernier déplacement est annulé.
- [ ] Toucher **Indice** : les cases de la pièce sélectionnée apparaissent.
- [ ] Essayer une case interdite et une case occupée : le jeu refuse sans supprimer de pièces.
- [ ] Reproduire le modèle : victoire, étoiles et déblocage du niveau suivant.
- [ ] Recharger l'onglet : meilleur score et niveau débloqué conservés.
- [ ] Installer le jeu depuis le navigateur, puis lancer sans connexion après un premier chargement.
- [ ] Tester le rendu à 320px, 360px, 390px et 768px de largeur.

## Parcours ordinateur

- [ ] Placer via clic, rotation via **R**, supprimer via **Suppr**.
- [ ] Annuler via **Ctrl+Z**.
- [ ] Parcourir les boutons au clavier et vérifier le focus visible.
- [ ] Désactiver les sons : aucun son lors du placement.
- [ ] Terminer les six niveaux : pas de blocage ni de plateau insoluble.

## Contrôles automatiques

Exécuter `npm run check` puis `npm test` (Node.js 22+).

Les tests vérifient les six solutions, la connectivité des formes, les rotations,
les collisions, la condition de victoire, les chemins PWA et les éléments d'interface.

**Important :** une réussite des tests automatiques ne remplace pas les essais tactiles
sur un appareil physique.
