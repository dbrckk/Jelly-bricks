# Prototype d'empilement — trois Jelly Bricks

## Base de comparaison

- Vidéo source réelle : [2824-original.mp4](../../../reference-media/2824-original.mp4), SHA-256 `e7423f103b11678e2f2bbc8224562c67b3924079c7f262def81d90723b971ef4`.
- Dans la moitié supérieure du film, les briques apparaissent plus lumineuses, réfléchissantes et translucides, avec des chevauchements et des déséquilibres. Aucun logo/texte n'est repris.
- Le prototype précédent gardait **une seule brique** ; celui-ci ajoute **trois volumes distincts** rouge / bleu / vert.

## Fonctionnement réellement implanté

- Trois briques moulées de 2×1, en trois couches espacées de `0.55` unité ; chaque couche dispose de son propre ShaderMaterial et de ses tenons colorés.
- La brique supérieure descend, touche à `t=0.68s` ; transmission analytique amortie vers la couche médiane `+0.085s`, puis la base `+0.170s`, avec pertes d'amplitude.
- Déformation GPU et léger rebond après contact. L'animation peut être inspectée avec le doigt sur la scène dédiée.
- Cinq véritables captures rendues par Godot 4.6 Compatibility en 720×1280, contrôlées par un test de luminosité/couleurs et un contrôle de propagation dans le bon ordre.

## Exécution

```bash
godot --headless --path native-godot --editor --import --quit
mkdir -p build/three-stack
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --path native-godot --rendering-driver opengl3 --resolution 720x1280 --script res://prototypes/single_brick/three_stack_capture.gd
godot --path native-godot --scene res://prototypes/single_brick/three_stack.tscn
```

## Bilan objectif

Le **contact sur trois couches est observable**, et les tests passent ; cependant l'aspect reste proche du plastique verni. L'effet est *déterministe*, **pas une physique des corps rigides ni une vraie gélatine volumétrique**. Il n'y a ni destruction/réassemblage ni collisions entre briques indépendantes. La transparence traversante essayée dans le prototype monopiece montrait les faces internes incorrectement, donc elle a été volontairement désactivée au profit d'un cœur teinté stable.

**Ne pas fusionner dans le gameplay principal avant validation visuelle.** Pour se rapprocher de la vidéo, prochaines priorités : modèle viscoélastique cohérent aux points d'appui, refraction/transmission sans révélation des faces internes, puis véritable étude de chute/instabilité à plusieurs briques.
