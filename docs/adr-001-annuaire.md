# ADR 001 : annuaire des parties en ligne

**Statut : Proposé** (25/11/2026). Aucune ligne de code avant la validation de Phil.

## Contexte

Aujourd'hui, on joue par Internet en saisissant l'IP de l'hôte (README, « Jouer par Internet ») ; la
découverte automatique (`reseau/decouverte.gd`) ne couvre que le réseau local (diffusion UDP
7778). Phil a lancé le lot 7 le 25/11/2026, avant l'habillage graphique : un petit **annuaire** sur
son VPS liste les salons ouverts, et l'hôte ouvre son port par UPnP.

Principe fixé par Phil (25/11/2026) :

- L'hôte héberge toujours la partie sur sa machine. Aucune donnée de jeu ne passe par le VPS.
- L'annuaire ne tient que : nom, joueurs, maximum, version, et l'adresse IP et le port **vus par le
  VPS** (jamais une adresse déclarée par le client).
- Une entrée disparaît **30 s** après la dernière annonce.

**Écart technique à ce principe** : l'IP est bien celle que le VPS voit, mais le **port** ne peut
pas l'être. En TCP, le port vu est un port éphémère sans rapport avec le port UDP de jeu. Le port est
donc **déclaré par l'hôte** (voir Décision et décision 1).

Ce que le code fait aujourd'hui et qui contraint la décision :

- `Decouverte` encode et décode ses paquets avec `Protocole.LecteurOctets` (décodage défensif :
  taille bornée, UTF-8 valide, pas de caractère de contrôle, reste nul). L'annuaire suit ce style.
- `Salon.ajouter` (`reseau/salon.gd:24-35`) donne le rôle d'hôte au **premier pair dont le bonjour
  est accepté** (`if hote == -1: hote = id`). `SessionReseau.heberger` (`app/session_reseau.gd:48-78`)
  démarre le serveur ENet, lance le client local en 127.0.0.1 (la connexion et le bonjour sont
  asynchrones : `Client.connecter` ne les envoie qu'à la connexion établie, `reseau/client.gd:54,139`),
  puis démarre aussitôt l'annonce locale. Entre l'ouverture du port et l'enregistrement du client
  local, un joueur extérieur peut donc devenir hôte. `Salon.retirer` (`reseau/salon.gd:37-48`)
  désigne de plus le premier pair restant si l'hôte part. Avec un salon public, le risque est réel.
- `Serveur` ouvre `PLACES_ENET = MAX_CLIENTS + 1 = 9` places ; un pair qui se connecte sans dire
  bonjour n'entre pas dans le salon (`reseau/serveur.gd:217-220`, `257-283`).
- Le serveur dédié (`--serveur`, `reseau/serveur_dedie.gd`, scène `res://scenes/serveur.tscn`,
  aiguillée par `app/principal.gd:36-38`) prouve qu'un processus Godot sans interface convient. Il n'a
  **pas de client local** : son hôte est le premier pair connecté, et `Serveur._lancer_partie`
  (`reseau/serveur.gd:407`) lance la partie avec `salon.hote`.
- `tools/install-godot.sh` fixe Godot 4.7.2 et vérifie la somme SHA-512 de la liste officielle
  (`SHA512-SUMS.txt` de la release `godotengine/godot-builds`).

## Décision

Un service **Godot sans interface**, `godot --headless --path . -- --annuaire`, tient en mémoire
la liste des salons. Il parle un **protocole binaire maison sur TCP** (port 7779), une requête par
connexion. Il vérifie par une **connexion ENet de sonde** qu'un salon est joignable avant de le
lister, et ne retient que l'**adresse source de la connexion TCP**. Il tourne dans une image Docker
sur le VPS, derrière un sous-domaine déclaré dans `infra`. Le jeu l'interroge et lui annonce le
salon ; s'il est injoignable, le réseau local et l'IP saisie fonctionnent comme avant.

Pourquoi TCP et non UDP : une annonce UDP a une adresse source falsifiable. Le service sonde
l'adresse annoncée ; avec UDP, n'importe qui ferait envoyer par le VPS des paquets ENet vers une
victime (réflexion, balayage) et ferait lister l'IP de la victime comme serveur de jeu. Avec TCP, la
poignée de main à trois temps prouve que l'adresse source est celle de l'annonceur : **l'adresse
retenue est celle que le VPS voit, jamais un champ du message** (il n'y en a d'ailleurs aucun). Le
service ne peut donc sonder que l'adresse de celui qui parle, et la liste ne contient que des
adresses qui ont prouvé leur contrôle d'un port ENet ouvert. Seul le **port** est déclaré (TCP ne
révèle pas le port UDP de jeu). **Écart à la phrase de Phil** (« l'IP et le port vus par le VPS ») :
le port vient du message, l'IP de la connexion. Risque résiduel : un port arbitraire, mais la sonde
ne vise que l'IP de l'émetteur, donc elle est inoffensive pour un tiers. Le port déclaré est le port
**externe** (celui qu'ouvre UPnP, qui peut différer du port local : T7.2 le fournit).

## Protocole

Constantes de `AnnuaireProtocole` : `MAGIE = 0x41`, `VERSION = 1` (version de l'annuaire, distincte
de `Protocole.VERSION` du jeu, valant 2 aujourd'hui), `PORT_DEFAUT = 7779` (TCP). Entiers en petit
boutisse, comme `LecteurOctets`. Tout octet reçu est une donnée non fiable : invalide, trop grand ou
tronqué, il est refusé sans exception.

**Cadre** : `u16 taille · corps`. La taille est contrôlée avant toute lecture du corps (voir l'ordre
des contrôles plus bas). Le corps commence toujours par `u8 magie · u8 version · u8 type`. **Le
préfixe `u16` et ces 3 octets ne changent jamais**, pour qu'une version inconnue reste
reconnaissable.

| Sens      | Type           | Corps après l'en-tête                                                                     | Taille max du corps |
| --------- | -------------- | ----------------------------------------------------------------------------------------- | ------------------- |
| jeu → svc | `0x01` ANNONCE | `u8 version_jeu · u8 joueurs · u8 max · u16 port · u8 n + nom UTF-8`                      | 105 octets          |
| jeu → svc | `0x02` RETRAIT | `u16 port`                                                                                | 5 octets            |
| jeu → svc | `0x03` LISTE   | (rien)                                                                                    | 3 octets            |
| svc → jeu | `0x81` REPONSE | `u8 statut · u8 version_service`                                                          | 5 octets            |
| svc → jeu | `0x83` SALONS  | `u8 n` puis n × `u8[4] ip · u16 port · u8 version_jeu · u8 joueurs · u8 max · u8 n + nom` | 10 604 octets       |

- **Bornes de champ** : nom 1 à 24 caractères (96 octets UTF-8 au pire, `Protocole.MAX_NOM`),
  validé par `LecteurOctets.texte` (UTF-8 valide, aucun contrôle) ; `max` entre 1 et
  `Salon.MAX_JOUEURS` (8) ; `joueurs` ≤ `max` ; `port` entre 1 024 et 65 535 ; `n` ≤ 100. Reste de
  lecture nul, sinon refus.
- **Limites de taille** : le service refuse tout cadre entrant de plus de **128 octets** de corps
  (le plus grand message légitime en fait 105) ; le client refuse tout cadre de plus de **16 384
  octets** (le plus grand légitime en fait 10 604).
- **Statuts de REPONSE** : 0 accepté · 1 version d'annuaire différente · 2 port injoignable · 3
  débit dépassé · 4 message invalide · 5 annuaire plein ou quota par IP atteint · 6 adresse non
  publique · 7 service occupé (sondes saturées, réessayer à la période suivante).
- **Version différente** : le service répond `magie · VERSION du service · 0x81 · statut 1 · VERSION`
  quelle que soit la requête, sans en lire le reste, puis ferme. Un client qui reçoit une version
  autre que la sienne n'interprète rien d'autre et affiche « Annuaire incompatible : mettez le jeu
  à jour » ; le réseau local et l'IP saisie restent disponibles. Un changement de format incrémente
  `VERSION`. La version du **jeu** n'est pas refusée par le service : elle est listée, et la liste
  du jeu marque en texte (« autre version ») un salon dont `version_jeu` diffère de la sienne.
- **Cycle** : l'hôte annonce **immédiatement** à l'ouverture du salon, puis toutes les **10 s**
  (trois annonces par fenêtre d'expiration), et à chaque changement du nombre de joueurs (dans la
  limite de débit). Il envoie RETRAIT en fermant le salon ou au lancement de la partie (comme
  `SessionReseau._annonce`, qui n'annonce plus rien une fois la partie lancée). Sans RETRAIT, l'entrée
  expire **30 s après la dernière annonce**. RETRAIT n'agit que sur l'entrée de la clé
  (IP source, port) de l'émetteur.
- **Clé d'entrée** : `ip_source:port`. Une annonce répétée met à jour nom et joueurs.
- **Liste** : un client ouvre une connexion, envoie LISTE, lit SALONS, ferme. Le service ne renvoie
  que les entrées non expirées, au plus 100.

## Joignabilité

Avant de **lister** un salon (première annonce, puis toutes les 120 s tant qu'il est listé), le
service tente une **connexion ENet** depuis le VPS vers `ip_source:port`, puis la coupe aussitôt.
Succès : l'entrée est créée ou conservée. Échec ou dépassement de **4 s** : réponse 2, entrée
absente ou supprimée. La connexion TCP de l'annonce reste ouverte pendant la sonde (voir Délais).

Pourquoi ENet plutôt qu'un ping UDP propre : la sonde éprouve exactement ce dont un joueur aura
besoin (port ouvert, redirection de box, pare-feu, ENet qui répond) sans rien ajouter au serveur de
jeu, dont le port ne répond à aucun autre paquet. Effet de bord chez l'hôte : une place ENet est
occupée un instant ; l'`ENetMultiplayerPeer` du serveur n'émet ni `peer_connected` ni
`peer_disconnected` (vérifié à la relecture), donc rien n'entre au salon. La neuvième place d'ENet
(`PLACES_ENET`) existe justement pour qu'elle ne prenne pas celle d'un joueur.

Garde-fous de la sonde (elle est une capacité d'envoi de paquets) : jamais vers une adresse non
publique (boucle locale, privée, lien local, CGNAT 100.64/10, multicast, non spécifiée : réponse 6),
une sonde par couple (IP, port) toutes les 30 s (le résultat de la dernière est réutilisé entre-temps),
**4 sondes simultanées** au plus, aucune sonde sur une annonce invalide ou refusée par le débit.
Quand 4 sondes sont en cours, une annonce qui en exigerait une cinquième reçoit tout de suite la
réponse 7 : **pas de file d'attente** ; l'hôte réessaie à sa période suivante (10 s). Le service
n'écoute qu'en IPv4 (ENet de Godot aussi).

## Limites de débit et de mémoire

Par IP source, en seau à jetons (mémoire seule) :

| Requête            | Capacité   | Recharge                        |
| ------------------ | ---------- | ------------------------------- |
| ANNONCE et RETRAIT | 3          | 1 par 5 s                       |
| LISTE              | 5          | 1 par 2 s                       |
| Message invalide   | 5 par 60 s | au-delà : IP mise de côté 5 min |

Autres plafonds : **100 entrées** au total ; **3 entrées par IP** ; **64 connexions** simultanées,
**4 par IP** (une connexion en attente d'une sonde compte dans les deux) ; une requête par connexion ;
**1 024 IP** suivies par la table de débit (les plus anciennes sortent) et oubliées 60 s après leur
dernière requête (5 min si mises de côté). Horloge, vérificateur de joignabilité et source d'adresse
sont **injectables** (tests sans réseau, graine fixe pour le fuzz).

### Délais

Côté service : **3 s** pour recevoir le cadre complet depuis l'acceptation (connexions lentes), puis
au plus **4 s** de sonde ; une connexion vit donc **7 s au plus**. Côté jeu : **3 s** pour joindre le
service, puis **8 s** pour la réponse à une ANNONCE ou à un RETRAIT (3 + 4 s de sonde + 1 s de marge),
**3 s** pour la réponse à LISTE. Sans cela, un salon injoignable n'obtiendrait jamais la réponse 2.
L'hôte n'envoie pas une nouvelle annonce tant que la précédente attend sa réponse.

### Ordre des contrôles

Le service applique ces contrôles dans cet ordre et s'arrête au premier qui échoue.

| N°  | Contrôle                                                                                    | Si échec                                                                                                  |
| --- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 1   | IP mise de côté (5 min)                                                                     | Fermeture à l'acceptation, sans lire ni répondre                                                          |
| 2   | 64 connexions, ou 4 pour cette IP                                                           | Fermeture, sans réponse                                                                                   |
| 3   | Préfixe `u16` reçu en 3 s ; taille ≥ 3                                                      | Fermeture, sans réponse ; compte comme message invalide                                                   |
| 4   | Les 3 octets d'en-tête reçus en 3 s (même si la taille dépasse 128, on ne lit rien de plus) | Fermeture, sans réponse ; invalide                                                                        |
| 5   | `magie`                                                                                     | Fermeture, sans réponse ; invalide                                                                        |
| 6   | `version` différente                                                                        | REPONSE 1, fermeture ; ne compte pas comme invalide (un cadre de version future peut dépasser 128 octets) |
| 7   | Taille ≤ 128 octets, reste du corps reçu en 3 s                                             | REPONSE 4 (ou fermeture si le délai passe) ; invalide                                                     |
| 8   | Type connu                                                                                  | REPONSE 4 ; invalide                                                                                      |
| 9   | Seau à jetons du type                                                                       | REPONSE 3                                                                                                 |
| 10  | Décodage et bornes de champ                                                                 | REPONSE 4 ; invalide                                                                                      |
| 11  | Adresse source publique (ANNONCE)                                                           | REPONSE 6                                                                                                 |
| 12  | Quota (3 par IP, 100 au total ; une mise à jour d'entrée existante en est exemptée)         | REPONSE 5                                                                                                 |
| 13  | Sonde (ANNONCE) : résultat récent réutilisé, sinon 4 sondes au plus                         | REPONSE 7 si saturé ; REPONSE 2 si échec ; sinon REPONSE 0                                                |

RETRAIT et LISTE s'arrêtent après le contrôle 10 (RETRAIT répond toujours 0, même sans entrée). La 6ᵉ
erreur « invalide » en 60 s met l'IP de côté.

## Rôle d'hôte

Constat vérifié dans le code (voir Contexte) : l'ordre des étapes ne suffit pas, car le port est
ouvert avant que le client local ait dit bonjour, et UPnP (T7.2) l'ouvre vers l'extérieur dès la
création. On prend donc **les deux mesures** :

1. **Jeton d'hôte, prérequis de T7.3** (proposition : tâche à part **T7.2b**, soumise à Phil,
   décision 5). `SessionReseau.heberger` tire un jeton de 8 octets (`Crypto.generate_random_bytes`),
   le remet au `Serveur` et au `Client` local. Le bonjour du client local le porte ; quand un jeton
   est configuré, `Salon.ajouter` ne donne le rôle d'hôte qu'à un pair dont le jeton correspond. Un
   bonjour sans jeton ou avec un mauvais jeton entre au salon comme joueur, jamais comme hôte. Le
   salon reste sans hôte (`hote == -1`, accepté par `Salon.depuis_octets` pour un salon vide et non
   lancé) tant que le client local n'est pas arrivé ; personne ne peut lancer. Pour ce salon hébergé,
   le repli « premier pair restant devient hôte » de `Salon.retirer` est supprimé (l'hôte parti ferme
   le serveur). Le jeton se représente au bonjour qui suit `rouvrir_salon`. Le bonjour change de
   format : `Protocole.VERSION` passe de 2 à 3 (`reseau/protocole.gd`, `test_protocole.gd`,
   `test_salon.gd`, `test_serveur.gd`, `test_client.gd` mis à jour).
   **Le serveur dédié reste inchangé** : il n'a pas de client local, donc aucun jeton n'y est
   configuré ; sans jeton, l'ancienne règle (le premier pair devient hôte, repli sur le suivant)
   s'applique. `test_serveur_dedie.gd` garde ce comportement. Le jeton est donc optionnel côté
   `Serveur` et `Salon`.
2. **Ordre, porté par T7.3** : l'annonce à l'annuaire ne part qu'une fois le client local enregistré
   comme hôte. `SessionReseau` émet un signal `hote_enregistre` à la première mise à jour de salon
   où le client local est dans `joueurs` et vaut `hote` ; l'annonceur l'attend. Un salon listé a donc
   un hôte présent.

## UPnP chez l'hôte (T7.2)

Les appels de la classe `UPNP` (`discover`, `add_port_mapping`, `delete_port_mapping`,
`query_external_address`) **bloquent** : ils s'exécutent dans un `Thread` dédié, le résultat revient
par un signal appelé en différé, et l'écran de création ne gèle jamais. Règles :

- **Protocole UDP**, description « Last Tower Standing », port interne = port de jeu.
- **Découverte** : délai de 2 s (`discover`). Pas de passerelle, ou adresse externe privée (double
  NAT, CGNAT) : échec.
- **Bail fini** de 3 600 s, renouvelé toutes les 1 800 s tant que le salon est ouvert. Si la box refuse
  un bail fini, repli sur un bail 0 (permanent) ; sinon, un plantage laisserait la redirection
  ouverte. Avec le bail fini, elle expire seule.
- **Fermeture** : `delete_port_mapping` en quittant le salon et à la fermeture du jeu (le fil est
  attendu 2 s au plus). Jamais d'écriture de l'ancien état sur disque.
- **Port externe** : on demande d'abord le même port qu'en interne. Si la box refuse pour conflit, un
  seul nouvel essai sur un port tiré à l'exécution entre 49 152 et 65 535. `port_externe` (celui
  obtenu) est ce que l'annonce déclare.
- **Échec** : jamais bloquant. Le jeu affiche « Votre box n’a pas ouvert le port : les joueurs
  extérieurs ne pourront pas vous rejoindre ». Le réseau local et l'IP saisie fonctionnent.
- Test avec un double de `UPNP` injecté (succès, refus de bail, conflit de port, absence de
  passerelle, fermeture).

## Sécurité et vie privée

- Une IP publique est une **donnée personnelle**. Le service la garde **en mémoire seulement**, tant
  que le salon est ouvert (entrée) ou que la table de débit l'exige (60 s, 5 min si mise de côté) ;
  rien sur disque (conteneur en lecture seule, aucun volume), aucune sauvegarde.
- **Aucun journal d'IP** : le service n'écrit sur sa sortie que des compteurs agrégés (annonces
  acceptées et refusées par statut, salons listés) une fois par minute. Le journal Docker est borné
  (`max-size`). Ce que le noyau ou le pare-feu du VPS journalisent hors du conteneur relève de la
  configuration du VPS (à rappeler à Phil en T7.4).
- Qui voit quoi : l'annuaire voit l'IP de l'hôte (et celle de qui consulte la liste, le temps de la
  requête) ; **toute personne qui consulte la liste voit l'IP des hôtes** (il le faut pour les
  rejoindre) ; l'hôte voit l'IP des joueurs qui le rejoignent, comme aujourd'hui.
- **Notice dans le jeu**, à côté de la case « Partie publique » (cochée par défaut, décision de
  Phil), avant tout envoi : « Partie publique : votre adresse IP sera transmise à l'annuaire et
  visible des joueurs qui consultent la liste, tant que le salon est ouvert. Rien n'est conservé
  ensuite. » Le même texte va dans `docs/jouer.md`.
- Pas de TLS ni d'authentification : l'annuaire ne porte aucun secret. Un attaquant sur le chemin
  pourrait altérer une liste (rediriger vers un faux salon), ce qui n'expose pas plus qu'un salon
  public ; un faux salon doit de toute façon répondre à ENet. Écarté : la gestion de certificats
  pour un service sans secret.
- Entrées bornées (§ 11 du contexte commun) : tailles ci-dessus ; décodage sans exception ; fuzz en
  test. Le nom d'un salon est un texte libre vu de tous : il est affiché comme texte, jamais
  interprété ; aucun filtrage de contenu (à valider).
- Respect des limites de débit (§ 14) : celles du service, ci-dessus. Le client n'insiste pas :
  une annonce échouée est retentée à la période suivante, pas plus.

## Déploiement

- **Image Docker** (`service-annuaire/Dockerfile`, contexte = racine du dépôt, `.dockerignore` à la
  racine excluant `.git`, `tests/`, `docs/`, `.superpowers/`). Elle part d'une image Debian
  minimale, télécharge Godot 4.7.2 depuis la release `godotengine/godot-builds` (même archive que
  `tools/install-godot.sh`), **vérifie obligatoirement** la somme SHA-512 (`sha512sum -c`, la
  construction échoue si elle diffère ; contrairement au script, aucun repli « non vérifiée »), lance
  `godot --headless --import`, puis un utilisateur non root exécute
  `godot --headless --path . -- --annuaire`. `GODOT_VERSION` et `GODOT_SHA512` sont des `ARG` ; T7.1
  recopie la somme de la ligne de `SHA512-SUMS.txt` que lit `install-godot.sh`, et ajoute un test qui
  échoue si la version du Dockerfile diffère de celle du script (un garde-fou non branché ne garde
  rien).
- **Réseau** : port 7779/TCP publié ; aucun reverse proxy, car le service doit voir l'IP source
  réelle. Si la publication Docker masque l'IP (adresse 172.x vue), toutes les annonces recevraient
  la réponse 6 : T7.4 le vérifie de bout en bout, avec l'option `--autoriser-prive` réservée à ce
  contrôle et aux tests (elle désactive le seul rejet des adresses non publiques).
- **`docker compose`** (T7.4, `service-annuaire/compose.yaml`) : `restart: unless-stopped`, système
  de fichiers en lecture seule, journal borné, contrôle de santé par ouverture TCP du port.
- **Sous-domaine** : proposé `annuaire-lts.phamelin.fr`, enregistrement A vers le VPS, déclaré dans
  `infra` par une PR (T7.4). Je n'ai pas accès au dépôt `infra` : **ce que `projects.json` sait
  exprimer (un A vers un VPS, hors Vercel) est à vérifier en T7.4** ; sinon c'est à Phil d'en décider
  (extension d'`infra`, ou enregistrement manuel exceptionnel).
- **Écart au contexte commun, résolu** : le § 20 de `CLAUDE.commun.md` disait « ni `infra` » pour
  last-tower-standing, alors que le lot 7 (décision plus récente de Phil) demande ce sous-domaine.
  Le § 20 de `claude-context` a été corrigé par la PR #13 (fusionnée, commit 747aefb) : « `infra` ne
  déclare que le sous-domaine de l'annuaire des parties (lot 7, service sur le VPS) ». La recopie de
  ce contexte dans le jeu reste à faire.
- **Hors du dépôt, à faire par Phil** (liste donnée en T7.4) : pare-feu du VPS (7779/TCP ouvert en
  entrée, UDP sortant libre pour la sonde), Docker installé, enregistrement DNS.

## Repli

Si l'annuaire est injoignable (DNS, TCP, délais ci-dessus, version autre, réponse invalide), le jeu :
affiche en texte « Annuaire indisponible » dans la liste ; garde les salons du réseau local et le
champ d'IP saisie, inchangés ; crée le salon normalement (l'annonce échouée ne bloque jamais
« Créer une partie ») ; retente à la période suivante. L'adresse de l'annuaire est un réglage
(`annuaire_adresse`, 255 caractères au plus, vide pour désactiver). La résolution du nom se fait
sans bloquer l'image (`IP.resolve_hostname_queue_item`).

## Fichiers et tâches

Un **seul module** code et décode les messages : `reseau/annuaire_protocole.gd`
(`AnnuaireProtocole`). T7.1 le crée ; le service et le client du jeu (T7.3) l'appellent tous deux,
aucun ne code d'octets à la main. Chaque nouveau `.gd` s'accompagne de son `.uid` (étape CI).

| Fichier                                                                                                                                                                                                                                                                                  | Rôle                                                                                                                                                                                                                                                                    | Tâche                         |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `reseau/annuaire_protocole.gd`                                                                                                                                                                                                                                                           | Codec unique : constantes, cadre, 5 messages, bornes                                                                                                                                                                                                                    | T7.1 crée                     |
| `reseau/annuaire_service.gd`                                                                                                                                                                                                                                                             | Logique pure (`RefCounted`) : entrées, expiration, seaux à jetons, quotas, filtre d'adresses ; horloge et vérificateur injectés                                                                                                                                         | T7.1 crée                     |
| `reseau/annuaire_sonde.gd`                                                                                                                                                                                                                                                               | Sonde ENet asynchrone (`ENetConnection`), sans thread                                                                                                                                                                                                                   | T7.1 crée                     |
| `reseau/annuaire_serveur.gd`                                                                                                                                                                                                                                                             | Nœud : `TCPServer`, connexions, délais, compteurs de journal                                                                                                                                                                                                            | T7.1 crée                     |
| `reseau/annuaire_dedie.gd`, `scenes/annuaire.tscn`                                                                                                                                                                                                                                       | Lancement `--annuaire [--port N] [--autoriser-prive]`, comme `serveur_dedie.gd` ; codes de sortie 0, 3 (port)                                                                                                                                                           | T7.1 crée                     |
| `app/principal.gd`, `app/arguments.gd`                                                                                                                                                                                                                                                   | Aiguillage de `--annuaire` vers la scène                                                                                                                                                                                                                                | T7.1 modifie                  |
| `service-annuaire/Dockerfile`, `.dockerignore`                                                                                                                                                                                                                                           | Image (voir Déploiement)                                                                                                                                                                                                                                                | T7.1 crée                     |
| `tests/unitaires/test_annuaire_protocole.gd`, `test_annuaire_service.gd`, `test_annuaire_serveur.gd`, `test_annuaire_dockerfile.gd`                                                                                                                                                      | Aller-retour de chaque message ; fuzz à graine fixe (tailles, tronqués, UTF-8 invalide, contrôles, champs hors bornes) ; expiration ; débit ; IP vue et non déclarée ; sonde simulée puis réelle en boucle locale ; version différente ; cohérence Dockerfile et script | T7.1 crée                     |
| `reseau/protocole.gd`, `reseau/salon.gd`, `reseau/serveur.gd`, `reseau/client.gd`, `app/session_reseau.gd` (tirage et remise du jeton), `tests/unitaires/test_protocole.gd`, `test_salon.gd`, `test_serveur.gd`, `test_client.gd`, `test_serveur_dedie.gd` (inchangé : doit rester vert) | Jeton d'hôte optionnel, `Protocole.VERSION` = 3 ; **serveur dédié inchangé** (sans jeton, règle du premier pair)                                                                                                                                                        | T7.2b modifie (si décision 5) |
| `reseau/upnp_hote.gd`                                                                                                                                                                                                                                                                    | `UpnpHote` : fil dédié, découverte, bail, ouverture et fermeture du port, `port_externe` ; double de `UPNP`                                                                                                                                                             | T7.2 crée                     |
| `app/session_reseau.gd`, `ui/salon_ui.gd` ou l'écran de création, `i18n/textes_salon.csv`                                                                                                                                                                                                | Appel d'`UpnpHote`, message d'échec                                                                                                                                                                                                                                     | T7.2 modifie                  |
| `tests/unitaires/test_upnp_hote.gd`                                                                                                                                                                                                                                                      | Succès, refus de bail, conflit de port, aucune passerelle, fermeture au départ                                                                                                                                                                                          | T7.2 crée                     |
| `reseau/annuaire_client.gd`                                                                                                                                                                                                                                                              | Nœud TCP : annoncer, retirer, lister ; période de 10 s ; repli                                                                                                                                                                                                          | T7.3 crée                     |
| `app/session_reseau.gd` (signal `hote_enregistre`, annonceur), `app/principal.gd`, `app/reglages.gd` (`annuaire_adresse`, `salon_public`), `ui/connexion_ui.gd` (liste fusionnée, case, notice), `i18n/textes_menu.csv`                                                                  | Intégration dans le jeu                                                                                                                                                                                                                                                 | T7.3 modifie                  |
| `tests/unitaires/test_annuaire_client.gd` (et ceux de réglages, de la liste)                                                                                                                                                                                                             | Annonce, retrait, liste, doublons, repli                                                                                                                                                                                                                                | T7.3 crée                     |
| `service-annuaire/compose.yaml`, `README.md`, `docs/jouer.md`                                                                                                                                                                                                                            | Déploiement et notice ; retrait de « À venir »                                                                                                                                                                                                                          | T7.4 crée ou modifie          |
| PR vers `infra` (`projects.json`)                                                                                                                                                                                                                                                        | Sous-domaine                                                                                                                                                                                                                                                            | T7.4                          |

**Ordre** : T7.0 validée, puis **{T7.1, T7.2b}** (fichiers disjoints), puis **T7.2** (après T7.2b : les
deux touchent `app/session_reseau.gd`), puis T7.3, puis T7.4. Le plan prévoyait {T7.1, T7.2} en
parallèle ; T7.2b est **proposée** (décision 5). Si Phil la refuse, le jeton passe dans T7.3 ou le
suivi « rôle d'hôte » de la fin du plan reste ouvert. Si elle est acceptée, elle couvre ce suivi.

**Doublons liste locale et annuaire** (T7.3) : une entrée d'annuaire est masquée si un salon du
réseau local a le même nom et le même port ; l'entrée locale l'emporte. Origine affichée en texte :
« Réseau local » ou « Annuaire ».

## Conséquences

- Un seul processus Godot, un seul lanceur de tests ; un service de plus à héberger et à surveiller
  sur le VPS.
- Le jeu en ligne dépend du VPS pour **trouver** un salon, jamais pour y **jouer**.
- Si la décision 5 est validée, `Protocole.VERSION` passe à 3 : les clients et serveurs de version 2 ne
  se parlent plus (déjà géré par `motif_version`).
- La sonde fait du VPS un émetteur de paquets ENet : d'où TCP, les rejets d'adresses non publiques et
  les plafonds.
- L'IP des hôtes publics est visible de tous les consultants : assumé, signalé dans la notice.
- Un salon qui n'ouvre pas son port n'est jamais listé : l'hôte le sait par le message UPnP (T7.2) et
  la réponse 2 de l'annuaire.

## Options écartées

- **Annonce UDP** (comme `Decouverte`) : source falsifiable, donc sonde réfléchissante et faux salons.
- **HTTP ou WebSocket** : plus de code et de dépendances côté service et client pour trois messages ;
  `Protocole` fournit déjà le décodage défensif.
- **Sonde par ping UDP propre** : demanderait de modifier le serveur de jeu pour répondre aux paquets
  étrangers, et n'éprouverait pas ENet.
- **Adresse déclarée par le client** : ouvre la réflexion et la pollution de la liste ; écartée par
  Phil.
- **Relais de la partie par le VPS** : contraire au principe (hôte local, aucune donnée de jeu).
- **Service Node ou autre langage** : deuxième pile, deuxième lanceur de tests.
- **Ordre des étapes seul pour le rôle d'hôte** : laisse le créneau entre ouverture du port et
  enregistrement du client local, et le port UPnP déjà ouvert.
- **Tout stocker sur disque ou journaliser les IP** : inutile et contraire à la vie privée.

## Décisions à valider par Phil

1. **Transport** : TCP binaire maison, une requête par connexion. Raison : adresse source non
   falsifiable. **Écart au principe : l'IP est vue, le port est déclaré** (TCP ne donne pas le port
   UDP de jeu ; la sonde ne vise que l'IP de l'émetteur). Écartés : UDP, HTTP, WebSocket.
2. **Port du service** : 7779/TCP (7777 jeu UDP, 7778 découverte locale). Écarté : 443 (inutile sans
   proxy).
3. **Sous-domaine** : `annuaire-lts.phamelin.fr`, enregistrement A seul, sans proxy. Faisabilité dans
   `infra` à vérifier en T7.4.
4. **Joignabilité** : sonde ENet depuis le VPS, avant de lister, puis toutes les 120 s ; échec = pas
   listé ou retiré. Écartés : ping UDP propre, aucune vérification.
5. **Rôle d'hôte** : jeton d'hôte optionnel (bonjour en version 3, **suppression du repli « premier
   pair restant » pour le salon hébergé**, serveur dédié inchangé) **et** annonce après enregistrement
   de l'hôte ; nouvelle tâche T7.2b avant T7.2 et T7.3. Écarté : ordre seul (laisse le créneau
   d'usurpation).
6. **Limites de débit** : annonce et retrait 3 en rafale puis 1 par 5 s, liste 5 puis 1 par 2 s, 5
   messages invalides par minute avant 5 min d'exclusion, ordre des contrôles du tableau. Raison : un
   hôte légitime émet 1 annonce par 10 s.
7. **Cycle** : annonce toutes les 10 s, expiration 30 s (fixée par Phil), RETRAIT explicite à la
   fermeture.
8. **Plafonds** : 100 entrées, 3 par IP, 64 connexions dont 4 par IP, 4 sondes simultanées, nom de 24
   caractères.
9. **Adresses** : IPv4 publiques seulement ; boucle locale, privée, CGNAT et assimilées refusées
   (réponse 6), sauf `--autoriser-prive` pour les tests et la vérification de T7.4.
10. **Versions** : version d'annuaire stricte (autre version = « Annuaire incompatible ») ; version de
    jeu listée et marquée « autre version », jamais filtrée. Écarté : masquer les salons d'une autre
    version.
11. **Vie privée** : mémoire seule, aucun journal d'IP, notice dans le jeu (texte ci-dessus, à
    valider mot pour mot), case « Partie publique » cochée par défaut (décision de Phil déjà prise).
12. **Docker** : Godot 4.7.2 téléchargé avec somme SHA-512 obligatoire (`ARG` plus test de cohérence
    avec le script), dépôt entier copié sauf tests et docs, utilisateur non root. Écarté : exécuter
    `install-godot.sh` tel quel (il tolère une liste de sommes injoignable).
13. **Doublons** : une entrée d'annuaire de même nom et de même port qu'un salon local est masquée.
14. **Pas de TLS ni d'authentification** : aucun secret ne transite. Écarté : certificats.
15. **Nom du salon** : texte libre sans filtrage de contenu. Écarté : liste de mots interdits (coût,
    contournable).
16. **Valeur par défaut du réglage** : `annuaire_adresse = annuaire-lts.phamelin.fr:7779`, modifiable
    et vidable dans les réglages.
17. **UPnP** : UDP, bail de 3 600 s renouvelé toutes les 1 800 s (repli bail 0 si la box refuse), fil
    dédié, découverte 2 s, un seul nouvel essai sur un port aléatoire 49 152 à 65 535 en cas de
    conflit. Écarté : bail permanent d'emblée (redirection orpheline après plantage).
18. **Délais et sondes saturées** : service 3 s pour recevoir le cadre puis 4 s de sonde ; jeu 8 s pour
    la réponse à une annonce, 3 s pour une liste ; 5ᵉ sonde simultanée refusée par la réponse 7, sans
    file. Écarté : file d'attente (connexions retenues, plafonds saturés).
