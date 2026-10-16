# Jelly Bricks — reconstruction 3D native Godot (Android)

Ce projet est une **nouvelle application Android native Godot 4.6**, pas un effet visuel supplémentaire sur l'ancienne version HTML/CSS. Le projet web Three.js reste accessible dans le dossier principal pendant la migration.

## Moteur et rendu
- Godot Engine 4.6, licence MIT, moteur **OpenGL Compatibility** (Android).
- Caméra 3D inclinée et éclairage directionnel + ponctuel.
- Géométrie 3D construite directement avec `SurfaceTool` en conservant les côtés des polyominoes, **sans faces cachées entre les cubes collés**.
- Shader spatial propriétaire au jeu (pas de textures tierces), matière colorée brillante avec Fresnel, densité de gelée, faibles reflets internes et rebond amorti par pièce.
- Plateau 3D, modèle miniature, sélection de la forme, rotation à 90°, placement magnétique, annulation, score de reconstitution, animation de réussite.
- Les **21 niveaux originaux** sont copiés dans `data/levels.json` (sans changement de motif). Le déblocage est sauvegardé sur l'appareil.
- Écran conçu pour le mode portrait Android, avec les commandes en bas et l'objectif en haut.

## Compiler sans PC (GitHub Actions)

Ouvrir [Actions — Godot Android Native APK](https://github.com/dbrckk/Jelly-bricks/actions/workflows/native-android.yml). Sur une branche ou via **Run workflow**, GitHub télécharge Godot et les templates d'export officiels, valide les niveaux dans le moteur réel puis génère un **APK de test** signé avec une clé Android de développement. Après réussite, sélectionner l'exécution et récupérer **jelly-bricks-android-debug-apk** dans *Artifacts* depuis le téléphone.

L'APK de développement n'est **pas encore une version de production Google Play**. Une signature de publication différente et des tests Android physiques sont nécessaires avant diffusion officielle.

## Développement local

Installer Godot 4.6 standard et ouvrir `native-godot/project.godot`. Lancer la scène principale `scenes/main.tscn`.

Test automatisé : `godot --headless --path native-godot --script res://tests/validate.gd`.

Export : `godot --headless --path native-godot --export-debug Android build/jelly-bricks-native-debug.apk` (avec templates d'export Android, SDK Android et JDK 17 configurés).

## À ne pas confondre
La présence du code source Godot ne garantit **ni** qu'un APK est construit **ni** qu'il fonctionne sur un téléphone donné. L'état de l'APK doit être contrôlé dans la CI et par essai tactile réel. La qualité visuelle doit aussi être évaluée sur captures réelles avant de parler d'un rendu premium final.

## Mise à jour native 0.9.1 — gelée volumétrique plus souple

Les pièces du puzzle disposent de **six bandes de biseau arrondi** le long de leur contour réel, avec une surface supérieure bombée. Les murs internes entre cellules jointes restent supprimés. Le shader spatial Compatibility possède des contours Fresnel lumineux, un faux éclairage interne coloré, des reflets « softbox » procéduraux et une transparence douce. Le fantôme de déplacement est plus translucide que les briques posées.

Toutes les géométries sont calculées et partagées entre pièces placées et fantômes de la même rotation, afin d'éviter les reconstructions lors des gestes Android. Les tests Godot vérifient désormais la profondeur, la présence des biseaux et la transparence des fantômes en plus de la résolution des 21 niveaux. Il s'agit toujours d'une version de **test** dont la fluidité et la qualité visuelle réelles devront être vérifiées sur un téléphone physique.


## Géométrie jelly adoucie (nouveau moteur de volumes)

Le générateur `scripts/gel_mesh.gd` remplace les bandes plates construites cellule par cellule. Il reconstruit le **périmètre continu** de chaque forme puis applique sept anneaux profilés et des normales lissées aux flancs. Le dessus conserve une légère courbure en coussin, tandis que la base est fermée. Les trous et les formes diagonales séparées gardent leurs contours individuels. Le résultat est une enveloppe géométrique 3D réellement arrondie et non un simple filtre CSS.

Les mêmes volumes sont partagés par les pièces posées et les aperçus afin de limiter le coût sur Android. Le test Godot vérifie les normales de surface, la fermeture du volume et les contours à trous avant de tester les 21 niveaux. Une compilation native réussie ne suffit pas à qualifier les graphismes de parfaits : les captures réelles et les performances du Redmi 15 5G restent à examiner.


## Mise à jour native 0.9.4 — plateau studio et feedback fiable

Le plateau dispose de trois niveaux de profondeur, d'un liseré lumineux statique (sans post-traitement coûteux), de cases cibles teintes selon le modèle et de repères plus lisibles. Les dalles partagent leur géométrie `BoxMesh` et leurs matériaux par groupe au lieu d'allouer un exemplaire par case à chaque niveau : cette mutualisation vise la mémoire GPU et la stabilité Android, sans promettre un FPS mesuré.

Le placement distingue désormais :
- **Menthe :** l'ensemble de la forme correspond aux couleurs et à la position du modèle.
- **Ambre :** la forme tient géométriquement, mais ne reproduit pas le modèle ; ce choix reste autorisé pour conserver le défi et peut être annulé.
- **Rose :** position impossible (hors cible ou collision).

La couleur du fantôme et le texte de statut sont cohérents avec ce diagnostic. Les tests automatisés vérifient la distinction entre placements corrects et incorrects, la récupération par annulation et la réutilisation des ressources.

La validation GitHub Actions n'équivaut pas à une certification visuelle ni ergonomique sur appareil physique ; faire un test tactile en portrait sur Android reste requis avant une version publique finale.


## Mise à jour native 0.9.5 — sensations tactiles et son intégralement original

Les gestes possèdent désormais un retour audio distinct pour la sélection, la rotation, la pose correcte, la pose erronée, le refus, l'annulation, l'indice et la réussite. Ces 8 sons sont **générés mathématiquement dans Godot** en PCM mono 16 bits / 22 050 Hz par `scripts/candy_audio.gd`, sans téléchargement, audio sous licence, dépendance ou microphone. Trois `AudioStreamPlayer` sont mis en commun pour les événements rapprochés. Les courtes vibrations Android sont déclenchées seulement sur certains gestes et nécessitent uniquement la permission `VIBRATE` de l'APK (pas `INTERNET`).

Le bouton `FX : ON / FX : OFF` à côté de `Suivant` coupe **à la fois** les sons et les vibrations et enregistre la préférence dans `user://jelly-native-progress.json`, avec la progression. La préférence reste conservée après redémarrage. Il est possible d'utiliser le jeu en silence complet.

Les tests natifs vérifient que chaque son a des échantillons PCM non silencieux, que les trois lecteurs sont créés et que les sons coupés ne sont plus émis. La compilation Android et les tests du puzzle doivent rester verts. La perception du son, la synchronisation et l'intensité des vibrations restent à valider sur un appareil Android réel avant d'annoncer une finition définitive.


## Mise à jour native 0.9.6 — aimant intelligent et retour visuel persistant

La recherche de la pose magnétique ne se contente plus du premier ajustement géométrique. Parmi la case touchée et ses quatre voisines directes, elle **privilégie d'abord un placement qui correspond exactement au modèle**, puis seulement un placement physiquement possible. Elle ne saute jamais à distance. L'aperçu 3D et la pose définitive utilisent la même fonction.

Les formes déjà posées au mauvais endroit gardent désormais un subtil **liseré ambré de Fresnel**, sans perdre leur couleur d'origine. Les nouveaux gestes sur la même position et orientation ne consomment plus un mouvement et ne polluent plus l'historique d'annulation. Un aperçu fantôme déjà affiché se déplace avec un amortissement court dans la boucle de rendu plutôt que d'allouer un nouveau tween à chaque événement tactile. Sa rotation et sa sélection s'actualisent sur place.

La victoire annule sa propre animation lorsque le niveau change, évitant qu'un ancien tween n'étire le nouveau plateau. Les tests natifs couvrent la priorité aux positions correctes voisines, le refus de téléporter une mauvaise pose lointaine, le matériau ambré, l'absence de faux mouvements et la mise à jour du fantôme.

**APK debug Android :** numéro de version porté à 3 (version 0.9.6). La CI renouvelle actuellement la clé de développement à chaque construction ; une mise à jour directe d'un APK de CI antérieur peut donc nécessiter une signature stable ou une réinstallation (qui efface potentiellement la progression locale). Ce point doit être résolu avant de considérer les mises à jour Android comme prêtes pour la distribution.
