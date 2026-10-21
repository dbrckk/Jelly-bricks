# Référence vidéo d'origine — Jelly Bricks

Le fichier `2824-original.mp4` est **l'original binaire non modifié** transmis comme référence artistique le 18 octobre 2026. Il a été récupéré dans la bibliothèque du projet `/Jelly-bricks/references/2026-10-18-2824-original.mp4` le 22 octobre 2026, puis son SHA-256 a été contrôlé avant archivage Git.

- Taille : 2 305 045 octets
- Durée : 13,258594 secondes
- Codec : H.264 + AAC ; 1008 × 1280 ; 30 images/s
- SHA-256 : `e7423f103b11678e2f2bbc8224562c67b3924079c7f262def81d90723b971ef4`
- Git blob SHA-1 : `9563f0dde2d725642d339a4108b941a38508d6d4`

Les fichiers `2824-contact-sheet.png`, `2824-stack.jpg` et `2824-collapse.jpg` sont des images extraites de la même vidéo, conservées pour consulter rapidement les repères visuels. **Toujours utiliser le MP4 comme source de vérité** pour les mouvements, les angles et la matière.

La capture présente **deux rendus en comparaison verticale**, avec sur la moitié supérieure des briques à surface plus brillante. Ne pas reproduire les marques d'IA, tarifs, logos ni menus de la capture : seuls les matériaux, formes, empilements et réactions des briques constituent la référence visuelle.

## Contrôle local de l'original

```bash
sha256sum reference-media/2824-original.mp4
ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,r_frame_rate -of json reference-media/2824-original.mp4
```

L'archive est conservée directement en Git (2,3 Mo, pas de LFS requis). Elle ne doit pas être remplacée par un lien vers un chat, par une miniature ou par un réencodage. En cas de déplacement, maintenir cette empreinte de référence. La publication et redistribution éventuelles du film doivent respecter les droits applicables.
