# Outils libres de dessin et d'animation, sans écran

Éprouvés le 26/11/2026 dans un conteneur cloud (Linux, sans écran ni GPU, proxy à liste blanche).
Tous sont des outils de développement : rien n'entre dans le jeu livré, seul leur résultat (PNG,
planche) est versionné, avec sa ligne dans `CREDITS.md`. Les archives des pages « releases » de
GitHub sont refusées par le proxy ; `git clone` anonyme et `apt-get` passent.

| Outil                          | Licence        | Sert à                                       | Poids   |
| ------------------------------ | -------------- | -------------------------------------------- | ------- |
| Godot (déjà installé)          | MIT            | animer, particules, shaders, capture         | 0       |
| Pixelorama                     | MIT            | éditeur de pixel art ; export par commande   | 24 Mo   |
| LibreSprite                    | GPL-2.0        | fork libre d'Aseprite ; mode batch et JS     | ~320 Mo |
| Inkscape                       | GPL-2.0+       | formes vectorielles (arcs, cercles) vers PNG | ~210 Mo |
| Pillow + NumPy (déjà présents) | MIT-CMU et BSD | prototype rapide d'effet par script Python   | 0       |
| Synfig                         | GPL-2.0+       | animation vectorielle 2D rendue en PNG       | ~10 Mo  |
| Blender                        | GPL-2.0+       | rendu 3D en sprites : sans usage en 2D pur   | ~310 Mo |

## Capture Godot

`tools/capturer.sh res://<scène>` (voir son en-tête). Ce qu'il encapsule :

- `--write-movie` exige un chemin **absolu** dont le dossier existe, sinon aucune image, et
  ignore `--resolution` : les images ont la taille du projet (1152 × 648) ;
- Vulkan logiciel, le moteur de rendu du jeu : `VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json`
  puis `xvfb-run -a godot --path . --rendering-driver vulkan --rendering-method forward_plus` ;
- Compatibility : `--rendering-driver opengl3 --rendering-method gl_compatibility`, plus rapide,
  mais une traînée (`trail_enabled`) fait disparaître toutes les particules du `GPUParticles2D` ;
- `--fixed-fps 30` et `use_fixed_seed` sur chaque émetteur : deux rendus identiques au pixel.

## Pixelorama (MIT, projet Godot 4.7)

Pas de binaire à télécharger : c'est un projet Godot, que le Godot du dépôt fait tourner.

```sh
git clone --depth 1 https://github.com/Orama-Interactive/Pixelorama /tmp/pixelorama
godot --headless --path /tmp/pixelorama --import
godot --headless --path /tmp/pixelorama --quit -- planche.png --export --scale 3 --output x3.png
```

Options d'export : `--spritesheet`, `--frames a-b`, `--tag`, `--json`, `--split-layers`,
`--size`, `--help`. Des erreurs « signal already connected » s'affichent à l'ouverture, sans
effet. Pour Phil : la même application, sur un poste, dessine et anime à la main (dépôt
`Orama-Interactive/Pixelorama`).

## LibreSprite (GPL-2.0)

Ni paquet apt ni binaire accessible : compilation depuis les sources (~5 min sur 4 cœurs).

```sh
apt-get install -y libfreetype6-dev libgif-dev libjpeg-dev libpixman-1-dev libpng-dev \
  libsdl2-dev libsdl2-image-dev libtinyxml2-dev libnode-dev zlib1g-dev libarchive-dev \
  libx11-dev libxi-dev libcurl4-openssl-dev ninja-build
git clone --depth 1 --recurse-submodules https://github.com/LibreSprite/libresprite /tmp/ls
python3 -m venv /tmp/ls-venv && /tmp/ls-venv/bin/pip install cmake   # CMake ≥ 4.1 exigé
mkdir /tmp/ls/build && cd /tmp/ls/build
/tmp/ls-venv/bin/cmake -G Ninja -DCMAKE_BUILD_TYPE=Release .. && ninja libresprite
```

Mode batch, sans Xvfb, avec `export XDG_RUNTIME_DIR=/tmp/xdg` :

- `libresprite -b in.png --scale 2 --save-as x2.png` ;
- `libresprite -b in.png --sheet planche.png --sheet-width 256 --data planche.json` ;
- `libresprite -b --script t.js` : `app.open`, `app.command.NewFrame()`, `sprite.saveAs(chemin)`
  (pas `saveAs(chemin, true)`, qui n'écrit rien) ; API dans `SCRIPTING.md` du dépôt.

## Inkscape (GPL)

```sh
apt-get install -y --no-install-recommends inkscape
inkscape --export-type=png --export-filename=arc.png -w 256 arc.svg
```

Utile pour un arc de coup ou un cercle magique net, ensuite réduit et ramené à la palette.

## Pillow et NumPy

Déjà présents (`python3 -I`). Bon pour prototyper un effet en quelques minutes (arc de 6 images,
explosion de 8 images en 64 × 64, palette extraite des planches du pack). La version qui entre au
dépôt est un `tools/*.gd` typé (API `Image`), qui ne dépend que de Godot.

## Synfig, GIMP, Krita, Blender

Marchent sans écran (`synfig a.sif -t png -o f.png` ; `xvfb-run -a gimp -i -b -` ;
`xvfb-run -a krita --export …`, Krita refuse `QT_QPA_PLATFORM=offscreen` ;
`blender -b -P script.py`), mais n'apportent rien de plus que Godot et Pixelorama pour du pixel art
2D. Synfig demande d'écrire le `.sif` à la main.
