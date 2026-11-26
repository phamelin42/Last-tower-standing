class_name Effets
extends Node2D
## Tirs, impacts, anneaux, traits et objets au sol de l'arène 2D, pris dans un pool plafonné.
## Chaque type de dégâts a sa forme (le trait, la flèche du pack, le disque, la dynamite du
## pack, le losange) : on le reconnaît sans la couleur, qui ne fait que la souligner. Au-delà de
## `PLAFOND` effets vivants, les nouveaux sont ignorés et aucun nœud n'est créé de plus.
## L'événement d'arène (`VueArene.evenements`) peut porter deux clés facultatives : `genre` (le
## `kind` de l'effet d'arme) et `statut` ; sans elles, le genre se déduit de l'événement.

## Un impact vient de devenir visible (à l'arrivée de son projectile, s'il en a un) : point en
## unités de jeu, rayon en unités de jeu (0 pour un coup simple). L'arène en fait réagir les
## ennemis. `fort` : le coup gèle son effet (zone, siège, explosion) et donc ses ennemis ; jamais
## une aura ni une onde.
signal impact_visible(ou: Vector2, rayon: float, fort: bool)

## Un coup se joue en images à 60 i/s : les durées ci-dessous sont des nombres d'images.
const IMAGE: float = 1.0 / 60.0

const PLAFOND: int = 200
## Aucun effet n'est opaque : la tour reste lisible dessous.
const ALPHA_MAX: float = 0.85
## Le projectile vole 7 images : l'impact attend son arrivée (`_impact`).
const DUREE_TIR: float = 7.0 * IMAGE
const DUREE_TRAIT: float = 0.2
## L'impact : pic (images 0 à 3), retour à la taille normale (3 à 6), dissipation (6 à 18).
const DUREE_IMPACT: float = 18.0 * IMAGE
const DUREE_STATUT: float = 0.35
## Un disque de 260 px à chaque coup encaissé : au plus un toutes les 0,34 s (WCAG 2.3.1).
const INTERVALLE_ABSORPTION: float = 0.34
const DUREE_ANNEAU: float = 0.45
const DUREE_EXPLOSION: float = 0.5
const DUREE_FEU: float = 0.5
## Durée de vie la plus longue d'un effet qui n'est pas un objet au sol.
const DUREE_MAX: float = 0.5
## Une mine ou un piège qui n'a jamais servi finit par s'effacer.
const DUREE_SOL_MAX: float = 60.0
## Les modèles de sprite dont la mort est l'explosion du pack : une famille explose si son modèle
## de sprite (`Apparence.ENTITES`) en fait partie.
const MODELES_EXPLOSIFS: Array[String] = ["barrel", "tnt"]
const COUCHE_DESSUS: int = 0
const COUCHE_SOL: int = 1

## Taille d'un impact sans rayon, en pixels du monde.
const TAILLE_IMPACT: float = 90.0
const TAILLE_PROJECTILE: float = 40.0
const EPAISSEUR_TRAIT: float = 8.0
## Les traînées de signature sont des bandeaux de 16 px aux traits fins : épaissies pour se lire
## au dézoom maximal.
const ECHELLE_TRAINEE: float = 3.0
const ARC_DYNAMITE: float = 70.0
const ECHELLE_FLECHE: float = 2.0
const ECHELLE_DYNAMITE: float = 1.3
## Écart (px) en deçà duquel un impact « est » l'endroit d'une mine ou d'un piège.
const TOLERANCE_SOL: float = 2.0
## Rayon d'une explosion de mort, en unités de jeu.
const RAYON_MORT: float = 110.0
## Gel d'impact : un impact de zone ou une explosion naît sur son image de pic et la tient
## `GelImpact.DUREE_GEL`. Le pic d'une explosion est sa 3e image (la boule de feu à sa taille).
const IMAGE_PIC_EXPLOSION: int = 2
const AGE_PIC_EXPLOSION: float = DUREE_EXPLOSION * (IMAGE_PIC_EXPLOSION + 0.5) / IMAGES_EXPLOSION

## Un saut de rebond démarre 3 images après le précédent ; son trait est blanc la première image.
const DECALAGE_SAUT: float = 3.0 * IMAGE
## Écart (px) en deçà duquel un impact « est » l'arrivée d'un tir, ou un saut part de l'arrivée du
## précédent.
const TOLERANCE_LIEN: float = 4.0
## Au-delà de ce reste de temps (s), un événement différé n'est pas encore échu.
const EPSILON_TEMPS: float = 0.000001

const FEUILLE_FEU := "Effects/Fire/Fire.png"
const FEUILLE_EXPLOSION := "Effects/Explosion/Explosions.png"
const FEUILLE_FLECHE := "Factions/Knights/Troops/Archer/Arrow/Arrow.png"
const FEUILLE_DYNAMITE := "Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png"

const CASE_FEU: int = 128
const IMAGES_FEU: int = 7
## Où les flammes touchent le sol dans leur case : le pied du boss.
const PIED_FEU: float = 106.0
## La flamme dépasse sous les pieds du boss, que son corps large cacherait sinon.
const DECALAGE_FLAMME: float = 10.0
const ECHELLE_FLAMME_BOSS: float = 0.5
const IMAGES_FEU_PAR_SECONDE: float = 10.0
const CASE_EXPLOSION: int = 192
const IMAGES_EXPLOSION: int = 9
## Diamètre visible de l'explosion à son plus grand, en pixels de feuille.
const DIAMETRE_EXPLOSION: float = 105.0
const CASE_DYNAMITE: int = 64
const IMAGES_DYNAMITE: int = 6
const REGION_FLECHE := Rect2(1.0, 28.0, 63.0, 14.0)
const REGION_DYNAMITE := Rect2(20.0, 2.0, 27.0, 51.0)

## Formes de projectile, d'impact et de trait par type de dégâts (`Types.TypeDegats`).
const PROJECTILES: Array[String] = ["trait", "fleche", "disque", "dynamite", "losange"]
const IMPACTS: Array[String] = ["entaille", "pointes", "halo", "explosion", "etoile"]
const TRAITS: Array[String] = ["trait", "trait", "trait_ondule", "trait", "trait_zigzag"]
## Couleurs du pack : acier, bois et paille, bleu, rouge, violet.
const COULEURS: Array[Color] = [
	Color(0.9, 0.93, 1.0),
	Color(0.95, 0.78, 0.35),
	Color(0.38, 0.62, 1.0),
	Color(0.92, 0.38, 0.28),
	Color(0.72, 0.4, 0.88),
]
## L'éclat de l'absorption par la mana : bleu, plus large qu'un impact pour couvrir la tour.
## Le soin du vol de vie : il remonte de l'ennemi vers la tour, vert menthe pour ne pas se
## confondre avec le poison.
const COULEUR_SOIN := Color(0.35, 1.0, 0.6)
const DUREE_SOIN: float = 0.45
## Taille d'un projectile à signature d'arme : plus large qu'un tir par type, pour se lire de loin.
const TAILLE_SIGNATURE: float = 56.0
## Formes que `Effets` dessine lui-même ; toutes les autres viennent de `FormesSignatures`.
const FORMES_PROPRES: Array[String] = [
	"trait",
	"disque",
	"halo",
	"anneau",
	"losange",
	"entaille",
	"pointes",
	"etoile",
	"flocon",
	"croix_plus",
	"bulles",
	"piege",
	"trait_ondule",
	"trait_zigzag",
]  # gdlint: ignore=max-line-length
const COULEUR_ABSORPTION := Color(0.3, 0.6, 1.0)
const TAILLE_ABSORPTION: float = 260.0
const COULEURS_STATUT: Dictionary = {
	"givre": Color(0.7, 0.9, 1.0),
	"poison": Color(0.5, 0.82, 0.35),
	"etourdissement": Color(1.0, 0.88, 0.35),
	"brulure": Color(1.0, 0.55, 0.2),
	"vol_de_vie": COULEUR_SOIN,
}
const FORMES_STATUT: Dictionary = {
	"givre": "flocon",
	"poison": "bulles",
	"etourdissement": "croix_plus",
	"brulure": "feu",
	"vol_de_vie": "soin"
}

## Où poser les objets au sol (mines, pièges, flammes). Sans valeur : sous les autres effets.
var parent_sol: Node2D = null
## `Donnees.ids_catalogue` (posé par `Arene2D`) : traduit l'index `arme` d'un événement en arme,
## donc en signature. Vide ou index inconnu : le rendu par type de dégâts.
var catalogue: PackedStringArray = PackedStringArray()
## Mouvement réduit (D21) : ni gel, ni rebond d'échelle, ni étincelles ; un éclat bref reste.
var mouvement_reduit: bool = false

var _libres: Array = [[], []]
var _vivants: Array[Dictionary] = []
var _nb_noeuds: int = 0
var _tous: Array[Sprite2D] = []
var _tex: TexturesEffets = TexturesEffets.new()
## Projectiles en vol, qu'un impact de la même arme au même point attend : `{type, genre, arme,
## arrivee, reste}`.
var _tirs_en_vol: Array[Dictionary] = []
## Impacts liés à un projectile ou à un saut précédent, pas encore visibles : `{reste, ...}`.
var _en_attente: Array[Dictionary] = []
## Chaîne de rebond du lot en cours (entre deux `avancer`) : arrivée et attente du dernier saut.
var _chaine_vers: Vector2 = Vector2.ZERO
var _chaine_reste: float = 0.0
var _chaine_active: bool = false
## Âge d'un effet qui naît en retard (un impact différé échu pendant un grand pas de temps).
var _age_initial: float = 0.0
## Le dernier impact joué est un coup fort : celui qui gèle son effet (voir `_burst`).
var _coup_fort: bool = false
## Temps avant la prochaine absorption admise.
var _pause_absorption: float = 0.0
var _etincelles: Etincelles = Etincelles.new(self)


## Une flamme en boucle, posée derrière l'unité qui la porte (le boss). Elle s'anime seule.
class Flamme:
	extends Sprite2D
	var _temps: float = 0.0

	func _process(delta: float) -> void:
		_temps += delta
		var image: int = int(_temps * Effets.IMAGES_FEU_PAR_SECONDE) % Effets.IMAGES_FEU
		region_rect = Rect2(image * Effets.CASE_FEU, 0.0, Effets.CASE_FEU, Effets.CASE_FEU)


static func creer_flamme() -> Sprite2D:
	var flamme := Flamme.new()
	flamme.name = "Flamme"
	flamme.texture = load(Apparence.RACINE + FEUILLE_FEU) as Texture2D
	flamme.region_enabled = true
	flamme.region_rect = Rect2(0.0, 0.0, CASE_FEU, CASE_FEU)
	flamme.offset = Vector2(0.0, CASE_FEU * 0.5 - PIED_FEU + DECALAGE_FLAMME)
	flamme.show_behind_parent = true
	flamme.scale = Vector2.ONE * ECHELLE_FLAMME_BOSS
	return flamme


## Chemins des images du pack citées par les effets.
static func textures_citees() -> PackedStringArray:
	var chemins := PackedStringArray()
	for nom: String in [FEUILLE_FEU, FEUILLE_EXPLOSION, FEUILLE_FLECHE, FEUILLE_DYNAMITE]:
		chemins.append(Apparence.RACINE + nom)
	return chemins


## Ce qu'on dessine pour un type de dégâts et un genre d'effet d'arme : `projectile` (forme du
## tir, vide s'il n'y en a pas), `impact` (forme à l'arrivée) et `sol` (objet posé, s'il y en a).
static func rendu(type_degats: int, genre: String) -> Dictionary:
	if type_degats < 0 or type_degats >= PROJECTILES.size():
		return {}
	var projectile: String = PROJECTILES[type_degats]
	var impact: String = IMPACTS[type_degats]
	var sol: String = ""
	match genre:
		"rebond":
			impact = TRAITS[type_degats]
		"aura", "onde":
			projectile = ""
			impact = "anneau"
		"zone":
			impact = "explosion"
		"piege":
			projectile = ""
			sol = "piege"
		"mine":
			projectile = ""
			sol = "mine"
			impact = "explosion"
	return {"projectile": projectile, "impact": impact, "sol": sol}


func nombre_vivants() -> int:
	return _vivants.size()


## Temps de gel d'impact qui reste au plus long gel en cours (0 sans gel).
func gel_restant() -> float:
	var reste: float = 0.0
	for e: Dictionary in _vivants:
		reste = maxf(reste, float(e["gel"]))
	return reste


func taille_pool() -> int:
	return _nb_noeuds


## Nœuds du pool encore visibles (doit retomber à zéro quand tout est fini).
func nombre_visibles() -> int:
	var n: int = 0
	for noeud: Sprite2D in _tous:
		if noeud.visible:
			n += 1
	return n


func formes_vivantes() -> PackedStringArray:
	var formes := PackedStringArray()
	for e: Dictionary in _vivants:
		formes.append(String(e["forme"]))
	return formes


func opacite_max() -> float:
	var alpha: float = 0.0
	for e: Dictionary in _vivants:
		alpha = maxf(alpha, (e["n"] as Sprite2D).modulate.a)
	return alpha


func couleur_du_premier() -> Color:
	if _vivants.is_empty():
		return Color.BLACK
	return (_vivants[0]["n"] as Sprite2D).modulate


## Départ et arrivée (pixels du monde) du premier effet vivant de cette forme ; vide sans elle.
func trajet_de(forme: String) -> Array[Vector2]:
	var trajet: Array[Vector2] = []
	for e: Dictionary in _vivants:
		if String(e["forme"]) == forme:
			trajet.append(e["depart"])
			trajet.append(e["arrivee"])
			break
	return trajet


## Échelle du premier effet vivant de cette forme, 0 sans elle.
func echelle_de(forme: String) -> float:
	for e: Dictionary in _vivants:
		if String(e["forme"]) == forme:
			return (e["n"] as Sprite2D).scale.x
	return 0.0


## Impacts liés à un projectile ou à un saut précédent, qui ne sont pas encore visibles.
func impacts_en_attente() -> int:
	return _en_attente.size()


## Les émetteurs d'étincelles créés (jamais plus de `PLAFOND_ETINCELLES`).
func emetteurs_etincelles() -> Array[CPUParticles2D]:
	return _etincelles.emetteurs()


## Les émetteurs dont la salve est en cours.
func etincelles_actives() -> Array[CPUParticles2D]:
	return _etincelles.actifs()


func couleur_de(forme: String) -> Color:
	for e: Dictionary in _vivants:
		if String(e["forme"]) == forme:
			return (e["n"] as Sprite2D).modulate
	return Color.BLACK


## La couleur d'un statut (marque sur l'ennemi touché), `Color.WHITE` pour un statut inconnu.
static func couleur_statut(statut: String) -> Color:
	return COULEURS_STATUT.get(statut, Color.WHITE)


## La signature de l'arme de l'événement, `{}` sans arme ou avec un index hors du catalogue.
func _signature(evenement: Dictionary) -> Dictionary:
	var index: Variant = evenement.get("arme")
	if typeof(index) != TYPE_INT:
		return {}
	var rang: int = index
	if rang < 0 or rang >= catalogue.size():
		return {}
	return SignaturesArmes.de(catalogue[rang])


func taille_du_premier() -> float:
	if _vivants.is_empty():
		return 0.0
	return (_vivants[0]["n"] as Sprite2D).scale.x


## Éteint tout : chaque nœud revient au pool.
func vider() -> void:
	for i: int in range(_vivants.size() - 1, -1, -1):
		_liberer(i)
	_tirs_en_vol.clear()
	_pause_absorption = 0.0
	_en_attente.clear()
	_chaine_active = false
	_etincelles.vider()


## `evenement` : {k, de, vers, type_degats, rayon} d'une `VueArene`, avec `genre` et `statut` en
## plus si on les connaît. Rend vrai si au moins un effet a été créé ; une mort est laissée à
## l'arène (crâne du pack) ou à `exploser`.
func ajouter(evenement: Dictionary) -> bool:
	var k: String = evenement.get("k", "")
	if k == "absorption":
		return _absorption(Apparence.vers_pixels(evenement.get("de", Vector2.ZERO)))
	if k != "tir" and k != "impact":
		return false
	var de: Vector2 = evenement.get("de", Vector2.ZERO)
	var vers: Vector2 = evenement.get("vers", Vector2.ZERO)
	var type_degats: int = evenement.get("type_degats", 0)
	var rayon: float = evenement.get("rayon", 0.0)
	var genre: String = _nom_champ(evenement.get("genre", ""), VueArene.GENRES_ARME)
	var statut: String = _nom_champ(evenement.get("statut", ""), VueArene.STATUTS_ARME)
	if type_degats < 0 or type_degats >= PROJECTILES.size():
		return false
	var signature: Dictionary = _signature(evenement)
	var arme: int = evenement.get("arme", -1) if typeof(evenement.get("arme")) == TYPE_INT else -1
	if k == "tir":
		return _tir(type_degats, genre, de, vers, signature, arme)
	return _impact(type_degats, genre, de, vers, rayon, statut, signature, arme)


## Le genre et le statut arrivent en index (simulation, réseau) ; un nom est accepté tel quel. Une
## valeur hors liste ou d'un autre type vaut « aucun », donc le genre se déduit de l'événement.
static func _nom_champ(valeur: Variant, noms: Array[String]) -> String:
	if typeof(valeur) == TYPE_STRING:
		return valeur
	if typeof(valeur) == TYPE_INT:
		var index: int = valeur
		if index >= 0 and index < noms.size():
			return noms[index]
	return ""


## Vrai si la mort de l'entité `id` (famille, convoi ou boss) est l'explosion du pack.
static func famille_explosive(id: String) -> bool:
	var entite: Dictionary = Apparence.ENTITES.get(id, {})
	return MODELES_EXPLOSIFS.has(String(entite.get("modele", "")))


## Une explosion du pack à `ou` (unités de jeu) : la mort d'un tonneau ou d'un artificier.
func exploser(ou: Vector2) -> bool:
	return not _explosion(Apparence.vers_pixels(ou), RAYON_MORT).is_empty()


func avancer(delta: float) -> void:
	_chaine_active = false
	_pause_absorption = maxf(_pause_absorption - delta, 0.0)
	for i: int in range(_vivants.size() - 1, -1, -1):
		var effet: Dictionary = _vivants[i]
		var age: float = float(effet["age"]) + _apres_gel(effet, delta)
		effet["age"] = age
		if age >= float(effet["duree"]):
			_liberer(i)
		else:
			_poser(effet)
	_avancer_attentes(delta)
	_etincelles.avancer(delta)


## La part de `delta` qui fait vieillir l'effet : le gel d'impact en retient le début.
func _apres_gel(effet: Dictionary, delta: float) -> float:
	var gel: float = minf(float(effet["gel"]), delta)
	var reste: float = float(effet["gel"]) - gel
	effet["gel"] = reste if reste > EPSILON_TEMPS else 0.0
	return delta - gel


## Fige l'effet sur son image de pic pour le reste de `DUREE_GEL` (rien en mouvement réduit).
func _geler(effet: Dictionary, age_pic: float) -> void:
	var reste: float = GelImpact.DUREE_GEL - _age_initial
	if mouvement_reduit or effet.is_empty() or reste <= EPSILON_TEMPS:
		return
	effet["gel"] = reste
	effet["age"] = maxf(float(effet["age"]), age_pic)


## Les projectiles arrivent ; les impacts qu'ils retenaient (ou qu'un saut précédent retenait) se
## jouent, avec l'âge qu'ils auraient eu s'ils étaient nés à l'heure.
func _avancer_attentes(delta: float) -> void:
	for i: int in range(_tirs_en_vol.size() - 1, -1, -1):
		var tir: Dictionary = _tirs_en_vol[i]
		tir["reste"] = float(tir["reste"]) - delta
		if float(tir["reste"]) <= EPSILON_TEMPS:
			_tirs_en_vol.remove_at(i)
	var echus: Array[Dictionary] = []
	for i: int in range(_en_attente.size() - 1, -1, -1):
		var attente: Dictionary = _en_attente[i]
		attente["reste"] = float(attente["reste"]) - delta
		if float(attente["reste"]) <= EPSILON_TEMPS:
			echus.push_front(attente)
			_en_attente.remove_at(i)
	for attente: Dictionary in echus:
		_age_initial = maxf(-float(attente["reste"]), 0.0)
		_impact_maintenant(
			int(attente["type"]),
			String(attente["genre"]),
			attente["de"],
			attente["vers"],
			float(attente["rayon"]),
			String(attente["statut"]),
			attente["signature"]
		)
		_age_initial = 0.0


# --- Création ----------------------------------------------------------------------------------


func _tir(
	type_degats: int,
	genre: String,
	de: Vector2,
	vers: Vector2,
	signature: Dictionary = {},
	arme: int = -1
) -> bool:
	var rendu_arme: Dictionary = rendu(type_degats, genre)
	var couleur: Color = COULEURS[type_degats]
	if not signature.is_empty():
		couleur = signature["couleur"]
	var depart: Vector2 = Apparence.vers_pixels(de)
	var arrivee: Vector2 = Apparence.vers_pixels(vers)
	var sol: String = rendu_arme["sol"]
	if sol != "":
		var objet: Dictionary = _creer(sol, "sol", DUREE_SOL_MAX, couleur, COUCHE_SOL)
		if objet.is_empty():
			return false
		objet["depart"] = arrivee
		objet["taille"] = TAILLE_PROJECTILE * 1.4
		_poser(objet)
		return true
	var forme: String = rendu_arme["projectile"]
	if forme == "":
		return false
	var taille: float = TAILLE_PROJECTILE
	if not signature.is_empty():
		forme = signature["projectile"]
		taille = TAILLE_SIGNATURE
	var effet: Dictionary = _creer(forme, "vol", DUREE_TIR, couleur, COUCHE_DESSUS)
	if effet.is_empty():
		return false
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	effet["taille"] = taille
	_poser(effet)
	if _tirs_en_vol.size() < PLAFOND:
		(
			_tirs_en_vol
			. append(
				{
					"type": type_degats,
					"genre": genre,
					"arme": arme,
					"arrivee": arrivee,
					"reste": DUREE_TIR,
				}
			)
		)
	if not signature.is_empty():
		_trainee(String(signature["trainee"]), depart, arrivee, couleur)
	return true


## La traînée de la signature : un bandeau tendu du départ à l'arrivée, qui s'efface.
func _trainee(forme: String, depart: Vector2, arrivee: Vector2, couleur: Color) -> void:
	var effet: Dictionary = _creer(forme, "trait", DUREE_TIR, couleur, COUCHE_DESSUS)
	if effet.is_empty():
		return
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	_poser(effet)


## Un impact qui répond à un tir du même lot attend l'arrivée du projectile ; un saut de rebond
## attend en plus 3 images après le précédent de sa chaîne. Les autres (aura, onde, piège, mine)
## partent tout de suite.
func _impact(
	type_degats: int,
	genre: String,
	de: Vector2,
	vers: Vector2,
	rayon: float,
	statut: String,
	signature: Dictionary = {},
	arme: int = -1
) -> bool:
	var depart: Vector2 = Apparence.vers_pixels(de)
	var arrivee: Vector2 = Apparence.vers_pixels(vers)
	var attente: float = _reprendre_tir(type_degats, genre, arme, arrivee)
	var saut: bool = genre == "rebond" or (genre == "" and rayon <= 0.0 and de.length() >= 1.0)
	if saut:
		if attente < 0.0 and _chaine_active and _chaine_vers.distance_to(depart) <= TOLERANCE_LIEN:
			attente = _chaine_reste + DECALAGE_SAUT
		if attente >= 0.0:
			_chaine_active = true
			_chaine_vers = arrivee
			_chaine_reste = attente
	if attente <= EPSILON_TEMPS:
		return _impact_maintenant(type_degats, genre, de, vers, rayon, statut, signature)
	if _en_attente.size() >= PLAFOND:
		return false
	(
		_en_attente
		. append(
			{
				"reste": attente,
				"type": type_degats,
				"genre": genre,
				"de": de,
				"vers": vers,
				"rayon": rayon,
				"statut": statut,
				"signature": signature,
			}
		)
	)
	return true


## Le temps de vol qui reste au projectile que cet impact attend, -1 s'il n'y en a pas. Un tir ne
## retient qu'un impact.
func _reprendre_tir(type_degats: int, genre: String, arme: int, arrivee: Vector2) -> float:
	for i: int in _tirs_en_vol.size():
		var tir: Dictionary = _tirs_en_vol[i]
		if (
			int(tir["type"]) == type_degats
			and String(tir["genre"]) == genre
			and int(tir["arme"]) == arme
			and (tir["arrivee"] as Vector2).distance_to(arrivee) <= TOLERANCE_LIEN
		):
			var reste: float = tir["reste"]
			_tirs_en_vol.remove_at(i)
			return reste
	return -1.0


func _impact_maintenant(
	type_degats: int,
	genre: String,
	de: Vector2,
	vers: Vector2,
	rayon: float,
	statut: String,
	signature: Dictionary = {}
) -> bool:
	var couleur: Color = COULEURS[type_degats]
	if not signature.is_empty():
		couleur = signature["couleur"]
	var depart: Vector2 = Apparence.vers_pixels(de)
	var arrivee: Vector2 = Apparence.vers_pixels(vers)
	var cree: bool = false
	_coup_fort = false
	_retirer_objet_sol(arrivee)
	var anneau: bool = (
		genre == "aura" or genre == "onde" or (genre == "" and rayon > 0.0 and de == vers)
	)
	var saut: bool = genre == "rebond" or (genre == "" and rayon <= 0.0 and de.length() >= 1.0)
	if anneau:
		var effet: Dictionary = _creer("anneau", "anneau", DUREE_ANNEAU, couleur, COUCHE_DESSUS)
		if not effet.is_empty():
			effet["depart"] = arrivee
			effet["taille"] = maxf(rayon * Apparence.PX_PAR_UNITE * 2.0, TAILLE_IMPACT)
			_poser(effet)
			cree = true
	elif saut:
		# Le premier saut part de la tour, que le tir a déjà tracée : seul le trait des suivants.
		if de.length() >= 1.0:
			cree = _trait(type_degats, depart, arrivee, couleur, signature)
	else:
		cree = _burst(type_degats, genre, arrivee, rayon, couleur, signature)
	if statut != "" and FORMES_STATUT.has(statut):
		cree = _statut(statut, arrivee) or cree
	var zone: bool = (
		anneau
		or rayon > 0.0
		or genre == "zone"
		or genre == "mine"
		or type_degats == Types.TypeDegats.SIEGE
		or String(signature.get("impact", "")) == "explosion"
	)
	var nombre: int = Etincelles.NOMBRE_ZONE if zone else Etincelles.NOMBRE_COUP
	if not mouvement_reduit:
		_etincelles.lancer(arrivee, nombre, couleur, _age_initial)
	impact_visible.emit(vers, rayon, _coup_fort)
	return cree


func _burst(
	type_degats: int,
	genre: String,
	ou: Vector2,
	rayon: float,
	couleur: Color,
	signature: Dictionary = {}
) -> bool:
	var taille: float = rayon * Apparence.PX_PAR_UNITE * 2.0 if rayon > 0.0 else TAILLE_IMPACT
	var forme: String = IMPACTS[type_degats]
	if not signature.is_empty():
		forme = signature["impact"]
	var explose: bool = (
		type_degats == Types.TypeDegats.SIEGE
		or genre == "zone"
		or rayon > 0.0
		or forme == "explosion"
	)
	var cree: bool = false
	_coup_fort = explose
	if explose:
		cree = not _explosion(ou, taille * 0.5 / Apparence.PX_PAR_UNITE).is_empty()
	# Le siège garde l'explosion du pack seule, sauf si sa signature a une autre forme d'impact.
	var dessine_forme: bool = type_degats != Types.TypeDegats.SIEGE
	if not signature.is_empty():
		dessine_forme = forme != "explosion"
	if dessine_forme:
		var effet: Dictionary = _creer(forme, "burst", DUREE_IMPACT, couleur, COUCHE_DESSUS)
		if not effet.is_empty():
			effet["depart"] = ou
			effet["taille"] = taille if not explose else minf(taille, TAILLE_IMPACT)
			if explose:
				_geler(effet, CourbesEffets.IMAGES_MONTEE_IMPACT * IMAGE)
			_poser(effet)
			cree = true
	return cree


func _trait(
	type_degats: int, depart: Vector2, arrivee: Vector2, couleur: Color, signature: Dictionary = {}
) -> bool:
	var forme: String = TRAITS[type_degats]
	if not signature.is_empty():
		forme = signature["trainee"]
	var effet: Dictionary = _creer(forme, "saut", DUREE_TRAIT, couleur, COUCHE_DESSUS)
	if effet.is_empty():
		return false
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	_poser(effet)
	return true


## L'éclat bleu de la mana qui encaisse un coup, sur la tour.
func _absorption(ou: Vector2) -> bool:
	if _pause_absorption > 0.0:
		return false
	var effet: Dictionary = _creer(
		"halo", "absorption", DUREE_IMPACT, COULEUR_ABSORPTION, COUCHE_DESSUS
	)
	if effet.is_empty():
		return false
	_pause_absorption = INTERVALLE_ABSORPTION
	effet["depart"] = ou
	effet["taille"] = TAILLE_ABSORPTION
	_poser(effet)
	return true


func _statut(statut: String, ou: Vector2) -> bool:
	var forme: String = FORMES_STATUT[statut]
	if statut == "vol_de_vie":
		# Le soin remonte de l'ennemi touché vers la tour, à l'origine du monde.
		var soin: Dictionary = _creer(forme, "vol", DUREE_SOIN, COULEUR_SOIN, COUCHE_DESSUS)
		if soin.is_empty():
			return false
		soin["depart"] = ou
		soin["arrivee"] = Vector2.ZERO
		soin["taille"] = TAILLE_IMPACT * 0.6
		_poser(soin)
		return true
	if statut == "brulure":
		var feu: Dictionary = _creer("feu", "image", DUREE_FEU, Color.WHITE, COUCHE_DESSUS)
		if feu.is_empty():
			return false
		feu["depart"] = ou
		feu["taille"] = TAILLE_IMPACT
		_poser(feu)
		return true
	var couleur: Color = couleur_statut(statut)
	var effet: Dictionary = _creer(forme, "statut", DUREE_STATUT, couleur, COUCHE_DESSUS)
	if effet.is_empty():
		return false
	effet["depart"] = ou
	effet["taille"] = TAILLE_IMPACT
	_poser(effet)
	return true


## `rayon` en unités de jeu. Rend un dictionnaire vide si le plafond est atteint.
func _explosion(ou: Vector2, rayon: float) -> Dictionary:
	var effet: Dictionary = _creer(
		"explosion", "image", DUREE_EXPLOSION, Color.WHITE, COUCHE_DESSUS
	)
	if effet.is_empty():
		return {}
	effet["depart"] = ou
	effet["taille"] = rayon * Apparence.PX_PAR_UNITE * 2.0
	_geler(effet, AGE_PIC_EXPLOSION)
	_poser(effet)
	return effet


func _retirer_objet_sol(ou: Vector2) -> void:
	for i: int in range(_vivants.size() - 1, -1, -1):
		var effet: Dictionary = _vivants[i]
		if (
			String(effet["anim"]) == "sol"
			and (effet["depart"] as Vector2).distance_to(ou) <= TOLERANCE_SOL
		):
			_liberer(i)


## Prend un nœud du pool et le prépare pour `forme`. Vide si le plafond est atteint.
func _creer(forme: String, anim: String, duree: float, couleur: Color, couche: int) -> Dictionary:
	if _vivants.size() >= PLAFOND or _age_initial >= duree:
		return {}
	var noeud: Sprite2D = _prendre(couche)
	_tex.habiller(noeud, forme)
	noeud.modulate = Color(couleur, ALPHA_MAX)
	noeud.visible = true
	var effet := {
		"n": noeud,
		"forme": forme,
		"anim": anim,
		"age": _age_initial,
		"duree": duree,
		"couleur": couleur,
		"couche": couche,
		"depart": Vector2.ZERO,
		"arrivee": Vector2.ZERO,
		"taille": TAILLE_IMPACT,
		"image": -1,
		"gel": 0.0,
		"reduit": mouvement_reduit,
	}
	_vivants.append(effet)
	return effet


# --- Mouvement ---------------------------------------------------------------------------------


func _poser(effet: Dictionary) -> void:
	var noeud: Sprite2D = effet["n"]
	var age: float = effet["age"]
	var t: float = clampf(age / float(effet["duree"]), 0.0, 1.0)
	var depart: Vector2 = effet["depart"]
	var arrivee: Vector2 = effet["arrivee"]
	var taille: float = effet["taille"]
	var forme: String = effet["forme"]
	var couleur: Color = effet["couleur"]
	var alpha: float = ALPHA_MAX
	var reduit: bool = effet["reduit"]
	var gele: bool = float(effet["gel"]) > 0.0
	match String(effet["anim"]):
		"vol":
			noeud.position = depart.lerp(arrivee, t)
			var sens: Vector2 = arrivee - depart
			_orienter_vol(noeud, forme, sens, t, taille)
			noeud.scale *= CourbesEffets.echelle_apparition_tir(age)
		"burst", "absorption":
			noeud.position = depart
			var grandeur: float = CourbesEffets.echelle_impact(age, reduit)
			noeud.scale = Vector2.ONE * _echelle(forme, taille) * grandeur
			if String(effet["anim"]) == "burst":
				couleur = couleur.lerp(Color.WHITE, CourbesEffets.blanc_impact(age, reduit, gele))
			alpha = CourbesEffets.alpha_impact(age)
		"statut":
			noeud.position = depart
			var tourne: bool = forme == "croix_plus" or forme == "flocon"
			noeud.rotation = t * 0.8 if tourne and not reduit else 0.0
			noeud.scale = (
				Vector2.ONE * _echelle(forme, taille) * (1.0 if reduit else lerpf(0.3, 1.0, t))
			)
			noeud.scale *= CourbesEffets.echelle_apparition_statut(age, reduit)
			alpha = lerpf(ALPHA_MAX, 0.0, t)
		"anneau":
			noeud.position = depart
			var ouverture: float = CourbesEffets.echelle_anneau(t, reduit)
			noeud.scale = Vector2.ONE * _echelle("anneau", taille) * ouverture
			alpha = CourbesEffets.alpha_anneau(t)
		"trait", "saut":
			var sens: Vector2 = arrivee - depart
			noeud.position = depart.lerp(arrivee, 0.5)
			noeud.rotation = sens.angle()
			var epaisseur: float = 1.0
			if FORMES_PROPRES.has(forme):
				epaisseur = EPAISSEUR_TRAIT / 8.0
			else:
				epaisseur = ECHELLE_TRAINEE
			noeud.scale = Vector2(maxf(sens.length(), 1.0) / 64.0, epaisseur)
			alpha = lerpf(ALPHA_MAX, 0.0, t)
			if String(effet["anim"]) == "saut":
				# Allumé blanc la première image, puis la couleur de l'arme qui s'éteint en t².
				if age < IMAGE:
					couleur = Color.WHITE
				alpha = lerpf(ALPHA_MAX, 0.0, t * t)
		"image":
			noeud.position = depart
			_image(effet, noeud, forme, t, taille)
			if forme == "feu":
				noeud.scale *= CourbesEffets.echelle_apparition_statut(age, reduit)
		"sol":
			noeud.position = depart
			noeud.rotation = 0.0
			noeud.scale = Vector2.ONE * _echelle(forme, taille)
			var pouls: float = 0.5 + 0.5 * sin(age * 4.0)
			alpha = lerpf(ALPHA_MAX * 0.6, ALPHA_MAX, pouls)
	var voulue := Color(couleur, alpha)
	if noeud.modulate != voulue:
		noeud.modulate = voulue


func _orienter_vol(noeud: Sprite2D, forme: String, sens: Vector2, t: float, taille: float) -> void:
	var angle: float = sens.angle() if sens.length() > 0.001 else 0.0
	match forme:
		"fleche":
			noeud.rotation = angle
			noeud.scale = Vector2.ONE * ECHELLE_FLECHE
		"dynamite":
			noeud.position.y -= sin(t * PI) * ARC_DYNAMITE
			noeud.rotation = t * TAU * 2.0
			noeud.scale = Vector2.ONE * ECHELLE_DYNAMITE
		"trait":
			noeud.rotation = angle
			noeud.scale = Vector2(taille * 2.2 / 64.0, EPAISSEUR_TRAIT / 8.0)
		"losange", "shuriken", "spirale":
			noeud.rotation = t * TAU * 2.0
			noeud.scale = Vector2.ONE * _echelle(forme, taille)
		_:
			var pouls: float = 1.0 + 0.3 * sin(t * TAU * 2.0)
			noeud.scale = Vector2.ONE * _echelle(forme, taille) * pouls


## Images du pack lues d'un bout à l'autre sur la durée de l'effet.
func _image(effet: Dictionary, noeud: Sprite2D, forme: String, t: float, taille: float) -> void:
	var nb: int = IMAGES_EXPLOSION if forme == "explosion" else IMAGES_FEU
	var case_px: int = CASE_EXPLOSION if forme == "explosion" else CASE_FEU
	var image: int = mini(int(t * nb), nb - 1)
	if image != int(effet["image"]):
		effet["image"] = image
		noeud.region_rect = Rect2(image * case_px, 0.0, case_px, case_px)
	var visible_px: float = DIAMETRE_EXPLOSION if forme == "explosion" else float(case_px) * 0.6
	noeud.scale = Vector2.ONE * taille / visible_px


## Échelle qui donne à une forme (texture de 32 px, 64 px pour l'anneau) la taille voulue en pixels.
func _echelle(forme: String, taille: float) -> float:
	match forme:
		"anneau":
			return taille / 64.0
		"mine", "dynamite":
			return taille / REGION_DYNAMITE.size.y
	if not FORMES_PROPRES.has(forme) and forme != "fleche" and forme != "explosion":
		return taille / float(FormesSignatures.TAILLE)
	return taille / 32.0


# --- Pool --------------------------------------------------------------------------------------


func _prendre(couche: int) -> Sprite2D:
	var libres: Array = _libres[couche]
	if not libres.is_empty():
		return libres.pop_back()
	var noeud := Sprite2D.new()
	noeud.name = "Effet"
	var parent: Node2D = parent_sol if couche == COUCHE_SOL and parent_sol != null else self
	parent.add_child(noeud)
	_nb_noeuds += 1
	_tous.append(noeud)
	return noeud


func _liberer(i: int) -> void:
	var effet: Dictionary = _vivants[i]
	var noeud: Sprite2D = effet["n"]
	noeud.visible = false
	(_libres[int(effet["couche"])] as Array).append(noeud)
	_vivants.remove_at(i)
