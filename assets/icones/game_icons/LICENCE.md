# Licence des icônes de repères d'arme (`assets/icones/game_icons/`)

Les 28 icônes de ce dossier viennent de game-icons.net, dépôt `game-icons/icons` (commit
`82d948812bfe3f269ef8f731dcdb07b08160edc4`, 23/04/2026). La licence est lue dans le `license.txt` du dépôt :
« Icons provided under the Creative Commons 3.0 BY or CC0 if mentioned below » ; Lorc et Delapouite ne sont pas
dans la liste CC0, donc **CC BY 3.0** (https://creativecommons.org/licenses/by/3.0/deed.fr). Le crédit des auteurs
est dû dans `CREDITS.md`.

Chaque fichier est la source SVG, **sans son fond noir**, rastérisée en blanc sur transparent à 32 px par
`tools/preparer_icones_offres.gd` (liste dans `tools/icones_offres.json`) ; le jeu les teinte. Aucun dessin n'est
retouché. Le choix de chaque icône pour chaque valeur est dans `data/assets.json` (section `icones_offre`).

| Fichier               | Usage          | Valeur                | Auteur     | Page                                                       |
| --------------------- | -------------- | --------------------- | ---------- | ---------------------------------------------------------- |
| `broadsword.png`      | type de dégâts | `tranchant`           | Lorc       | https://game-icons.net/1x1/lorc/broadsword.html            |
| `arrowhead.png`       | type de dégâts | `perçant`             | Lorc       | https://game-icons.net/1x1/lorc/arrowhead.html             |
| `magic-swirl.png`     | type de dégâts | `magique`             | Lorc       | https://game-icons.net/1x1/lorc/magic-swirl.html           |
| `trebuchet.png`       | type de dégâts | `siège`               | Delapouite | https://game-icons.net/1x1/delapouite/trebuchet.html       |
| `vortex.png`          | type de dégâts | `chaos`               | Lorc       | https://game-icons.net/1x1/lorc/vortex.html                |
| `crosshair.png`       | mécanique      | `cible_unique`        | Delapouite | https://game-icons.net/1x1/delapouite/crosshair.html       |
| `explosion-rays.png`  | mécanique      | `zone`                | Lorc       | https://game-icons.net/1x1/lorc/explosion-rays.html        |
| `bouncing-sword.png`  | mécanique      | `rebond`              | Lorc       | https://game-icons.net/1x1/lorc/bouncing-sword.html        |
| `aura.png`            | mécanique      | `aura`                | Lorc       | https://game-icons.net/1x1/lorc/aura.html                  |
| `sonic-boom.png`      | mécanique      | `onde`                | Lorc       | https://game-icons.net/1x1/lorc/sonic-boom.html            |
| `arrow-cluster.png`   | mécanique      | `barrage`             | Lorc       | https://game-icons.net/1x1/lorc/arrow-cluster.html         |
| `mantrap.png`         | mécanique      | `piege`               | Lorc       | https://game-icons.net/1x1/lorc/mantrap.html               |
| `land-mine.png`       | mécanique      | `mine`                | Lorc       | https://game-icons.net/1x1/lorc/land-mine.html             |
| `spinning-blades.png` | mécanique      | `tournant`            | Lorc       | https://game-icons.net/1x1/lorc/spinning-blades.html       |
| `circle-cage.png`     | mécanique      | `zone_posee`          | Lorc       | https://game-icons.net/1x1/lorc/circle-cage.html           |
| `falling-bomb.png`    | mécanique      | `bombe`               | Delapouite | https://game-icons.net/1x1/delapouite/falling-bomb.html    |
| `ghost-ally.png`      | mécanique      | `invocation`          | Lorc       | https://game-icons.net/1x1/lorc/ghost-ally.html            |
| `poison-bottle.png`   | statut         | `poison`              | Lorc       | https://game-icons.net/1x1/lorc/poison-bottle.html         |
| `small-fire.png`      | statut         | `brulure`             | Lorc       | https://game-icons.net/1x1/lorc/small-fire.html            |
| `snowflake-2.png`     | statut         | `givre`               | Lorc       | https://game-icons.net/1x1/lorc/snowflake-2.html           |
| `star-swirl.png`      | statut         | `etourdissement`      | Lorc       | https://game-icons.net/1x1/lorc/star-swirl.html            |
| `vampire-dracula.png` | statut         | `vol_de_vie`          | Delapouite | https://game-icons.net/1x1/delapouite/vampire-dracula.html |
| `broken-shield.png`   | statut         | `vulnerabilite`       | Lorc       | https://game-icons.net/1x1/lorc/broken-shield.html         |
| `cursed-star.png`     | statut         | `malediction_degats`  | Lorc       | https://game-icons.net/1x1/lorc/cursed-star.html           |
| `eye-target.png`      | statut         | `malediction_toucher` | Delapouite | https://game-icons.net/1x1/delapouite/eye-target.html      |
| `push.png`            | statut         | `repoussement`        | Delapouite | https://game-icons.net/1x1/delapouite/push.html            |
| `marrow-drain.png`    | statut         | `siphon`              | Lorc       | https://game-icons.net/1x1/lorc/marrow-drain.html          |
| `bubbling-flask.png`  | statut         | `mana_au_coup`        | Lorc       | https://game-icons.net/1x1/lorc/bubbling-flask.html        |
