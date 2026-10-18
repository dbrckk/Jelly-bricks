# Jelly Bricks — sauvegarde de l'identité Android

## État des lieux

Ce dépôt est **public**. Les sources, historiques de commits, artefacts et caches GitHub Actions ne doivent jamais contenir de keystore Android, de mot de passe ou de clé de déchiffrement en clair. Une chaîne Base64 n'est **pas** du chiffrement.

GitHub Actions reçoit le keystore de signature stable par les secrets privés `JELLY_ANDROID_KEYSTORE_B64`, `JELLY_ANDROID_KEYSTORE_PASSWORD` et `JELLY_ANDROID_KEYSTORE_ALIAS`. La variable publique `JELLY_ANDROID_CERT_SHA256` verrouille l'identité. Le workflow compare aussi le certificat réel de l'APK à la clé vérifiée.

## Créer l'identité, la protéger et l'enregistrer sur GitHub

Depuis un terminal local Linux/macOS/WSL disposant de Java `keytool`, `gh`, `age`, `tar` et `base64`, dans le dépôt :

```sh
gh auth login
bash scripts/setup-android-signing.sh
```

Le script :
1. Vérifie les droits GitHub et l'absence de secrets existants (pour ne pas tourner accidentellement la clé).
2. Crée **une fois** le keystore privé local (mot de passe de 12 caractères au minimum).
3. Lance `scripts/escrow-android-signing.sh`, qui chiffre un paquet contenant **le keystore, son mot de passe, son alias et l'empreinte SHA-256** avec `age -p -a`. Le logiciel `age` demande une **phrase de récupération indépendante** et peut en générer une forte automatiquement.
4. Dépose **uniquement le fichier chiffré** sur `security/android-signing-recovery.age` via l'API GitHub.
5. Fixe l'empreinte publique et configure les trois secrets GitHub Actions. La compilation régulière sur `main` peut alors réutiliser la même identité pour chaque nouvelle version Android.

La phrase `age` doit être conservée dans un gestionnaire de mots de passe ou dans un coffre hors ligne fiable ; **elle n'est pas et ne doit pas être dans GitHub**. Toute personne disposant de l'archive ET de la phrase de déchiffrement pourrait signer une application au nom de Jelly Bricks. Le fichier chiffré est public, donc une phrase de récupération courte ou réutilisée serait dangereuse. Le keystore et son mot de passe doivent également être sauvegardés hors ligne indépendamment.

## Reconstituer l'identité depuis une nouvelle machine

```sh
gh auth login
bash scripts/recover-android-signing.sh
```

Le script télécharge `security/android-signing-recovery.age`, demande la phrase `age`, récupère le keystore **localement**, puis compare l'empreinte à celle enregistrée dans GitHub. Il **ne remplace jamais** une clé locale ou des secrets GitHub déjà existants. Si les trois secrets ont disparu, il peut les reconstituer à partir du paquet, toujours avec la même clé privée. En cas de configuration GitHub partielle, il s'arrête afin d'éviter toute rotation accidentelle.

## Limitations importantes

- **La configuration doit être lancée dans le terminal d'une machine de confiance, avec une session GitHub authentifiée.** L'intégration GitHub de l'assistant peut modifier le code, mais ne possède pas les permissions d'écriture sur les secrets GitHub Actions. Un agent ne peut pas déchiffrer ce fichier public sans la phrase de récupération privée.
- **Ne pas réinstaller sans avoir exporté les sauvegardes du jeu.** Les APK signés avec les anciennes clés debug éphémères ne peuvent pas être mis à jour avec un certificat différent.
- **Ne pas générer une deuxième identité** pour le même package Android. Le contrôle SHA-256 empêche sa publication si la signature est incompatible.
- Cette clé sert uniquement à la **distribution de tests debug Android**, pas à une publication Google Play avec clé release.
- Une perte simultanée de l'archive GitHub, de la sauvegarde hors ligne et de la phrase de récupération peut rendre l'identité définitivement irrécupérable.

**État actuellement vérifié dans le dépôt :** le code du processus de sauvegarde et récupération est versionné ; aucune identité privée n'a été déposée dans GitHub depuis cette conversation. Le fichier `security/android-signing-recovery.age` n'apparaîtra qu'après exécution volontaire du script sur la machine du propriétaire.
