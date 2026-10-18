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

**Configuration automatisée recommandée (Android 0.9.46)** : sur un poste Linux, macOS ou WSL doté de Java `keytool`, GitHub CLI `gh` et `base64`, exécuter `gh auth login` puis, à la racine du dépôt, `bash scripts/setup-android-signing.sh`. Le script demande deux fois un mot de passe masqué, crée une **seule** identité locale dans `~/.local/share/jelly-bricks/android-signing/jelly-debug.keystore`, vérifie son certificat, fixe son SHA-256 public dans la variable GitHub `JELLY_ANDROID_CERT_SHA256` puis envoie les trois secrets via l'entrée standard de `gh` (ni arguments contenant un mot de passe, ni affichage du keystore). Si un des secrets existe déjà ou si le certificat diffère de l'empreinte publiée, il **refuse** de régénérer ou remplacer l'identité : il faut conserver la clé d'origine. Conserver une copie de sécurité chiffrée du fichier keystore et de son mot de passe **hors du téléphone et de GitHub**. L'installation n'a pas été effectuée sur le compte GitHub par le CI : cette étape locale nécessite une authentification et une clé réellement détenue par son propriétaire.

**Contrôle bloquant dans GitHub Actions** : chaque compilation `main` utilisant les secrets refuse un certificat qui ne correspond pas à la variable `JELLY_ANDROID_CERT_SHA256`. Toutes les compilations, y compris celles des pull requests utilisant une clé éphémère, vérifient ensuite la **signature effective de l'APK** avec `apksigner verify --print-certs` et comparent son certificat à celui du keystore. Un APK non signé, endommagé, ou signé avec une autre identité ne sera pas publié comme artefact valide. Les APK de pull request ne sont **jamais** signés avec la clé privée permanente.

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


## Version Android 0.9.14 — nouvel atelier d'empilage libre en 3D

Le bouton **Tour 3D** (première ligne de commandes du puzzle) ouvre un **deuxième mode réellement jouable**, fondé sur les briques sculptées et le studio blanc. Il ne remplace pas les 21 niveaux de reproduction de motifs et ne les réinitialise pas.

### Contrôles tactiles

- **Couleurs** : cinq pastilles de teintes Jelly différentes.
- **Taille** : Petit = une case (2×2 tenons), Moyen = deux cases (2×4 tenons), Long = trois cases (2×6 tenons).
- **Tourner** : bascule l'orientation de la brique.
- **Glisser sur la scène** : déplace le fantôme au-dessus du socle ; relâcher valide la pose. **Poser** pose directement à la position du fantôme sans glisser.
- **Annuler** : retire uniquement la dernière brique de l'atelier.
- **Effacer** : demande confirmation avant de vider la pile.
- **‹ Puzzles** : retrouve immédiatement la partie puzzle (niveau, annulations, choix de pièce et caméra) sans perte de progression.

### Empilement et animation

Le studio prend en charge jusqu'à **32 briques et neuf couches verticales**. Chaque pièce possède une vraie coque gel sculptée, des tenons 3D partagés par MultiMesh, des couleurs au choix, un placement automatique sur le niveau de support le plus haut et une animation de chute, compression, rebond et oscillation. Une brique ne peut pas dépasser du socle ; les pièces en hauteur nécessitent le soutien d'au moins la moitié de leur empreinte sur le niveau inférieur. Ce système est **cinématique et déterministe**, pas une simulation RigidBody3D complète : il préserve la précision mobile et évite les effondrements aléatoires. L'évolution vers une pile physiquement instable sera étudiée après mesure du rendu sur Android.

Les états de la pile sont sauvegardés localement après chaque pose, annulation ou réinitialisation, dans \`user://jelly-stack-v1.json\`, avec écriture temporaire et copie de secours. Ils sont distincts des sauvegardes des 21 niveaux. **Attention : l'export/import SAF du mode puzzle ne comprend pas encore les piles de l'atelier** ; ne pas désinstaller l'application en supposant que ce fichier est exporté.

### Vérification

Le test natif Godot couvre la séparation des deux modes, la protection multitouch, les contacts annulés, la validité de l'empilement (support et limites), la pose, l'annulation et le rejet d'une pile corrompue. Le rendu Mesa OpenGL produit désormais **deux captures réelles**, puzzle et atelier, puis exporte l'APK ARM64. La capture automatisée et les tests logiques ne remplacent pas la validation tactile et le contrôle qualité sur téléphone Android.

Cette version est un premier atelier d'empilement original inspiré du **niveau de finition** du film de référence ; elle ne prétend pas égaler encore sa simulation ni ses reflets et n'utilise aucun asset tiers payant.


## Version native 0.9.15 — matière gel, ombres entre couches et réaction de pile

Le mode **Tour 3D** reçoit trois améliorations concrètes qui ne modifient ni les niveaux du puzzle ni les règles d'empilement.

- **Contact entre briques.** Chaque brique posée possède désormais un plan d'ombre procédural doux (shader \`contact_shadow.gdshader\`), correctement positionné au-dessous de sa coque et près des tenons de la pièce inférieure. Les ressources de shader sont partagées, les fantômes n'émettent pas d'ombre et aucune carte d'ombre ou requête physique ne s'exécute par frame.
- **Matière gel studio.** Un paramètre \`studio_glass\` dédié affine l'absorption sur les côtés, les reflets de Fresnel laiteux et la transparence du centre. Il vaut 1 dans la tour et 0 par défaut dans les puzzles, afin de ne pas modifier leurs couleurs ou leur lisibilité.
- **Réaction en chaîne.** À la pose, le nouveau bloc tombe, se comprime et rebondit ; seuls les blocs qui le soutiennent (puis leurs propres supports) oscillent légèrement, avec une amplitude décroissante selon la distance verticale. Cette animation n'affecte jamais les cellules logiques, les vérifications de support ni les sauvegardes. Les tweens sont annulés avant reconstruction, annulation ou changement rapide.
- **Glissement sans allocations 3D répétées.** Le fantôme conserve son mesh, son lot de tenons et son ShaderMaterial lors des mouvements tactiles ou d'un changement de couleur. Seuls la pose et la couleur sont actualisées. La reconstruction n'a lieu que si la taille ou l'orientation géométrique change.

Les tests Godot vérifient la transmission du choc, les ombres et la matière, la réutilisation du même fantôme, et l'absence de tweens sur des noeuds supprimés. L'atelier reste déterministe : **ce n'est pas encore une vraie simulation molle avec collision dynamique**. Les captures OpenGL et l'APK ARM64 0.9.15 (versionCode 12) sont compilés par GitHub Actions avant fusion.

L'export/import des niveaux de puzzle ne contient toujours pas \`user://jelly-stack-v1.json\`. Une désinstallation peut donc effacer l'atelier, même si les niveaux classiques ont été exportés.


## Android 0.9.16 — sauvegarde unique complète, vues studio et reflets retravaillés

Le transfert portable Android (boutons **Exporter** et **Importer** dans le mode puzzle) inclut désormais **la progression des 21 puzzles et la construction libre 3D**, dans un fichier JSON unique vérifié par SHA-256. Les anciens exports version 1, qui ne contenaient que les puzzles, restent importables : dans ce cas **l'atelier local est conservé**.

- **Format v2** : le checksum couvre conjointement les puzzles et les 32 briques possibles de l'atelier. L'import valide chaque pose dans son ordre d'origine : couleurs, dimensions, orientation, hauteur, contacts et au moins 50 % de support. Un fichier corrompu ou une pile impossible est rejeté avant d'altérer le jeu.
- **Restauration** : l'ancienne progression du puzzle est sauvegardée et un échec d'import de l'atelier déclenche une restauration compensatoire des puzzles. Les anciennes sauvegardes v1 ne remplacent pas le contenu de l'atelier.
- **Caméra studio** : nouveau bouton de vues dans le mode Tour 3D. Il alterne entre *Vue 3D*, *Vue côté* et *Vue dessus* sans affecter la caméra sauvegardée du mode puzzle. Les gestes utilisent le rayon de la caméra active.
- **Material** : reflets de deux softboxes procéduraux et réduction de l'émission blanchâtre sur les faces colorées. Aucun asset additionnel ou lumière dynamique coûteuse.
- **Effets** : les poses du mode Tour 3D utilisent les petites particules déjà instanciées pour les puzzles, sans émetteurs supplémentaires. Les effets sont remis à zéro à la sortie du mode.

Les tests Godot doivent valider les deux versions de sauvegarde, les restaurations, le rejet des piles corrompues, les trois vues, les gestes, les 21 niveaux et les captures OpenGL. APK Android ARM64 version 0.9.16 (versionCode 13), signé en debug.

**Prudence** : l'APK généré par une pull request continue de recevoir un certificat de test temporaire. Exporte toujours ton jeu avant de désinstaller une ancienne version. Le système de signatures persistantes requiert une clé sauvegardée en secret GitHub et ne peut pas être remplacé en toute sécurité par un cache public.


## Android 0.9.17 — déformation volumique Jelly, scène ancrée et caméra adaptative

Le but reste de rejoindre la référence vidéo : **vraies briques de gelée moulées** et **réactions élastiques**, sans multiplier les moteurs, textures de tiers ni effets artificiels.

- **Déformation par sommets sur GPU** : nouveau paramètre shader \`gel_spring\` (initialement 0) qui courbe légèrement les surfaces et comprime le dessus au contact. L'onde dépend du temps et de la position locale ; elle préserve la base ancrée et disparaît par tween après l'impact. La même propriété se propage, en plus faible, aux briques qui soutiennent la nouvelle pièce. Les niveaux puzzle restent à \`gel_spring=0\`.
- **Photographie produit** : deux rehauts spéculaires supplémentaires calculés directement à partir des normales, relief plus net sur les bords moulés et côtés légèrement plus denses. Aucun fichier texture ni nouvelle dépendance.
- **Ancrage du studio** : socle satin au bord plus visible, ombre de contact diffuse unique sous l'ensemble, plus les voiles de contact locaux repositionnés *sous* les briques. Aucun shadow map ou calcul physique continu n'est nécessaire.
- **Caméra automatique** : au-delà des petites piles, la caméra ajuste sa hauteur cible et son cadrage pour inclure les neuf étages possibles, dans les trois angles déjà sélectionnables.
- **Sécurité** : les animations de déformation sont annulées et remises à zéro lors d'une reconstruction, d'une annulation ou d'une nouvelle pose, au même titre que le mouvement rigide.

### Qualité automatisée

Les tests Godot réels vérifient les uniformes de déformation des blocs, la propagation du choc, le retour au repos, l'ombre placée sous le vrai volume, le socle et une pile de neuf étages. Le pipeline Mesa OpenGL produit **cinq captures** : puzzle, studio 3/4, côté, dessus et **une capture pendant l'impact d'une nouvelle brique**, au lieu de ne contrôler que des matériaux immobiles. Les tests de sauvegarde Android v1/v2 restent inchangés et toute régression bloque la fusion.

Cette amélioration est une **simulation volumique cinématique**, pas une physique complète des matériaux mous, et la finesse du résultat doit être évaluée sur le téléphone Android. Les anciennes sauvegardes restent compatibles. APK debug \`0.9.17\` (\`versionCode=14\`). Avant une réinstallation nécessitant une autre signature, exporter la sauvegarde complète.


## Android 0.9.18 — densité du gel et contraste packshot

Cette passe répond aux défauts réellement observés sur les captures de la 0.9.17, sans modifier la progression, la sauvegarde combinée, les règles de support, les trois vues ou le gameplay tactile.

- **Pigmentation optique mieux équilibrée** : le nouveau paramètre \`studio_pigment\` recentre la couleur du gel sur le pigment de la brique au lieu de laisser les nombreuses lumières blanches laver toute sa surface. L'alpha de la matière posée est renforcé tandis que le fantôme reste translucide. Le shader ajoute un anneau spéculaire très fin à la couronne des tenons moulés, sans ajouter de géométrie.
- **Support visible en studio blanc** : peinture satin légèrement plus contrastée sur le socle, bord gris perle plus lisible et voile d'ombre de contact doux plus visible.
- **Optimisation du shader** : la déformation par ondes (\`sin\`/\`cos\`) est ignorée par les GPU lorsque \`gel_spring\` vaut zéro. Le calcul du liseré des tenons est également ignoré en dehors de la partie supérieure du tenon et du mode studio. Aucun nouveau draw call, asset, texture ou lumière dynamique n'est ajouté.
- **Séparation stricte** : les nouveaux réglages restent spécifiques à l'atelier 3D. Les 21 niveaux classiques gardent la valeur par défaut \`studio_pigment=0\` et leurs matériaux actuels. Les préférences, exports Android et constructions 3D sauvegardées restent compatibles.
- **Régression** : les tests Godot contrôlent la saturation/opacité du matériau, les tenons partageant bien le matériau, le fantôme non opaque, la couleur du socle et la force de l'ombre, en plus des 21 niveaux, transferts v1/v2, captures OpenGL et APK ARM64.

**Limite :** il s'agit d'un rendu de matériau gélatineux simulé, non d'une réfraction géométrique calculée par ray tracing. Mesurer les FPS et inspecter le résultat sur Android reste indispensable pour juger la proximité visuelle avec la vidéo de référence.

APK Android debug 0.9.18 / versionCode 15. En cas de conflit de certificat debug entre builds, exporter une sauvegarde complète (puzzles et atelier) avant toute réinstallation.


## Version native 0.9.19 — véritable coque Jelly moulée et coins arrondis

Cette passe vise la différence fondamentale observée entre les références vidéo et le rendu actuel : les briques du studio ne doivent **plus ressembler à des cellules carrées assemblées**.

- Nouvelle géométrie créée dans \`scripts/gel_mesh.gd::build_studio\`, uniquement pour le mode Tour 3D : **coque d'un seul tenant à quatre coins de rayon 0,175 et sept subdivisions angulaires par coin**, prolongés continûment dans les sept niveaux du bevel latéral.
- Dessus **lisse et sans joints intermédiaires**, formé par une seule couronne arrondie et un centre légèrement bombé. Les faces inférieures, la section volumique et les normales interpolées restent cohérentes ; les tenons arrondis sont toujours instanciés par MultiMesh avec le même matériau.
- Les trois tailles Petit/Moyen/Long et leurs deux orientations utilisent ce nouveau maillage. Chaque variante est mise en cache et partagée entre les briques identiques ; **aucune création de maillage lors d'un glissement ou à chaque image**.
- Le mode puzzle classique conserve son maillage \`GEL.build\`, adapté aux 21 formes complexes et aux éventuels trous : ses silhouettes, règles et sauvegardes restent inchangées.
- Tests natifs ajoutés pour les six variantes de maillage : dimensions 3D, arc convexe réel aux coins, dessus continu, présence de normales et géométrie exploitable sur Godot 4.6. Toujours soumis aux tests des 21 niveaux, cinq captures Mesa OpenGL, Android ARM64 et Chromium.

Cette amélioration est géométrique, pas un simple changement de couleur : elle devrait rapprocher les volumes du packshot de référence. Les performances et l'appréciation finale restent à confirmer sur un téléphone Android réel.

APK Android debug **0.9.19**, versionCode 16. Avant une réinstallation impliquant une signature différente, exporter la sauvegarde complète.


## Android 0.9.20 — Galerie cinématique avec couche optique Jelly

La référence visuelle présente les briques comme un **objet de photographie produit**, pratiquement sans commandes à l'écran. Pour observer et partager visuellement une construction, l'atelier `Tour 3D` dispose désormais du bouton **Photo** dans la rangée des tailles/vues.

- **Présentation plein écran** : le bouton Photo masque toutes les commandes de construction et le fantôme de placement. Seuls restent le discret titre « JELLY BRICKS » et un bouton **✕ Fermer**, accessible même lorsque l'éditeur est caché. Fermer restitue la vue, les réglages et les commandes d'avant la présentation. Un appui dans le décor ne place jamais de brique.
- **Caméra de présentation** : orbite automatique lente autour de la construction, cadrage adapté de l'exemple de six briques jusqu'aux tours de neuf niveaux. Le socle massif disparaît uniquement dans cette vue ; le sol studio mat remonte jusqu'aux véritables contacts des briques et son état d'origine est restauré à la fermeture.
- **Clearcoat original** : nouveau shader spatial `shaders/studio_clearcoat.gdshader` utilisé uniquement pendant la présentation. Cette couche transparente est décalée légèrement vers l'extérieur et simule un liseré de Fresnel + deux panneaux de lumière blanche. Elle partage exactement les meshes du corps et le MultiMesh des tenons, et ne demande **aucune nouvelle géométrie, texture, requête réseau, réfraction écran ou moteur physique**.
- **Budget Android contrôlé** : le clearcoat reste invisible pendant la partie normale, donc sans passages de rendu supplémentaires. En présentation, le corps reçoit sa couche optique ; le clearcoat des tenons est désactivé au-delà de 18 briques pour limiter les draw calls des grosses constructions.
- **Contrôles de qualité** : nouveaux tests de changement de mode, réutilisation des Mesh/MultiMesh, extinction complète du clearcoat au retour au jeu, vue tournante et protection contre les gestes tactiles accidentels. Le pipeline Mesa OpenGL produit maintenant **six captures**, dont une photographie sans interface de l'atelier.

L'exhibition est un mode de visualisation, pas une véritable sauvegarde photographique sur Android. Les constructions et les 21 puzzles continuent à utiliser la sauvegarde commune portable déjà existante.

APK native 0.9.20 / versionCode 17. Le certificat de test peut différer entre compilations ; exporter une sauvegarde avant toute désinstallation.


## Android 0.9.21 — ombres physiques uniquement en galerie

Jusqu'à 0.9.20, la scène ne disposait que de voiles de contact procéduraux : la photo de la construction n'avait aucune ombre directionnelle et certaines briques pouvaient sembler détachées du sol.

- Le mode **Photo** utilise désormais une **unique lumière directionnelle chaude** avec ombres du vrai moteur Godot Compatibility, afin que chaque brique moulée projette une ombre sur les autres et sur le sol continu.
- **Coques de projection originales** : chaque brique garde son ShaderMaterial gélatineux translucide et son clearcoat. Une troisième instance du *même* maillage arrondi, définie `SHADOW_CASTING_SETTING_SHADOWS_ONLY` avec un matériau opaque partagé, est invisible dans la couleur, mais projette correctement sa silhouette volumique dans l'atlas d'ombres. Aucun nouveau modèle, vertex buffer, asset ou texture externe n'est alloué.
- **Ombre de contact sur sol blanc** : sous la pile, un seul voile radial doux est conservé même avec l'ombre réelle, car les éclairages studio saturés peuvent masquer les ombres de la lumière directionnelle sur un sol presque blanc. Cet effet léger est garanti et sa force est restaurée à la sortie de galerie.
- **Budget strict de performances** : seules les galeries de **14 briques au maximum** activent l'ombre directionnelle. Le jeu normal ne rend jamais les coques de projection. Au-dessus de 14 briques, ce seul voile radial sans shadow map assure le contact avec le sol. La sortie de galerie restaure aussi le socle et les ressources d'éclairage.
- Les **21 puzzles classiques, l'empilement tactile, la logique des appuis, les sauvegardes exportables, les trois caméras et le matériau Jelly normal** restent inchangés.
- Tests Godot supplémentaires : maillage identique pour corps et ombre, mode de projection `SHADOWS_ONLY`, aucun passage supplémentaire hors galerie, vraie lumière active sur la petite pile, désactivation en scène chargée et restauration complète.

Les **six captures OpenGL Mesa**, les tests Godot 4.6 des 21 niveaux et l'APK ARM64 sont les critères de fusion. **Attention :** un contrôle de scène vérifie l'état du moteur, mais ne mesure pas automatiquement la qualité perçue des ombres ni les FPS physiques sur Android. Le rendu reste à comparer sur appareil.

APK natif debug **0.9.21**, versionCode **18**. Conserver une sauvegarde complète avant une réinstallation nécessitant une désinstallation de l'ancienne signature debug.


## Android 0.9.23 — absorption optique du gel

Amélioration du rendu inspirée par les références vidéo : les briques Jelly prennent un pigment plus dense sur les côtés et aux angles où l'épaisseur apparente de la matière augmente. L'effet reste une **approximation artistique monocouche** : pas de ray tracing, réfraction écran, textures ni passages de rendu supplémentaires.

- `shaders/jelly.gdshader` : nouveau paramètre `optical_depth` dont l'intensité dépend du regard, de la normale du volume et de l'angle du flanc. L'intérieur est plus coloré et une fine lumière diffuse suit le bord arrondi. Les puzzles classiques conservent la valeur par défaut `optical_depth = 0`.
- Jeu dans l'atelier : absorption **0,54**, conservatrice pour les performances et la lisibilité ; fantôme **0,18**, plus translucide et facilement distinguable ; présentation Photo **0,93**, pour simuler une coloration plus profonde sans mesh supplémentaire.
- La sortie du mode Photo restaure le réglage normal ; les sauvegardes puzzles/atelier et les gestes ne sont pas modifiés.
- Régressions Godot : vérification des valeurs du shader et de la restauration lors du changement de mode. Capture OpenGL du puzzle, de l'atelier, de l'impact et de la Galerie, tests des 21 niveaux et export Android ARM64.

**Limite :** ces reflets et cette absorption ne reproduisent pas une vraie propagation optique à l'intérieur d'un matériau. Des captures et des mesures sur téléphone Android restent nécessaires pour apprécier le résultat et la fluidité.

APK debug v0.9.23, versionCode 20. Exporter une sauvegarde complète avant toute réinstallation nécessitant de désinstaller un ancien APK signé différemment.


## Android 0.9.24 — Galerie 3D interactive à un et deux doigts

Le mode Photo n'est plus limité à son orbite automatique. Sur Android, **glisser horizontalement avec un doigt** tourne librement la caméra autour de la sculpture Jelly ; **écarter ou rapprocher deux doigts** zoome sur la pièce ou recule (plage volontairement limitée à 70–175 % du cadrage normal). La caméra cesse son orbite lente pendant le contact et reprend après le relâchement.

L'implémentation reste native Godot et n'ajoute ni asset, shader, texture, passe de rendu ni dépendance ; elle actualise seulement la transformation et la taille orthographique de la caméra existante. Les commandes d'assemblage restent désactivées pendant la présentation, même si plusieurs doigts sont posés successivement. Toute sortie du mode Photo efface les contacts en cours et restaure le cadrage de construction initial.

Le test Godot simule une rotation à un doigt, l'arrêt temporaire de l'orbite automatique, un pincement à deux doigts, le relâchement complet, la reprise du mouvement et l'absence de pose accidentelle. Les 21 puzzles, l'import/export combiné et les contrôles de construction restent inchangés. La CI conserve ses six captures OpenGL et l'export de l'APK Android ARM64.

APK de développement 0.9.24, versionCode 21. Si la signature de cet APK diffère de celle de l'application installée, exporter la sauvegarde complète avant une désinstallation.
 

## Android 0.9.26 — lumière transmise par la gelée

Les briques posées **directement sur le socle** projettent un halo coloré discret, rappelant la transmission et la diffusion de lumière par une matière gélatineuse translucide. Ce n'est pas du ray tracing ni une réfraction volumique physique : c'est une approximation artistique et peu coûteuse, qui améliore visuellement l'ancrage des objets au sol.

- Nouveau shader spatial original `shaders/studio_caustics.gdshader` : une plage lumineuse à dégradé radial et un liseré diffus, teints par la couleur de chaque brique. Aucun fichier texture, sample du framebuffer ou nouvelle lumière.
- Une seule instance graphique `CandyLightTransmission` et **un seul MultiMesh partagé** pour toutes les briques du niveau zéro. Jusqu'à 32 briques sont représentées sans 32 objets de halo ni 32 matériaux.
- Les tailles et orientations des empreintes sont calculées à partir des dimensions réelles des briques. Les pièces empilées plus haut ne projettent pas artificiellement de lumière au sol.
- Les projections restent présentes sur le socle pendant la construction et sur le fond continu du mode Photo ; leur alpha faible protège le rendu épuré. Elles suivent automatiquement les poses, annulations, importations et réinitialisations, sans mise à jour à chaque frame.
- Tests : pool partagé, trois halos de l'exemple de départ, aucun halo sur une pièce au-dessus du sol, nettoyage après reset, couleur et hauteur des trois instances vérifiées sous **Mesa OpenGL réel**, 21 puzzles, captures et APK Android.

Le matériau Jelly, les 21 puzzles et le format des sauvegardes restent inchangés. Le gain esthétique et l'impact sur les FPS doivent encore être examinés sur l'appareil Android.

APK native 0.9.26, versionCode 23. Exporter une sauvegarde complète avant une réinstallation nécessitant un nouveau certificat de développement.


## Android 0.9.28 — pigment plus vif, peau Jelly vernie

Les photographies de référence ont des couleurs plus profondes et saturées que les premières versions de l'atelier, trop pastel, avec des petits points blancs aléatoires. La nouvelle finition **moulée/vernie** corrige directement la matière, plutôt que de superposer de nouveaux effets ou lumières.

- Uniforme `studio_finish` (0 par défaut) : `0.94` sur les briques solides du mode Tour 3D et `0.46` sur le fantôme de placement, qui demeure translucide. Les 21 niveaux puzzles conservent automatiquement la valeur zéro et leur matériau initial.
- **Suppression du moucheté blanc** sur les surfaces Jelly vernies, responsable d'un effet « poussière » indésirable. Les petites bulles restent dans le matériau de puzzle, où elles faisaient partie de son apparence établie.
- **Pigment rééquilibré** sur le corps et les côtés : remplace une grande part du blanc accumulé par la couleur réelle des cinq teintures. Les zones en bordure conservent leur profondeur et leur subtil liseré laiteux.
- Deux reflets optiques plus concentrés suivent l'angle caméra et les normales sculptées. Ils ne nécessitent aucun nouvel éclairage, texture, rendu à passes multiples, calcul de réfraction d'écran ni animation par script.
- **Silhouette remoulée** pour rejoindre les blocs Jelly de la vidéo : rayon des quatre coins réduit de 0,175 à 0,130 et biseau latéral maximal ramené de 0,109 à 0,080 unité. Les faces sont davantage planes et le profil moins gonflé, sans réduire le nombre de subdivisions. Uniquement dans `build_studio()` : les contours spéciaux des puzzles conservent leur ancien maillage. Les six formes/orientations sont testées avec leurs nouvelles dimensions réelles.
- Tests Godot : matière vernie installée sur toutes les briques solides, différence visible dans les paramètres du fantôme, validation des 21 puzzles, de la sauvegarde et du mode Photo ; captures Mesa OpenGL et export Android ARM64.

**Référence recherchée :** couleur vive de briques en gel brillante, moulées et lisibles, sans transformer le tout en plastique opaque. Il s'agit toujours de reflets et d'absorption stylisés ; aucune promesse de correspondance exacte ou de FPS physique sans essais sur Android.

Version Android 0.9.28 / versionCode 25. Avant une réinstallation nécessitant de supprimer l'ancienne version, exporter la sauvegarde complète.


## Android 0.9.29 — brillance vernie et angle de caméra de référence

Les pigments plus vifs de 0.9.28 ont mis en évidence le dernier problème de rendu : les côtés paraissent encore uniformément mats, alors que les briques de référence ont un liseré brillant net sur leur peau translucide.

- Réécriture du shader original `studio_clearcoat.gdshader` (utilisé **exclusivement dans le mode Photo**) : deux surfaces lumineuses de studio, dont une projection de softbox étirée sur les flancs par les coordonnées locales du volume, et un reflet étroit dépendant de l'angle de la caméra. Couche transparente limitée à 0,42 d'opacité, sans cacher la couleur renforcée par le shader principal.
- Le clearcoat continue de partager les maillages du corps et le `MultiMesh` des tenons : pas de géométrie supplémentaire, aucune texture d'environnement, aucune capture de l'écran, aucun coût additionnel pendant l'atelier normal.
- **Cadrage Photo abaissé** : caméra à 5,8 unités au-dessus du point de visée, rayon horizontal 12,4 (contre 7,9/11,3). Les parois rectangulaires et les reliefs des tenons deviennent plus visibles, comme sur la vidéo originale. Cadre légèrement resserré à 8,8 unités minimum, avec recalcul automatique pour les grandes tours et maintien de l'orbite/pincement Android.
- Test de non-régression Godot sur le nouvel angle et le cadrage, avec les tests de zoom, de rotation et du suivi des doigts déjà existants. Toujours contrôlé par six captures réelles Mesa OpenGL, les 21 puzzles Godot, Chromium tactile, et APK ARM64.

Cette version simule des softboxes en shader léger : **ni ray tracing ni véritable réfraction physiquement calculée**. La fidélité photographique doit être jugée sur les captures et sur un téléphone réel, sans supposer un framerate vérifié.

APK 0.9.29 / versionCode 26 ; sauvegardes puzzles+studio inchangées.


## Android 0.9.30 — arrêt sur image en Galerie

Le mode Photo dispose d'un bouton **Pause / Reprise** pour figer l'orbite au moment où les reflets Jelly sont les plus lisibles. Le cadrage et le zoom tactile restent manipulables pendant la pause ; aucun objet n'est posé accidentellement. Chaque entrée en Galerie redémarre en rotation et la sortie efface l'état de pause. Test Godot dédié au gel de l'angle et à la reprise. Version Android 0.9.30, versionCode 27.


## Android 0.9.31 — tenons Jelly moulés fidèles à la vidéo

Une nouvelle comparaison de la vidéo originale et des captures Godot a isolé un écart graphique important : les tenons étaient trop bombés, donnant aux briques l'allure de bonbons à protubérances plutôt que celle de véritables briques transparentes moulées.

- Nouveau mesh natif `GEL.build_studio_stud()` propre à l'atelier 3D : **dessus quasi plat**, bord supérieur finement arrondi, flanc cylindrique droit, raccord inférieur adouci. Profil 16 segments au lieu des 12 du modèle puzzle, pour des cercles plus propres en gros plan.
- Rayon maximal réduit de 0,145 à 0,136 unité, tandis que **la hauteur de contact reste rigoureusement à 0,798 unité** : les empilements et leur support ne flottent pas. Le modèle classique `GEL.build_stud()` reste inchangé pour les 21 puzzles.
- **Un seul maillage de tenon par atelier** partagé par les MultiMesh de toutes les pièces. Le mode Photo partage toujours exactement le même tampon d'instances avec le clearcoat : aucune géométrie supplémentaire par tenon et aucune texture.
- Tests Godot précis sur le disque de surface, la couronne cylindrique, le rayon et la hauteur de contact, le maintien du modèle d'origine des puzzles, la mutualisation dans tous les six blocs initiaux.
- Test de vérification **Mesa OpenGL réel** : la première longue brique réutilise le mesh de tenon studio dans ses 12 instances et leurs transformations GPU sont correctes. Les six captures Godot, la sauvegarde, les 21 niveaux et l'APK ARM64 restent validés automatiquement par GitHub Actions.

Version Android **0.9.31 / versionCode 28**. Ce changement cible les silhouettes et n'est pas une véritable simulation volumique de la transparence. Vérifier les performances et l'apparence sur le téléphone physique avant qualification commerciale.


## Android 0.9.32 — Vitrine 3D fidèle à la composition de référence

Les prises de vue reçues montrent une vraie tour verticale Jelly multicolore, accompagnée de quelques briques séparées. Jusqu'ici, la Galerie présentait surtout la construction courte de départ, et donnait l'impression de briques groupées plutôt que d'une tour instable.

- Nouveau bouton **Vitrine** dans la Galerie Photo, transformé en **Ma pile** pendant l'exposition. Un appui montre une **tour originale de neuf niveaux validés physiquement**, avec douze vraies briques au total : neuf pièces enchevêtrées et trois pièces isolées au pied. Retour direct à l'assemblage personnel par **Ma pile**.
- Vitrine générée exclusivement avec `_build_piece()`, les géométries Godot natives, le matériau Jelly verni, les tenons plats du 0.9.31, l'éclairage et les ombres existantes. **Aucune photographie prédécoupée ni image 2D**.
- Les données de démonstration passent avant rendu par `SAVE_TRANSFER.validate_studio` : la tour suit les mêmes limites (6 × 6, neuf étages, au moins la moitié du pied soutenu) que le vrai jeu.
- **Séparation absolue des données** : les exemplaires de vitrine appartiennent à `GalleryReferenceTower`, un nœud 3D temporaire indépendant. Ni `bricks`, ni l'occupation, ni le JSON enregistré, ni les puzzles ne sont modifiés. Retour à `Ma pile`, fermeture Photo, retour aux puzzles et libération des objets 3D rétablissent le jeu.
- Le cadrage et l'orbite automatiques s'adaptent à la hauteur réelle exposée. La projection colorée du sol garde **le même MultiMesh** et change seulement ses quatre instances pendant l'exposition. La lumière de la vitrine réutilise le rig existant, sans nouvelle shadow-map.
- Tests natifs : vérification structurelle des 12 pièces, hauteur des 9 couches, ressources visuelles, aucune mutation du joueur, restauration des trois caustiques et libération de la scène d'exposition.
- Sept captures **réelles du moteur Godot/OpenGL** demandées en CI, y compris `jelly-stack-reference-tower-preview.png`. L'APK ARM64 n'est publiée qu'après tests, avec versionCode 29.

Les reflets restent stylisés et devront poursuivre leur évolution pour se rapprocher de la vidéo. Une capture OpenGL virtuelle ne remplace pas la mesure des FPS sur un vrai smartphone Android.


## Android 0.9.33 — disposition réelle des tenons Jelly

La capture de référence montre deux rangées de petits tenons le long de la largeur d'une brique. L'ancien atelier générait quatre tenons par unité de longueur, soit douze petites bosses sur la barre de trois unités, beaucoup trop dense visuellement.

- **Deux tenons par unité** sur le petit axe des briques : 2, 4 ou 6 tenons selon leur longueur. La disposition est réorientée automatiquement de 90° avec la pièce, sans modifier le maillage de sa coque ou les positions de sauvegarde.
- Les tenons conservent le profil plat et bas de la version 0.9.31, la même teinte et le même clearcoat optionnel. Leur **MultiMesh reste partagé** par la coque opaque et le vernis de la Galerie.
- Réduction de moitié des instances de tenons dans le mode Tour 3D, sans supprimer la physique visuelle ni altérer les volumes Jelly. Les 21 niveaux puzzles continuent d'utiliser leur géométrie indépendante inchangée.
- Contrôles natifs de 2, 4 ou 6 instances selon la longueur. Le test OpenGL Mesa vérifie **les six positions GPU** et l'origine exacte du premier tenon de la pièce longue, et les sept captures de la Galerie verticale restent obligatoires.
- Android 0.9.33, versionCode 30. Exporter la sauvegarde complète si une désinstallation est nécessaire à cause de la clé debug.

Le rendu n'est pas encore identique à la vidéo : réfraction, rugosité et déformation du gel restent des pistes d'évolution.


## Android 0.9.34 — vitrine frontale et bande de lumière Jelly

Comparaison à la vidéo `Jelly Bricks` : la tour de démonstration était photographiée trop en diagonale alors que la référence montre des briques rectangulaires alignées, principalement vues de face. Les flancs restaient presque mats malgré la finition transparente.

- **Cadrage de vitrine dédié** : bouton « Vitrine » du mode Photo bascule vers un angle presque frontal (`photo_angle=0.06`) et un zoom un peu plus proche (`photo_zoom=0.92`). Le dessin rectangulaire des neuf niveaux est plus lisible, les deux rangées de tenons gardent leur relief. L'orbite cinématique et les gestes de l'utilisateur continuent de fonctionner dans la vitrine.
- **Retour sans perte de caméra** : l'angle et le zoom précédents de la construction personnelle sont mémorisés et restaurés exactement lorsque l'utilisateur presse « Ma pile » ou sort du mode Photo. La vitrine ne modifie toujours pas les sauvegardes.
- **Trois briques libres mieux disposées** : des pièces jaunes, orange et corail sont réparties à gauche, à droite et au premier plan. Cela évite qu'une pièce soit cachée derrière la tour ou à moitié coupée par l'écran portrait. Ces coordonnées n'appartiennent qu'à la vitrine temporaire et passent par le validateur habituel des 12 briques.
- **Vernis mieux orienté** : dans `studio_clearcoat.gdshader`, une bande de lumière blanche diffuse est concentrée sur les faces latérales avant et un liseré très fin souligne l'arête supérieure. Pas de lumière supplémentaire, pas de texture, pas de maillage, pas de passe en mode puzzle ou construction normale ; le revêtement est déjà utilisé uniquement en mode Photo.
- **Régressions natives** : assertions de composition frontale et restitution exacte de l'angle/zoom à la sortie, vérification des douze briques de démonstration, sauvegardes intactes, 21 puzzles et validation réelle OpenGL des captures, dont la vitrine de neuf niveaux. Compilation Android ARM64 obligatoire avant fusion.

Version Android 0.9.34 / versionCode 31. La correspondance visuelle et les FPS sur matériel Android réel restent à vérifier sur téléphone.


## Android 0.9.35 — vrais flancs plats et biseaux Jelly

La référence utilisateur présente des blocs de construction majoritairement rectangulaires avec un gel poli et des arêtes adoucies ; dans la 0.9.34, les biseaux latéraux s'étendaient encore sur toute la hauteur, donnant une silhouette trop gonflée.

- Le générateur de maillage `build_studio()` utilise désormais ses **propres anneaux de hauteur et de normales**, entièrement indépendants des puzzles : un flanc réellement **vertical de 0,27 unité** (de `y=0,435` à `y=0,165`) et des biseaux géométriques en haut et en bas.
- Deux anneaux partagent le même rayon extérieur `0,064` et des normales strictement horizontales : c'est une vraie surface 3D plane, pas une illusion dans le shader. Les petits coins restent arrondis avec les subdivisions existantes.
- La nouvelle emprise maximale des briques est `largeur + 0,128` et `profondeur + 0,128`, sans changer le nombre d'instances de tenons, la simulation de soutien, la position des pièces ou les sauvegardes.
- Contrôle Godot de **six maillages** (trois longueurs et deux orientations) : épaisseur, surface continue, coins arrondis, présence de deux bandes de normales horizontales et hauteur minimale du flanc plan. Les 21 puzzles utilisent leur ancien profil, non modifié.
- Captures Mesa OpenGL de la scène interactive, de l'impact et de la vitrine verticale ; export APK Android ARM64 et tests Chromium obligatoires avant fusion.

Version Android 0.9.35, versionCode 32. La qualité du rendu final et le coût GPU doivent rester contrôlés sur Android physique.


## Android 0.9.36 — optimisation des ressources du fantôme Jelly

Le fantôme translucide de placement n'entre jamais dans la Galerie. Il n'alloue donc plus les deux nœuds optiques supplémentaires (`OpticalBody`, `OpticalStuds`) réservés à la photographie. Les vraies briques conservent leurs reflets et leurs ombres inchangés. Test de régression natif ajouté. L'amélioration réduit les allocations et le nombre de nœuds pendant les changements de longueur et d'orientation, sans modifier les 21 puzzles ni le format des sauvegardes. VersionCode 33.


## Android 0.9.37 — stabilité de l'orbite de la Galerie après un geste

Dans la Galerie, la rotation automatique attend désormais **2,5 secondes après le relâchement du dernier doigt ou du clic souris** avant de reprendre. L'angle et le zoom choisis restent stables pendant ce délai. Une animation lente reprend ensuite sans saut ; le mode Pause manuel reste prioritaire. Changer de mode réinitialise les gestes et le délai, sans toucher aux constructions ni aux sauvegardes.

Les tests natifs vérifient le délai complet, le redémarrage de l'orbite et la parité entre gestes tactiles et souris. Version Android 0.9.37, versionCode 34. La fluidité perçue et l'absence de sauts doivent encore être vérifiées sur appareil réel.


## Android 0.9.38 — coût GPU borné dans les grandes galeries Jelly

Les constructions de 1 à 18 briques ainsi que la vitrine de référence (12 briques) conservent l'intégralité des reflets photographiques. Pour une construction de 19 à 32 briques, le nombre de surcouches `OpticalBody` affichées est désormais **plafonné à 18** : les dernières briques posées, généralement au sommet, gardent la finition vitrine, tandis que les plus anciennes conservent leur **shader Jelly brillant de base**, sans surcouche supplémentaire. Au-delà de 18 briques, les surcouches `OpticalStuds` restent désactivées, et les véritables cartes d'ombres restent limitées à 14 briques, comme avant.

Les petits plans de contact des briques sont désormais mutualisés en **six géométries seulement** (trois longueurs × deux orientations), au lieu d'être recréés à chaque pose. La forme, les couleurs, l'ombre au sol, la géométrie principale, les collisions, les sauvegardes et les puzzles ne changent pas. Les tests natifs vérifient un ensemble de **32 objets distincts**, le nombre exact de couches actives, le retour à zéro après la galerie et la réutilisation des géométries de contact. Le test réel Mesa OpenGL, l'APK Android et les captures de contrôle restent requis avant fusion.

Version Android 0.9.38 (versionCode 35). Il s'agit d'un plafond de travail graphique prévisible, **pas d'une mesure prouvée de FPS, de température ou de consommation** sur smartphone physique.


## Android 0.9.39 — mouvement élastique cohérent de la tour Vitrine

La vidéo de référence montre une tour de petites briques Jelly qui oscille doucement sous son propre poids. La Vitrine 3D à neuf étages adopte ce comportement, sans animation rigide aléatoire ni moteur physique temps réel.

- Un **déplacement harmonique progressif** croît quadratiquement avec l'étage : le niveau au sol reste rigoureusement fixe, le sommet oscille horizontalement au maximum de 0,085 unité en X et 0,042 en Z, avec une légère torsion de 0,009 radian.
- Les 12 briques déjà mises en cache sont animées par leurs vrais `Node3D` : **aucun nouveau mesh, matériau, particule, lumière ou draw call**. Le calcul porte uniquement sur cette vitrine facultative et non sur les 21 puzzles ni sur les piles personnelles du joueur.
- Le bouton **Pause** gèle réellement les mouvements de la tour, en plus de l'orbite de la caméra. Toucher/pivoter la photo suspend temporairement les oscillations. La reprise du mouvement est progressive car la phase est gelée et réutilisée ; pas de saut temporel.
- Fermer la Vitrine remet toutes ses briques exactement à leur position enregistrée dans la démonstration, rétablit la caméra et la construction personnelle et ne touche jamais aux sauvegardes.
- Les tests Godot vérifient l'immobilité totale des briques au sol, la limite d'amplitude en haut, la pause, la reprise, le retour à la pose neutre et l'identité des données sauvegardées. Le pipeline Mesa OpenGL exige désormais **huit vraies captures**, dont deux à des instants différents de la tour animée.
- Android 0.9.39, versionCode 36. Les performances réelles sur appareils Android restent à mesurer.



## Android 0.9.40 — lumière sur le véritable biseau Jelly

La comparaison visuelle de la tour 0.9.39 avec les images de référence montre que la géométrie est désormais proche mais que les flancs restent trop uniformément mats. La nouvelle finition introduit un **ménisque verni photographique**, directement ancré aux sommets du maillage 3D sculpté, sur les bandes de biseau `y=0.497–0.56`.

- Nouveau paramètre `studio_wet_edge` dans `shaders/jelly.gdshader`, zéro par défaut, utilisé exclusivement sur le gel de l'atelier : **0.95** sur les briques solides / la tour Vitrine, **0.15** sur le fantôme de placement. Le biseau renvoie un reflet blanc localisé selon son orientation, son inclinaison et la caméra ; un **large panneau lumineux rectangulaire atténué** suit aussi les flancs moulés, sans écran ni texture. Le cœur des briques conserve son pigment coloré.
- Les tenons plats ont désormais un liseré de vernis plus lisible sur leur arête supérieure. Ils réutilisent leur MultiMesh d'origine, sans ajouter un seul cylindre ou dessin séparé.
- **Optimisation du shader fragment** : les briques solides vernies ne calculent plus les deux sinus et la puissance du bruit de microbulles, totalement masqué depuis le changement de finition. Le puzzle original et le fantôme conservent leur microtexture. Aucune texture supplémentaire, HDRI, réfraction d'écran, shadow map, passe GPU ou simulation physique.
- Tests Godot : matériau vérifié sur toutes les briques du mode normal, sur les **12 objets de la Vitrine référence** et sur le fantôme transparent. Les validations précédentes (21 niveaux, sauvegardes, interactions, tours hautes et basiques) restent en place.
- Pipeline réel Godot 4.6 : import et compilation shader, huit captures Mesa OpenGL, Android ARM64 debug APK, tests web/Chromium tactile.

Le rendu reste une stylisation mobile adaptée à Godot Compatibility, pas une simulation complète de réfraction spectrale. Une image Mesa ne remplace pas une mesure de FPS sur un appareil Android réel. Version 0.9.40 / versionCode 37. Le debug APK peut avoir une nouvelle identité de signature : exporter la sauvegarde avant désinstallation.


## Android 0.9.41 — Galerie figée plus économe

Lorsque l'utilisateur met le mode Photo en pause, la caméra et les animations de présentation cessent désormais leurs calculs/écritures à chaque image. Une rotation ou un zoom manuel reste possible via les gestionnaires tactiles, et Reprise remet en marche la caméra et le gel animé. Le test Godot vérifie que le transform de la caméra ne change pas pendant une pause. Aucun changement aux 21 puzzles, aux matériaux ou aux sauvegardes. Android 0.9.41 / versionCode 38.


## Android 0.9.42 — briques Jelly réellement emboîtées

Le défaut visuel le plus important de la tour 0.9.41 était **l'espace entre les corps** : chaque niveau était élevé de 0,74 unité, posant la brique supérieure sur la pointe des tenons, avec plus de 0,23 unité de vide visible entre les flancs. Cette silhouette paraissait flotter à côté de la vidéo Jelly Bricks fournie.

**Correction géométrique, pas simple effet d'éclairage :**

- Chaque brique moulée 1/2/3 cellules, dans les deux orientations, possède maintenant une **véritable cavité sous sa face inférieure**, de profondeur `0,16` et de retrait `0,10` sur le pourtour. Un anneau et une paroi internes raccordent cette poche au maillage d'origine. Le volume se termine par un plafond enfoncé, au lieu d'un grand couvercle parfaitement plat.
- L'écartement vertical passe de `STEP=0,74` à `STEP=0,60` pour toutes les briques du studio, y compris la démonstration de neuf étages. Le sommet du tenon inférieur (`y=0,798`) vient ainsi juste sous le plafond de la cavité supérieure (`y=0,60 + 0,215 = 0,815`). La différence est de `0,017` unité : **le tenon est effectivement encastré dans le volume**, et le vide visible entre deux faces de gel n'est plus que `0,095` unité contre `0,235` auparavant.
- Les ombres de contact des couches élevées sont replacées sous le plafond réel des cavités. Le contact des pièces au sol reste inchangé ; les halos colorés existants sont toujours regroupés en un seul MultiMesh. En mode Photo uniquement, la force des ombres proches des briques est augmentée de 0,35 à 0,44 sur le **même matériau partagé** et rétablie à 0,35 à la fermeture.
- Le cadrage « Vitrine » est légèrement élargi (`photo_zoom=1.0` au lieu de 0,92) pour conserver les trois briques libres dans le portrait malgré la tour plus compacte. Une vérification directe des pixels Mesa OpenGL refuse maintenant les captures où un objet coloré est coupé au bord gauche.
- **Aucune nouvelle texture, passe de rendu, lumière ou physique par frame** : on ajoute des triangles uniquement aux six maillages déjà cachés/mutualisés par taille et orientation.
- **La géométrie des 21 puzzles n'est pas modifiée**, pas plus que les couleurs, commandes tactiles, sauvegardes v1/v2 et règles déterministes de support. Toutes les tours restent à neuf étages maximum, sans migration de données : les positions sont reconstruites à partir du niveau déjà sauvegardé.

Tests automatiques ajoutés : les six géométries ont un plafond de cavité, un anneau décalé et aucune ancienne face plane obturant l'ouverture ; l'emboîtement est testé en valeurs géométriques (jeu de 0,017 autour des tenons, espace entre corps limité). L'intégralité de la CI Godot 4.6, huit captures Mesa OpenGL, navigateur tactile Chromium et export APK Android ARM64 sont requis avant fusion.

**Version Android 0.9.42 / versionCode 39.** L'APK de test peut avoir une identité de signature temporaire : sauvegarder intégralement la progression avant toute désinstallation.

## Android 0.9.52 — profondeur de gel et studio photographique

**Constat issu des véritables captures Mesa OpenGL** : les grandes surfaces moulées de la Vitrine étaient visuellement trop uniformes. Les reflets précédents se concentraient surtout sur les biseaux ; un premier essai de fenêtres latérales restait trop discret pour le cadrage portrait. L'angle quasi frontal (0,06 rad) comprimait également la profondeur perçue des pièces.

- Le shader partagé `shaders/jelly.gdshader` propose désormais `studio_light_card`, réglé à **0** pour les 21 puzzles et les fantômes, **0,88** pour les briques de l'atelier et **1,0** dans la Galerie. La réflexion des fenêtres est calculée à partir du véritable espace local et des normales des faces, puis **teintée par le pigment**. Une large lumière rectangulaire adoucie éclaire aussi les surfaces supérieures `y≈0,56` ; elle évite les tenons plus hauts. Les bases des flancs reçoivent une légère absorption supplémentaire pour rappeler l'épaisseur du gel.
- La référence de **neuf niveaux et douze briques** utilise une pose photographique à **0,34 rad** en trois-quarts, qui laisse apparaître les surfaces latérales, les biseaux et les deux files de tenons. L'utilisateur conserve la possibilité d'orbiter/zoomer librement et retrouve **son angle et son zoom exacts** après la démonstration.
- Les captures de tests `tests/capture.gd` fixent uniquement la caméra photographique pendant la QA afin d'éviter des comparaisons visuelles faussées par la vitesse variable de l'orbite selon le GPU Mesa. La véritable oscillation de la tour reste active entre les deux captures de référence.
- Aucun nouveau maillage, texture, échantillonnage écran, rendu hors-écran, lumière, ombre ou appel de dessin : le nouveau calcul est une **branche uniforme uniquement activée pour le studio**. Les limites de 18 surcouches de vernis et 14 sources d'ombres restent inchangées.
- Godot valide les réglages par mode, la transparence des fantômes, le retour aux valeurs normales en quittant la Galerie, le cadre de la vitrine, les **21 puzzles** et les scènes de **32 briques**. Les captures OpenGL réelles et l'APK Android arm64 sont produits par CI.

**Android 0.9.52 / versionCode 49.** Les captures Mesa apportent une vérification du rendu, mais pas une mesure de FPS, de chauffe ni de batterie sur un appareil Android physique. Ne jamais placer les secrets de signature Android dans le dépôt public.
