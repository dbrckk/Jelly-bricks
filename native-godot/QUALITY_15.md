# Jelly Bricks — 15 critères de qualité, traçabilité

Ce fichier documente les **critères**. Ne jamais déclarer un critère « terminé »
uniquement parce qu'une compilation réussit. Référence visuelle : les images
archivées de `2824.mp4`. Cible : jeu Android Godot 4.6, rendu Compatibility.

| # | Pilier | Déjà présent | Condition nécessaire avant validation complète |
|---|---|---|---|
| 1 | Optique de gelée | Shader pigment + essai PR #106 | Contrôle visuel multi-angle sur vrai Android ; fidélité non validée |
| 2 | Géométrie moulée | Coque continue + tenons instanciés | Comparaison dimensionnelle et des silhouettes avec la référence |
| 3 | Conservation du volume | Déformation shader à l'impact | Mesurer pénétrations et rebonds sur contacts multiples |
| 4 | Contact et support | Support déterministe + propagation amortie | Contact synchronisé au visuel/audio sur 30/60 FPS |
| 5 | Éclairage | Softboxes procédurales + ombres galerie | Comparaison dynamique sur écrans Android |
| 6 | Performance GPU | MultiMesh + limitations de couches | Profilage Android GPU : coût shader/overdraw/ombres |
| 7 | Performance CPU | Mesh réutilisé, fantôme réutilisé | Profilage allocations et 99e percentile frame-time |
| 8 | Contrôles tactiles | Capture multi-doigts, snap | Test tactile réel : annulation et précision |
| 9 | Game feel | Tweens + sons PCM + haptique | Alignement temporel des impacts sur appareil |
| 10 | Caméra | 3 angles + galerie + cadrage | Tests sur différents ratios d'écran |
| 11 | Feedback de placement | Vert/erreur/snap/undo | Mesurer erreurs de placement sur sessions |
| 12 | Gameplay | 21 niveaux + studio | Difficulté progressive testée auprès de joueurs |
| 13 | Rejouabilité | Atelier libre + galerie | Défis récurrents à définir et tester |
| 14 | Fiabilité | Sauvegarde atomique/backup + tests | Test installation, reprise, migration, mémoire |
| 15 | Publication | CI APK debug + export Android | Signature durable, AAB de production, Play Console |

## Lot technique 0.9.66

- [x] Éviter le calcul du reflet animé réservé au puzzle pour les briques du studio.
- [x] Supprimer le changement d'échelle global du modèle pendant l'atterrissage ;
      la géométrie GPU reste seule responsable du squash.
- [x] Exécuter les tests 21 niveaux et les captures OpenGL (environnement de développement).
- [ ] CI Android et contrôles Web de la branche.
- [ ] Validation esthétique qualitative et mesures de performance sur un vrai Android.

Les tests logiciels garantissent des invariants structurels, pas le photoréalisme,
ni des FPS mesurés sur un téléphone. Ne pas affirmer que les 15 piliers
sont « optimisés à fond » tant que leurs critères respectifs ne sont pas prouvés.
