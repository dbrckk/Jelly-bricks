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

## Installer et jouer hors ligne (v0.6.0)

L'application affiche maintenant **Installer sur mon téléphone** au-dessus du plateau. Dans Chrome Android, lorsque l'installation PWA native est proposée, ce bouton lance la demande d'installation. Sinon, une aide explique le chemin par le menu ⋮ du navigateur : **Installer l'application** ou **Ajouter à l'écran d'accueil**. Le jeu ne prétend pas être installé avant la confirmation du navigateur. Un indicateur signale également si le navigateur détecte une perte de connexion.

À la première visite **avec une connexion**, ouvrir le jeu et laisser les fichiers du cache hors ligne s'enregistrer. Ensuite, le jeu et les 21 niveaux peuvent fonctionner sans réseau, avec progression sauvegardée localement. La commande `npm run smoke` inclut désormais une vraie désactivation du réseau dans Chromium, un rechargement de la page, puis le contrôle du niveau 21 et des ressources en cache. Ce contrôle automatisé est distinct d'une validation sur un appareil Android physique. Pour la publication, activer une fois **Settings → Pages → GitHub Actions** dans le dépôt et vérifier le résultat du workflow **Publish Jelly Bricks**.

## Diagnostic sur Android (v0.6.1)

Le bouton **Tester mon téléphone** ouvre un diagnostic local. **Lancer les tests** vérifie que la sauvegarde locale accepte l'écriture, que les six fichiers essentiels sont effectivement présents dans la version la plus récente du cache PWA, détecte le mode application installée, et mesure pendant environ 1,25 seconde le rafraîchissement du navigateur au premier plan. Il présente aussi la taille de l'écran en pixels CSS et la présence d'un écran tactile. **Copier le rapport** permet de partager volontairement les résultats ; rien n'est envoyé automatiquement.

**Limites :** la fréquence mesurée est indicative, elle ne reflète pas nécessairement les FPS du puzzle en jeu. Le cache complet vérifié n'est pas une preuve que Chrome a installé l'application. Pour vérifier réellement le hors ligne sur le téléphone : ouvrir le jeu avec Internet, démarrer une partie, activer le mode avion, fermer puis rouvrir l'application, vérifier que la partie reprend. La disponibilité publique de GitHub Pages et les résultats sur Redmi physique demandent une vérification distincte.


## Vérification de la publication GitHub Pages

Après chaque fusion dans `main`, le workflow **Publish Jelly Bricks** exécute d'abord les tests, puis déploie le site. Une étape de contrôle interroge l'URL renvoyée par GitHub Pages et compare le contenu publié de `index.html`, `styles.css`, `manifest.webmanifest`, `sw.js` et de **tous les modules JavaScript** aux fichiers du commit. Les résultats et l'URL sont ajoutés au résumé du job en cas de succès.

**Attention :** la réussite de la PR ne confirme pas que le site est publié. Pour activer la première publication, sélectionner **Settings → Pages → Build and deployment → Source : GitHub Actions**. Vérifier ensuite le **job deploy** dans [Actions](https://github.com/dbrckk/Jelly-bricks/actions/workflows/pages.yml). Une erreur à l'étape « Check actual public release » indique une publication inaccessible ou une ancienne version encore servie. Le site attendu est `https://dbrckk.github.io/Jelly-bricks/`, sous réserve que Pages ait été activé.


## Jelly Bricks 3D — nouveau moteur WebGL (v0.7.0)

Le **rendu principal du plateau et du modèle mobile** utilise désormais une véritable scène WebGL avec des géométries 3D. Les morceaux sont des volumes arrondis, éclairés par des sources directionnelles, avec matériau **MeshPhysicalMaterial** (vernis, translucidité et absorption colorée), socle en relief et petite déformation amortie lors d'un placement. Le moteur 3D est synchronisé directement avec les rotations et placements existants. La caméra orthographique légèrement inclinée préserve les contrôles tactiles et l'alignement du puzzle ; la souris, le glisser-déposer, l'annulation et la sauvegarde continuent d'utiliser la logique déterministe déjà testée. L'agrandissement du modèle conserve pour l'instant l'affichage DOM classique.

**Bibliothèques open source utilisées et intégrées :**

- [Three.js](https://github.com/mrdoob/three.js) (MIT) : moteur de rendu WebGL, éclairages, géométries, matériau physique. Géométrie `RoundedBoxGeometry` issue des modules officiels Three.js.
- [esbuild](https://github.com/evanw/esbuild) (MIT) : compile Three.js et le code du jeu en un fichier statique `dist/app.js` autonome, sans CDN ni clé API.

La création des niveaux, la résolution et le stockage ne dépendent pas de Three.js. Une indisponibilité de WebGL laisse le plateau et les briques HTML/CSS **entièrement jouables**. Le rendu est limité à deux vues WebGL (plateau + modèle visible), la résolution est plafonnée à 1,5 pixel physique par pixel CSS, et l'animation 3D ne tourne pas en boucle à vide. Le mode de réduction des mouvements désactive le rebond du moteur 3D.

### Développement et publication

Installer Node.js 22+, puis exécuter :

```bash
npm install
npm run build
npm test
npm run smoke
```

Servir le dossier **`dist/`**, pas la racine source : `python3 -m http.server 5173 --directory dist`. L'application de production charge `./app.js`, le bundle local 3D. GitHub Actions construit ce même dossier avant de le publier sur GitHub Pages. Le service worker met en cache le bundle avec le reste des assets, permettant de réouvrir le jeu sans connexion après la première visite. Les tests Chromium forcent un WebGL logiciel si disponible et vérifient le repli 2D sinon.

**Limite de cette étape :** le rendu est désormais *réellement* volumétrique, mais ce n'est pas encore une simulation physique de gelée déformable sommet par sommet. Le prochain chantier est le matériau et la silhouette continue des polyominoes, les animations élastiques plus complexes et la mesure de FPS sur un vrai appareil Android.


## Gameplay 3D tactile amélioré (v0.7.1)

La pièce déplacée affiche désormais un fantôme semi-transparent **directement dans la scène Three.js**, en vert lorsque la position est valide et en rouge sinon. Ce fantôme est retiré automatiquement à la fin du geste. L'assistance de placement magnétique pardonne au maximum **une case de décalage horizontal ou vertical**, sans jamais contourner les règles du puzzle : aucune collision ni emplacement hors de la forme cible ne sont autorisés. Les placements exacts sont toujours prioritaires, l'annulation et la sauvegarde restent inchangées. Le code de résolution est testé indépendamment et sur tous les 21 niveaux.

Ce système donne un guidage visuel 3D mais **pas encore une physique de gelée intégralement déformable** ; les prochaines étapes peuvent approfondir la simulation des vibrations et la liaison entre cubes, en fonction des mesures de performances sur Android.

## Gélatine 3D souple (v0.7.2)

Les impacts disposent maintenant d'un **ressort amorti de 590 ms** qui combine squash/stretch, élévation temporaire et ondulations des sommets 3D par le GPU. L'animation n'utilise pas un moteur physique permanent : seules les briques qui viennent d'être posées sont animées, avec un matériau temporaire qui se déforme au niveau des sommets (`MeshPhysicalMaterial.onBeforeCompile`). Le point de pivot est situé **au milieu de la pièce elle-même**, évitant que les longues briques bougent hors de leur case pendant le rebond. Les matériaux statiques et la géométrie restent mutualisés pour ménager les GPU Android. Les matériaux temporaires sont libérés lorsqu'ils ne sont plus utilisés.

Le shader de déformation est testé dans Chromium avec WebGL logiciel ; les fonctions mathématiques de rebond et le centrage géométrique sont testés sur toutes les rotations des **21 niveaux**. Les préférences système « réduire les animations » et le repli HTML/CSS continuent à être respectés. Il s'agit désormais d'une déformation dynamique de sommets, mais pas d'une simulation de collision viscoélastique complète entre briques.

## Pièces de gelée fusionnées en véritables volumes 3D (v0.7.3)

Les briques adjacentes d'une même pièce ne sont plus dessinées comme autant de cubes distincts : un algorithme de contours supprime les parois intérieures et crée une silhouette continue de polyomino. Three.js extrude cette silhouette avec un **biseau arrondi sur tout son contour**, en conservant les trous des formes qui en comportent. Le matériau translucide et le shader de déformation élastique de la v0.7.2 continuent à s'appliquer à la forme entière. Un fantôme de glisser-déposer en 3D affiche la même pièce fusionnée plutôt qu'une collection de cubes.

Les géométries sont partagées et mises en cache par forme et rotation, évitant de recréer les volumes à chaque interaction. Les tests confirment que la surface de chaque pièce, pour toutes les rotations des 21 niveaux, est strictement préservée ; les trous et les îlots sont aussi vérifiés. Le nombre de *maillages GPU* est désormais réduit : trois pièces distinctes de neuf cases se dessinent en trois volumes, pas neuf cubes.

Le fonctionnement tactile reste basé sur les cellules logiques de départ, donc la fusion graphique ne change ni les collisions, ni la notation, ni les sauvegardes.

## Studio jelly : éclairage, reflets et ombres (v0.7.4)

Le moteur Three.js calcule maintenant une **image d'éclairage de studio** en local avec le module officiel open source `RoomEnvironment` et un environnement PMREM : les pièces gélatineuses bénéficient de reflets PBR de type softbox, d'un vernis plus brillant et d'une transmission modérée qui préserve leur couleur. Aucune image HDR distante, requête de texture, publicité ou service payant n'est nécessaire.

Une ombre de contact géométrique est générée à partir du **véritable contour de chaque polyomino**, y compris les trous, et placée sous les formes 3D. Pendant le rebond, elle s'élargit discrètement sans bouger de la surface du plateau. Les silhouettes d'ombre sont mises en cache par forme et rotation ; les matériaux sont partagés à l'échelle de chaque scène.

Sur smartphone, la résolution effective WebGL est plafonnée à **1,25×** et le cube de réflexion à **64 px** ; sur ordinateur, respectivement 1,5× et 128 px. Si le navigateur signale 2 Go de RAM ou moins, l'environnement est désactivé et le rendu utilise uniquement les lumières directes. Le mode HTML/CSS reste un recours en cas d'échec WebGL. Les tests vérifient les limites de qualité et l'éclairage/les ombres sur les scènes mobiles avec Chromium, sans prétendre mesurer les FPS d'un vrai Redmi.


## Réactions jelly entre les briques (v0.7.5)

Quand une nouvelle pièce touche **par un côté** une ou plusieurs briques déjà placées, les volumes 3D voisins vibrent légèrement. Cette réaction secondaire dépend du nombre d'arêtes en contact, se propage avec un petit retard et revient automatiquement au repos. Les contacts diagonaux ne comptent pas. Elle fonctionne sur les mêmes maillages fusionnés que les volumes continus de la v0.7.3.

Le calcul des contacts est une fonction pure testée sur les 21 niveaux, sans modification des règles ni du score. L'effet n'ajoute **aucune boucle d'animation permanente** et est désactivé quand le système demande de réduire les animations. Le navigateur Chromium mobile valide aussi qu'une seconde pièce posée provoque bien une réaction sur la première. Cette amélioration ne constitue pas une simulation complète des contacts physiques souples ; elle donne un retour visuel plus vivant à l'assemblage.

## Graphismes Three.js adaptables pour Android (v0.8.0)

Un nouveau sélecteur **Graphismes** apparaît dans la barre supérieure du jeu, utilisable sur Android sans ordinateur. Il propose :
- **Auto** (réglage par défaut) : scène 3D réfléchissante en rendu 1,25× sur mobile ; selon les indications du navigateur, passe au mode économique lorsque la mémoire annoncée est ≤2 Go ou que l'économiseur de données est actif.
- **Fluide** : rendu de 1× ou moins, suppression de l'environnement préfiltré, de l'anticrénelage et de la réfraction coûteuse ; conserve les pièces 3D, les ombres de contact et les animations.
- **Détaillé** : rendu jusqu'à 1,75× sur Android, reflets de studio 128 px, matière plus translucide et légère iridescence dans les reflets.

Le choix est conservé *sur le téléphone uniquement* dans `localStorage` et s'applique immédiatement à la scène Three.js sans perdre le niveau, la progression, l'annulation ou les pièces posées. Les anciens contextes WebGL et leurs textures sont libérés à chaque changement, ce qui évite de laisser les contextes concurrents utiliser la mémoire GPU. Le mode Auto est un **choix conservateur selon les indices exposés par le navigateur**, et non un réglage dynamique déjà calibré sur les FPS du Redmi. Un GPU ancien ou un navigateur sans WebGL conserve le jeu 2D accessible.

Le coût de `MeshPhysicalMaterial` dépend des fonctionnalités activées, notamment la transmission, l'iridescence et le vernis : le mode Fluide les simplifie délibérément. La version fonctionne toujours sans CDN, téléchargements de textures, compte ou API. Le test navigateur contrôle les trois profils sur la même partie, le nombre de canvases et la sauvegarde, en plus des tests unitaires habituels.
