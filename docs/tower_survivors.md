# Tower Survivors : comparatif des armes et des améliorations

Recherche du 25/11/2026 (Phil : « fais un comparatif des armes et améliorations, compare avec ce qu’on a, on doit faire le même nombre d’armes dans le même type »). **Le jeu reprend seulement les mécaniques** de la map Warcraft 3 « Tower Survivors » (auteur : Nethalythic) ; les noms d’origine ci-dessous servent à l’inventaire et **n’entrent jamais dans `data/`, `i18n/` ni dans le jeu** (spec `2026-11-24-jeu-tour-design.md`, ligne 10). De même, **aucun chiffre de ce document ne se recopie dans `data/`** (prix, dégâts, durées, charges) : les valeurs du jeu restent les nôtres, calées par le test d’équilibrage.

## 1. Résumé

- **« Type » = type de dégâts.** La boutique de la map demande d’abord de choisir un type : cinq boutons d’armes (Normal, Piercing, Magic, Siege, Chaos) plus un sixième, « Spikes Damage Upgrades » (améliorations d’épines). Ce sont aussi nos cinq `type_degats` (tranchant, perçant, magique, siège, chaos).
- **Armes : la map en a 15 par type, nous 6.** Version 1.58 (la seule dont j’ai pu lire les données) : 75 armes en boutique, exactement 15 par type, réparties 1 / 6 / 6 / 2 entre commune, peu commune, rare, épique. Nous : 30 armes, 6 par type, réparties 2 / 2 / 1 / 1. **Écart : +9 armes par type, soit +45 au total.**
- **Améliorations : 84 dans le pool de la map contre 40 chez nous (+44).** Les plus gros trous : états (poison, givre, feu, étourdissement), épines, bouclier de mana, classes d’armes.
- **Version.** La spec cite la v1.95, que Hive donne bien comme version actuelle, mais son fichier ne se télécharge que depuis le Discord de l’auteur. La dernière version publique est la v1.58 (EpicWar, mars 2024) : c’est elle que j’ai analysée. Hive annonce 90 armes pour la v1.92 ; pour la v1.95, rien n’est lisible (voir § 2 et § 8, question 2).

## 2. Sources et version

| Source                                                                                                                                                                                              | Ce qu’elle m’a donné                                                                                                                                                                                                                                                                                  | Statut                                                                                                                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fichier `TowerSurvivorsv1.58.w3x` (1,63 Mo, SHA-256 `2a8d7afd8…190e`), liste des versions : https://www.epicwar.com/maps/330677/versions/ (page de la v1.58 : https://www.epicwar.com/maps/335241/) | Tables d’objets (`war3map.w3a`, `.w3u`), textes (`war3map.wts`), script (`scripts\war3map.j`) : noms, types, infobulles, prix, et les listes de boutique du script                                                                                                                                    | **Primaire**, version 1.58 (datée du 4 mars 2024 par EpicWar)                                                                                       |
| Page de ressource Hive de la v1.95 : https://www.hiveworkshop.com/resources/tower-survivors-v1-95.129184/more-info                                                                                  | Confirme « Version 1.95 », journal des modifications dans le jeu (touche F9), fichier à prendre sur le Discord de l’auteur                                                                                                                                                                            | **Primaire**, lue directement ; ne contient aucune liste d’armes                                                                                    |
| Fil Hive de la map : https://www.hiveworkshop.com/threads/tower-survivors.353429/                                                                                                                   | Description : armes de rareté commune, peu commune, rare ou épique ; types Normal, Piercing, Magic, Siege, Chaos ; types de dégâts supplémentaires ; améliorations de revenu, de dégâts, de survie ou d’utilité ; 80 armes (ancienne version) puis 90 (v1.92) ; morceaux du journal des modifications | **Primaire mais illisible ici** (défi Cloudflare, 403 par WebFetch, curl et navigateur) : je ne cite que des extraits remontés par la recherche web |
| Page de la v1.21 sur EpicWar : https://www.epicwar.com/maps/330677/                                                                                                                                 | Description de l’auteur : « Buy towers and upgrades. All towers and upgrades stack. »                                                                                                                                                                                                                 | Primaire                                                                                                                                            |
| Guide https://warcraftsurvivors.com/warcraft-3/tower-survivors/                                                                                                                                     | Reprend « Hive v1.92, 90 armes, mise à jour le 17/10/2026 » ; ne nomme aucune arme                                                                                                                                                                                                                    | **Secondaire**                                                                                                                                      |
| NamuWiki (https://en.namu.wiki/w/Tower%20Survivors), wc3maps.com                                                                                                                                    | Pages derrière le même défi Cloudflare, illisibles                                                                                                                                                                                                                                                    | Non utilisées                                                                                                                                       |

Écartés après lecture : le guide Google Doc « Tower Build Guide » (c’est « The Tower », un autre jeu) et la fiche Steam « Tower Survivors: Fortress » (produit distinct inspiré de la map).

**Méthode.** Le `.w3x` est une archive MPQ lue avec la bibliothèque `mpyq` (installée dans un venv hors dépôt) ; aucun code de la map n’a été exécuté. Le fichier est resté dans un dossier du scratchpad, jamais dans le dépôt. Les chaînes de `war3map.wts` portent un commentaire qui nomme l’objet et le champ (« Abilities: A00D (Poison Bow), Ubertip »), ce qui rend les infobulles lisibles : « Weapon - Piercing & Poison », type d’attaque, portée, capacités. **Le prix est le champ `Ndt1`** de chaque capacité d’achat (500, 2 000, 5 000, 10 000) : c’est cohérent avec Hive (« Rare (5000 Gold) », « Epic (10000 Gold) ») et avec le fil, qui parle de rareté sans donner de seuil ; **la correspondance prix ↔ rareté est donc une déduction** (500 commune, 2 000 peu commune, 5 000 rare, 10 000 épique).

**Ce que « la boutique propose » vient du script.** Le script (`scripts\war3map.j`, noms de variables brouillés) remplit, dans une même fonction, des tableaux d’identifiants d’achat : un pool d’armes de 75 entrées, répété trois fois (je suppose un exemplaire par emplacement de boutique), et quatre pools d’améliorations (dégâts, survie, revenu, épiques) eux aussi en triple, plus un petit pool de départ. Les étiquettes « dégâts », « survie », « revenu », « épiques » sont **les miennes**, déduites du contenu.

**Ce qui n’a pas pu être vérifié**

- Le contenu des v1.92 et v1.95 (90 armes selon Hive) : aucun fichier public, fil Hive illisible. Les noms vus dans les extraits du journal (Death Scythe, Flame Pillar, Slicerglaive, Lightning Ball, Ice Beam, Hungering Maw…) ne sont pas dans la v1.58 ou n’y sont pas rangés comme dans l’extrait ; leur version d’origine est inconnue.
- Trois armes de la v1.58 (**Overloaded Catapult**, **Storm Generator**, **Entangler**, toutes épiques) existent dans les données mais **ne figurent dans aucun pool de boutique** ; seul du code de test réservé au joueur « WorldEdit » les appelle. Je ne les compte pas dans les 75 ; si Phil veut les compter, la map aurait 78 armes (hypothèse : elles sont en cours d’ajout).
- Le sens exact de « Spikes » comme type de dégâts supplémentaire d’une arme (Knives, Impaler) : les infobulles ne le disent pas.
- Les colonnes du tableau d’efficacité (`war3mapMisc.txt`) : les trois premiers bonus ×2 (Normal sur moyenne, Piercing sur légère, Magic sur lourde) concordent avec `data/efficacite.json` ; le ×2 du siège tombe en sixième colonne, dont je n’ai pas établi le nom.
- Les effets précis des états à charges (givre 5 charges, feu 20 charges…) : les infobulles donnent les charges, pas la règle de calcul.

## 3. Comment la map regroupe armes et améliorations

| Regroupement                  | Ce que la map en fait                                                                                                                                                                                                                                                                                                                                                               | Effectifs v1.58 (pool de boutique)                                                                               |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Type de dégâts**            | **Regroupement que le joueur voit en boutique** : boutons « Normal / Piercing / Magic / Siege / Chaos Weapons » (« vous pouvez revenir en arrière si vous changez d’avis et voulez un autre type de dégâts »), plus « Spikes Damage Upgrades » ; l’infobulle de chaque arme commence par « Weapon - <type> »                                                                        | 15 armes par type ; 11 améliorations d’épines                                                                    |
| Rareté (palier de prix)       | Commune 500, peu commune 2 000, rare 5 000, épique 10 000 or ; les armes comme les améliorations en ont                                                                                                                                                                                                                                                                             | Armes 5 / 30 / 30 / 10 ; améliorations 13 / 29 / 29 / 11 (+ 2 sans prix)                                         |
| Type de dégâts supplémentaire | Une arme peut cumuler un second type : feu, givre, poison ou épines                                                                                                                                                                                                                                                                                                                 | 24 armes sur 75 : 9 feu, 7 givre, 6 poison, 2 épines                                                             |
| Forme d’attaque               | « Attack Type » de l’infobulle : cible unique, zone (rayon), rebond (n cibles), onde, barrage, zone ciblée                                                                                                                                                                                                                                                                          | cible unique 27, zone 17, rebond 10, onde 8, barrage 6, zone ciblée 4, zone autour de la tour 2, rebond + zone 1 |
| Portée                        | Quatre paliers : 300, 600, 900, 1 200 (les mêmes que `portee` chez nous)                                                                                                                                                                                                                                                                                                            | 300 : 13 ; 600 : 20 ; 900 : 25 ; 1 200 : 17                                                                      |
| Rôle des améliorations        | Hive : revenu, dégâts, survie, utilité ; en jeu, des boutons « Normal Damage… Other Damage », « Utility Upgrades » et « Income Upgrades » **affichent les bonus accumulés** (journal de la v1.09 : « Utility Upgrades ability displaying non-damage related upgrades ») : ce ne seraient donc pas des rayons de boutique (inférence : leurs infobulles ne sont pas dans le fichier) | pools du script : dégâts 37, survie 29, revenu 9, épiques 10 (avec recoupements)                                 |

Hypothèse retenue pour Phil : **type de dégâts**, parce que c’est le seul regroupement où la map demande un choix au joueur, que nos cinq `type_degats` et notre tableau d’efficacité en reprennent les noms, et que la répartition est parfaitement régulière (15 par type) : « le même nombre d’armes dans le même type » a donc un sens exact. Les épines forment la sixième entrée de ce menu, mais pour des améliorations, pas des armes.

## 4. Inventaire de la map (v1.58)

### 4.1 Armes : 75 dans le pool de boutique

Colonnes : rareté (prix), second type de dégâts éventuel, forme d’attaque, portée, particularités. Les dégâts et temps de recharge d’origine sont volontairement omis (nos chiffres restent originaux).

#### Tranchant (Normal) : 15 armes

| Arme (nom d’origine) | Rareté              | Second type | Attaque            | Portée | Particularités                                          |
| -------------------- | ------------------- | ----------- | ------------------ | ------ | ------------------------------------------------------- |
| Throwing Axes        | commune (500)       | —           | cible unique       | 900    | —                                                       |
| Holy Bolt            | peu commune (2 000) | —           | cible unique       | 1200   | soigne 80 PV                                            |
| Quills               | peu commune (2 000) | —           | zone (rayon 300)   | 600    | —                                                       |
| Seeker Axe           | peu commune (2 000) | —           | rebond (4 cibles)  | 600    | —                                                       |
| Shocker              | peu commune (2 000) | —           | cible unique       | 1200   | étourdit 0,75 s                                         |
| Shockwave Axe        | peu commune (2 000) | —           | onde (+300)        | 300    | —                                                       |
| Thorn                | peu commune (2 000) | —           | cible unique       | 900    | vulnérabilité : +5 % de dégâts normaux subis, cumulable |
| Ale Launcher         | rare (5 000)        | —           | zone (rayon 300)   | 300    | −25 % de chances de toucher pour l’ennemi pendant 3 s   |
| Firebreather         | rare (5 000)        | feu         | onde (+150)        | 300    | balayage tournant ; feu (20 charges)                    |
| Ice Spears           | rare (5 000)        | givre       | barrage (4 cibles) | 600    | givre (5 charges)                                       |
| Net Thrower          | rare (5 000)        | —           | zone (rayon 300)   | 900    | étourdit 2 s                                            |
| Poison Spear         | rare (5 000)        | poison      | cible unique       | 600    | poison (900 sur 3 s) et ralentit de 50 %                |
| Storm Hammer         | rare (5 000)        | —           | rebond (4 cibles)  | 900    | étourdit 3 s                                            |
| Chain Heal           | épique (10 000)     | —           | rebond (4 cibles)  | 600    | soigne 200 PV par ennemi touché                         |
| Impaler              | épique (10 000)     | épines      | onde (+300)        | 300    | étourdit 1 s                                            |

#### Perçant (Piercing) : 15 armes

| Arme (nom d’origine) | Rareté              | Second type | Attaque                        | Portée | Particularités                                             |
| -------------------- | ------------------- | ----------- | ------------------------------ | ------ | ---------------------------------------------------------- |
| Bow                  | commune (500)       | —           | cible unique                   | 900    | —                                                          |
| Fire Bow             | peu commune (2 000) | feu         | zone (rayon 150)               | 900    | feu (5 charges)                                            |
| Frost Bow            | peu commune (2 000) | givre       | cible unique                   | 900    | givre (5 charges)                                          |
| Moon Glaive          | peu commune (2 000) | —           | rebond (4 cibles)              | 300    | —                                                          |
| Poison Bow           | peu commune (2 000) | poison      | cible unique                   | 900    | poison (300 sur 3 s)                                       |
| Poisonspitter        | peu commune (2 000) | poison      | barrage (4 cibles)             | 900    | —                                                          |
| Serpent              | peu commune (2 000) | —           | cible unique                   | 600    | étourdit 0,75 s                                            |
| Frostbolt            | rare (5 000)        | givre       | zone (rayon 150)               | 600    | —                                                          |
| Glaive Thrower       | rare (5 000)        | —           | zone (rayon 300)               | 1200   | vulnérabilité : +10 % de dégâts perçants subis, cumulable  |
| Knives               | rare (5 000)        | épines      | zone autour de la tour         | 600    | —                                                          |
| Lavaspitter          | rare (5 000)        | feu         | barrage (4 cibles)             | 600    | —                                                          |
| Lifeleecher          | rare (5 000)        | —           | cible unique                   | 600    | +0,2 régénération permanente et 60 PV instantanés par coup |
| Splasher             | rare (5 000)        | —           | rebond (4 cibles) + zone (150) | 900    | —                                                          |
| Ballista             | épique (10 000)     | —           | barrage (8 cibles)             | 1200   | étourdit 3 s                                               |
| Wind Spear           | épique (10 000)     | —           | cible unique                   | 900    | repousse (300)                                             |

#### Magique (Magic) : 15 armes

| Arme (nom d’origine) | Rareté              | Second type | Attaque                 | Portée | Particularités                                                                              |
| -------------------- | ------------------- | ----------- | ----------------------- | ------ | ------------------------------------------------------------------------------------------- |
| Magic Missile        | commune (500)       | —           | cible unique            | 900    | —                                                                                           |
| Flamecaster          | peu commune (2 000) | feu         | onde (+150)             | 300    | balayage tournant ; feu (2 charges)                                                         |
| Living Ice           | peu commune (2 000) | givre       | zone (rayon 150)        | 900    | givre (2 charges)                                                                           |
| Living Spittle       | peu commune (2 000) | poison      | cible unique            | 900    | poison (300 sur 3 s)                                                                        |
| Magic Bolt           | peu commune (2 000) | —           | cible unique            | 600    | étourdit 1,5 s                                                                              |
| Magic Claw           | peu commune (2 000) | —           | rebond (4 cibles)       | 600    | —                                                                                           |
| Soulstealer          | peu commune (2 000) | —           | cible unique            | 1200   | +20 de bouclier de mana par coup                                                            |
| Arcane Blaster       | rare (5 000)        | —           | zone (rayon 300)        | 1200   | vulnérabilité : +10 % de dégâts magiques subis, cumulable                                   |
| Icebreather          | rare (5 000)        | givre       | onde (+150)             | 300    | balayage tournant ; givre (3 charges)                                                       |
| Lightning Generator  | rare (5 000)        | —           | rebond (8 cibles)       | 900    | —                                                                                           |
| Living Water         | rare (5 000)        | —           | onde (+300)             | 300    | étourdit 2 s                                                                                |
| Manastone            | rare (5 000)        | —           | cible unique            | 1200   | siphon continu de mana ; rend 80 mana/s                                                     |
| Spell Glaive         | rare (5 000)        | —           | rebond (4 cibles)       | 300    | dégâts selon la mana maximale et la régénération de mana ; sinon rend 20 de mana par ennemi |
| Flame Generator      | épique (10 000)     | feu         | zone ciblée (rayon 300) | 600    | pilier de feu : 5 000 dégâts sur 3 s ; feu (250 charges)                                    |
| Ice Generator        | épique (10 000)     | givre       | zone ciblée (rayon 375) | 1200   | vague d’éclats de glace ; givre (5 charges)                                                 |

#### Siège (Siege) : 15 armes

| Arme (nom d’origine) | Rareté              | Second type | Attaque                 | Portée | Particularités                                                                     |
| -------------------- | ------------------- | ----------- | ----------------------- | ------ | ---------------------------------------------------------------------------------- |
| Boulder              | commune (500)       | —           | cible unique            | 900    | —                                                                                  |
| Blaster              | peu commune (2 000) | —           | cible unique            | 600    | +10 % de dégâts par amélioration « Bash », +25 % par « Dazing Stuns »              |
| Bombs                | peu commune (2 000) | —           | zone (rayon 300)        | 300    | étourdit 0,5 s                                                                     |
| Healing Sprayer      | peu commune (2 000) | —           | zone (rayon 150)        | 900    | soigne 4 PV par ennemi touché                                                      |
| Missile Barrage      | peu commune (2 000) | —           | barrage (4 cibles)      | 1200   | —                                                                                  |
| Mortar Launcher      | peu commune (2 000) | —           | zone (rayon 300)        | 1200   | —                                                                                  |
| Steam Cannon         | peu commune (2 000) | —           | cible unique            | 600    | vulnérabilité : +5 % de dégâts de siège subis, cumulable                           |
| Bouncy Cannonball    | rare (5 000)        | —           | rebond (8 cibles)       | 1200   | —                                                                                  |
| Cluster Rockets      | rare (5 000)        | —           | zone ciblée (rayon 375) | 900    | tir continu 2 s sur une zone ; étourdit 2 s                                        |
| Frost Bomb           | rare (5 000)        | givre       | zone (rayon 300)        | 900    | bombe à retardement 1 s (600 dégâts, 3 charges de givre) ; givre (2 charges)       |
| Liquid Fire Hurler   | rare (5 000)        | feu         | cible unique            | 900    | +25 % de dégâts de feu subis (autres sources)                                      |
| Meatapult            | rare (5 000)        | —           | zone (rayon 300)        | 600    | dégâts selon les PV maximum                                                        |
| Poison Bomb          | rare (5 000)        | poison      | zone (rayon 300)        | 1200   | poison (300 sur 3 s)                                                               |
| Goblin Land Mines    | épique (10 000)     | —           | onde (+150)             | 300    | pose des mines (60 s) en motif tournant, une de plus par exemplaire ; étourdit 3 s |
| Spikewheel Launcher  | épique (10 000)     | feu         | zone (rayon 300)        | 1200   | huile brûlante 3 s (1 000/s) ; feu (150 charges)                                   |

#### Chaos (Chaos) : 15 armes

| Arme (nom d’origine) | Rareté              | Second type | Attaque                 | Portée | Particularités                                            |
| -------------------- | ------------------- | ----------- | ----------------------- | ------ | --------------------------------------------------------- |
| Chaos Orb            | commune (500)       | —           | cible unique            | 900    | —                                                         |
| Chaos Claw           | peu commune (2 000) | —           | rebond (4 cibles)       | 600    | —                                                         |
| Chaos Heart          | peu commune (2 000) | —           | zone (rayon 300)        | 1200   | —                                                         |
| Chaos Web            | peu commune (2 000) | —           | zone (rayon 150)        | 900    | étourdit 1,5 s                                            |
| Death Coil           | peu commune (2 000) | —           | cible unique            | 900    | vulnérabilité : +10 % de dégâts de chaos subis, cumulable |
| Demon Eye            | peu commune (2 000) | —           | cible unique            | 900    | étourdit 1,5 s                                            |
| Healthstone          | peu commune (2 000) | —           | cible unique            | 600    | siphon continu de vie sur la cible ; soigne 40 PV/s       |
| Chaos Skulls         | rare (5 000)        | —           | barrage (12 cibles)     | 1200   | —                                                         |
| Chaos Swarm          | rare (5 000)        | —           | onde (+300)             | 300    | soigne 40 PV par ennemi touché                            |
| Crippler             | rare (5 000)        | —           | cible unique            | 600    | malédiction : −50 % de dégâts de l’ennemi pendant 10 s    |
| Death Generator      | rare (5 000)        | —           | cible unique            | 1200   | +10 % de dégâts par exemplaire supplémentaire             |
| Immolation           | rare (5 000)        | feu         | zone autour de la tour  | 300    | feu (20 charges)                                          |
| Necromancer’s Tome   | rare (5 000)        | —           | cible unique            | 1200   | invoque un mage squelette toutes les 10 s (dure 10 s)     |
| Chaotic Spirit       | épique (10 000)     | poison      | rebond (8 cibles)       | 600    | poison (450 sur 3 s)                                      |
| Inferno Stone        | épique (10 000)     | feu         | zone ciblée (rayon 150) | 900    | invoque un infernal (8 s) ; étourdit 2 s                  |

Hors pool (code de test seulement) : Overloaded Catapult (siège, épique, zone, étourdit), Storm Generator (magique, épique), Entangler (normal et poison, épique).

### 4.2 Améliorations : 84 dans les pools de boutique

Familles : classement **à moi**. Le prix donne la rareté (500 commune, 2 000 peu commune, 5 000 rare, 10 000 épique). Hors pool, présentes dans les données : Reanimating Poison, Terror Teeth, Vulnerability Totem (non branchées) ; « Bombardment » (ancien palier épique de la v1.09) ; « Golden Key » et le lancer gratuit, qui sont des récompenses de défi.

#### Dégâts par type de dégâts : 15

| Amélioration (nom d’origine) | Prix   | Effet                                                    |
| ---------------------------- | ------ | -------------------------------------------------------- |
| Improved Chaos Attacks       | 500    | +10 % de dégâts de chaos                                 |
| Improved Magic Attacks       | 500    | +10 % de dégâts magiques                                 |
| Improved Normal Attacks      | 500    | +10 % de dégâts normaux                                  |
| Improved Piercing Attacks    | 500    | +10 % de dégâts perçants                                 |
| Improved Siege Attacks       | 500    | +10 % de dégâts de siège                                 |
| Normal Scroll                | 2 000  | +20 % de dégâts normaux, puis +3 % toutes les 30 s       |
| Scroll of Chaos              | 2 000  | +20 % de dégâts de chaos, puis +3 % toutes les 30 s      |
| Scroll of Magic              | 2 000  | +20 % de dégâts magiques, puis +3 % toutes les 30 s      |
| Scroll of Piercing           | 2 000  | +20 % de dégâts perçants, puis +3 % toutes les 30 s      |
| Scroll of Siege              | 2 000  | +20 % de dégâts de siège, puis +3 % toutes les 30 s      |
| Blessed Steel                | 10 000 | +100 % de dégâts normaux, +1 % par arme de base du type  |
| Chaos Legion                 | 10 000 | +100 % de dégâts de chaos, +1 % par arme de base du type |
| Enchanted Moon Arrow         | 10 000 | +100 % de dégâts perçants, +1 % par arme de base du type |
| Magic Gemstone               | 10 000 | +100 % de dégâts magiques, +1 % par arme de base du type |
| Refined Explosives           | 10 000 | +100 % de dégâts de siège, +1 % par arme de base du type |

#### Dégâts globaux : 3

| Amélioration (nom d’origine) | Prix   | Effet                                                                                                        |
| ---------------------------- | ------ | ------------------------------------------------------------------------------------------------------------ |
| Improved Attacks             | 500    | +5 % de dégâts de tous les types                                                                             |
| Power Generator              | 2 000  | +2 % de dégâts, puis +1 % toutes les 30 s                                                                    |
| Orb of Power                 | 10 000 | +30 % de dégâts de tous les types et d’épines, +30 % contre les ennemis étourdis, +15 % poison, givre et feu |

#### Dégâts selon la classe d’arme : 7

| Amélioration (nom d’origine) | Prix  | Effet                                                   |
| ---------------------------- | ----- | ------------------------------------------------------- |
| Command Aura                 | 5 000 | +25 % de dégâts pour les armes de portée 300 et 600     |
| Engineering Upgrade          | 5 000 | +100 % de dégâts pour les armes de base (palier commun) |
| Focusfire                    | 5 000 | +25 % de dégâts pour les armes à cible unique           |
| Multifire                    | 5 000 | +25 % d’ennemis touchés par les rebonds et les barrages |
| Splashfire                   | 5 000 | +25 % de dégâts pour les armes de zone                  |
| Trueshot Aura                | 5 000 | +25 % de dégâts pour les armes de portée 900 et 1200    |
| Wavefire                     | 5 000 | +25 % de dégâts pour les armes à onde                   |

#### Cadence : 1

| Amélioration (nom d’origine) | Prix  | Effet            |
| ---------------------------- | ----- | ---------------- |
| Rapidfire                    | 2 000 | +10 % de cadence |

#### Dégâts et durée des états (poison, givre, feu, étourdissement) : 8

| Amélioration (nom d’origine) | Prix  | Effet                                                                                  |
| ---------------------------- | ----- | -------------------------------------------------------------------------------------- |
| Bash                         | 2 000 | +20 % de dégâts aux ennemis étourdis                                                   |
| Freezing Cold                | 2 000 | +10 % de dégâts de givre et de force du ralentissement                                 |
| Potent Poison                | 2 000 | +10 % de dégâts de poison                                                              |
| Searing Heat                 | 2 000 | +10 % de dégâts de feu et de vulnérabilité au feu                                      |
| Combustion                   | 5 000 | +500 % de dégâts de l’explosion de feu                                                 |
| Corrosive Poison             | 5 000 | +25 % de dégâts aux ennemis empoisonnés                                                |
| Dazing Stuns                 | 5 000 | +50 % de durée d’étourdissement                                                        |
| Ice Shard                    | 5 000 | gel de 1,5 s à 25 charges de givre ; le gel augmente de 50 % les dégâts de givre subis |

#### Épines (« Spikes ») : 11

| Amélioration (nom d’origine) | Prix   | Effet                                                                            |
| ---------------------------- | ------ | -------------------------------------------------------------------------------- |
| Spiked Barricades            | 500    | +40 épines                                                                       |
| Bloody Spikes                | 2 000  | +80 épines, saignement cumulable sur l’ennemi qui frappe                         |
| Dreadlord Fang               | 2 000  | +80 épines, +8 PV rendus quand la tour est touchée                               |
| Growing Spikes               | 2 000  | +80 épines, +10 toutes les 30 s                                                  |
| Protruding Spikes            | 2 000  | +80 épines, +240 sur la première attaque                                         |
| Shredding Spikes             | 2 000  | +80 épines, +10 %                                                                |
| Deflection                   | 5 000  | +160 épines ; réduit les dégâts reçus d’un pourcentage des épines (plafond 50 %) |
| Incinerating Spikes          | 5 000  | +160 épines, +20 charges de feu à l’ennemi qui frappe                            |
| Poisonous Spikes             | 5 000  | +160 épines, poison à l’ennemi qui frappe                                        |
| Sharpened Spikes             | 5 000  | +160 épines, +30 %                                                               |
| Crypt Carapace               | 10 000 | +400 épines, +30 % des dégâts reçus en épines                                    |

#### Points de vie maximum : 7

| Amélioration (nom d’origine) | Prix   | Effet                                                                    |
| ---------------------------- | ------ | ------------------------------------------------------------------------ |
| Improved Masonry             | 500    | +500 PV maximum                                                          |
| Magic Seeds                  | 2 000  | +1 000 PV maximum, +5 PV maximum par seconde                             |
| Mask of Death                | 2 000  | +1 000 PV maximum, +15 PV rendus à chaque mort d’ennemi                  |
| Ankh of Reconstruction       | 5 000  | à la mort : répare entièrement la tour (usage unique), +2 000 PV maximum |
| Imbued Masonry               | 5 000  | +2 000 PV maximum, +25 % (rétroactif)                                    |
| Living Wood                  | 5 000  | +2 000 PV maximum, soigne 1,5 % des PV manquants par seconde             |
| Mastercrafted Masonry        | 10 000 | +5 000 PV maximum, +1 % de dégâts par 2 000 PV gagnés                    |

#### Régénération et soins : 6

| Amélioration (nom d’origine) | Prix  | Effet                                                                                      |
| ---------------------------- | ----- | ------------------------------------------------------------------------------------------ |
| Repair Crew                  | 500   | +20 régénération de PV                                                                     |
| Healing Hand                 | 2 000 | +25 % de soins                                                                             |
| Rejuvenating Petal           | 2 000 | +40 régénération, régénération doublée par à-coups toutes les 30 s                         |
| Wisp                         | 2 000 | +40 régénération, +0,2 par seconde                                                         |
| Renew                        | 5 000 | +80 régénération, +25 % (rétroactif)                                                       |
| Smiting Hand                 | 5 000 | +50 % de soins, +35 % de dégâts des armes et améliorations de soin au-dessus de 95 % de PV |

#### Armure (et effet quand la tour est touchée) : 5

| Amélioration (nom d’origine) | Prix  | Effet                                                           |
| ---------------------------- | ----- | --------------------------------------------------------------- |
| Tower Armor                  | 2 000 | +5 armure                                                       |
| Blessed Armor                | 5 000 | +10 armure, +15 armure bonus toutes les 30 s (−1 par coup reçu) |
| Frost Armor                  | 5 000 | +10 armure, charges de givre sur l’ennemi qui frappe            |
| Poison Armor                 | 5 000 | +10 armure, poison sur l’ennemi qui frappe                      |
| Spiky Armor                  | 5 000 | +10 armure, +0,25 % d’épines cumulable par coup reçu            |

#### Esquive : 1

| Amélioration (nom d’origine) | Prix  | Effet                                      |
| ---------------------------- | ----- | ------------------------------------------ |
| Evasion                      | 2 000 | +10 % d’esquive (dégressif à chaque achat) |

#### Bouclier de mana : 7

| Amélioration (nom d’origine) | Prix   | Effet                                                                      |
| ---------------------------- | ------ | -------------------------------------------------------------------------- |
| Mana Shield                  | 500    | +1 000 de bouclier de mana                                                 |
| Energy Pulse                 | 2 000  | +2 000 de mana, étourdit 0,5 s les ennemis proches quand le bouclier tombe |
| Maw of Death                 | 2 000  | +2 000 de mana, +15 de mana rendus par mort d’ennemi                       |
| Moonwell                     | 2 000  | +2 000 de mana, +10 de mana par seconde                                    |
| Arcane Mark                  | 5 000  | +4 000 de mana, +20 % de dégâts tant que le bouclier tient                 |
| Recharge                     | 5 000  | +4 000 de mana, +25 % de régénération de mana                              |
| Energy Shield                | 10 000 | +10 000 de mana, −30 % de dégâts reçus tant que le bouclier tient          |

#### Revenu et prime : 9

| Amélioration (nom d’origine) | Prix      | Effet                                                      |
| ---------------------------- | --------- | ---------------------------------------------------------- |
| Cursed Treasure              | sans prix | sans prix : −100 régénération contre +5 000 or             |
| Philosopher’s Stone          | sans prix | sans prix : −1 000 PV maximum contre +2 000 or             |
| Magic Coin                   | 500       | +5 de revenu d’or                                          |
| Magic Treasure               | 500       | gain d’or unique (250, croissant avec le temps)            |
| Bounty Hunter                | 2 000     | +50 % de prime d’élimination                               |
| Gold Mine                    | 2 000     | +10 de revenu, +10 %                                       |
| Entangled Gold Mine          | 5 000     | +20 de revenu, soin instantané égal à 25 % du revenu bonus |
| Transmute                    | 5 000     | +100 % de prime, 5 % de chances de +200 %                  |
| Golden Ring                  | 10 000    | +200 % de prime, +1 % de dégâts par 50 % de prime          |

#### Boutique (copie, marché noir) : 3

| Amélioration (nom d’origine) | Prix  | Effet                                                                    |
| ---------------------------- | ----- | ------------------------------------------------------------------------ |
| Black Market                 | 500   | achat au choix d’une arme peu commune ou d’une amélioration d’épines     |
| Multiplication Gems          | 2 000 | +3 copies de la prochaine amélioration de palier commun                  |
| Duplicator                   | 5 000 | un exemplaire de plus de la prochaine arme rare ou amélioration d’épines |

#### Aura mixte : 1

| Amélioration (nom d’origine) | Prix   | Effet                                                                  |
| ---------------------------- | ------ | ---------------------------------------------------------------------- |
| Blight Aura                  | 10 000 | +200 régénération ; 200 dégâts de poison par seconde aux ennemis à 600 |

### 4.3 Noms hors boutique

Noms d’origine que les tableaux ci-dessus ne rangent pas : lus par le garde-fou `tests/unitaires/test_noms_origine.gd`, au même titre que ceux des tableaux.

- Overloaded Catapult
- Storm Generator
- Entangler
- Reanimating Poison
- Terror Teeth
- Vulnerability Totem
- Bombardment
- Golden Key

## 5. Ce que nous avons, par les mêmes regroupements

### 5.1 Armes : 30 (`data/armes.json`)

| Type      | Rareté      | Armes (`id`)                             |
| --------- | ----------- | ---------------------------------------- |
| tranchant | commune     | `lame_de_fil`, `faucille_a_ressort`      |
| tranchant | peu commune | `disque_scie`, `moulinet_de_cuivre`      |
| tranchant | rare        | `guillotine_a_vapeur`                    |
| tranchant | épique      | `tourbillon_d_acier`                     |
| perçant   | commune     | `arbalete_de_bureau`, `chausse_trape`    |
| perçant   | peu commune | `carreau_ricochet`, `herse_de_ressorts`  |
| perçant   | rare        | `baliste_de_guet`                        |
| perçant   | épique      | `pluie_d_aiguilles`                      |
| magique   | commune     | `etincelle_runique`, `orbe_de_brume`     |
| magique   | peu commune | `chaine_d_arcanes`, `cercle_de_givre`    |
| magique   | rare        | `nova_d_ambre`                           |
| magique   | épique      | `tempete_astrale`                        |
| siège     | commune     | `bombarde_de_poche`, `petard_de_rempart` |
| siège     | peu commune | `trebuchet_de_chambre`, `mine_de_forge`  |
| siège     | rare        | `canon_de_cloche`                        |
| siège     | épique      | `grande_bombarde`                        |
| chaos     | commune     | `de_pipe`, `sablier_fele`                |
| chaos     | peu commune | `cornue_instable`, `miroir_brise`        |
| chaos     | rare        | `vortex_de_verre`                        |
| chaos     | épique      | `horloge_folle`                          |

### 5.2 Améliorations : 40 (`data/ameliorations.json`)

| Famille                                | Améliorations (`id`)                                                                                                                                                                                    |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dégâts par type de dégâts              | `affutage_fin`, `pointes_trempees`, `encre_d_arcane`, `poudre_noire`, `poussiere_d_entropie`, `forge_du_maitre`, `carquois_sans_fond`, `grimoire_des_cimes`, `poudriere_renforcee`, `coeur_du_desordre` |
| Dégâts globaux                         | `etincelle_d_ame`, `couronne_de_rouages`                                                                                                                                                                |
| Dégâts selon la classe d’arme          | `double_encoche`, `eclats_multiples`, `lentille_fixe`                                                                                                                                                   |
| Cadence                                | `balancier_rapide`, `engrenage_affole`                                                                                                                                                                  |
| Dégâts et durée des états              | —                                                                                                                                                                                                       |
| Épines                                 | `herisson_de_fer`, `couronne_d_epines`                                                                                                                                                                  |
| Points de vie maximum                  | `renfort_de_poutres`, `fondations_de_pierre`                                                                                                                                                            |
| Régénération et soins                  | `mousse_de_guerison`, `seve_d_ambre`, `gorgee_de_sang`, `calice_des_vaincus`                                                                                                                            |
| Armure                                 | `plaques_de_laiton`, `cuirasse_de_bronze`                                                                                                                                                               |
| Esquive                                | `meurtrieres_biaisees`                                                                                                                                                                                  |
| Bouclier de mana                       | —                                                                                                                                                                                                       |
| Revenu et prime                        | `cagnotte_du_guet`, `atelier_de_tisserands`, `placement_de_rente`, `livre_de_comptes`, `fonderie_de_pieces`, `prime_du_guet`, `chasse_aux_trophees`, `tirelire_d_honneur`                               |
| Boutique                               | `bourse_de_rebut`, `jeton_de_l_arriere_boutique`                                                                                                                                                        |
| Aura mixte                             | —                                                                                                                                                                                                       |
| Critique (sans équivalent dans la map) | `oeil_de_lynx`, `de_de_fortune`                                                                                                                                                                         |

Palier de rareté : commune 11, peu commune 13, rare 13, épique 3.

## 6. Écarts

### 6.1 Armes : même nombre dans le même type

Cible v1.58 : 15 armes par type, **1 commune, 6 peu communes, 6 rares, 2 épiques**. Les cinq types ont exactement le même écart.

| Type (map ↔ nous)  | Commune         | Peu commune       | Rare             | Épique          | Total map | Total nous | **Écart** |
| ------------------ | --------------- | ----------------- | ---------------- | --------------- | --------- | ---------- | --------- |
| Normal ↔ tranchant | 1 ↔ 2 (−1)      | 6 ↔ 2 (+4)        | 6 ↔ 1 (+5)       | 2 ↔ 1 (+1)      | 15        | 6          | **+9**    |
| Piercing ↔ perçant | 1 ↔ 2 (−1)      | 6 ↔ 2 (+4)        | 6 ↔ 1 (+5)       | 2 ↔ 1 (+1)      | 15        | 6          | **+9**    |
| Magic ↔ magique    | 1 ↔ 2 (−1)      | 6 ↔ 2 (+4)        | 6 ↔ 1 (+5)       | 2 ↔ 1 (+1)      | 15        | 6          | **+9**    |
| Siege ↔ siège      | 1 ↔ 2 (−1)      | 6 ↔ 2 (+4)        | 6 ↔ 1 (+5)       | 2 ↔ 1 (+1)      | 15        | 6          | **+9**    |
| Chaos ↔ chaos      | 1 ↔ 2 (−1)      | 6 ↔ 2 (+4)        | 6 ↔ 1 (+5)       | 2 ↔ 1 (+1)      | 15        | 6          | **+9**    |
| **Total**          | **5 ↔ 10 (−5)** | **30 ↔ 10 (+20)** | **30 ↔ 5 (+25)** | **10 ↔ 5 (+5)** | 75        | 30         | **+45**   |

Lecture : il nous manque, par type, 4 peu communes, 5 rares et 1 épique, et nous avons 1 commune de trop si l’on copie la répartition de la map. Si Phil ne veut pas copier la répartition (question 3), on garde nos 2 communes et il faut 3 peu communes, 5 rares et 1 épique en plus, soit encore 9 armes par type (2 / 5 / 6 / 2). Avec la v1.92 (90 armes, soit 18 par type si la répartition est régulière, non vérifié), l’écart serait de +12 par type, +60 au total.

Autres différences d’armes, hors effectifs :

| Critère                                             | Map (75 armes)                          | Nous (30 armes)                  |
| --------------------------------------------------- | --------------------------------------- | -------------------------------- |
| Cible unique                                        | 27                                      | 5                                |
| Zone                                                | 17 (+ 1 rebond et zone)                 | 6                                |
| Rebond                                              | 10                                      | 5                                |
| Onde                                                | 8                                       | 3                                |
| Barrage                                             | 6                                       | 5                                |
| Zone autour de la tour (aura)                       | 2                                       | 2                                |
| Zone ciblée qui dure (tir continu, pilier, huile)   | 4                                       | 0                                |
| Mines                                               | 1                                       | 2                                |
| Pièges                                              | 0                                       | 2                                |
| Second type de dégâts ou état de feu, givre, poison | 24 (feu 9, givre 7, poison 6, épines 2) | 8 (brûlure 3, givre 2, poison 3) |
| Étourdissement                                      | 14                                      | 3                                |
| Soin ou vol de vie en tirant                        | 6                                       | 3                                |
| Vulnérabilité cumulable (« +x % de dégâts subis »)  | 6                                       | 0                                |

### 6.2 Améliorations

| Famille                                                        | Map    | Nous   | Écart   |
| -------------------------------------------------------------- | ------ | ------ | ------- |
| Dégâts par type de dégâts                                      | 15     | 10     | +5      |
| Dégâts globaux                                                 | 3      | 2      | +1      |
| Dégâts selon la classe d’arme                                  | 7      | 3      | +4      |
| Cadence                                                        | 1      | 2      | −1      |
| Dégâts et durée des états (poison, givre, feu, étourdissement) | 8      | 0      | +8      |
| Épines (« Spikes »)                                            | 11     | 2      | +9      |
| Points de vie maximum                                          | 7      | 2      | +5      |
| Régénération et soins                                          | 6      | 4      | +2      |
| Armure (et effet quand la tour est touchée)                    | 5      | 2      | +3      |
| Esquive                                                        | 1      | 1      | +0      |
| Bouclier de mana                                               | 7      | 0      | +7      |
| Revenu et prime                                                | 9      | 8      | +1      |
| Boutique (copie, marché noir)                                  | 3      | 2      | +1      |
| Aura mixte                                                     | 1      | 0      | +1      |
| Critique (absent de la map)                                    | 0      | 2      | −2      |
| **Total**                                                      | **84** | **40** | **+44** |

Par rareté (prix) : commune 13 ↔ 11 (+2), peu commune 29 ↔ 13 (+16), rare 29 ↔ 13 (+16), épique 11 ↔ 3 (+8), sans prix 2 ↔ 0 (+2).

Les familles de nos améliorations sans homologue exact : `oeil_de_lynx` et `de_de_fortune` (critique), `gorgee_de_sang` (vol de vie par coup : la map soigne à la mort d’un ennemi ou quand la tour est touchée, pas à chaque coup), `double_encoche` (un tir de plus : la map n’a que « +25 % d’ennemis touchés par rebonds et barrages »), `bourse_de_rebut` (la map donne un lancer gratuit par défi, pas par achat).

## 7. Mécaniques de la map et couverture actuelle

### 7.1 Armes

| Mécanique (exemples de la map)                                                                       | Couverte par                                                                                                             | Reste à faire                                                                                                        |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| Cible unique (27)                                                                                    | `lame_de_fil`, `arbalete_de_bureau`, `etincelle_runique`, `de_pipe`, `baliste_de_guet`                                   | Nombre seulement                                                                                                     |
| Zone (17)                                                                                            | `faucille_a_ressort`, `orbe_de_brume`, `bombarde_de_poche`, `trebuchet_de_chambre`, `grande_bombarde`, `cornue_instable` | Nombre seulement                                                                                                     |
| Rebond (10 ; jusqu’à 8 cibles)                                                                       | `disque_scie`, `carreau_ricochet`, `chaine_d_arcanes`, `tempete_astrale`, `miroir_brise`                                 | Nombre ; nos rebonds vont à 8 cibles (`tempete_astrale`)                                                             |
| Onde (8)                                                                                             | `guillotine_a_vapeur`, `nova_d_ambre`, `vortex_de_verre`                                                                 | Équivalent partiel : la nôtre est un cercle qui s’étend, celle de la map un balayage (« +portée »), parfois tournant |
| Barrage (6 ; jusqu’à 12 cibles)                                                                      | `tourbillon_d_acier`, `herse_de_ressorts`, `pluie_d_aiguilles`, `canon_de_cloche`, `horloge_folle`                       | Nombre seulement                                                                                                     |
| Zone autour de la tour (2)                                                                           | `moulinet_de_cuivre`, `cercle_de_givre`                                                                                  | Nombre seulement                                                                                                     |
| Mines (1) et pièges                                                                                  | Mines : `petard_de_rempart`, `mine_de_forge` ; pièges : `chausse_trape`, `sablier_fele`                                  | Nos pièges n’ont pas d’équivalent dans la map (à garder, c’est un écart assumé)                                      |
| Zone ciblée qui dure : tir continu 2 s, pilier de feu, huile brûlante, éclats de glace (4)           | **manquante**                                                                                                            | Une zone posée sur une cible qui inflige ses dégâts dans le temps                                                    |
| Poison (6)                                                                                           | `disque_scie`, `baliste_de_guet`, `cornue_instable`                                                                      | Nombre                                                                                                               |
| Givre (7)                                                                                            | `orbe_de_brume`, `cercle_de_givre`                                                                                       | Nombre ; la map empile des charges (1 à 5), à confirmer dans `sim/`                                                  |
| Feu (9)                                                                                              | `nova_d_ambre`, `canon_de_cloche`, `horloge_folle`                                                                       | Nombre ; charges, explosion à la mort (non vérifié)                                                                  |
| Étourdissement (14)                                                                                  | `herse_de_ressorts`, `tempete_astrale`, `grande_bombarde`                                                                | Nombre ; durées de 0,5 à 3 s                                                                                         |
| Soin ou vol de vie en tirant (6)                                                                     | `tourbillon_d_acier`, `de_pipe`, `vortex_de_verre`                                                                       | Nombre ; siphon continu de vie manquant                                                                              |
| Vulnérabilité cumulable : l’arme augmente les dégâts subis d’un type (6)                             | **manquante**                                                                                                            | Statut « vulnérabilité » par type de dégâts, cumulable, avec plafond à définir                                       |
| Malédiction : −50 % de dégâts ennemis ; −25 % de chances de toucher (2)                              | **manquante**                                                                                                            | Deux statuts de réduction de l’attaque ennemie                                                                       |
| Repoussement (1)                                                                                     | **manquante**                                                                                                            | Déplacement de l’ennemi vers l’arrière                                                                               |
| Mana : siphon, +mana au coup, dégâts selon la mana maximale (3)                                      | **manquante** (prévue : D12, `degats_par_mana_max`)                                                                      | Déjà décidé dans `2026-11-25-retours-partie-design.md` § 6.4 ; ce comparatif ajoute le siphon continu de mana        |
| Dégâts qui croissent avec les PV maximum, le nombre d’exemplaires ou des améliorations possédées (4) | **manquante**                                                                                                            | Un champ d’arme du type `degats_par_*` ; à étendre au-delà de la mana                                                |
| Invocation : mage squelette, infernal (2)                                                            | **manquante**                                                                                                            | Une unité alliée temporaire : coût élevé en simulation et en rendu                                                   |
| Motif tournant : balayage horaire ou antihoraire (3, plus les mines)                                 | **manquante**                                                                                                            | Une direction de tir qui tourne au lieu de viser                                                                     |
| Bombe à retardement (1)                                                                              | **manquante**                                                                                                            | Projectile qui explose après un délai                                                                                |

### 7.2 Améliorations

| Famille de la map                              | Couverte par                                                                                                                                                                                            | Reste à faire                                                                                                           |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Dégâts par type (15 : trois paliers par type)  | `affutage_fin`, `pointes_trempees`, `encre_d_arcane`, `poudre_noire`, `poussiere_d_entropie`, `forge_du_maitre`, `carquois_sans_fond`, `grimoire_des_cimes`, `poudriere_renforcee`, `coeur_du_desordre` | Palier épique par type (+100 %, +1 % par arme de base du type) et palier qui croît dans le temps (+3 % toutes les 30 s) |
| Dégâts globaux (3)                             | `etincelle_d_ame`, `couronne_de_rouages`                                                                                                                                                                | Palier commun (+5 %) ; version qui croît dans le temps                                                                  |
| Dégâts selon la classe d’arme (7)              | `double_encoche`, `eclats_multiples`, `lentille_fixe` en approchant                                                                                                                                     | `lentille_fixe` ≈ cible unique ; classes zone, onde, portée courte, portée longue, armes de base : **manquantes**       |
| Cadence (1)                                    | `balancier_rapide`, `engrenage_affole`                                                                                                                                                                  | Rien (nous en avons un de plus)                                                                                         |
| États : poison, givre, feu, étourdissement (8) | **manquante**                                                                                                                                                                                           | Bonus de dégâts et de durée des états, bonus contre les ennemis étourdis ou empoisonnés                                 |
| Épines (11)                                    | `herisson_de_fer`, `couronne_d_epines`                                                                                                                                                                  | Variantes : croissantes, premier coup, soin, poison, feu, saignement, réduction des dégâts reçus                        |
| Points de vie maximum (7)                      | `renfort_de_poutres`, `fondations_de_pierre`                                                                                                                                                            | Variantes : PV par seconde, soin des PV manquants, dégâts selon les PV, résurrection unique                             |
| Régénération et soins (6)                      | `mousse_de_guerison`, `seve_d_ambre`, `gorgee_de_sang`, `calice_des_vaincus`                                                                                                                            | Régénération qui croît, soins en à-coups, bonus de soins                                                                |
| Armure et effet quand la tour est touchée (5)  | `plaques_de_laiton`, `cuirasse_de_bronze`                                                                                                                                                               | Armure qui se reconstitue, givre ou poison sur l’attaquant                                                              |
| Esquive (1)                                    | `meurtrieres_biaisees`                                                                                                                                                                                  | Rien                                                                                                                    |
| Bouclier de mana (7)                           | **manquante** (prévue : D12)                                                                                                                                                                            | Mana maximale, régénération, étourdissement quand le bouclier tombe, dégâts et réduction tant qu’il tient               |
| Revenu et prime (9)                            | `cagnotte_du_guet`, `atelier_de_tisserands`, `placement_de_rente`, `livre_de_comptes`, `fonderie_de_pieces`, `prime_du_guet`, `chasse_aux_trophees`, `tirelire_d_honneur`                               | Compromis « PV contre or » ; gain d’or unique qui croît ; revenu convertible en soin                                    |
| Boutique (3)                                   | `bourse_de_rebut`, `jeton_de_l_arriere_boutique`                                                                                                                                                        | Copie de la prochaine arme rare ou amélioration d’épines (`Duplicator`) et de la prochaine amélioration commune         |
| Aura mixte (1)                                 | **manquante**                                                                                                                                                                                           | Aura de poison autour de la tour liée à la régénération                                                                 |

## 8. Questions à trancher par Phil

Chaque question porte une valeur par défaut ; sans réponse, je prends celle-ci.

1. **« Type » veut-il bien dire type de dégâts ?** Défaut : oui. Les épines resteraient une sixième catégorie d’**améliorations** (pas d’armes), comme dans la boutique de la map.
2. **Quelle version viser : v1.58 (vérifiée) ou v1.92 / v1.95 (90 armes selon Hive, non détaillées) ?** Défaut : v1.58, soit **15 armes par type, 75 au total**, et nous reprenons le chiffre de la v1.95 si Phil me donne le journal F9 ou le fichier (à récupérer sur le Discord de l’auteur ; je n’y entre pas). Un passage à 18 par type se ferait en un second lot.
3. **Copier la répartition par rareté (1 / 6 / 6 / 2 par type) ?** Défaut : non, garder nos 2 communes et ajouter 3 peu communes, 5 rares et 1 épique par type (2 / 5 / 6 / 2 = 15). Cela évite de déclasser des armes existantes et leurs signatures visuelles (D5).
4. **Comment découper les 45 nouvelles armes ?** Chacune demande une signature visuelle unique (D5), un son de tir unique (D15, § 6.5 bis de `2026-11-25-retours-partie-design.md`) et un test d’équilibrage (spec § 5.6). Défaut : une PR par type (9 armes), dans l’ordre tranchant, perçant, magique, siège, chaos.
5. **Faut-il aussi égaler le nombre d’améliorations ?** Phil n’a demandé l’égalité que pour les armes. Défaut : non ; on comble d’abord les mécaniques manquantes (états, épines, mana, classes d’armes) et on décide du total ensuite. Le total de la map est de 84, le nôtre de 40.
6. **Quelles mécaniques sans équivalent reprendre ?** Défaut : reprendre la vulnérabilité cumulable, la malédiction, le repoussement, la mana (déjà décidée), les dégâts selon PV maximum ou exemplaires ; **reporter** invocation, motif tournant, zone ciblée qui dure et bombe à retardement (coût de simulation et de rendu), à rouvrir lot par lot.
7. **Copier les prix de la map (500, 2 000, 5 000, 10 000) ?** Défaut : non, nos prix restent ceux de `data/` (70 à 1 150), calés par le test d’équilibrage ; seule la hiérarchie de rareté compte.
8. **Garder nos pièges (`chausse_trape`, `sablier_fele`), absents de la map ?** Défaut : oui, ce sont des mécaniques à nous.
9. **Ajouter un contrôle automatique qui interdit les noms d’origine dans `data/`, `i18n/` et le code ?** Défaut : oui, un test qui lit les noms listés dans ce document (4.1 et 4.2) et échoue si l’un d’eux apparaît ailleurs, pour tenir la règle de la spec (noms originaux).
