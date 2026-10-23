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

## v7 — transmission réelle de l'arrière-plan en restant opaque

**Résolution du principal blocage visuel v6 :** le gel peut maintenant
transmettre et déformer une image de fond sans afficher les surfaces
intérieures de l'évidement comme si elles étaient au premier plan.

1. `soft_reference.gd` place le corps, les tenons et le vernis sur la couche
   de visibilité **2** ; le plan de fond, les contacts et la carte de
   diagnostic restent sur la couche **1**.
2. Un `SubViewport` séparé réutilise le **même World3D**, avec une caméra
   orthographique synchronisée sur la vraie caméra, mais avec
   `cull_mask = 1` : il n'y a donc **aucune brique dans la texture de fond**.
3. La texture du `SubViewport` est affectée directement à un **sampler2D
   ordinaire**, sans `hint_screen_texture` : le matériau principal reste
   dans la passe **opaque**, écrit la profondeur et masque sa cavité.
4. `wet_gel_viewport_reference.gdshader` échantillonne le fond à partir de
   `SCREEN_UV`, décale légèrement la coordonnée selon la normale, atténue
   les composantes lumineuses différemment selon l'épaisseur analytique
   du corps (Beer-Lambert approximatif) et mélange la transmission à la
   couleur de peau. Cinq petits échantillons spatiaux diffusent le motif
   au lieu de le recopier tel un autocollant.
5. Le fond secondaire coûte une passe additionnelle **à demi-résolution**,
   plafonnée à **540 × 960** sur les grands écrans. Lorsqu'on désactive
   `LUMIERE`, sa mise à jour est désactivée pour économiser le GPU.
6. `transmission_test_card.gdshader` dessine un échiquier contrasté sous
   la brique, invisible normalement. Les boutons **FOND TEST** et
   **LUMIERE** du visualiseur Android contrôlent de vraies géométries et
   paramètres shader, sans remplacer l'image de jeu par un montage.
7. Le test Godot crée **5 vrais rendus GPU** :
   `01-red-rest.png`, `02-red-compression.png`,
   `03-red-rebound.png`, `04-pattern-transmitted.png`,
   `05-pattern-opaque.png`. Il mesure la différence de pixels rouges
   entre transmission ON/OFF et échoue si elle est quasi nulle.

**Première preuve mesurée sur rendu Mesa/OpenGL :** delta moyen RVB
ON/OFF **0,2183** dans la zone rouge diagnostique (avant la correction de
coloration/diffusion ajoutée ensuite). Les carrés sous la brique sont
effectivement visibles à travers sa surface, tandis que le dessus reste
fermé.

**Limites importantes :** cette méthode transmet un fond rendu séparément ;
ce n'est **pas** une véritable réfraction multi-interface, elle ne simule
pas les rayons traversant plusieurs gelées empilées, et elle exige une
passe graphique supplémentaire. Les ombres, occlusions et objets ajoutés
au fond doivent être explicitement inclus dans la vue secondaire.
Le profilage sur un vrai Android reste obligatoire avant une intégration
à plusieurs pièces ; la vitesse de Mesa CI ne mesure pas celle du téléphone.

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

**État actuel :** la référence Blender est éditable et optiquement
transmissive. Dans la référence Godot, la transmission d'un arrière-plan réel
est désormais visible tout en conservant la profondeur opaque. Son réalisme,
sa profondeur chromatique et son coût GPU restent à améliorer ; **ne pas
fusionner ce prototype dans le jeu principal** avant validation sur appareil.
