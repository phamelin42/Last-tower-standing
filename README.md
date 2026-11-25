# Last Tower Standing

Jeu de survie à tour, multijoueur (1 à 8 joueurs), sous [Godot](https://godotengine.org) 4.7.2 en
GDScript typé. Chaque joueur défend sa propre tour au centre de son arène : les armes tirent seules,
et tout se joue dans la boutique, entre économie, dégâts et survie, face à des vagues qui montent en
puissance. Le dernier en vie gagne.

Le jeu reprend les mécaniques d'une map Warcraft 3, « Tower Survivors » ; noms, contenu, chiffres et
graphismes sont originaux (primitives Godot), et n'utilisent que des ressources libres.

Le guide du joueur est dans [`docs/jouer.md`](docs/jouer.md).

## Prérequis

- [Godot 4.7.2](https://godotengine.org/download) standard (GDScript, pas la version .NET).
- Pour les vérifications de développement : gdtoolkit 4 (gdlint, gdformat), installé par
  `tools/install-gdtoolkit.sh`.

## Lancer le jeu

1. Ouvrir le dossier du projet dans Godot 4.7.2 (fichier `project.godot`).
2. Lancer la scène principale (touche F5).

## Jouer

Le menu propose :

- **Jouer seul** : une partie contre les vagues, sans réseau.
- **Créer une partie** : ouvre un salon sur votre machine, qui en devient l'hôte. Les autres
  joueurs le rejoignent. Dans le salon, l'hôte choisit la vitesse de partie puis lance la partie.
- **Rejoindre une partie** : liste automatiquement les salons du réseau local. Vous pouvez aussi
  saisir l'adresse IP de l'hôte et son port (7777 par défaut).
- **Réglages** et **Quitter**.

### Vitesse de partie

L'hôte choisit la vitesse dans le salon : **×1**, **×2** ou **×4**. Une vitesse ×2 divise toutes les
durées par deux, ×4 par quatre.

### Jouer sur le réseau local

Les joueurs doivent être sur le même réseau. L'hôte clique sur « Créer une partie », les autres
cliquent sur « Rejoindre une partie » et choisissent le salon dans la liste. Le pare-feu doit
autoriser Godot à recevoir des connexions UDP sur le port 7777, et la découverte des salons utilise
le port UDP 7778.

### Jouer par Internet

Pour qu'un joueur extérieur au réseau local rejoigne votre salon :

1. Sur votre box, redirigez le port **7777 en UDP** vers l'ordinateur qui héberge.
2. Autorisez le port 7777 en UDP dans le pare-feu de cette machine.
3. Donnez votre adresse IP publique aux autres joueurs. Ils la saisissent dans « Rejoindre une
   partie », avec le port 7777.

Le jeu ne passe pas les NAT tout seul : sans redirection de port, la connexion échoue.

## Serveur dédié

Un serveur sans interface se lance ainsi :

```
godot --headless --path . -- --serveur --port 7777
```

Options lues au lancement :

| Option               | Valeur    | Défaut | Rôle                                                                                         |
| -------------------- | --------- | ------ | -------------------------------------------------------------------------------------------- |
| `--serveur`          | (drapeau) | absent | Lance le serveur dédié au lieu du menu.                                                      |
| `--port`             | 1 à 65535 | 7777   | Port UDP de jeu. Une valeur invalide ou un port déjà pris arrête le serveur (code 3).        |
| `--acceleration`     | 1 à 60    | 1      | Accélère le temps de la partie. Une valeur hors bornes est ramenée dans l'intervalle.        |
| `--quitter-a-la-fin` | (drapeau) | absent | Quitte le processus à la fin de la partie. Sans lui, le salon se rouvre après chaque partie. |

Le serveur journalise en français sur la sortie standard. Codes de sortie : 0 normal, 2 données du
jeu absentes ou invalides, 3 port impossible.

Pour une partie solo reproductible, les options `--graine N` et `--vitesse X` (X valant 1, 0.5 ou
0.25) s'appliquent à « Jouer seul » :

```
godot --path . -- --graine 42 --vitesse 0.5
```

## Mesurer les images par seconde

Le jeu vise **60 images par seconde au minimum avec 1 000 ennemis visibles**. Deux outils le
vérifient sur votre machine.

**Le compteur** affiche les images par seconde actuelles, le minimum des 5 dernières secondes et le
nombre d'ennemis visibles, en haut à gauche sous la barre du haut, dans le menu comme en partie.

- **F3** l'affiche ou le masque pour la séance en cours, sans toucher au réglage enregistré.
- **Réglages**, case « Afficher les images par seconde » (éteinte par défaut) : le compteur
  s'affiche à chaque lancement du jeu tant qu'elle est cochée.

**Le banc d'essai** ouvre, à la place du menu, une arène où 1 000 ennemis des huit familles avancent
vers la tour, sans partie ni réseau. Le compteur y est affiché d'office. Au bout de 30 s, un résumé
(moyenne, minimum, nombre d'ennemis) s'écrit en bas de l'écran et dans la console ; les 2 premières
secondes ne comptent pas (chargement des images). Échap quitte.

- En ligne de commande : `godot --path . -- --banc-ips` (1 000 ennemis), ou
  `godot --path . -- --banc-ips 2000` pour un autre nombre (de 1 à 5 000).
- Depuis l'éditeur : menu Projet, Paramètres du projet, Application, Run, champ « Main Run Args »
  (arguments de la ligne de commande), y mettre `-- --banc-ips 1000`, puis lancer avec F5. Penser à
  vider le champ ensuite : il est enregistré dans `project.godot`.

**Ce qu'il faut lire** : un minimum d'au moins 60 img/s sur 5 s avec 1 000 ennemis (ligne
« min. 5 s » du compteur, ou « minimum » du résumé). La synchronisation verticale plafonne les
images à la fréquence de l'écran (60 Hz le plus souvent) : un compteur collé à 60 est un bon
résultat, pas une limite du jeu. Pour mesurer la marge, la désactiver :
`godot --path . --disable-vsync -- --banc-ips`. Sans carte graphique réelle (serveur, conteneur),
le rendu est logiciel et le chiffre n'a aucune valeur.

## Développer

- `tools/verifier.sh` : rejoue toutes les étapes de la CI (import, uid, lint, format, tests,
  contrôle du lanceur, intégration), arrêt à la première étape rouge. `tools/verifier.sh --etape
<nom>` lance une seule étape.
- `tools/install-godot.sh` : installe Godot 4.7.2 (somme SHA-512 vérifiée).
- `tools/install-gdtoolkit.sh` : installe gdtoolkit 4 dans un environnement Python dédié.
- `tools/equilibrage.gd` : simule des parties d'un joueur seul, sans rendu, et résume les manches
  atteintes, le taux de victoire sur le boss, les causes de mort et les achats :

  ```
  godot --headless --path . --script res://tools/equilibrage.gd -- \
      [--graines 50] [--strategie raisonnable|passive|bonne|toutes] [--graine-depart 1]
  ```

Les chiffres d'équilibrage sont dans `data/*.json`, validés au chargement.

## Documentation

- Spécification : [`docs/superpowers/specs/2026-11-24-jeu-tour-design.md`](docs/superpowers/specs/2026-11-24-jeu-tour-design.md)
- Plan de travail : [`docs/superpowers/plans/2026-11-24-jeu-tour-plan.md`](docs/superpowers/plans/2026-11-24-jeu-tour-plan.md)
- Guide du joueur : [`docs/jouer.md`](docs/jouer.md)

## À venir

- **Graphismes 2D pixel art** avec l’ancienne version CC0 du pack Tiny Swords de Pixel Frog.
- **Annuaire en ligne** des salons, avec ouverture du port par UPnP : en attendant, on joue
  en réseau local ou par adresse IP directe.

## Licence

Code sous licence MIT (voir [`LICENSE`](LICENSE)). Ressources tierces : voir
[`CREDITS.md`](CREDITS.md).
