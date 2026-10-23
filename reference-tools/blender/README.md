# Jelly Bricks — étalon matière rouge 2×1 (Blender / Godot)

**Projet de recherche optique isolé.** Aucune image Blender n'est intégrée au
jeu, aucun niveau ni fichier de sauvegarde n'est modifié, et la PR reste
expérimentale jusqu'à validation artistique et sur téléphone Android.

## Référence source et objectif

- Vidéo originale : `reference-media/2824-original.mp4`.
- Planche originale : `reference-media/2824-contact-sheet.png`.
- Point de départ : une unique brique rouge 2×1 à quatre tenons et dessous
  évidé, avant de passer à la pile multicolore. Les rendus ci-dessous ne sont
  **pas** des images extraites de la vidéo.
- Objectif : construire un standard visuel réel pour guider ensuite la
  transmission, les contours, la luminosité, la réflexion et la déformation.

## Deux moteurs différents, deux niveaux de réalisme

**Blender Cycles — étalon hors ligne**

- Script autonome `reference-tools/blender/render_red_gel.py`.
- Géométrie de référence : coque extérieure arrondie, quatre tenons, vrai
  évidement obtenu par différence booléenne.
- Matériau transparent Principled BSDF : IOR **1,34**, transmission **0,72**,
  rugosité **0,14** et absorption volumique (densité **0,78**).
- Trois grandes lumières studio, fond neutre, ombre réelle, colorimétrie
  contrôlée et rendu CPU à **96 échantillons** avec denoising.
- Sorties : `01-three-quarter.png`, `02-side.png`, `03-top.png` et un fichier
  `red-2x1-photoreal-reference.blend` éditable.
- CI séparée `.github/workflows/blender-gel-reference.yml`, téléchargeables en
  tant qu'artefact `jelly-bricks-red-gel-blender-cycles`. Les résultats sont
  des rendus ray-tracés hors ligne, **pas des mesures de qualité sur Android**.

**Godot 4.6 / Compatibility — matériau de jeu de référence**

- `subdivided_studio_mesh.gd` produit un maillage 2×1 de
  **512 à 8 192 triangles** après deux subdivisions géométriques :
  multiplication par 16 calculée et vérifiée réellement sous Godot 4.6.
- Cette densité est limitée à la **brique d'étude**, car généraliser
  8 192 triangles + une couche vernie à toutes les pièces peut être excessif
  pour le GPU mobile. La grille 21 niveaux conserve son maillage normal.
- `soft_reference.gd` partage exactement le même mesh entre le cœur coloré
  et le vernis et définit les états `rest`, `compression`, `rebound`.
- Les shaders continuent de déformer la silhouette sur GPU ; ce n'est **pas**
  une simulation FEM ou XPBD ni un changement de collider.
- Le studio `wet_gel_opaque_reference.gdshader` est **volontairement opaque**,
  avec absorption/diffusion colorée approximative. La tentative initiale de
  réfraction à l'écran (`hint_screen_texture`) mettait le corps dans la passe
  transparente de Godot Compatibility et révélait à tort le toit intérieur
  de l'évidement *à travers la surface supérieure*. La nouvelle référence
  supprime complètement les lectures écran et évite ce défaut géométrique
  observable, plutôt que de revendiquer une fausse réfraction volumique.

## Commandes de génération

Blender (sur une machine ou sur GitHub Actions) :

```bash
blender -b -t 4 --python reference-tools/blender/render_red_gel.py
```

Godot (dans la racine du dépôt) :

```bash
mkdir -p build/soft-reference
godot --headless --path native-godot --editor --import --quit
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot \
  --path native-godot --rendering-driver opengl3 \
  --resolution 720x1280 \
  --script res://prototypes/single_brick/soft_reference_capture.gd
```

La scène `soft_reference_mobile.tscn` permet aussi de sélectionner au doigt
les trois états et de pivoter autour de la brique. La CI exporte son APK de
revue sous un package distinct : `org.jellybricks.redreference`.

## Conditions avant intégration au jeu complet

1. Comparer **les mêmes cadrages et couleurs** à la référence source.
2. Obtenir une transmission de lumière crédible dans Godot *sans* faire
   apparaître les surfaces intérieures incorrectement.
3. Vérifier la silhouette déformée sur plusieurs impacts et différentes tailles.
4. Mesurer FPS, chauffe et stabilité sur smartphone Android réel.
5. Intégrer seulement l'architecture retenue et revalider les 21 niveaux.

**État actuel :** la référence Blender est éditable et optiquement transmissive.
La référence Godot est désormais dense, stable et correctement fermée mais
encore **visiblement opaque et moins réaliste**, ce qui reste à résoudre.
