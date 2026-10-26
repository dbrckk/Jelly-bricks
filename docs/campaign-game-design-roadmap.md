# Jelly Bricks — direction produit et plan vers une V1 publiable

**Mise à jour : 26 octobre 2026.** Mode défis Godot natif, en plus du Studio libre et des 21 puzzles classiques. Les éléments « implémentés » correspondent à la PR #133 ; leur sortie stable dépend des workflows et de la validation Android réelle.

## Positionnement / boucle de jeu

**Promesse :** construire une sculpture de gelée 3D pour reproduire un modèle visuel, puis ressentir l'impact de la matière à chaque brique. Une session doit pouvoir durer 2–5 minutes sans publicité obligatoire.

1. **Voir** le nom et la miniature 6×6 colorée d'un modèle. Pour les niveaux en relief, inspecter chaque couche depuis le bouton « Hauteur ».
2. **Choisir** une couleur, une longueur (1/2/3) et une orientation. Placer librement avec le doigt.
3. **Comparer** en direct les cases correctes, les cases incorrectes et le volume à construire. Undo sans recharger les 31 autres briques.
4. **Terminer** en reproduisant toutes les cellules 3D (coordonnées, hauteur, teinte). Une répartition en briques différente de celle de l'auteur est autorisée.
5. **Récolter** des points, des étoiles, des XP, un rang et le déblocage du modèle suivant. Copier ou partager le résultat depuis la feuille native Android.
6. **Rejouer** pour améliorer le record et atteindre trois étoiles, mais sans gagner indéfiniment des XP sur le même modèle.

## V1 : 20 niveaux de difficultés progressives

| Monde | Niveaux | Modèles | Compétence |
| --- | --- | --- | --- |
| Initiation | 1–4 | Cœur, flèche, fleur, étoile | Orientation, correspondance des couleurs, assemblage plat |
| Faune simple | 5–8 | Poisson, papillon, tortue, canard | Reconnaître une silhouette colorée, économiser les briques |
| Animaux en relief | 9–12 | Lapin, grenouille, crabe, chat | Gérer la deuxième couche, détails d'yeux/oreilles |
| Animaux experts | 13–16 | Hibou, pingouin, renard, ours | Plusieurs couleurs, emboîtements, précision |
| Créations maîtres | 17–20 | Éléphant, fusée, château, dragon | Formes denses, relief et optimisation du score |

Les 20 niveaux sont des assemblages conçus pour la grille physique native 6×6 et le cap de 32 briques. Les niveaux s'ouvrent successivement, pas par achat. La maquette du modèle est une **projection 2D par couche** de la sculpture 3D ; une vraie miniature 3D est une amélioration d'interface future.

## Règles de victoire et progression

- **Victoire** : toutes les cellules 3D attendues correspondent, par coordonnées et couleur, sans cellule superflue. Le joueur choisit librement ses pièces et l'ordre des opérations.
- **Score** : base 600, +150 par niveau de difficulté, bonus d'efficacité 65 par brique économisée par rapport au montage de référence, bonus temps décroissant à 0 après 100 s, bonus annulations et étoiles.
- **Étoiles** : 1 pour terminer ; 2 pour une construction dans une marge de deux briques par rapport au montage de référence ; 3 pour atteindre le par avec 0–1 annulation.
- **XP** : 40 + 20 × difficulté + 25 × étoiles au premier succès du niveau. Une répétition peut améliorer les points/étoiles mais ne génère plus d'XP.
- **Rang** : `floor(sqrt(XP / 100)) + 1`, progression sans serveur ni inscription.
- **Sauvegarde** : un brouillon par niveau, indépendant de l'empilage libre ; records et XP stockés séparément avec contrôle de structure et sauvegarde secondaire.
- **Partage** : texte de réussite avec nom du modèle, points, étoiles, XP et #JellyBricks ; Intent Android `ACTION_SEND` et repli presse-papiers. Pas de collecte d'amis ni permission réseau supplémentaire.

## Priorités des prochaines versions

| Priorité | Chantier | Définition de « terminé » |
| --- | --- | --- |
| P0 | Vérifier la V1 sur Redmi Android 15 | 20 modèles testés avec les doigts ; rotation/touches lisibles, aucune perte de sauvegarde, 30+ FPS visés en scène dense ; test réel nécessaire |
| P0 | Onboarding 45 secondes | Tutoriel interactif : choisir, tourner, poser, repérer une erreur, annuler et basculer de couche |
| P0 | Accessibilité du modèle | Modèle agrandissable, aperçu 3D indépendant et rotation sans toucher au placement, légende de hauteurs |
| P1 | Victoire émotionnelle | Animation courte et spectaculaire de la sculpture terminée, score + étoiles animées, photo au bon angle |
| P1 | Partage visuel | Créer une carte de réussite image PNG avec modèle, photo de sculpture, étoiles, score et niveau ; partager via `FileProvider` Android |
| P1 | Progression de campagne | Carte de 4 mondes, galerie des 20 sculptures gagnées, médailles pour records et collections de modèles |
| P1 | Aide non intrusive | Bouton « indice » visualisant quelques cases manquantes ; coût uniquement en bonus de score, jamais de blocage |
| P1 | Qualité sonore / tactile | Signatures Jelly par matériau, haptique douce aux impacts, musique/ambiance personnalisable |
| P2 | Défis renouvelables | Défi du jour déterministe et hors ligne, récompense cosmétique ; aucune obligation de connexion |
| P2 | Éditeur communautaire | Publication de plans contrôlés (36 cases × niveaux), import/export de codes lisibles, validation du support avant diffusion |
| P2 | Cosmétiques éthiques | Couleurs, gelées, podiums et particules gagnables ; publicité récompensée facultative et achat unique 2 € de retrait des pubs si monétisation activée |
| P3 | Compétition optionnelle | Classements sécurisés par modèle seulement après anti-triche, protection des données et contrôle des coûts |

## Mesurer la qualité du jeu

- **Activation** : part des joueurs qui terminent le premier défi à la première session.
- **Apprentissage** : taux d'abandon du tutoriel et nombre d'erreurs de couleur/hauteur par niveau.
- **Difficulté** : temps médian, nombre de pièces, taux de victoire, Undo et distribution 1/2/3 étoiles par niveau.
- **Rétention** : envie de terminer l'animal suivant, retour à J+1/J+7 ; mesurer uniquement avec consentement si analytique distante un jour.
- **Performance** : temps de frame, FPS P10, température batterie du Redmi dans une pile de 32 briques ; les captures Mesa CI ne mesurent pas le GPU Android.
- **Respect du joueur** : sauvegarde localement d'abord, jamais de publicité imposée après une victoire, pas de difficulté artificiellement bloquante pour inciter à payer.

## Critères avant Google Play

APK/AAB de publication signé de façon persistante, tests sur Android 15/Redmi, notification des données collectées, classement de contenu, page Play Store, captures réelles, icône, description, consentements le cas échéant, conservation des progressions et absence de crash sur chacun des 20 défis. Les scores ne prétendent pas être comparables en ligne tant qu'ils sont purement locaux.
