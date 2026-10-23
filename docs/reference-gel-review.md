# Comparaison aux références Jelly Bricks — 23 octobre 2026

Sources : dossier Drive `Jelly-Bricks-Reference-Transfer`, vidéo originale
`reference-media/2824-original.mp4`, deux extractions stack/collapse et planche
contact. Le MP4 archivé est vérifié par SHA-256 ; il dure 13,26 secondes.
La moitié supérieure de la vidéo sert de cible matière : couleurs denses,
reflets blancs localisés, arêtes arrondies translucides et ombres diffuses.
La moitié inférieure illustre surtout un rendu plus mat et des ombres dures.

| Priorité | Observation du projet actuel | Intervention |
| --- | --- | --- |
| 0 — faces visibles | Les captures OpenGL montrent le dessous à travers le dessus : les triangles sont émis dans le sens opposé aux faces avant horaires de Godot. | Inversion des sommets et de leurs normales dans le générateur commun des corps et tenons. |
| 1 — matière et éclairage | Le shader utilise la normale en espace caméra pour reconnaître le dessus et les flancs. Un changement de vue modifie donc aussi les masques de pigment, de diffusion et de reflet. | Transmission des normales locales après déformation ; masques du studio indépendants de l'orbite. Les reflets de Fresnel restent liés à la vue. |
| 2 — couleurs | Les masques incorrects peuvent éclaircir un flanc comme un dessus et déplacer les fenêtres de lumière entre les faces. | Les mêmes couleurs et réglages de pigment utilisent désormais les vraies faces. Après correction des faces, recalibrage du volume teinté : alpha 0,94, pigment final préservé et couche blanche de galerie réduite à 30 % de son intensité précédente. Les fantômes restent à 0,43. |
| 3 — déformations | La compression et la propagation commencent à 0,27 s alors que l'arrivée visuelle dure 0,29 s. | Début à 0,29 s pour la brique et son premier support ; délais entre les couches conservés. |
| 4 — contact | Le disque d'occlusion suit la brique pendant son approche, ce qui crée une ombre de contact flottante. | Masque caché en vol, visible à l'arrivée et restauré lors de l'interruption d'une animation. |
| 5 — validation visuelle | Les réglages déjà présents couvrent les tenons arrondis, la cavité, le pigment, le ménisque et les caustiques. | Réutiliser les scènes de capture réelles pour comparer plusieurs angles avant d'ajouter d'autres couches optiques. |

Les silhouettes, la palette, les niveaux, la sauvegarde et les règles de
construction restent compatibles. Le shader ajoute un varying vec3 ; pas de
texture, de nouvelle passe de rendu ou de lumière supplémentaire. Le puzzle
conserve ses masques historiques ; la correction de repère concerne le studio.

La vidéo comparative ne permet pas de déduire un indice de réfraction, une
viscosité ou une vitesse de simulation physique. La fidélité au mouvement et
la fluidité sur Redmi nécessitent toujours une vérification sur l'appareil.

## Vérifications exécutées

- Godot 4.6 : chargement, solutions des 21 niveaux, géométrie et sauvegardes.
- Contrôle géométrique ajouté : orientation horaire de chaque triangle des
  six corps moulés et des deux familles de tenons, comparée aux normales.
- Test temps réel : contact à l'arrivée, Undo sans effet retardé et remise
  en état de l'ombre lors de l'interruption d'une animation.
- Trois captures OpenGL/Mesa de la brique isolée : dessus maintenant visible,
  tenons complets, cavité perceptible à travers le gel translucide.
- `npm run check` et `npm test` : build web et 78 tests réussis.

Les captures d'avant correction montraient effectivement la cavité comme
surface principale depuis le dessus. Après correction, le dessus et les
quatre tenons sont rendus : cela corrige la visibilité, sans démontrer une
fidélité photoréaliste ou les performances Android physiques.

Après remise à l'endroit des faces, les anciens réglages ont révélé une
surcouche blanche trop forte. Le volume est recalibré (alpha 0,94 ; spéculaire
studio 0,50 ; voile de galerie à 30 %), tout en conservant le fantôme à 0,43.
Le contrôle de teinte rouge échantillonne maintenant une paroi rouge exposée
au milieu de la tour : l'ancienne zone du sommet contient désormais aussi
la brique verte vue à travers la cavité. Les seuils RGB restent identiques.

Captures réelles Godot/Mesa conservées dans `docs/visual-validation/` : avant
correction des faces, brique finale et tour de référence. La séquence complète
de capture OpenGL (construction, impact, galerie, tour, chute et réception)
a réussi, ainsi que les trois angles de la brique isolée.
