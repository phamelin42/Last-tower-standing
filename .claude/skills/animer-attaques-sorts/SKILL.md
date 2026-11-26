---
name: animer-attaques-sorts
description: >
  Concevoir, améliorer et vérifier à l'œil les animations de combat de last-tower-standing :
  attaques, tirs, projectiles, impacts, explosions, sorts, effets de statut, particules, flash de
  dégâts, secousse, gel d'impact (hit-stop), sprites d'effets. À utiliser dès qu'une demande touche
  au rendu d'un coup ou d'un sort, même formulée vaguement (« c'est moche », « plus de punch »,
  « on ne voit pas qui tape », « les sorts sont fades »), et avant de modifier `visuels/effets.gd`.
---

# Animer attaques et sorts

Un bon effet de combat se lit au premier coup d'œil dans une arène pleine, donne du poids au coup,
et ne change jamais le temps de jeu. Les chiffres ci-dessous sont des ordres de grandeur sourcés,
pas des normes : on les ajuste à l'œil, sur une capture. Sources complètes et limites :
`docs/skills-claude/animation-et-vfx.md`.

## Où vit le rendu

- `visuels/effets.gd` : tirs, impacts, anneaux, traits, explosions, objets au sol, dans un pool
  plafonné (`PLAFOND`). Chaque type de dégâts a sa **forme** (on le reconnaît sans la couleur, qui
  ne fait que la souligner) et aucun effet n'est opaque (`ALPHA_MAX`) : la tour reste lisible.
  Ces trois garanties sont testées ; un nouvel effet les respecte.
- `visuels/apparence.gd` (entité vers sprites), `visuels/interpolation.gd` (positions lissées entre
  deux vues d'arène), `visuels/teinte_tour.gdshader`. Planches du pack : `assets/tiny_swords/`
  (crédits dans `CREDITS.md`).
- Un effet naît d'un événement d'arène (`VueArene.evenements`, clés `genre` et `statut`). `visuels/`
  lit l'état ; il n'écrit jamais dans `sim/` et ne retarde rien côté réseau.

## Méthode

1. **Capture avant.** Lance `tools/capturer.sh res://tools/vitrines/vitrine_effets.tscn`, qui
   rejoue en boucle chaque effet de `Effets` (une ligne par type de dégâts, une colonne par genre),
   ou une vitrine propre à l'effet sous `tools/vitrines/` (particules à graine fixe), puis regarde
   `planche.png` avec l'outil Read. Fini quand tu sais nommer, avec les mots de la
   section suivante, ce qui manque : anticipation absente, impact mou, dissipation trop longue,
   effet illisible dans la foule, couleur seule pour porter le type.
2. **Fiche de l'effet.** Avant de coder, écris en commentaire ou dans la PR les phases et leurs
   durées en images à 60 i/s (anticipation, contact, récupération pour une attaque ; anticipation,
   impact, dissipation pour un sort), le palier d'importance, le nombre de particules et la teinte
   dominante. Fini quand chaque phase a une durée chiffrée.
3. **Test d'abord** (skill `tdd`, lanceur `tests/lanceur.gd`) pour ce qui se vérifie sans les yeux :
   durée totale, plafond de particules ou de flashs, une forme par type, gel qui ne touche ni
   `Engine.time_scale` ni `sim/`, variante « mouvement réduit » si le réglage existe.
4. **Implémentation** dans `visuels/`, en GDScript typé, durées et quantités en constantes
   nommées. Skills d'API : `godot-animation`, `particles-vfx`, `godot-shaders`,
   `shader-programming`, `game-feel` (son hit-stop se remplace par le gel visuel ci-dessous).
5. **Capture après**, même scène, mêmes options. Compare les deux planches image par image. Fini
   quand chaque phase de la fiche se voit sur la planche et que l'effet reste lisible au milieu des
   autres. Pour un regard neuf : deux sous-agents notent la planche sans voir le code, on garde la
   note la plus basse.
6. `tools/verifier.sh` vert. Envoie les planches avant et après à Phil (`SendUserFile`) : le
   ressenti final se juge sur un vrai écran, et la PR dit « non vérifié sur un vrai écran » tant
   qu'il ne l'a pas vu. Les captures restent hors du dépôt.

## Principes

**Attaque : lente, puis brève.** Anticipation lisible, contact en une ou deux images, récupération
qui revient au repos. Ralentir l'anticipation et accélérer l'action améliore plus qu'ajouter des
images. Pixel art : 3 images au minimum, 5 en standard, 6 à 8 pour un coup soigné, à 10-12 i/s ;
une image de traînée (smear) au contact ; réaction de la cible en 2 ou 3 images. L'effet sur la
cible part quand le coup arrive, jamais au déclenchement ; un projectile retarde l'impact de son
temps de vol.

**Sort : trois phases.** Anticipation (charge, cercle, aspiration), impact (le pic, atteint dans le
premier quart de la durée de vie de l'effet), dissipation (fumée, braises, érosion). Si l'effet
paraît long, il l'est beaucoup trop. Hiérarchie : d'abord l'information de jeu (où, qui, quelle
zone), ensuite la saveur. Taille proportionnelle à l'importance, une teinte dominante, le bord
d'attaque le plus clair, les valeurs les plus hautes réservées au flash d'impact. La zone dessinée
est exactement la zone touchée : un cercle plus grand ou plus petit que la vraie portée est une
faute de lisibilité grave. Un projectile montre sa direction même immobile.

**Paliers d'importance.** L'arène affiche des centaines d'unités : un coup courant reste discret
(pas de gel ni de secousse, quelques particules), un coup moyen gèle 40 à 60 ms avec 6 à 12
particules et un flash, un coup fort ou un sort majeur gèle 100 à 150 ms avec 20 à 40 particules
et une secousse. Le palier se déduit de l'événement (dégâts, type, arme), pas du hasard. Plafonne le
total à l'écran : au-delà, on garde les effets les plus importants.

**Gel d'impact (hit-stop) : purement visuel.** Suspendre l'animation, les tweens et
l'interpolation de l'attaquant et de la cible dans `visuels/` pendant le gel, puis reprendre.
La simulation à 20 Hz (un pas = 50 ms) et le réseau continuent : aucun `Engine.time_scale`,
aucune écriture dans `sim/`. Un gel de 50 ms vaut un pas de simulation ; au-delà de 150 ms,
l'unité gelée saute à sa vraie position à la reprise.

**Flash et secousse.** Flash de dégâts : blanc ou teinte claire pendant 1 à 3 images (50 à 67 ms),
par shader `canvas_item` ou `modulate`, puis retour. Secousse de caméra par « trauma » (amplitude =
trauma², décroissance rapide), réservée aux paliers forts. Au plus trois flashs par seconde dans
une même zone de l'écran (WCAG 2.3.1) : plafonne les flashs blancs simultanés. Un réglage
« mouvement réduit » remplace flash et secousse par une teinte fixe (WCAG 2.3.3) ; s'il n'existe
pas encore, propose-le à Phil au lieu de l'inventer.

**Style Tiny Swords.** Les planches restent en `TEXTURE_FILTER_NEAREST` (pixels nets, comme
l'arène dans `visuels/arene_2d.gd`), palette du pack, contour sombre comme les unités, pas de
dégradé lisse ni de lueur floue qui jure avec le pixel art. Réutilise d'abord les planches
d'effets du pack (`assets/tiny_swords/Effects/`).

## Outils, tous libres

- **Godot** (MIT), déjà là : `AnimatedSprite2D` et `SpriteFrames`, `AnimationPlayer`, `Tween`,
  `CPUParticles2D` et `GPUParticles2D` en salve unique (`one_shot`, relancée par `restart()`, pas
  par `emitting = true`), shaders `canvas_item`.
- **Capture** : `tools/capturer.sh` rend la scène sous un écran virtuel, en Vulkan logiciel avec le
  moteur de rendu du jeu (Forward+), et assemble la planche. `--compat` est plus rapide, mais en
  Compatibility un `GPUParticles2D` à traînée perd TOUTES ses particules. Les images sortent à la
  taille du projet (`--write-movie` ignore `--resolution` ; `--taille` réduit après coup) ; ce qui
  suit `--` va au jeu. Une cadence fixe et des particules à graine fixe (`use_fixed_seed`, `seed`)
  donnent des images identiques d'un rendu à l'autre : une différence entre deux captures vient
  alors de ton changement, pas du hasard ni de l'horloge.
- **Sprites d'effets générés** : un script `tools/*.gd` typé (API `Image` de Godot, comme
  `tools/composer_images_offres.gd`) qui dessine l'effet sur la palette du pack et écrit la planche
  PNG ; il se relance partout où Godot tourne. Le PNG produit est une création du projet : une
  ligne dans `CREDITS.md`.
- **Dessin à la main, logiciels libres** : Pixelorama (MIT), LibreSprite (GPL-2.0, fork libre
  d'Aseprite), Inkscape (GPL) pour des formes vectorielles. Installation et commandes sans écran
  éprouvées dans ce conteneur : `references/outils-libres.md`.
- Écartés : Aseprite (licence propriétaire), générateurs d'images par IA (services payants, licence
  des sorties incertaine), addons de « juice » tiers (dépendance d'exécution, qui demande un ADR ;
  quelques lignes dans `visuels/` suffisent). Un pack d'effets CC0 n'entre qu'avec l'accord de
  Phil, licence relue et crédit dans `CREDITS.md`.
