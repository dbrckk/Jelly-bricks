# Jelly Bricks — audit de faisabilité et seuil de qualité (2026-10-21)

## Décision actuelle : **NON PUBLIABLE SUR PLAY STORE**

Les captures Android fournies par l'utilisateur montrent une application bleu marine à grille quasiment 2D, sans véritable lecture du volume Jelly. Le rendu réel de Godot `main` 0.9.68, re-généré avec la scène de capture OpenGL, est différent : fond blanc, caméra 3D inclinée, maillages en relief et mode studio, **mais toujours une apparence plastique/cartoon**. La simple réussite de GitHub Actions ne contredit pas la note 0/10 du rendu communiqué.

**Ne pas vendre les builds debug ou les 21/21 niveaux testés comme preuve de direction artistique aboutie.**

## Référence vérifiable disponible

- Cahier source : `docs/JELLY_VISUAL_REFERENCE.md`.
- Film original : `2824.mp4`, SHA-256 `e7423f103b11678e2f2bbc8224562c67b3924079c7f262def81d90723b971ef4`, **non récupérable depuis ce dépôt**.
- Notes extraites antérieurement de la vidéo : comparaison de deux rendus de briques rouges/bleues/vertes/oranges, préférence pour la **moitié supérieure brillante**, couches emboîtées et rebond/collapse.
- Tant que la vidéo binaire n'est pas restaurée, il n'est pas possible de certifier un alignement pixel par pixel, un comportement équivalent ou une similarité subjective.

## Écarts vérifiables qui bloquent la direction artistique

1. **Silhouette** : les polyominos de puzzle ont des tenons épais de type plastique ; la vue top-down/gabarit dans les anciennes APK ne montre pas clairement la 3D. Les briques d'atelier ont une géométrie plus correcte, mais conservent une apparence jouet.
2. **Optique** : les surfaces actuelles n'ont pas encore une absorption, des zones translucides internes et des cartes de lumière comparables à la référence ; plusieurs variations de shader ont passé les tests tout en échouant visuellement.
3. **Contact et mouvements** : animations déterministes et courtes, pas une simulation validée d'empilement, d'équilibre, d'oscillation et d'effondrement.
4. **Produit** : les 21 puzzles 2D et la galerie d'empilement sont des boucles distinctes ; le jeu référence ne doit pas être présenté comme une copie fidèle.
5. **Distribution** : pas de signature persistante confirmée pour des mises à jour Android sans désinstallation, aucun test terrain documenté sur appareil physique, et pas d'AAB de publication validé Play Console.

## Critères d'acceptation avant toute annonce « prêt pour le Play Store »

- Restaurer le **binaire de référence original** sous forme récupérable (dans un stockage avec droits adaptés) et vérifier son empreinte.
- Réaliser **4 captures comparatives contrôlées** avec mêmes poses caméra/éclairage : brique isolée, tour immobile, contact, effondrement. Faire valider le visuel par le créateur **avant** de réinvestir dans des fonctionnalités.
- Offrir dans l'application une interaction de gelée réellement 3D et un gameplay rejouable explicite ; pas seulement une vidéo de démonstration.
- Mesurer et consigner sur appareil Android réel : fréquence d'images et 99e percentile du temps de frame, mémoire, chauffe, commandes tactiles et annulation, sauvegarde/restauration, lancement hors ligne.
- Installer un APK identique à la version visible dans l'interface. Les debug APK GitHub peuvent être signés par une clé éphémère ; NE PAS conseiller une désinstallation sans exporter les sauvegardes.
- AAB signé pour release, identité de signature durable, fiche de confidentialité et tests de la Play Console validés.

## Décision technologique

Une version **jouable techniquement** peut rester Godot 4.6 Compatibility. Une **fidélité supérieure à la vidéo** demande probablement une révision importante de la matière et de la géométrie via un workflow d'assets 3D (Blender ou outil équivalent), des éclairages propres aux volumes, une simulation viscoélastique testée et une validation d'images réelle. Rien ne permet aujourd'hui d'affirmer qu'un portage Unity, un shader supplémentaire ou une migration complète règlera ces écarts sans un prototype visuel comparé et accepté.

**Règle de continuation :** ne plus classer « amélioration visuelle réussie » une retouche dont on n'a pas inspecté les captures et obtenu un rendu effectivement meilleur. Si le prototype de matière n'atteint pas la direction de référence, interrompre la préparation Play Store plutôt que multiplier les petites fonctionnalités.
