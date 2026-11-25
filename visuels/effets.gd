class_name Effets
extends Node2D
## Tirs, impacts, anneaux, traits et objets au sol de l'arène 2D, pris dans un pool plafonné.
## Chaque type de dégâts a sa forme (le trait, la flèche du pack, le disque, la dynamite du
## pack, le losange) : on le reconnaît sans la couleur, qui ne fait que la souligner. Au-delà de
## `PLAFOND` effets vivants, les nouveaux sont ignorés et aucun nœud n'est créé de plus.
## L'événement d'arène (`VueArene.evenements`) peut porter deux clés facultatives : `genre` (le
## `kind` de l'effet d'arme) et `statut` ; sans elles, le genre se déduit de l'événement.

const PLAFOND: int = 200
## Aucun effet n'est opaque : la tour reste lisible dessous.
const ALPHA_MAX: float = 0.85
const DUREE_TIR: float = 0.18
const DUREE_TRAIT: float = 0.2
const DUREE_IMPACT: float = 0.35
const DUREE_ANNEAU: float = 0.45
const DUREE_EXPLOSION: float = 0.5
const DUREE_FEU: float = 0.5
## Durée de vie la plus longue d'un effet qui n'est pas un objet au sol.
const DUREE_MAX: float = 0.5
## Une mine ou un piège qui n'a jamais servi finit par s'effacer.
const DUREE_SOL_MAX: float = 60.0
## Les familles dont la mort est l'explosion du pack (identifiants de `data/ennemis.json`).
const FAMILLES_EXPLOSIVES: Array[String] = ["tonneau_de_poudre", "artificier_de_fumee"]
const COUCHE_DESSUS: int = 0
const COUCHE_SOL: int = 1

## Taille d'un impact sans rayon, en pixels du monde.
const TAILLE_IMPACT: float = 90.0
const TAILLE_PROJECTILE: float = 40.0
const EPAISSEUR_TRAIT: float = 8.0
const ARC_DYNAMITE: float = 70.0
const ECHELLE_FLECHE: float = 2.0
const ECHELLE_DYNAMITE: float = 1.3
## Écart (px) en deçà duquel un impact « est » l'endroit d'une mine ou d'un piège.
const TOLERANCE_SOL: float = 2.0
## Rayon d'une explosion de mort, en unités de jeu.
const RAYON_MORT: float = 110.0

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
const COULEURS_STATUT: Dictionary = {
	"givre": Color(0.7, 0.9, 1.0),
	"poison": Color(0.5, 0.82, 0.35),
	"etourdissement": Color(1.0, 0.88, 0.35),
}
const FORMES_STATUT: Dictionary = {
	"givre": "flocon", "poison": "bulles", "etourdissement": "croix_plus", "brulure": "feu"
}

## Textures de formes simples, dessinées une fois pour toutes (blanches : `modulate` les teinte).
static var _formes: Dictionary = {}

## Où poser les objets au sol (mines, pièges, flammes). Sans valeur : sous les autres effets.
var parent_sol: Node2D = null

var _libres: Array = [[], []]
var _vivants: Array[Dictionary] = []
var _nb_noeuds: int = 0
var _tous: Array[Sprite2D] = []
var _textures: Dictionary = {}


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


func taille_du_premier() -> float:
	if _vivants.is_empty():
		return 0.0
	return (_vivants[0]["n"] as Sprite2D).scale.x


## Éteint tout : chaque nœud revient au pool.
func vider() -> void:
	for i: int in range(_vivants.size() - 1, -1, -1):
		_liberer(i)


## `evenement` : {k, de, vers, type_degats, rayon} d'une `VueArene`, avec `genre` et `statut` en
## plus si on les connaît. Rend vrai si au moins un effet a été créé ; une mort est laissée à
## l'arène (crâne du pack) ou à `exploser`.
func ajouter(evenement: Dictionary) -> bool:
	var k: String = evenement.get("k", "")
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
	if k == "tir":
		return _tir(type_degats, genre, de, vers)
	return _impact(type_degats, genre, de, vers, rayon, statut)


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


## Une explosion du pack à `ou` (unités de jeu) : la mort d'un tonneau ou d'un artificier.
func exploser(ou: Vector2) -> bool:
	return not _explosion(Apparence.vers_pixels(ou), RAYON_MORT).is_empty()


func avancer(delta: float) -> void:
	for i: int in range(_vivants.size() - 1, -1, -1):
		var effet: Dictionary = _vivants[i]
		var age: float = float(effet["age"]) + delta
		effet["age"] = age
		if age >= float(effet["duree"]):
			_liberer(i)
		else:
			_poser(effet)


# --- Création ----------------------------------------------------------------------------------


func _tir(type_degats: int, genre: String, de: Vector2, vers: Vector2) -> bool:
	var rendu_arme: Dictionary = rendu(type_degats, genre)
	var couleur: Color = COULEURS[type_degats]
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
	var effet: Dictionary = _creer(forme, "vol", DUREE_TIR, couleur, COUCHE_DESSUS)
	if effet.is_empty():
		return false
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	effet["taille"] = TAILLE_PROJECTILE
	_poser(effet)
	return true


func _impact(
	type_degats: int, genre: String, de: Vector2, vers: Vector2, rayon: float, statut: String
) -> bool:
	var couleur: Color = COULEURS[type_degats]
	var depart: Vector2 = Apparence.vers_pixels(de)
	var arrivee: Vector2 = Apparence.vers_pixels(vers)
	var cree: bool = false
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
			cree = _trait(type_degats, depart, arrivee, couleur)
	else:
		cree = _burst(type_degats, genre, arrivee, rayon, couleur)
	if statut != "" and FORMES_STATUT.has(statut):
		cree = _statut(statut, arrivee) or cree
	return cree


func _burst(type_degats: int, genre: String, ou: Vector2, rayon: float, couleur: Color) -> bool:
	var taille: float = rayon * Apparence.PX_PAR_UNITE * 2.0 if rayon > 0.0 else TAILLE_IMPACT
	var explose: bool = type_degats == Types.TypeDegats.SIEGE or genre == "zone" or rayon > 0.0
	var cree: bool = false
	if explose:
		cree = not _explosion(ou, taille * 0.5 / Apparence.PX_PAR_UNITE).is_empty()
	if type_degats != Types.TypeDegats.SIEGE:
		var effet: Dictionary = _creer(
			IMPACTS[type_degats], "burst", DUREE_IMPACT, couleur, COUCHE_DESSUS
		)
		if not effet.is_empty():
			effet["depart"] = ou
			effet["taille"] = taille if not explose else minf(taille, TAILLE_IMPACT)
			_poser(effet)
			cree = true
	return cree


func _trait(type_degats: int, depart: Vector2, arrivee: Vector2, couleur: Color) -> bool:
	var effet: Dictionary = _creer(
		TRAITS[type_degats], "trait", DUREE_TRAIT, couleur, COUCHE_DESSUS
	)
	if effet.is_empty():
		return false
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	_poser(effet)
	return true


func _statut(statut: String, ou: Vector2) -> bool:
	var forme: String = FORMES_STATUT[statut]
	if statut == "brulure":
		var feu: Dictionary = _creer("feu", "image", DUREE_FEU, Color.WHITE, COUCHE_DESSUS)
		if feu.is_empty():
			return false
		feu["depart"] = ou
		feu["taille"] = TAILLE_IMPACT
		_poser(feu)
		return true
	var couleur: Color = COULEURS_STATUT[statut]
	var effet: Dictionary = _creer(forme, "burst", DUREE_IMPACT, couleur, COUCHE_DESSUS)
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
	if _vivants.size() >= PLAFOND:
		return {}
	var noeud: Sprite2D = _prendre(couche)
	_habiller(noeud, forme)
	noeud.modulate = Color(couleur, ALPHA_MAX)
	noeud.visible = true
	var effet := {
		"n": noeud,
		"forme": forme,
		"anim": anim,
		"age": 0.0,
		"duree": duree,
		"couche": couche,
		"depart": Vector2.ZERO,
		"arrivee": Vector2.ZERO,
		"taille": TAILLE_IMPACT,
		"image": -1,
	}
	_vivants.append(effet)
	return effet


## Texture, région et ancrage d'une forme. Les images du pack restent nettes, les formes dessinées
## sont lissées.
func _habiller(noeud: Sprite2D, forme: String) -> void:
	noeud.rotation = 0.0
	noeud.offset = Vector2.ZERO
	noeud.region_enabled = false
	noeud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	match forme:
		"fleche":
			noeud.texture = _feuille(FEUILLE_FLECHE)
			noeud.region_enabled = true
			noeud.region_rect = REGION_FLECHE
		"dynamite", "mine":
			noeud.texture = _feuille(FEUILLE_DYNAMITE)
			noeud.region_enabled = true
			noeud.region_rect = REGION_DYNAMITE
		"explosion":
			noeud.texture = _feuille(FEUILLE_EXPLOSION)
			noeud.region_enabled = true
			noeud.region_rect = Rect2(0.0, 0.0, CASE_EXPLOSION, CASE_EXPLOSION)
			noeud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		"feu":
			noeud.texture = _feuille(FEUILLE_FEU)
			noeud.region_enabled = true
			noeud.region_rect = Rect2(0.0, 0.0, CASE_FEU, CASE_FEU)
			noeud.offset = Vector2(0.0, CASE_FEU * 0.5 - PIED_FEU)
			noeud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_:
			noeud.texture = _forme(forme)


func _feuille(chemin: String) -> Texture2D:
	if not _textures.has(chemin):
		_textures[chemin] = load(Apparence.RACINE + chemin) as Texture2D
	return _textures[chemin]


# --- Mouvement ---------------------------------------------------------------------------------


func _poser(effet: Dictionary) -> void:
	var noeud: Sprite2D = effet["n"]
	var t: float = clampf(float(effet["age"]) / float(effet["duree"]), 0.0, 1.0)
	var depart: Vector2 = effet["depart"]
	var arrivee: Vector2 = effet["arrivee"]
	var taille: float = effet["taille"]
	var forme: String = effet["forme"]
	var alpha: float = ALPHA_MAX
	match String(effet["anim"]):
		"vol":
			noeud.position = depart.lerp(arrivee, t)
			var sens: Vector2 = arrivee - depart
			_orienter_vol(noeud, forme, sens, t, taille)
		"burst":
			noeud.position = depart
			noeud.rotation = t * 0.8 if forme == "croix_plus" or forme == "flocon" else 0.0
			noeud.scale = Vector2.ONE * _echelle(forme, taille) * lerpf(0.3, 1.0, t)
			alpha = lerpf(ALPHA_MAX, 0.0, t)
		"anneau":
			noeud.position = depart
			noeud.scale = Vector2.ONE * _echelle("anneau", taille) * lerpf(0.1, 1.0, t)
			alpha = lerpf(ALPHA_MAX, 0.0, t)
		"trait":
			var sens: Vector2 = arrivee - depart
			noeud.position = depart.lerp(arrivee, 0.5)
			noeud.rotation = sens.angle()
			noeud.scale = Vector2(maxf(sens.length(), 1.0) / 64.0, EPAISSEUR_TRAIT / 8.0)
			alpha = lerpf(ALPHA_MAX, 0.0, t)
		"image":
			noeud.position = depart
			_image(effet, noeud, forme, t, taille)
		"sol":
			noeud.position = depart
			noeud.rotation = 0.0
			noeud.scale = Vector2.ONE * _echelle(forme, taille)
			var pouls: float = 0.5 + 0.5 * sin(float(effet["age"]) * 4.0)
			alpha = lerpf(ALPHA_MAX * 0.6, ALPHA_MAX, pouls)
	if noeud.modulate.a != alpha:
		noeud.modulate.a = alpha


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
		"losange":
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


# --- Formes dessinées --------------------------------------------------------------------------


func _forme(nom: String) -> Texture2D:
	if not _formes.has(nom):
		_formes[nom] = ImageTexture.create_from_image(_dessiner(nom))
	return _formes[nom]


static func _dessiner(nom: String) -> Image:
	var taille := Vector2i(64, 8) if nom.begins_with("trait") else Vector2i(32, 32)
	if nom == "anneau":
		taille = Vector2i(64, 64)
	var image := Image.create(taille.x, taille.y, false, Image.FORMAT_RGBA8)
	var centre := Vector2(taille) * 0.5
	for y: int in taille.y:
		for x: int in taille.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var plein: float = _couverture(nom, p, centre, taille)
			if plein > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(plein, 0.0, 1.0)))
	return image


## Opacité (0 à 1) de la forme `nom` au point `p`, bords adoucis sur un pixel.
static func _couverture(nom: String, p: Vector2, centre: Vector2, taille: Vector2i) -> float:
	var d: Vector2 = p - centre
	var rayon: float = centre.x
	match nom:
		"disque", "halo":
			var plein: float = rayon - d.length()
			return plein if nom == "disque" else minf(plein, 0.5 + 0.5 * plein / rayon)
		"anneau":
			return minf(rayon - d.length(), d.length() - (rayon - 4.0))
		"losange":
			return rayon - (absf(d.x) + absf(d.y))
		"trait":
			return minf(centre.y - absf(d.y) + 0.5, minf(p.x, taille.x - p.x))
		"trait_ondule":
			var y: float = sin(p.x / taille.x * TAU * 2.0) * 2.5
			return 1.6 - absf(d.y - y)
		"trait_zigzag":
			var y: float = absf(fposmod(p.x / taille.x * 6.0, 2.0) - 1.0) * 5.0 - 2.5
			return 1.6 - absf(d.y - y)
		"entaille":
			return 2.0 - minf(absf(d.x - d.y), absf(d.x + d.y)) * 0.7 if d.length() < rayon else 0.0
		"pointes", "piege":
			return _rayons(d, rayon, 8, 0.0, 1.6)
		"etoile":
			return _rayons(d, rayon, 4, PI * 0.25, 2.6)
		"flocon":
			return _rayons(d, rayon, 6, 0.0, 1.6)
		"croix_plus":
			return maxf(_rayons(d, rayon * 0.85, 4, 0.0, 3.0), 3.0 - d.length())
		"bulles":
			var meilleur: float = -1.0
			for c: Vector2 in [Vector2(-7, 5), Vector2(6, 2), Vector2(-1, -8)]:
				meilleur = maxf(meilleur, 5.0 - (d - c).length())
			return meilleur
	return 0.0


## Opacité d'une étoile à `n` branches : distance au plus proche rayon, de longueur `longueur`.
static func _rayons(
	d: Vector2, longueur: float, n: int, decalage: float, epaisseur: float
) -> float:
	var meilleur: float = -1.0
	var angle_pas: float = TAU / float(n) if n != 6 else PI / 3.0
	for k: int in n:
		var sens := Vector2.from_angle(decalage + angle_pas * k)
		var along: float = clampf(d.dot(sens), 0.0, longueur)
		meilleur = maxf(meilleur, epaisseur * 0.5 - (d - sens * along).length() + 0.5)
	return meilleur
