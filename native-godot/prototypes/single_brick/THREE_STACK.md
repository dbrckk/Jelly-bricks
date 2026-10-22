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

## Itération du 22 octobre — structure de référence et culling homogène

Les captures réellement générées depuis `2824-original.mp4` montrent une pile
**longue / courte / longue**, avec l'appui intermédiaire plus étroit. Le
prototype reproduit désormais cette distribution de tailles : deux cellules
rouge à la base, une cellule bleue avec deux tenons au centre, et deux cellules
vertes en haut. Il ne remplace toujours pas le jeu installé.

Le test OpenGL a identifié une régression structurale dans la nouvelle pièce
courte : son maillage utilisait les indices d'origine, alors que les deux
briques longues utilisaient la copie à orientation corrigée. Résultat : la
pièce centrale affichait une cavité sombre au lieu d'une face supérieure.
Les trois briques emploient à présent **la même correction de winding**,
avec une copie locale du maillage, et le test vérifie la largeur de la pièce
centrale et ses deux tenons.

La simulation différée est renforcée : impulsion supérieure à `t=0.68s`,
réaction médiane `+0.085s`, base `+0.170s`, inclinaison et cisaillement
amortis. La vérification OpenGL génère cinq états. Ce mouvement reste
analytique et non une vraie simulation de collision ou de matière.

**Comparaison qualitative :** proportions et lisibilité des empilements
meilleures ; finition encore trop opaque et trop plastique par rapport à la
moitié supérieure de la vidéo. Aucune validation Play Store revendiquée.
