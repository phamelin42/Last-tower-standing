# Last Tower Standing

Jeu de survie à tour, multijoueur (1 à 8 joueurs), sous [Godot](https://godotengine.org) 4.7.
Chaque joueur défend sa propre tour au centre de son arène : les armes tirent seules, et tout se
joue dans la boutique, entre économie, dégâts et survie, face à des vagues qui montent en
puissance. Le dernier en vie gagne.

Le jeu reprend les mécaniques d’une map Warcraft 3, « Tower Survivors » ; noms, contenu,
chiffres et graphismes sont originaux (primitives Godot), et n’utilisent que des ressources
libres.

## Lancer

- Ouvrir le dossier dans Godot 4.7.2 (version standard, GDScript), puis lancer la scène
  principale.
- Serveur dédié sans interface : `godot --headless -- --serveur --port 7777`.

## Développer

- `tools/verifier.sh` : toutes les vérifications de la CI (import, lint, format, tests).
- Spécification : `docs/superpowers/specs/2026-11-24-jeu-tour-design.md`.
- Plan de travail : `docs/superpowers/plans/2026-11-24-jeu-tour-plan.md`.

## Licence

Code sous licence MIT (voir `LICENSE`). Ressources tierces : voir `CREDITS.md`.
