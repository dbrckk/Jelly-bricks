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

## v8 — composition optique de deux briques indépendantes

Pour la première fois dans ce prototype, une brique **bleue 1×1** est posée
sur la brique **rouge 2×1**. La brique du dessus peut recevoir des pixels
qui contiennent déjà le rendu de la brique du dessous.

L'architecture est une composition **en profondeur, sans récursion** :

| Passe | Masque caméra | Contenu | Consommateur |
|---|---|---|---|
| A | `1` | Décor sans aucune brique | Gel rouge |
| B | `1 + 2 = 3` | Décor + gel rouge | Gel bleu |
| Vue principale | `1 + 2 + 4 = 7` | Décor + rouge + bleu | Écran Android |

- Chaque brique reste **opaque du point de vue du tampon de profondeur**,
  afin d'éviter les faces intérieures visibles par transparence incorrecte.
- Les deux briques utilisent chacune un matériau shader distinct, une géométrie
  dense distincte, et la même propagation visuelle compression/rebond.
  La brique bleue 1×1 comporte **deux tenons** et non quatre.
- Le modèle court est centré sur le modèle long ; ce placement est un
  **prototype de composition statique et animée visuellement**, pas une
  simulation physique de gelée molle.
- Les deux passes n'ont **pas de dépendance cyclique** : A est source de B,
  B est source de la principale. Le bleu n'est jamais inclus dans le
  rendu qu'il échantillonne.
- L'application de revue ajoute **PILE: 1 / 2 BRIQUES**, ainsi que
  **GPU: ECO / DETAIL**, aux boutons de v7.
- Le deuxième `SubViewport` utilise par défaut **34 % de résolution
  sur chaque axe**, au maximum 540 × 960 pixels. La passe additionnelle est
  automatiquement coupée en mode *une seule brique* ou transmission désactivée.
- Les **quatre captures Godot GPU** sont archivées par
  `layered_reference_capture.gd` :
  `01-two-gels-transmitted.png`,
  `02-blue-optics-off.png`,
  `03-red-only-gpu-saved.png`,
  `04-two-gels-compression.png`.
  Le test compare les pixels bleus de la brique supérieure avant/après
  désactivation de sa lecture du fond composite pour prouver que la passe B
  influe réellement sur l'image.
- Application indépendante `org.jellybricks.dualgellab`, exportée
  uniquement dans la PR expérimentale, sans remplacer le jeu principal ni
  la référence Android rouge v7.

### Coûts et limites

La méthode utilise **deux rendus secondaires supplémentaires** en plus de
la vue principale, dont le premier est déjà requis par la v7. Elle n'est
pas gratuitement extensible à de nombreuses pièces, faute de quoi les
passes graphiques se multiplieraient. L'architecture doit être mesurée
sur smartphone : temps de GPU, chauffe, autonomie, temps de frame et
surdessin. La transmission repose toujours sur une approximation en
espace écran, sans caustiques ni réfraction physique de chaque interface.
Aucun résultat de CI Mesa ne remplace ces mesures.

## v9 — retour élastique couplé, volume et étude de robustesse Android

**Objectif :** améliorer le ressenti de gelée sans abandonner le rendu
multicouche v8 et sans imposer une simulation de particules lourde sur Android.

- Le nouveau `coupled_gel_springs.gd` est un **oscillateur à deux degrés de
  liberté**, un pour la grande brique rouge et un pour la petite bleue.
  Chaque état possède vitesse, position, fréquence propre et amortissement ;
  une force de couplage échange les impulsions entre les deux. L'intégration
  semi-implicite se fait à un **pas numérique fixe de 1/120 s**, même si le
  smartphone affiche 30 ou 60 FPS. Les déplacements sont bornés, les
  impacts répétés amortis et l'état finit au repos.
- Cette approche est une simulation du **mouvement élastique d'affichage**,
  **pas** une simulation FEM, XPBD ou un `SoftBody3D` avec collisions
  déformables. La scène d'étude conserve ses objets géométriques de
  référence. Elle ne doit pas être commercialisée comme un moteur
  physique volumétrique complet.
- Les shaders du corps `wet_gel_viewport_reference.gdshader` et du
  vernis `wet_coat.gdshader` disposent d'un coefficient partagé
  `volume_conservation`, par défaut **0 pour les scènes v7** et les
  autres projets. Sur la pile d'étude v9, il approche la conservation
  du volume d'un objet élastique :
  `largeur = sqrt(1 / hauteur_relative)` (à forme homogène simplifiée).
  L'identité `hauteur × largeur² ≈ 1` est contrôlée mathématiquement.
  Le vernis et le corps utilisent exactement la même expression.
- Le bouton **CHOC GEL** déclenche une vraie évolution temporelle du
  système couplé et non un changement instantané vers une image fixe.
  Les deux couronnes s'écrasent, rebondissent avec une légère inertie
  différente et reviennent au repos. Le mouvement des deux maillages de
  tenons reste lié à leur pièce respective.
- Le modèle physique affiche son résultat dans la même paire de rendus
  secondaires qu'en v8. **Aucune passe graphique supplémentaire pour
  ajouter le ressort** ; seulement quelques paramètres de shader
  actualisés aux images et deux équations différentielles amorties.
- La validation numérique `coupled_gel_springs_verify.gd` vérifie
  les amplitudes rouge/bleu, le rebond signé, l'échange de mouvement,
  l'absence de valeurs infinies/NaN, le retour au repos, les tapotements
  répétés et la stabilité du résultat à 30 et 60 FPS.
- La validation GPU `layered_reference_capture.gd` contrôle
  l'alignement corps/vernis pendant les oscillations et produit en
  complément **`05-coupled-impact.png`**,
  **`06-coupled-rebound.png`** et
  **`07-coupled-settled.png`**. Le flux Android de comparaison est
  toujours séparé du jeu principal.
- APK dédiée `org.jellybricks.geldynamicslab`, avec les contrôles
  précédents et le nouvel impact. L'ancien prototype optique v8 peut
  rester installé pour les comparaisons.

**Optimisation et garde-fous :** le modèle viscoélastique est léger,
mais les deux textures de fond et les maillages denses restent les postes
de coût possibles. La qualité doit être jugée sur Android réel (FPS,
`frame time`, chauffe et autonomie), pas à partir des performances
de rendu Mesa/OpenGL des captures automatisées.

## v10 — une déformation réellement perceptible, avec onde d'interface

Les captures v9 montrent un ressort mathématiquement correct mais **une
silhouette trop rigide**, avec des détails de brillance donnant encore une
impression de plastique moulé. La v10 cible explicitement ces lacunes
sans augmenter le nombre de passes graphiques.

- `GEL FORT` : nouveau curseur Android **100 à 220 %** (valeur
  initiale **190 %**) qui amplifie *uniquement* la déformation affichée.
  Le calcul de ressort à 120 Hz reste inchangé ; on peut ainsi évaluer
  l'impact esthétique indépendamment de la stabilité physique.
- Deux points de contact explicites correspondant à la géométrie du
  laboratoire sont injectés dans les shaders :
  **rouge (1, 0,52, 0,5)** sur la couronne supérieure et
  **bleu (0,5, 0,06, 0,5)** sous la petite brique. Le choc fait naître
  une compression locale et une onde annulaire temporaire, puis les
  amplitudes décroissent exponentiellement jusqu'au repos.
  **Ces coordonnées sont inférées de la mise en scène**, et non des
  données de contact d'un `RigidBody3D` ; la distinction est importante.
- Le cœur et le vernis de **chaque pièce** ont les mêmes coordonnées
  de contact, énergie, âge d'onde et taux de compression. Les corps restent
  physiquement **rigides** et la conservation du volume demeure une
  **approximation analytique** et non une contrainte de simulation volumique.
- Les matériaux des tenons sont moins laiteux et moins spéculaires ;
  la fine couche de vernis est atténuée pour limiter l'aspect jouet
  plastique. Aucun fichier graphique externe n'est ajouté.
- Les sept captures Godot restent obligatoires ; la CI mesure la
  **déformation plus importante** pendant l'impact, prouve que le
  curseur ne touche pas à l'énergie du ressort, vérifie l'exacte parité
  cœur/vernis de l'onde, et impose une onde éteinte au repos.
- **Coût sur Android** : nouvelles valeurs de shader pour deux briques,
  pas de passe de rendu supplémentaire. Les performances réelles doivent
  toujours être contrôlées sur le smartphone.

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
