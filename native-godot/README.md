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


## Refonte de la matière jelly : volumes arrondis et reflets

Les premières captures de l'APK natif montraient encore des briques très anguleuses. Le volume n'utilise plus trois flancs rigides par arête : le générateur `scripts/gel_mesh.gd` crée désormais **sept anneaux profilés le long des contours exposés**, avec des normales de surface interpolées, un dessus continu et une base fermée. Les faces intérieures des cellules adjacentes sont absentes. Les contours fermés, trous et îlots diagonalement voisins sont traités séparément.

Le shader ajoute un vernis `CLEARCOAT` et des reflets doux directionnels sans charger de texture HDR, ce qui maintient l'application indépendante d'Internet. Les géométries d'une même pièce/rotation sont réutilisées pour le modèle et les pièces posées. Ces améliorations modifient le maillage réel, et pas seulement la feuille de style ou les effets 2D.

Le test Godot natif vérifie les anneaux, les normales unitaires, les trous et le volume avant d'essayer les 21 niveaux. Il faut encore contrôler **une capture du rendu construit** et l'APK sur un vrai smartphone avant de qualifier le résultat de haut de gamme.
