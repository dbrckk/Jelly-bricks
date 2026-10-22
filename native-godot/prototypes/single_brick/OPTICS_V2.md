# Jelly Bricks — optique V2 et déformation cohérente

**Statut : prototype expérimental, non fusionné dans le jeu.**

## Source de vérité

- `reference-media/2824-original.mp4` (copie binaire archivée et vérifiée par SHA-256)
- Planche originale : `reference-media/2824-contact-sheet.png`
- Modèle sélectionné : moitié supérieure, pigment saturé et peau brillante, formes 2x1/1x1 et impact à plusieurs couches

## Changements contrôlés

1. **Coloration approximant un trajet lumineux** : l'épaisseur apparente (faces latérales, couronne, base) module une atténuation pigmentée exponentielle, **sans transparence alpha**. Cela évite la révélation des faces intérieures qui cassait les premiers prototypes. Ce n'est ni une réfraction ni une diffusion sous-surface physique.
2. **Réduction de la dominante cyan** : pigmente le vert et le bleu, réduit la contribution d'une lumière auxiliaire bleue. Les tons restent plus saturés ; les couleurs et reflets doivent encore être validés sur un écran Android.
3. **Mouvement unifié** : les trois couches `corps / vernis / tenons` partagent la compression ; le vernis et le corps partagent les uniformes d'oscillation. Avant, le vernis ne suivait pas la déformation et se détachait à l'impact.
4. **Ondulation de surface** : oscillation spatiale de faible amplitude appliquée au sommet du corps et au vernis, avec une énergie et une phase communes, amorties par la propagation de contact entre les trois niveaux. Aucun nouveau maillage, système de collision, image, texture ni physique CPU.
5. **Régression** : le script de capture teste que l'énergie de compression, la peau et les tenons correspondent à l'impact de la couche supérieure, ainsi que la propagation dans l'ordre haut, milieu, bas.

## Contrôles effectivement exécutés

- Godot 4.6 — import et scripts du jeu : exécutés localement.
- Tous les 21 niveaux dans le vrai moteur : PASS.
- Prototype 1 brique / 5 états : PASS.
- Prototype 3 briques / 5 états, rendu Mesa OpenGL 720×1280 : PASS.
- Source bytes : PASS. `git diff --check` : PASS.

## Résultat artistique

Le dessus est maintenant vert saturé plutôt que cyan ; le corps, le vernis et les tenons se déforment ensemble et la pile reproduit mieux les tailles alternées de la référence. **Toujours insuffisant pour prétendre à une véritable gelée transparente :** les briques ont des reflets de plastique verni, le rendu d'empilement manque d'instabilité mécanique et d'emboîtement physique, et la déformation de surface n'est qu'une approximation shader.

**Décision : rester sur la PR expérimentale, sans fusion ni Play Store.** La prochaine étape à haut retour doit comparer une simulation d'instabilité entre briques à la vidéo et vérifier la fluidité GPU sur le téléphone.
