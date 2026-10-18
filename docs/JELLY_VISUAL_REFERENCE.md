# Jelly Bricks — cahier de référence visuelle (vidéo utilisateur)

**Référence artistique définitive : la vidéo envoyée précédemment par le
créateur du jeu.** Elle prime sur les captures issues des précédentes versions
de Jelly Bricks et sur les styles de matériaux génériques trouvés en ligne.

> Limite de traçabilité : le fichier vidéo original n'est **pas présent dans
> ce dépôt** et n'a pas pu être réouvert lors de la rédaction de cette fiche.
> Les éléments ci-dessous transcrivent les qualités visuelles retenues lors
> des discussions précédentes. Ne jamais annoncer une correspondance
> image-par-image ou une validation « identique à la vidéo » sans avoir
> effectivement comparé les mêmes images de référence.

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
- Opacité de base solide `0.940`, plus Fresnel/absorption déjà dans le
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
