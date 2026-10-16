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
