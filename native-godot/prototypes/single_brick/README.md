# Jelly Bricks — prototype optique isolé, itération 1

**État : prototype de recherche ; non validé visuellement et NON intégré au jeu Android.**

## Pourquoi

Le rendu précédent de la brique de studio montrait une face inférieure / cavité à travers le dessus ; modifier uniquement le shader empirait la perception. Une inspection de la géométrie produite par `GEL.build_studio(2, 0)` a confirmé un sens de winding incompatible avec le culling de cette étude. L'étude corrige les indices sur sa propre copie de maillage, sans toucher au code de production.

## Réalisations reproductibles

- Une brique 2×1 avec quatre tenons et une cavité inférieure, issue des fonctions réelles de `gel_mesh.gd`.
- Shader expérimental `wet_gel.gdshader` (cœur dense pigmenté) et vernis `wet_coat.gdshader` (une passe additionnelle réservée à ce prototype).
- Reflet étroit sur le biseau et transmission pigmentée au support via `contact.gdshader`.
- Pose et relâchement sur un cycle déterministe : repos, élévation, vol, compression latérale, détente amortie. Le déplacement ne modifie pas de sauvegarde.
- Caméra orbitale au doigt et déclenchement d'une nouvelle animation au toucher/clic.
- Cinq captures Godot OpenGL de phases fixes via `capture.gd`.

## Reproduction

Depuis la racine du dépôt avec Godot 4.6 installé :

```bash
godot --headless --path native-godot --editor --import --quit
godot --path native-godot --scene res://prototypes/single_brick/interactive.tscn
mkdir -p build/single-brick
xvfb-run -a godot --path native-godot --rendering-driver opengl3 --resolution 720x1280 --script res://prototypes/single_brick/capture.gd
```

Les captures sont enregistrées dans `build/single-brick/{01-rest,02-flight,03-impact,04-rebound,05-settled}.png`. Elles sont calculées par le moteur réel, pas par un générateur d'images.

## Résultat observé et limitations

Le dessus et les flancs apparaissent désormais comme une seule pièce avec des reflets de moulage, sans la grande diagonale noire que produisait la transparence sur la cavité. **Visuellement, cela reste du plastique/vernis**, avec une transmission et une déformation insuffisantes comparées à l'intention du film. Le vernis coûte un draw supplémentaire et doit être profilé avant adoption. La copie de mesh inversée est expérimentale : les indices d'origine et le culling de la géométrie complète (dessus, cavité, plots) doivent être audités avant toute modification du générateur de production.

La vidéo originale `2824.mp4` ne se trouve pas dans le dépôt ; comparer avec la description dans `docs/JELLY_VISUAL_REFERENCE.md` ne constitue **pas** une comparaison frame-by-frame. Aucun pixel-perfect match n'est revendiqué.

**Go/no-go :** faire approuver une matière jugée gélatineuse à partir des captures de la scène (et du film retrouvé) avant d'intégrer au jeu ou d'envisager le Play Store.
