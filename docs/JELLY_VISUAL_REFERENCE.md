# Jelly Bricks — cahier de référence visuelle (vidéo utilisateur)

**Référence artistique définitive : la vidéo envoyée précédemment par le
créateur du jeu.** Elle prime sur les captures issues des précédentes versions
de Jelly Bricks et sur les styles de matériaux génériques trouvés en ligne.

> **Référence originale effectivement analysée le 18/10/2026 :** pièce
> jointe `2824.mp4`, H.264, 1008×1280, 30 images/s, 13,259 secondes,
> SHA-256 `e7423f103b11678e2f2bbc8224562c67b3924079c7f262def81d90723b971ef4`.
> La vidéo est une capture **comparative de deux scènes Jelly Bricks
> côte à côte verticalement** ; la moitié supérieure rend les briques
> fortement vernies, la moitié inférieure plus mates. L'objectif retenu
> pour le matériau est le rendu brillant de la scène supérieure, sans
> reprendre sa surcouche d'interface ou ses mentions de modèles/prix.
> L'**original binaire est maintenant archivé sur GitHub** dans
> `reference-media/2824-original.mp4` avec son SHA-256 vérifié ; les captures
> `2824-contact-sheet.png`, `2824-stack.jpg` et `2824-collapse.jpg`
> sont archivées à côté.

## Critères visuels non négociables

1. **Silhouette** — véritables briques moulées, faces principales assez
   droites, coins/biseaux doux, deux rangées de tenons courts et presque
   plats. Ni LEGO opaque rigide, ni longues capsules ballon.
2. **Matière** — gel fortement coloré et légèrement transparent, à peau
   brillante; intérieur lumineux mais teinté, silhouette et base plus
   denses par absorption optique. La couleur ne vire pas à un pastel blanc.
3. **Jonctions physiques** — les tenons pénètrent dans les cavités sous les
   pièces du niveau supérieur. Les volumes semblent **reposer les uns
   sur les autres**, pas flotter entre des lames d'air régulières.
4. **Éclairage** — photographie produit sur fond clair, grandes fenêtres
   réfléchies dans les flancs et les dessus, fins liserés sur les vrais
   biseaux, ombres diffuses et lumière colorée transmise au support.
5. **Mouvement** — la pose déclenche une compression qui conserve à peu
   près le volume, suivie d'une légère détente / oscillation amortie.
   Le choc atteint les briques de soutien seulement **après** contact
   et se propage vers le bas avec retard et perte d'amplitude.
6. **Clarté tactile** — visualisation du placement et des refus sans
   déclencher de brique intempestivement lors des gestes à deux doigts.
7. **Mobile Android** — Godot 4.6 Compatibility/GLES3 sur ARM64; effets
   prioritaires exécutés dans les meshes et shaders déjà instanciés.
   Les modes Galerie coûteux demeurent facultatifs et plafonnés.

## Vérification des futures versions

- Générer avec le vrai moteur Godot les captures reproductibles
  `jelly-stack-preview.png`, `jelly-stack-impact-preview.png`,
  `jelly-stack-gallery-preview.png`, et
  `jelly-stack-reference-tower-preview.png`.
- Examiner **à taille écran smartphone** : densité des pigments, forme des
  tenons, transmission sur le cœur, contact entre les neuf niveaux,
  ombres, reflets, lisibilité des commandes. Un changement de shader
  compilable ne constitue pas en soi une amélioration visuelle.
- Lorsque la vidéo originale est disponible, extraire les mêmes instants :
  vue proche d'une brique isolée, tour immobile, moment d'impact et moment
  de retour au repos; aligner angle, cadrage et exposition. Consigner
  explicitement les différences résiduelles avant toute affirmation
  d'équivalence.
- Tous les changements de forme et de placement doivent conserver la
  validité déterministe des 21 puzzles, l'intégrité des constructions
  sauvegardées et le parcours d'export Android/APK/AAB.

## État de référence technique — Android 0.9.57

- `STEP = 0.55` entre niveaux, cavité profonde de `0.21` au lieu de
  `0.16`. Jeu au sommet des tenons `0.017` et espace extérieur de
  `0.045` unité, contre `0.095` auparavant.
- Opacité de base solide `0.865`, avec densification Fresnel renforcée déjà dans le
  shader; les fantômes restent `0.43`. Transmission pigmentée
  `studio_transmission = 0.86` en atelier, `1.0` en Galerie, `0.0`
  pour les fantômes et les 21 puzzles.
- La transmission est une **illusion locale de transport optique**, pas
  une réfraction physique ni une simulation volumétrique exacte.
- **Les captures Mesa/OpenGL ne remplacent pas le test de FPS,
  température, autonomie et couleurs sur un véritable appareil.**

Mettre à jour cette fiche quand les captures et, surtout, la vidéo
originale montrent un nouvel écart plus important que les effets déjà
corrigés. Ne pas remplacer cette référence finale par une intuition
esthétique, un preset de moteur ou un simple « rendu premium ».


## Comparaison image-par-image — vidéo 2824.mp4 / Godot 0.9.57

Images originales vues à **0,5 s**, **2,0 s**, **5,2 s**,
**6,5 s**, **9,5 s** et **12,5 s**. Captures Godot inspectées :
`jelly-stack-reference-tower-preview.png` et
`jelly-stack-gallery-preview.png` issues du vrai pipeline Mesa OpenGL.

| Aspect | Vidéo, moitié supérieure | Rendu Android 0.9.57 | Correction 0.9.58 |
| --- | --- | --- | --- |
| Dessus | Grand plateau presque plat, liseré périphérique étroit | Couronne bombée `+0,065` évoquant un coussin gonflable | Centre `+0,018`, normale proche de la verticale |
| Flanc | Mur presque droit, vertical sur l'essentiel de la hauteur | Biseaux étendus, impression de capsules | Mur plat `0,473→0,130`, rayon de coin réduit |
| Coins | Arrondis fins, de type moule à bonbons | Coins trop larges | Rayon `0,105` et retrait de biseau maxi `0,036` |
| Couleurs | Rouge rubis, bleu cobalt, vert vif, jaune or, orange | Rose/vert pastel, absorption visible sur de très grandes faces | Pigments recalibrés sans blanchir les reflets |
| Tenons | Deux files, petites têtes quasi plates | Deux files déjà présentes mais masquées par la couronne bombée | Géométrie de tenon conservée, plateau abaissé |
| Contact | Réel chevauchement des tenons, petits écarts variables | Passage `0,55` et cavité `0,21` déjà corrigés | Géométrie d'emboîtement inchangée |
| Mouvement | Empilement qui vacille puis effondrement spectaculaire | Ondes d'impact et oscillation mais pas de rigid bodies libres | Sujet de gameplay/physique ultérieur, pas simulé dans ces captures |
| Fond | Blanc, ombres délicates et traînées colorées | Cyclorama blanc + caustiques batched | Conservé, budget GPU stable |

**Aucun « pixel-perfect match » revendiqué :** la vidéo est un montage
comparatif filmé dans un navigateur à angles, interfaces et résolutions
différents du moteur 3D mobile. Ne pas surajuster à ses caractères, prix ou
étiquettes ; préserver seulement la matière, les proportions et les
réactions physiques. Les différences dans les mouvements et les collisions
nécessitent une tâche dédiée après validation de l'aspect des briques.


## Politique générale d'archivage des références photo/vidéo

**Règle du créateur, valable pour tous les projets :** chaque photo
ou vidéo reçue comme référence doit être conservée durablement
sur GitHub **en tant que fichier binaire véritablement récupérable**.
Un nom, un lien de conversation, une empreinte SHA-256 ou une
capture miniature ne constituent jamais une archive suffisante.

- Conserver l'original sans réencodage, et idéalement une planche
  d'images clés lorsque la référence est une vidéo.
- Ajouter au minimum la date, la provenance, le projet concerné,
  la taille et l'empreinte SHA-256 de chaque élément archivé.
- Préférer un dépôt **privé** pour les médias personnels, non publics
  ou couverts par des restrictions de diffusion. Vérifier les droits
  de redistribution avant un dépôt public.
- Vérifier que le fichier déposé se télécharge bien depuis GitHub
  et qu'il possède la **même empreinte** que l'original.
- Ne jamais annoncer « sauvegardé sur GitHub » tant que le binaire
  n'a pas été effectivement transféré et vérifié.

**Référence Jelly Bricks sauvegardée en binaire sur GitHub :**
`2824.mp4`, 2 305 045 octets, SHA-256
`e7423f103b11678e2f2bbc8224562c67b3924079c7f262def81d90723b971ef4`.
Le fichier récupéré de la bibliothèque du projet est maintenant archivé
à `reference-media/2824-original.mp4`, avec le même SHA-256.

Le dépôt possède maintenant un script d'archivage depuis un
poste possédant Git et `gh` authentifiés :

```bash
gh auth status
bash scripts/archive-reference-media.sh /chemin/vers/2824.mp4 jelly-bricks-reference-2026-10-18.mp4
```

Le script refuse les collisions de noms et les modifications Git
indépendantes, contrôle l'empreinte puis pousse une copie dans
`reference-media/`. Il utilise Git LFS pour les fichiers de plus
de 50 Mo. **L'original de cette référence a été archivé directement
avec une vérification de SHA-256 et Git blob, sans réencodage et sans LFS.**
