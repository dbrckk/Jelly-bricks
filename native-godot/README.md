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
