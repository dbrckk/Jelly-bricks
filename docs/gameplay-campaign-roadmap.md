# Jelly Bricks — Feuille de route jeu complet (27 octobre 2026)

## Vision
Le joueur assemble de vraies briques 3D en gelée pour reproduire une silhouette colorée. Une figure terminée doit procurer un résultat immédiatement lisible, une animation de récompense, une raison de poursuivre et une réalisation partageable. L'atelier libre et les 21 puzzles historiques restent disponibles.

## Livré dans cette branche — première campagne jouable
- 20 figures dessinées à la main sur une grille 6 × 6 : cœur, fleur, étoile, poisson, papillon, maison, arbre, chat, soleil, tortue, fusée, lapin, champignon, oiseau, couronne, renard, grenouille, pingouin, dragon, licorne.
- Bouton Défis dans l'atelier 3D, bouton Voir modèle coloré, validation exacte des couleurs et positions de chaque case, progression 1→20, passage au suivant après réussite.
- Calcul déterministe des points et XP, étoiles liées au nombre de briques, premier succès récompensé, meilleur score conservé, impossibilité de gagner des XP à l'infini en rejouant le même niveau.
- Sauvegarde locale séparée de l'atelier libre. Aucun compte ni réseau obligatoire.
- Le joueur peut utiliser Photo pour cadrer sa réalisation avant de passer au niveau suivant.

## P0 — Fiabilité et lisibilité avant publication
1. **Corriger et valider sur Android physique** : taille réelle des boutons, sécurité des sauvegardes, 20 figures terminables avec les outils Petit/Moyen/Long, fluidité sur Redmi 15 5G.
2. **Rendre le modèle visible pendant le placement** : miniature épinglable, grille 6 × 6 orientée comme la caméra, indicateurs de cases correctes/erronées sans révéler les solutions.
3. **Séparer les parties en cours par niveau** : autosave atomique de la construction défi, retour après fermeture, possibilité de reprendre chaque figure, sans modifier l'atelier libre.
4. **Corriger la progression** : fin de campagne, étoiles persistantes, historique des records, synchronisation éventuelle volontaire.
5. **Améliorer le retour de réussite** : animation Jelly de victoire, son distinct, fiche de récompense lisible et bouton Suite.

## P1 — Progression et plaisir de rejouer
- **Barème cible** : base 100 + 25 × niveau, bonus d'efficacité, 1–3 étoiles. Premier succès donne 35 + 10 × niveau XP ; rejouer ne donne que l'amélioration du meilleur score. Aucun achat ne doit permettre d'acheter le classement.
- **Paliers XP** : novice (0), apprenti (250), sculpteur (750), maître gelée (1 750), artiste (3 500). Déblocages cosmétiques uniquement.
- **3 difficultés** : 1–6 faciles (5–15 cases), 7–13 intermédiaires (15–24), 14–20 avancées (24–32) ; revoir les figures et le nombre minimal de briques selon les mesures de réussite.
- **Défis bonus** : limite de briques, palette réduite, reproduire sans zoom, construction en hauteur, chronomètre facultatif. Éviter les objectifs contradictoires avec le jeu relaxant.
- **Collection** : galerie des figures obtenues, médailles, historique, progression sur 20.

## P2 — Partage et découverte
- **Photo de réussite** : capture native propre sans interface, silhouette + nom + étoiles + score + signature Jelly Bricks. Export PNG local via l'API Android et partage natif vers Instagram/WhatsApp/TikTok, sans compte serveur.
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
