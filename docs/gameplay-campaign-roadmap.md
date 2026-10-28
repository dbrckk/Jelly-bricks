# Jelly Bricks — Feuille de route jeu complet (27 octobre 2026)

## Vision
Le joueur assemble de vraies briques 3D en gelée pour reproduire une silhouette colorée. Une figure terminée doit procurer un résultat immédiatement lisible, une animation de récompense, une raison de poursuivre et une réalisation partageable. L'atelier libre et les 21 puzzles historiques restent disponibles.

## Livré sur main — campagne et collection de 20 défis (PR #134 à #136)
- 20 figures dessinées à la main sur une grille 6 × 6 : cœur, fleur, étoile, poisson, papillon, maison, arbre, chat, soleil, tortue, fusée, lapin, champignon, oiseau, couronne, renard, grenouille, pingouin, dragon, licorne.
- **Campagne 0.10.0 :** boutons Défis, modèle coloré consultable en grand et **miniature 6 × 6 épinglée pendant le jeu**, validation exacte des positions et couleurs, passage au niveau suivant et sélecteur pour revoir tous les niveaux débloqués.
- **Points + XP + étoiles :** score déterministe, étoiles liées au nombre de pièces réellement atteignable pour chaque modèle (par horizontal ou vertical), récompense XP unique par première victoire, amélioration des records sans farming et résultats copiables vers les réseaux.
- **Reprise hors ligne :** sauvegarde de chaque construction après pose, annulation, effacement ou changement de niveau ; point de reprise mémorisé ; écriture temporaire et copie de secours ; aucune intervention sur les fichiers de l'atelier libre.
- **Succès :** fenêtre récapitulant étoiles/points/XP, partage de texte via le Sharesheet Android si disponible (repli presse-papiers), bouton Photo pour accéder à la sculpture terminée, bouton Continuer.
- **Collection :** 20 figures/60 étoiles, meilleurs scores, cinq rangs de maîtrise ; liste défilable sur Android. Tous les rangs sont atteignables avec les premières victoires sans répétitions.
- **Aide :** refus immédiat des mauvaises couleurs, positions hors modèle et superpositions dans les défis ; indice facultatif qui prévisualise une brique légale sans auto-placement.
- **Identité de version :** Android et interface affichent 0.10.0 / code 66, prêt à tester comme version de campagne, sans prétendre à une publication Play Store.

## P0 — Fiabilité et lisibilité avant publication
1. **À valider sur Android physique** : taille réelle de la nouvelle rangée de boutons/miniature, sauvegardes, fluidité des 20 niveaux sur Redmi 15 5G.
2. **Miniature et progression de construction — livrées** : mini-modèle coloré toujours visible, 20 figures sélectionnables selon les déblocages, indication des cases correctes. À améliorer : orientation selon la caméra et repérage explicite des cases erronées.
3. **Sauvegarde des niveaux en cours — livrée** : checkpoint transactionnel à chaque modification et récupération du dernier état sain, indépendamment de l'atelier libre. À améliorer : interface des parties commencées.
4. **Récompenses et records — livrés** : points, XP anti-farming, 3 étoiles atteignables, tableau personnel par niveau. À améliorer : succès spéciaux, historique de temps et vérification finale de l'achèvement 20/20.
5. **Retour de réussite — partiellement livré** : fenêtre avec étoiles, points, XP, Sharesheet texte Android et photo 3D. En PR #137 : export de capture PNG réelle via sélecteur SAF. À faire : animation de célébration, carte d'image contenant score/étoiles, partage direct d'une image via URI Android.

## P1 — Progression et plaisir de rejouer
- **Barème cible** : base 100 + 25 × niveau, bonus d'efficacité, 1–3 étoiles. Premier succès donne 35 + 15 × niveau XP (3 850 XP cumulés sur 20 défis) ; rejouer ne donne que l'amélioration du meilleur score. Aucun achat ne doit permettre d'acheter le classement.
- **Paliers XP** : novice (0), apprenti (250), sculpteur (750), maître gelée (1 750), artiste (3 500). Déblocages cosmétiques uniquement.
- **3 difficultés** : 1–6 faciles (5–15 cases), 7–13 intermédiaires (15–24), 14–20 avancées (24–32) ; revoir les figures et le nombre minimal de briques selon les mesures de réussite.
- **Défis bonus** : limite de briques, palette réduite, reproduire sans zoom, construction en hauteur, chronomètre facultatif. Éviter les objectifs contradictoires avec le jeu relaxant.
- **Collection** : galerie des figures obtenues, médailles, historique, progression sur 20.

## P2 — Partage et découverte
- **Photo de réussite** : capture native propre sans interface 3D via PR #137 (SAF ; test sur téléphone requis). Prochaine étape : carte PNG avec nom, étoiles, score et marque Jelly Bricks ; partage direct d'image via FileProvider Android, sans hébergement ni compte.
- **Carte de défi** : code/seed local reproductible à envoyer à un ami, lien profond vers le niveau si l'app est installée.
- **Succès Android** : intégration Play Games Services optionnelle seulement après validation de confidentialité, consentement et fonctionnement hors ligne.
- **Classement** : records personnels hors ligne d'abord ; leaderboard public uniquement avec anti-triche et infrastructure financée, jamais afficher un classement fictif.

## P3 — Qualité premium
- Figures véritablement **volumétriques** (hauteur et silhouette en 3D), animaux plus reconnaissables avec détails de museau/ailes/yeux, cibles de 3–6 étages ; ne pas se limiter à la mosaïque au sol.
- Gelée : fusion optique entre volumes, interfaces de contact, déformation volumique plus crédible, reflets calibrés, 30/60 FPS selon GPU.
- Direction artistique : menus compacts, palette lisible, vibrations légères réglables, musique originale agréable en boucle, sons Jelly non fatigants.
- Accessibilité : tailles de texte et contraste, alternatives aux couleurs seules, désactivation des effets intenses.
- Publication : icône, captures réelles, politique de confidentialité, consentement pub, Android App Bundle signé, suivi des plantages.

## Critères de sortie
- 20/20 modèles validés automatiquement et réalisables, 20/20 finissables sur vrai téléphone.
- Aucune régression des 21 puzzles ni de l'atelier libre.
- Pas de perte de sauvegarde, pas de XP dupliquée, score déterministe, résultat reproductible.
- Pas de publicité forcée pendant un défi ; aucune fonctionnalité essentielle derrière un paiement.
