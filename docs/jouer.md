# Guide du joueur

Last Tower Standing : vous défendez votre tour au centre de votre arène. Les armes tirent seules.
Vous achetez, vous améliorez et vous survivez aux vagues. Le dernier en vie gagne.

## La boucle de jeu

- **Préparation** : 30 secondes avant la première vague. La boutique est ouverte.
- **Manches** de 30 secondes. Au début de chaque manche, une nouvelle offre apparaît et une
  famille d'ennemis est tirée au hasard. La difficulté monte.
- **Boss** à la manche 31 : les apparitions normales s'arrêtent, et le boss marche sur votre tour.
  Le tuer vous donne la victoire.
- **Défaite** : la tour tombe à 0 PV. Vous voyez votre récapitulatif, puis vous pouvez observer
  les arènes des autres joueurs.
- **Fin de partie** : quand plus aucun joueur n'est en vie, ou quand les survivants ont vaincu le
  boss et quittent. Le classement se fait par manche atteinte, puis par victoire, puis par dégâts
  infligés.

## La boutique

- Chaque manche, la boutique propose **4 offres**. Chacune a une rareté : commune, peu commune,
  rare ou épique. Les offres épiques sont absentes au début et deviennent plus fréquentes au fil
  des manches.
- Une offre achetée disparaît de l'offre en cours.
- **Relancer** renouvelle l'offre. La première relance payante coûte 50 or, et chaque relance
  payante de la même manche coûte 25 or de plus. Le prix repart de 50 à la manche suivante.
  Certains objets donnent des relances gratuites.
- **Armes** : vous avez 8 emplacements. Une arme se revend à 50 % de son prix. Les améliorations
  n'occupent pas d'emplacement.
- **Marché noir** : un objet spécial. Au lieu d'une offre au hasard, il vous laisse choisir une
  amélioration dans une liste (jusqu'à la rareté rare).

## La mana

Certains objets donnent de la **mana maximale** et de la **régénération de mana**. La mana absorbe
les coups reçus **avant** les PV de la tour ; elle se régénère d'elle-même, par seconde. Sans objet de
mana, la réserve est nulle.

## La caméra et la mini-carte

- **Déplacer la vue** : les flèches ou `W`, `A`, `S`, `D`. **Espace** recentre la tour. La molette
  zoome (la sensibilité se règle dans les réglages) ; la vue s'éloigne au plus jusqu'à deux fois
  le cercle d'apparition des ennemis.
- **Mini-carte** : elle montre toute l'arène ; un clic y déplace la vue. Pendant l'observation, les
  vignettes des autres arènes s'y trouvent : cliquez sur l'une pour la regarder, **Espace** pour
  revenir à la vôtre.

## La taille de l'interface

Les réglages proposent cinq tailles pour toute l'interface : 75 %, 87,5 %, 100 %, 112,5 % et
125 %.

## L'économie

- Vous commencez avec **500 or**.
- Votre revenu tombe **toutes les 10 secondes**. Il est fait d'un revenu de base, qui augmente par
  paliers de manche, et de revenus que vous achetez.
- Chaque ennemi tué vous rapporte une **prime**. Son montant dépend de l'ennemi et d'un
  multiplicateur qui monte par paliers de manche. Certains objets l'augmentent.

## Efficacité des dégâts contre les armures

Le tableau donne le facteur appliqué aux dégâts : **×2** pour une combinaison favorable, **×1**
sinon. Il n'y a aucun malus.

| Type de dégâts \ Armure | légère | moyenne | lourde | fortifiée | aucune | boss |
| ----------------------- | ------ | ------- | ------ | --------- | ------ | ---- |
| tranchant               | 1      | 2       | 1      | 1         | 1      | 1    |
| perçant                 | 2      | 1       | 1      | 1         | 1      | 1    |
| magique                 | 1      | 1       | 2      | 1         | 1      | 1    |
| siège                   | 1      | 1       | 1      | 2         | 1      | 1    |
| chaos                   | 1      | 1       | 1      | 1         | 1      | 1    |

## Raccourcis clavier

| Touche        | Action                                          |
| ------------- | ----------------------------------------------- |
| Tabulation    | Afficher ou masquer le tableau des scores       |
| 1, 2, 3, 4    | Acheter l'offre correspondante dans la boutique |
| R             | Relancer la boutique                            |
| Flèche droite | Observation : arène suivante                    |
| Flèche gauche | Observation : arène précédente                  |
| Échap         | Ouvrir le menu de jeu                           |

## L’annuaire des parties en ligne

L’annuaire est un petit service qui liste les salons publics ouverts. Il ne retient que le nom du
salon, le nombre de joueurs, le maximum, la version et l’adresse IP et le port de l’hôte. Un salon
disparaît de la liste 30 secondes après sa dernière annonce, ou tout de suite quand l’hôte le
ferme. La partie, elle, se joue toujours directement chez l’hôte.

Vie privée : « Partie publique : votre adresse IP sera transmise à l’annuaire et visible des joueurs qui consultent la liste, tant que le salon est ouvert. Rien n’est conservé ensuite. »

**Héberger.** Sur la page « Créer une partie », la case « Partie publique » est cochée par défaut : le
salon est alors annoncé à l’annuaire dès que vous êtes dans votre salon et que votre box a répondu
(ouverture automatique du port, réussie ou non), puis toutes les 10 secondes, et retiré quand vous
quittez ou lancez la partie. Décochez-la pour ne rien envoyer. Si l’annuaire ne parvient pas à
joindre votre partie (port fermé, par exemple derrière un partage de connexion de l’opérateur), le
salon l’indique en texte et reste jouable en réseau local et par adresse IP. Un serveur dédié n’est
jamais annoncé.

**Port ouvert automatiquement.** À la création du salon, le jeu demande à votre box d’ouvrir le port
de jeu (UPnP, en UDP) : la redirection dure une heure, se renouvelle tant que le salon est ouvert,
et se retire quand vous quittez. Si la box refuse ou n’a pas d’UPnP, le salon affiche « Votre box
n’a pas ouvert le port : les joueurs extérieurs ne pourront pas vous rejoindre » ; il reste
jouable en réseau local, et vous pouvez rediriger le port à la main. Un port de jeu inférieur à
1 024 n’est jamais listé dans l’annuaire : le salon s’ouvre, mais seuls le réseau local et
l’adresse IP permettent de le rejoindre. Le jeu le dit à l’hôte à la création.

**Rejoindre.** « Rejoindre une partie » affiche les salons du réseau local et ceux de l’annuaire,
avec leur origine en texte (« Réseau local » ou « Annuaire »). Un salon d’une autre version du jeu
est marqué « autre version », sans être caché. Le jeu ne contacte l’annuaire qu’à l’ouverture de
cette page et quand vous cliquez sur « Actualiser », jamais en arrière-plan. Si l’annuaire est
injoignable, lent ou d’une autre version, un message le dit et le réseau local comme l’adresse IP
saisie continuent de marcher.

**Réglage.** L’écran des réglages a un champ « Adresse de l’annuaire » (par défaut
`annuaire-lts.phamelin.fr:7779`). Le vider désactive l’annuaire : plus rien n’est envoyé ni lu.

Pour héberger un annuaire sur un serveur équipé de
Docker, voir le [README](../README.md#annuaire-des-parties-en-ligne).
