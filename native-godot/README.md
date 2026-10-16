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


## Mise à jour native 0.9.7 — reprise automatique des puzzles Android

L'application sauvegarde le **niveau en cours**, les positions/rotations des pièces posées, la pièce sélectionnée, le nombre de coups et les 64 derniers états d'annulation. Chaque pose, annulation, sélection, rotation ou indice est persisté pour reprendre une partie interrompue sans écran supplémentaire. Les 21 niveaux et le réglage FX continuent d'être sauvegardés.

Avant toute restauration, les données sont vérifiées : identifiants de pièces du niveau, coordonnées entières valides, rotations entre 0 et 3, cases présentes dans le modèle et absence de chevauchement. Les états d'annulation sont soumis aux mêmes contrôles. Une sauvegarde de puzzle invalide est ignorée **entièrement** ; la progression de niveaux reste accessible. Un niveau déjà terminé est restauré sans rejouer le jingle de victoire.

Les tests Godot recréent une scène après une sauvegarde intermédiaire, vérifient le retour des pièces et l'annulation, puis injectent une session corrompue pour contrôler le repli. La résistance aux fermetures forcées par Android et le ressenti sur smartphone demandent toujours un essai sur appareil réel.


## Mise à jour native 0.9.8 — sessions multiples et robustesse des mises à jour

### Sauvegarde locale

La progression utilise désormais un document JSON `format: 2` avec **une session indépendante par niveau** dans `sessions`. Quitter un puzzle pour un autre ne détruit plus les pièces posées ou les possibilités d'annulation du premier. Les sauvegardes natives 0.9.7 restent lisibles : leur ancienne clé unique `session` est automatiquement reprise. La clé `session` est conservée dans le nouveau document pour la compatibilité ascendante limitée.

Les écritures sont préparées dans `user://jelly-native-progress.json.tmp`, validées sur disque puis déplacées vers le fichier principal. La copie précédente valide est conservée en `.bak`. Si le JSON principal est tronqué ou illisible, le jeu tente le fichier de secours. L'import de chaque session demeure soumis aux validations de géométrie, de rotation et d'absence de collision de la version 0.9.7. Les modifications de sélection et de rotation sont maintenant sauvegardées également. C'est une **protection contre les interruptions ordinaires**, pas une garantie face à une perte physique de stockage ou à la désinstallation de l'app.

### Signature Android de test

La clé privée Android **n'est jamais placée dans le cache GitHub Actions** : les pull requests peuvent lire les caches de leur branche cible, ce qui rend ce stockage dangereux même avec une condition limitée à `main`. Pour obtenir des mises à jour Android préservant les données, configurer **trois secrets du dépôt** (`Settings → Secrets and variables → Actions → New repository secret`) : `JELLY_ANDROID_KEYSTORE_B64` (contenu du fichier keystore encodé en base64, sur une seule ligne), `JELLY_ANDROID_KEYSTORE_PASSWORD` (mot de passe du magasin et de la clé), et `JELLY_ANDROID_KEYSTORE_ALIAS` (alias du certificat). La clé privée doit être conservée et sauvegardée **hors de GitHub** : perdre cette clé rend les mises à jour des installations déjà signées avec elle impossibles.

Seuls les workflows de `main` hors pull request lisent ces secrets. Si aucun n'est configuré, un keystore de **test jetable** est généré ; le build reste installable mais n'est PAS garanti compatible en tant que mise à jour, même depuis un autre build `main`. Si un seul secret est configuré, le job échoue explicitement au lieu de signer avec une autre identité par erreur. Le SHA-256 **public** du certificat apparaît dans les logs pour comparaison entre les builds. Aucun octet du keystore n'est placé dans les artefacts, le dépôt ou les caches.

Pour préparer les secrets, utiliser `keytool` depuis Java 17 (PC, Linux ou Termux avec OpenJDK) afin de créer **une seule fois** un fichier `jelly-debug.keystore` conservé localement. Exemple (les mots de passe sont demandés de façon interactive) : `keytool -genkeypair -keystore jelly-debug.keystore -alias jellybricksdebug -keyalg RSA -keysize 3072 -validity 10000`. Encoder **sans retour à la ligne** (Linux : `base64 -w0 jelly-debug.keystore`, macOS : `base64 < jelly-debug.keystore | tr -d '\\n'`) et saisir le résultat directement comme secret `JELLY_ANDROID_KEYSTORE_B64` dans l'interface GitHub. Enregistrer séparément le mot de passe comme `JELLY_ANDROID_KEYSTORE_PASSWORD` et `jellybricksdebug` comme `JELLY_ANDROID_KEYSTORE_ALIAS`. Ne jamais coller la valeur base64 dans un chat, un commit ou les logs CI. Utiliser le même mot de passe pour le keystore et la clé privée, comme indiqué dans la documentation Godot. Pour les APK déjà installés avant cette configuration, une identité de signature différente obligera Android à refuser la mise à jour : ne désinstaller qu'après avoir préservé les données.

La clé configurée ici est exclusivement une **clé debug pérenne pour le test**. Une diffusion publique exige une stratégie de signature/release séparée avec clé de publication dédiée et sauvegardée.

Les tests CI doivent vérifier : sauvegarde de plusieurs niveaux, annulation restaurée, conservation du format, reprise après JSON interrompu, 21 puzzles et export APK arm64.

## Version 0.9.9 — export / import des sauvegardes Android

L'application dispose de deux boutons dans la barre inférieure : **Exporter** et **Importer**. Depuis Android 10+, Godot 4.6 utilise le sélecteur de fichiers natif (Storage Access Framework, SAF) pour choisir un emplacement ou un fichier sans autorisation d'accès global au stockage, ni serveur, ni compte. Les fichiers de sauvegarde sont au format `jelly-bricks-backup.json` : JSON local comprenant tous les niveaux débloqués, les parties inachevées de chaque niveau, l'historique d'annulations et la préférence FX.

- **Avant une réinstallation** : toucher Exporter, choisir un emplacement externe à l'application (par exemple Documents ou Drive, si proposé par le sélecteur), puis conserver ce fichier. Le simple stockage dans `user://` n'est **pas** une sauvegarde externe.
- **Après la réinstallation** : toucher Importer, choisir le même fichier, vérifier le nombre de niveaux/parties indiqué et confirmer le remplacement. La progression actuelle n'est **pas** écrasée par une sauvegarde invalide.
- Le transfert comporte un marqueur de format et une empreinte SHA-256. À l'import, tous les placements et 64 états d'annulation par niveau sont validés (IDs, limites du plateau, rotations, absence de collisions). Une sauvegarde altérée, d'un format inconnu ou trop grande (plus de 2 Mio) est rejetée **avant** confirmation.
- Avant tout remplacement valide, la version locale précédente est copiée dans le fichier interne `.before-import.bak`, **distinct** de la sauvegarde `.bak` utilisée par les sauvegardes automatiques. La restauration écrit d'abord le JSON dans `.tmp`, puis le renomme : l'ancienne partie ne peut donc pas être écrasée par la prochaine sauvegarde automatique. La copie de secours reste interne : elle ne remplace pas une exportation sur un stockage externe.

**Attention :** toute personne qui détient le fichier JSON peut consulter les informations de progression. Il n'est pas chiffré ; ne pas l'envoyer publiquement. Le comportement réel du sélecteur de documents SAF doit être vérifié sur un Android physique avant toute opération de désinstallation. Les appareils Android plus anciens peuvent afficher un dialogue de fichiers différent.


## Version 0.9.10 — contrôle multitouch fiable et optimisation du glissement

- Le plateau est désormais contrôlé **exclusivement par le doigt qui a commencé le geste** (`InputEventScreenTouch.index`). Un deuxième doigt peut toucher, glisser ou se relever sans déplacer ni poser la première brique. Un geste annulé par Android (`canceled = true`) n'effectue jamais de placement.
- La limite de l'aire interactive n'est plus une fraction fixe de l'écran. Elle suit les rectangles réels du bandeau supérieur et du panneau de commandes inférieur, y compris lorsque la résolution ou le rapport hauteur/largeur change ; en cas de chevauchement des panneaux, un appui accidentel ne crée pas de pose.
- Les quatre orientations de chaque forme sont conservées dans un cache local au niveau : un glissement rapide ne recalcule plus inutilement le contour à chaque contrôle de collision. Les règles de l'aimant, les contours Jelly 3D, les niveaux, les sauvegardes et les boutons restent inchangés.
- Les tests natifs simulent deux doigts en parallèle, un relâchement secondaire, une annulation Android, les limites HUD et le cache des rotations. Le pipeline compile une nouvelle version Android debug **0.9.10** (`versionCode=7`).

Les actions tactiles réelles sont à vérifier sur téléphone avec le nouveau paquet ; les tests Godot exécutent les événements synthétiques et non du matériel physique. Ne désinstallez pas la version précédente avant d'avoir exporté une sauvegarde externe fiable, si le certificat de signature APK diffère.


## Mise à jour native 0.9.11 — grille 3D instanciée et rendu plus fluide

Les cases colorées du plateau 3D et les repères de position ne sont plus des dizaines de `MeshInstance3D` séparés. Ils sont désormais placés par **deux `MultiMeshInstance3D`** : un pour toutes les cases de sol, un pour tous les marqueurs du modèle. Chaque instance conserve sa position et sa vraie couleur grâce aux couleurs de sommets prises en charge par le matériau `StandardMaterial3D`.

Sur les niveaux 7 × 7, le plateau comprend jusqu'à **49 cases de sol et 49 repères** : ces géométries statiques sont soumises sous **2 lots de rendu** au lieu de jusqu'à 98 objets de rendu individuels, en plus du cadre et des pièces jelly. Cette optimisation ne change pas la résolution des puzzles, les contrôles tactiles, les shaders jelly ni les coordonnées de pose. Lorsque le joueur change rapidement de niveau, les anciens nœuds 3D sont détachés immédiatement avant d'ajouter la nouvelle grille, évitant un chevauchement temporaire.

Les tests natifs vérifient la grille et les couleurs de chaque cellule sur **les 21 niveaux**, les compteurs d'instances, la conservation des matériaux GPU, les sauvegardes et les 21 solutions. La CI valide la capture sous Mesa et l'export APK. **Ce changement réduit structurellement les objets de dessin ; il ne constitue pas une mesure de FPS sur un smartphone réel**. Les FPS, l'autonomie et la température doivent encore être vérifiés sur un appareil Android physique.


## Version native 0.9.12 — matière Jelly animée et éclats 3D

La matière `shaders/jelly.gdshader` conserve sa géométrie volumique, sa transparence, ses reflets et son liseré d'erreur ambré. Elle bénéficie d'un **reflet de studio qui balaye lentement la gelée**, calculé directement dans le shader avec `TIME` et la position locale : aucune texture, capture d'écran, ressource externe ni mise à jour de shader par script à chaque frame. L'effet est volontairement atténué sur le fantôme de placement pour ne pas distraire le joueur.

Le nouveau module `scripts/jelly_vfx.gd` crée une fois **trois émetteurs de pose réutilisables (12 particules chacun)** et **un émetteur de victoire (38 particules maximum)** en `CPUParticles3D` ; tous partagent une petite géométrie sphérique et une matière sans éclairage, teinte et translucide. Les poses correctes et incorrectes reçoivent des couleurs d'éclat distinctes. Aucun émetteur n'est créé lors d'un glissement tactile, d'une nouvelle pose ou d'une animation : on réutilise le pool. Les particules sont interrompues lors d'un changement de niveau et restent séparées du plateau pour éviter les doublons à la reconstruction.

Le choix `CPUParticles3D`, plutôt que les mécanismes GPU non universellement disponibles, vise la compatibilité Android OpenGL de Godot 4.6. Les tests en moteur Godot vérifient le nombre d'émetteurs, leur géométrie partagée, la limite des particules, le déclenchement uniquement à la pose et la réinitialisation. La CI compile aussi le shader, exécute les 21 niveaux et génère une capture OpenGL. La performance et le goût esthétique restent à mesurer sur téléphone réel ; les tests automatisés ne prouvent pas à eux seuls une finition AAA.

**APK debug :** version 0.9.12 / Android versionCode 9. Avant réinstallation avec une autre signature, exporter une sauvegarde externe via le bouton du jeu.


## Version 0.9.13 — refonte studio clair et briques Jelly à tenons sculptés

Première refonte visuelle majeure suivant les références photo/vidéo fournies : on conserve le puzzle Godot Android, mais la matière et la présentation doivent se rapprocher d'un **packshot de briques gélatineuses** plutôt que d'un plateau futuriste sombre.

- Scène 3D **blanc perlé**, studio sans horizon apparent : fond clair, grand plan mat, éclairage principal chaud et lumière de remplissage froide, avec moins de sources ponctuelles. Le socle est ivoire/gris perle ; les cases ont une teinte pastel permettant toujours de reconnaître le motif à reproduire.
- Chaque forme est désormais composée de son volume 3D arrondi existant et de **quatre tenons lisses par cellule**, avec dessus légèrement bombé et flancs progressivement arrondis. Les tenons utilisent une géométrie indexée unique, instanciée par **MultiMesh** : un seul lot par brique, pas un MeshInstance et un draw call par tenon. Ils partagent le ShaderMaterial translucide du corps pour préserver une teinte et un reflet cohérents.
- Sous chaque pièce définitivement posée, un petit **voile d'ombre de contact** est calculé dans un shader sans carte d'ombres, texture externe ni ray tracing. Il n'est pas ajouté au fantôme translucide.
- À la pose, les briques ont un ressort court avec léger *tilt* amorti, squash & stretch et retour à l'équilibre dépendant du poids de la forme. L'alignement logique sur les cellules, les niveaux, les validations et les sauvegardes restent inchangés.
- Les tests valident le volume et les normales des nouveaux tenons, leur rendu instancié avec le matériau partagé, l'absence d'ombre sous les fantômes, le rendu des couleurs pastel par Mesa OpenGL et la solvabilité des 21 puzzles.

Il s'agit d'une **première passe de refonte visuelle réelle**, pas d'une certification que le rendu égale déjà les captures de référence. La référence montre un jeu d'empilement libre : Jelly Bricks reste pour le moment un jeu de reproduction de motif ; adapter les mécaniques à une pile instable demanderait un mode distinct, à concevoir sans dégrader le puzzle actuel. Comparer l'APK et les captures de QA sur un Android physique avant d'aller plus loin.

APK 0.9.13, `versionCode=10`. Avant toute réinstallation impliquant un certificat de signature différent, exporter une sauvegarde externe via le jeu.
