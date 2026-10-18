# Références visuelles — règle permanente

**Règle de travail pour tous les projets : chaque photo, vidéo, audio ou autre fichier transmis comme référence est un actif source. L'original doit être sauvegardé durablement sur GitHub, sans recompression, et référencé dans un catalogue traçable.**

Cette règle complète les instructions du jeu ; elle n'autorise jamais à publier des données privées dans un dépôt public. Pour un média sensible, utiliser un dépôt **privé** explicitement autorisé.

## Processus obligatoire à chaque nouvel envoi

1. Identifier le projet et le dépôt cible ; préserver **tous les octets** de l'original (pas seulement un résumé, un montage, une miniature ou un nouvel encodage).
2. Calculer le SHA-256 et la taille du fichier ; conserver le nom d'origine et la date de réception. Dédupliquer selon SHA-256.
3. Archiver le fichier sous `references/media/YYYY-MM-DD/<sha-prefix>-<basename>` via Git, Git LFS ou un asset GitHub Release selon le poids et les contraintes du dépôt. Éviter les fichiers Git de plus de 10 MiB ; pour les gros médias, privilégier Git LFS/release.
4. Écrire un manifeste `references/catalog/YYYY-MM-DD-<id>.json` qui contient la **véritable URL GitHub** de l'original, son hash, sa taille, son rôle, son statut et éventuellement une timeline ou des captures dérivées. Ne pas écrire `archived_on_github=true` avant d'avoir vérifié le blob ou l'asset réel.
5. Vérifier la présence du fichier et idéalement re-télécharger pour confronter son SHA-256. Inscrire la référence canonique dans les documents du projet et l'utiliser pour toute comparaison future.
6. Pour un dépôt public, vérifier que les images/vidéos peuvent légitimement être mises en ligne et qu'elles ne contiennent pas d'éléments personnels ou confidentiels. Dans le doute, ne pas diffuser le fichier ; privilégier un dépôt privé.
7. Si le connecteur GitHub **ne sait pas transférer les données binaires** : conserver immédiatement l'original dans la **ChatGPT Library** (copie intermédiaire durable), écrire un manifeste GitHub avec `github_original_status: "pending_binary_upload"`, créer une tâche de suivi, puis compléter l'upload avec une interface GitHub capable d'envoyer des binaires. **Ne jamais annoncer que la vidéo ou photo complète est sur GitHub tant que ce n'est pas le cas.**

## Outils

Le script local `scripts/archive-reference.py` copie et vérifie les originaux, crée le manifeste et peut committer/pousser les fichiers lorsque le poste dispose de GitHub/Git LFS. Les scripts et les manifestes ne remplacent **pas** le média original.

Les aperçus, keyframes, GIF animés, descriptions de scène et retranscriptions sont **des dérivés**, jamais un substitut à la copie originale.

## Dernière référence Jelly Bricks

Voir `references/catalog/2026-10-18-2824.json`. La vidéo de 13,26 s montre deux rendus côte à côte verticalement, sur fond blanc, avec des briques vivement colorées, une tour qui grandit puis un effondrement. Les noms de modèles et les prix incrustés sont **des annotations de la vidéo comparative**, pas des éléments à reproduire dans l'interface du jeu.

Pour l'ensemble des autres projets : appliquer exactement ce protocole dans le dépôt GitHub du projet concerné, et maintenir un accès réutilisable à la référence originale.
