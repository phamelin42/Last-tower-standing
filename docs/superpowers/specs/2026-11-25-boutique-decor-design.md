# Icônes des offres, décor de l’arène et descriptions — conception

Demande de Phil (25/11/2026) : des images pour les améliorations, de la décoration sur la map, et une passe sur les descriptions, « qui manquent souvent de sens ». Ce document complète le lot 5 (habillage 2D avec Tiny Swords CC0).

## Intention

Une boutique qu’on lit d’un coup d’œil, une arène vivante, dans la direction artistique de Tiny Swords. Le joueur doit savoir, sans deviner, ce que fait une offre avant de l’acheter.

## Objectifs

1. **Une image par offre** : 30 armes et 40 améliorations, dans la boutique, la liste des armes équipées du HUD et le choix du marché noir.
2. **Du décor** autour et dans l’arène, sans jamais gêner la lecture des ennemis.
3. **Des descriptions qui ont du sens** : l’effet exact, avec ses chiffres, et une courte phrase d’ambiance.

## Hors périmètre et à éviter

- Aucune mécanique nouvelle, aucun rééquilibrage.
- **Les textes de la map d’origine ne sont pas repris**, même avec d’autres noms : ils appartiennent à son auteur, et la règle du projet veut des textes originaux. On reprend seulement ce qui les rend utiles (effet exact, chiffre, cumul).
- À éviter : des icônes qui jurent avec Tiny Swords, un décor qui cache un ennemi ou la tour, une description qui contredit les chiffres de `data/`.

## Approches

### Images

- **A. Pack d’icônes pixel art CC0, harmonisé par script (choix de Phil)**. Une image propre à chaque offre. Phil exige que la direction artistique ressemble à celle de Tiny Swords, d’où l’harmonisation décrite plus bas.
- B. Icônes dessinées par script, comme la guêpe : style parfait, mais 70 dessins uniques sont trop longs. Écartée.

### Descriptions

- **Ligne d’effet générée depuis `data/`, phrase d’ambiance écrite à la main (proposée)** : le texte ne peut jamais contredire les chiffres, même après un rééquilibrage.
- Tout écrit à la main : les chiffres dérivent à chaque rééquilibrage. Écartée.
- Reprendre les textes de la map : exclu (voir plus haut).

## Conception

### 1. Icônes des offres

- **Source** : un pack CC0 choisi par Phil. OpenGameArt refuse les requêtes automatiques, donc Phil télécharge l’archive et la dépose dans la session, comme pour Tiny Swords. Le pack est versionné dans `assets/icones/<pack>/` avec un `LICENCE.md` (auteur, URL, licence, date) et crédité dans `CREDITS.md`. Candidats : les packs « idylwilds » (CC0, 32×32) et « 496 pixel art icons » de 7Soul (étiqueté CC0, déclaré domaine public par l’auteur).
- **Harmonisation par script versionné** (`tools/harmoniser_icones.gd`, Godot sans interface) :
  - couleurs ramenées à la palette mesurée dans les feuilles de Tiny Swords ;
  - contour remplacé par la couleur de contour du pack (`#161c2e`, mesurée pour la guêpe) ;
  - agrandissement au plus proche voisin pour que le pixel ait la même taille que celui de l’interface du pack.

  Le script écrit les images harmonisées dans `assets/icones/harmonisees/`, toujours les mêmes octets, et un test les régénère pour le vérifier (même méthode que la guêpe).

- **Correspondance** : un seul fichier dans `visuels/` associe chaque identifiant d’offre à son icône. La simulation ne connaît pas les images. Un test parcourt toutes les offres de `data/` et vérifie que chacune a une icône existante, et que deux offres n’ont pas la même.
- **Cadre** : la couleur du cadre dit le type de dégâts pour une arme, la famille pour une amélioration (dégâts, défense, économie, utilitaire). Le texte dit aussi le type : la couleur ne porte jamais seule l’information.
- **Validation** : une planche des 70 icônes harmonisées, à côté de boutons et rubans de Tiny Swords, relue par Phil avant l’intégration.

### 2. Décor de l’arène

Extension de la tâche T5.2.

- **Hors du cercle d’apparition** : le décor du pack encadre l’arène (arbres animés, rochers, buissons, objets de `Deco/`, maisons, mine d’or, moutons, eau et rochers d’eau en bordure).
- **Dans la zone de marche** : seulement du décor plat, dessiné sous les ennemis (touffes, fleurs, petits cailloux). Jamais un objet qui cache un ennemi, un projectile ou la tour.
- **Disposition** : tirée d’une graine propre à chaque arène, donc différente d’un joueur à l’autre et stable pendant la partie. Le décor est purement visuel, sans effet sur la simulation ni sur le réseau.
- Captures aux trois résolutions, relues, et mesure des images par seconde à 1 000 ennemis, décor compris.

### 3. Descriptions

- Chaque offre garde dans `data/` une **phrase d’ambiance originale** : courte, sans chiffre, en lien avec son nom et son sprite. Les 70 phrases sont réécrites pour être cohérentes avec l’effet, par exemple sans « décuple » pour +20 %.
- Une **fonction pure** (`ui/`) produit la **ligne d’effet** depuis les données. Exemples :
  - arme : « Tranchant · 31 dégâts toutes les 0,8 s · portée 300 · vise le plus proche » ;
  - zone : « zone de 110 », rebond : « rebondit sur 4 ennemis », statut : « ralentit (givre) », « empoisonne : 40 % des dégâts en 5 s » ;
  - amélioration : « +10 % de dégâts tranchants », « +150 PV max », « 1 relance gratuite par manche ».
- Chaque genre d’effet et chaque statistique de `data/` a son modèle. Un test parcourt toutes les offres et vérifie que :
  - aucune ligne n’est vide ;
  - aucun genre n’est sans modèle ;
  - les chiffres affichés sont ceux des données ;
  - la typographie est française (espaces insécables, virgule décimale).
- **Affichage** : sur la carte de la boutique, la ligne d’effet passe en premier et reste toujours visible, la phrase d’ambiance vient dessous. Les tests de mise en page existants restent verts aux quatre résolutions.

## Ordre de travail

- **T5.9 Descriptions** : ne dépend de rien, peut partir tout de suite.
- **T5.2 Terrain et décor** : après T5.1 (arène 2D).
- **T5.8 Icônes** : dès que Phil a déposé le pack.
- T5.4 (interface aux couleurs du pack) affiche les icônes dans son thème.

## Laissé au réalisateur

- Le nombre exact de couleurs de la palette harmonisée.
- La densité du décor, à régler sur les captures.
- La taille des icônes à l’écran, dans le respect des tests de mise en page.
- La formulation des phrases d’ambiance.
