class_name AttaquesElementaires
extends Node2D
## Les attaques élémentaires des armes de la proposition D22 (`ElementsArmes`) : anticipation,
## vol, impact et dissipation tirés des planches de `assets/maison/effets_attaques/` (bandes
## horizontales, affichées à l'échelle 3, filtre `nearest`) et de quelques émetteurs de particules.
## Enfant d'`Effets`, qui ne fait qu'aiguiller : `tirer` rend la durée jusqu'à l'arrivée, que
## `Effets` donne au retard de l'impact ; `impacter` dessine l'impact à son arrivée.
##
## Durées en images à 60 i/s. Les sprites et les émetteurs sont réutilisés (pool), les particules
## ont une graine fixe : les mêmes événements donnent les mêmes images. `place` borne le nombre
## d'effets vivants (le plafond d'`Effets` vaut pour la somme des deux pools).

const IMAGE: float = 1.0 / 60.0
const DOSSIER: String = "res://assets/maison/effets_attaques/"
const ECHELLE: float = 3.0
const ALPHA_MAX: float = 0.85

## Anticipation puis vol : 3 + 7 = 10 images en direct, 3 + 11 = 14 en cloche.
const IMAGES_ANTICIPATION: int = 3
const IMAGES_VOL_DIRECT: int = 7
const IMAGES_VOL_CLOCHE: int = 11
const ECHELLE_DEPART_ANTICIPATION: float = 0.6
## L'anticipation naît au bord de la tour, côté cible.
const DECALAGE_ANTICIPATION: float = 14.0
## Barrage : chaque boule part 2 images après la précédente.
const RETARD_BARRAGE: float = 2.0 * IMAGE
const HAUTEUR_MIN_CLOCHE: float = 30.0
const ALPHA_OMBRE: float = 0.35
const ECHELLE_OMBRE_SOMMET: float = 0.7
const ECHELLE_BOMBE_SOMMET: float = 1.15
## Un éclat blanc (départ, première image d'impact) au plus trois fois par seconde (WCAG 2.3.1).
const INTERVALLE_ECLAT: float = 0.34
const IMAGES_MONTEE_IMPACT: float = 3.0
const ECHELLE_DEPART_IMPACT: float = 0.6
const IMAGES_ANNEAU: float = 4.0
const EPAISSEUR_ANNEAU: int = 4
const COTE_ANNEAU: int = 128
const COTE_CARRE: int = 4
const PLAFOND_EMETTEURS: int = 24
const GRAINE: int = 20261127
const EPSILON: float = 0.000001
## Un coup à cible unique reste petit.
const DIAMETRE_PETIT: float = 40.0

## Taille d'une image de chaque planche, en pixels.
const PLANCHES: Dictionary = {
	"boule_feu": Vector2i(16, 16),
	"braise": Vector2i(4, 4),
	"explosion_feu": Vector2i(32, 32),
	"depart": Vector2i(12, 12),
}
## Diamètre visible, en pixels de planche, de l'image la plus grande d'un impact.
const VISIBLE: Dictionary = {"explosion_feu": 28.0}

## Image de planche à chaque image à 60 i/s : le pic est dans le premier quart de l'impact.
const SEQ_EXPLOSION: Array[int] = [0, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5]
const SEQ_ANTICIPATION: Array[int] = [0, 1, 2]

const FEU: String = ElementsArmes.FEU

const CONF: Dictionary = {
	FEU:
	{
		"couleur": Color(1.0, 0.62, 0.2),
		"projectile": "boule_feu",
		"cloche": 0.0,
		"fps": 15.0,
	},
}

## Chaque nœud est un `Sprite2D` du pool ; `vivants` : `{n, kind, age, duree, ...}`.
var mouvement_reduit: bool = false
## Nombre d'effets que ce pool peut encore créer (posé par `Effets` avant chaque appel).
var place: int = 200

var _vivants: Array[Dictionary] = []
var _libres: Array[Sprite2D] = []
var _textures: Dictionary = {}
var _anneau: Texture2D = null
var _pause_eclat: float = 0.0
var _nb_salves: int = 0
var _nb_effets: int = 0
var _emetteurs: Array[Dictionary] = []
var _carre: Texture2D = null
var _degrade: Gradient = null


## Vrai si `element` a des attaques dessinées ici.
static func connait(element: String) -> bool:
	return CONF.has(element)


## Nom de la planche du projectile de `element`, `""` sans projectile.
static func planche_projectile(element: String) -> String:
	return String((CONF.get(element, {}) as Dictionary).get("projectile", ""))


func nombre_vivants() -> int:
	return _vivants.size()


## Les émetteurs dont la salve ou la traînée est en cours.
func particules_actives() -> int:
	var n: int = 0
	for e: Dictionary in _emetteurs:
		if float(e["reste"]) > 0.0:
			n += 1
	return n


## L'état des sprites vivants dont la planche est `planche` : position, rotation, échelle, taille
## affichée (pixels), visibilité et opacité.
func etats(planche: String) -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	for e: Dictionary in _vivants:
		if String(e["planche"]) != planche:
			continue
		var n: Sprite2D = e["n"]
		(
			liste
			. append(
				{
					"position": n.position,
					"rotation": n.rotation,
					"echelle": n.scale,
					"taille": n.region_rect.size * n.scale.abs(),
					"diametre": float(e["diametre"]),
					"visible": n.visible,
					"alpha": n.modulate.a,
				}
			)
		)
	return liste


## Plus grand diamètre (pixels) qu'un effet vivant doit montrer à son plus grand.
func diametre_max() -> float:
	var d: float = 0.0
	for e: Dictionary in _vivants:
		d = maxf(d, float(e["diametre"]))
	return d


func opacite_max() -> float:
	var alpha: float = 0.0
	for e: Dictionary in _vivants:
		alpha = maxf(alpha, (e["n"] as Sprite2D).modulate.a)
	return alpha


func vider() -> void:
	for i: int in range(_vivants.size() - 1, -1, -1):
		_liberer(i)
	for e: Dictionary in _emetteurs:
		e["reste"] = 0.0
		e["suit"] = null
		(e["n"] as CPUParticles2D).emitting = false
	_pause_eclat = 0.0


## L'anticipation puis le vol d'un projectile de `element`, de `depart` à `arrivee` (pixels du
## monde). `retard` : attente avant l'anticipation (les boules d'un barrage). Rend le temps
## jusqu'à l'arrivée, anticipation et retard compris, ou -1 si rien n'a pu être créé.
func tirer(element: String, depart: Vector2, arrivee: Vector2, retard: float = 0.0) -> float:
	if not CONF.has(element):
		return -1.0
	var conf: Dictionary = CONF[element]
	var cloche: bool = float(conf["cloche"]) > 0.0
	var images_vol: int = IMAGES_VOL_CLOCHE if cloche else IMAGES_VOL_DIRECT
	var attente: float = retard + IMAGES_ANTICIPATION * IMAGE
	var vol: float = images_vol * IMAGE
	var sens: Vector2 = (arrivee - depart).normalized()
	var anticipation: Dictionary = _nouveau("anticipation", "depart", IMAGES_ANTICIPATION * IMAGE)
	if anticipation.is_empty():
		return -1.0
	anticipation["age"] = -retard
	anticipation["depart"] = depart + sens * DECALAGE_ANTICIPATION
	anticipation["sens"] = sens
	anticipation["couleur"] = conf["couleur"]
	anticipation["seq"] = _sequence(SEQ_ANTICIPATION, _eclat_permis())
	var planche: String = String(conf["projectile"])
	if planche != "":
		var projectile: Dictionary = _nouveau("vol", planche, vol)
		if not projectile.is_empty():
			projectile["age"] = -attente
			projectile["depart"] = depart
			projectile["arrivee"] = arrivee
			projectile["couleur"] = Color.WHITE
			projectile["fps"] = float(conf["fps"])
			projectile["cloche"] = float(conf["cloche"])
			_poser(projectile)
			_suivre_vol(element, projectile)
	_poser(anticipation)
	return attente + vol


## Dessine l'impact de `element` en `ou` (pixels du monde). `rayon_px` : 0 pour une cible unique.
## `fort` : un coup de siège, dont le pic est tenu `GelImpact.DUREE_GEL`. `age` : le temps déjà
## écoulé depuis l'arrivée (un impact en retard). Rend vrai si un effet a été créé.
func impacter(
	element: String,
	ou: Vector2,
	rayon_px: float,
	fort: bool = false,
	_de: Vector2 = Vector2.ZERO,
	age: float = 0.0
) -> bool:
	if not CONF.has(element):
		return false
	var cree: bool = false
	match element:
		FEU:
			cree = _impact_feu(ou, rayon_px, fort, age)
	return cree


func avancer(delta: float) -> void:
	_pause_eclat = maxf(_pause_eclat - delta, 0.0)
	for i: int in range(_vivants.size() - 1, -1, -1):
		var effet: Dictionary = _vivants[i]
		var gel: float = minf(float(effet["gel"]), delta)
		var reste: float = float(effet["gel"]) - gel
		effet["gel"] = reste if reste > EPSILON else 0.0
		effet["age"] = float(effet["age"]) + delta - gel
		if float(effet["age"]) >= float(effet["duree"]):
			_liberer(i)
		else:
			_poser(effet)
	for e: Dictionary in _emetteurs:
		_avancer_emetteur(e, delta)


# --- Éléments ----------------------------------------------------------------------------------


## Un cœur de feu à la moitié du rayon, l'anneau au rayon exact, six braises.
func _impact_feu(ou: Vector2, rayon_px: float, fort: bool, age: float) -> bool:
	var zone: bool = rayon_px > 0.0
	var diametre: float = rayon_px if zone else DIAMETRE_PETIT
	var coeur: Dictionary = _image_impact("explosion_feu", ou, diametre, SEQ_EXPLOSION, age)
	var cree: bool = not coeur.is_empty()
	if cree and fort:
		_geler(coeur, age, IMAGES_MONTEE_IMPACT * IMAGE)
	if zone:
		cree = _anneau_impact(ou, rayon_px * 2.0, 18, age, CONF[FEU]["couleur"]) or cree
	_salve(ou, 6, CONF[FEU]["couleur"], 15.0 * IMAGE, 40.0, 110.0, Vector2(0.0, -80.0), 1.5)
	return cree


# --- Effets ------------------------------------------------------------------------------------


## Un effet du pool ; `{}` si `place` est atteint.
func _nouveau(kind: String, planche: String, duree: float) -> Dictionary:
	if _vivants.size() >= place:
		return {}
	var n: Sprite2D = _prendre()
	var taille: Vector2i = PLANCHES.get(planche, Vector2i(COTE_ANNEAU, COTE_ANNEAU))
	n.texture = _texture(planche)
	n.region_enabled = true
	n.region_rect = Rect2(0.0, 0.0, taille.x, taille.y)
	n.rotation = 0.0
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.modulate = Color(1.0, 1.0, 1.0, ALPHA_MAX)
	n.visible = true
	_nb_effets += 1
	var effet: Dictionary = {
		"id": _nb_effets,
		"n": n,
		"kind": kind,
		"planche": planche,
		"age": 0.0,
		"duree": duree,
		"gel": 0.0,
		"diametre": 0.0,
		"depart": Vector2.ZERO,
		"arrivee": Vector2.ZERO,
		"sens": Vector2.RIGHT,
		"couleur": Color.WHITE,
		"seq": [] as Array[int],
		"image": -1,
		"echelle": ECHELLE,
		"fps": 0.0,
		"cloche": 0.0,
	}
	_vivants.append(effet)
	return effet


## Une planche jouée image par image : `seq` donne l'image de planche à chaque image à 60 i/s.
func _image_impact(
	planche: String, ou: Vector2, diametre: float, seq: Array[int], age: float
) -> Dictionary:
	var effet: Dictionary = _nouveau("image", planche, seq.size() * IMAGE)
	if effet.is_empty() or age >= float(effet["duree"]):
		if not effet.is_empty():
			_liberer(_vivants.size() - 1)
		return {}
	effet["age"] = age
	effet["depart"] = ou
	effet["diametre"] = diametre
	effet["echelle"] = diametre / float(VISIBLE[planche])
	effet["seq"] = _sequence(seq, _eclat_permis())
	_poser(effet)
	return effet


func _anneau_impact(ou: Vector2, diametre: float, images: int, age: float, couleur: Color) -> bool:
	var effet: Dictionary = _nouveau("anneau", "", images * IMAGE)
	if effet.is_empty():
		return false
	effet["age"] = age
	effet["depart"] = ou
	effet["diametre"] = diametre
	effet["couleur"] = couleur
	effet["echelle"] = diametre / float(COTE_ANNEAU)
	(effet["n"] as Sprite2D).texture = _texture_anneau()
	(effet["n"] as Sprite2D).region_rect = Rect2(0.0, 0.0, COTE_ANNEAU, COTE_ANNEAU)
	(effet["n"] as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_poser(effet)
	return true


## Fige l'effet sur son pic pour le reste de `GelImpact.DUREE_GEL` (rien en mouvement réduit).
func _geler(effet: Dictionary, age: float, age_pic: float) -> void:
	var reste: float = GelImpact.DUREE_GEL - age
	if mouvement_reduit or reste <= EPSILON:
		return
	effet["gel"] = reste
	effet["age"] = maxf(float(effet["age"]), age_pic)


## La séquence d'images ; si l'éclat blanc n'est pas permis, la première image copie la deuxième.
func _sequence(base: Array[int], eclat: bool) -> Array[int]:
	var seq: Array[int] = base.duplicate()
	if not eclat and seq.size() > 1:
		seq[0] = seq[1]
	return seq


func _eclat_permis() -> bool:
	if _pause_eclat > 0.0:
		return false
	_pause_eclat = INTERVALLE_ECLAT
	return true


func _suivre_vol(element: String, vol: Dictionary) -> void:
	if element == FEU:
		_trainee(vol, 4, 15.0 * IMAGE, CONF[FEU]["couleur"])


# --- Mouvement ---------------------------------------------------------------------------------


func _poser(effet: Dictionary) -> void:
	var n: Sprite2D = effet["n"]
	var age: float = effet["age"]
	if age < 0.0:
		n.visible = false
		return
	n.visible = true
	var duree: float = effet["duree"]
	var t: float = clampf(age / duree, 0.0, 1.0)
	var couleur: Color = effet["couleur"]
	var alpha: float = ALPHA_MAX
	var echelle: float = float(effet["echelle"])
	match String(effet["kind"]):
		"anticipation":
			n.position = effet["depart"]
			echelle = lerpf(ECHELLE_DEPART_ANTICIPATION, 1.0, t) * ECHELLE
			_image(effet, int((effet["seq"] as Array[int])[mini(int(age / IMAGE), 2)]))
		"vol":
			_poser_vol(effet, n, t, age)
			echelle = ECHELLE
		"image":
			n.position = effet["depart"]
			var seq: Array[int] = effet["seq"]
			_image(effet, seq[mini(int(age / IMAGE), seq.size() - 1)])
			var montee: float = clampf(age / (IMAGES_MONTEE_IMPACT * IMAGE), 0.0, 1.0)
			echelle *= lerpf(ECHELLE_DEPART_IMPACT, 1.0, montee)
			alpha = ALPHA_MAX * (1.0 - maxf(t - 0.75, 0.0) / 0.25)
		"anneau":
			n.position = effet["depart"]
			var ouverture: float = clampf(age / (IMAGES_ANNEAU * IMAGE), 0.0, 1.0)
			echelle *= lerpf(0.3, 1.0, CourbesEffets.sortie(ouverture))
			alpha = ALPHA_MAX * 0.8 * (1.0 - maxf(t - 0.5, 0.0) / 0.5)
	n.scale = Vector2.ONE * echelle
	var voulue := Color(couleur, alpha)
	if n.modulate != voulue:
		n.modulate = voulue


func _poser_vol(effet: Dictionary, n: Sprite2D, t: float, age: float) -> void:
	var depart: Vector2 = effet["depart"]
	var arrivee: Vector2 = effet["arrivee"]
	var position: Vector2 = depart.lerp(arrivee, t)
	var sens: Vector2 = arrivee - depart
	var hauteur: float = float(effet["cloche"])
	if hauteur > 0.0:
		position.y -= sin(t * PI) * maxf(hauteur * sens.length(), HAUTEUR_MIN_CLOCHE)
	n.position = position
	n.rotation = sens.angle() if sens.length() > 0.001 else 0.0
	var fps: float = float(effet["fps"])
	if fps > 0.0:
		var images: int = int(n.texture.get_width() / float(PLANCHES[effet["planche"]].x))
		_image(effet, int(age * fps) % images)


func _image(effet: Dictionary, i: int) -> void:
	if i == int(effet["image"]):
		return
	effet["image"] = i
	var n: Sprite2D = effet["n"]
	var taille: Vector2i = PLANCHES.get(
		String(effet["planche"]), Vector2i(COTE_ANNEAU, COTE_ANNEAU)
	)
	n.region_rect = Rect2(i * taille.x, 0.0, taille.x, taille.y)


# --- Particules --------------------------------------------------------------------------------


## Une salve unique de `nombre` carrés, qui part de `ou` ; rien en mouvement réduit.
func _salve(
	ou: Vector2,
	nombre: int,
	couleur: Color,
	vie: float,
	vmin: float,
	vmax: float,
	gravite: Vector2,
	echelle: float
) -> void:
	if mouvement_reduit:
		return
	var e: Dictionary = _emetteur_libre()
	if e.is_empty():
		return
	_regler(e, ou, nombre, couleur, vie, vmin, vmax, gravite, echelle, true)
	e["reste"] = vie


## Une traînée : des carrés lâchés derrière le vol `vol` tant qu'il dure.
func _trainee(vol: Dictionary, nombre: int, vie: float, couleur: Color) -> void:
	if mouvement_reduit:
		return
	var e: Dictionary = _emetteur_libre()
	if e.is_empty():
		return
	_regler(e, vol["depart"], nombre, couleur, vie, 0.0, 20.0, Vector2(0.0, -80.0), 1.5, false)
	e["suit"] = int(vol["id"])
	e["vie"] = vie
	e["reste"] = INF
	(e["n"] as CPUParticles2D).emitting = false


func _regler(
	e: Dictionary,
	ou: Vector2,
	nombre: int,
	couleur: Color,
	vie: float,
	vmin: float,
	vmax: float,
	gravite: Vector2,
	echelle: float,
	salve: bool
) -> void:
	var p: CPUParticles2D = e["n"]
	p.position = ou
	p.amount = nombre
	p.lifetime = vie
	p.one_shot = salve
	p.explosiveness = 1.0 if salve else 0.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravite
	p.scale_amount_min = echelle
	p.scale_amount_max = echelle
	p.color = Color(couleur.lerp(Color.WHITE, 0.2), ALPHA_MAX)
	_nb_salves += 1
	p.seed = GRAINE + _nb_salves
	p.restart()
	p.emitting = true
	e["suit"] = null


func _avancer_emetteur(e: Dictionary, delta: float) -> void:
	if float(e["reste"]) <= 0.0:
		return
	var p: CPUParticles2D = e["n"]
	var suit: Variant = e["suit"]
	if suit != null:
		var vol: Dictionary = _trouver(int(suit))
		if not vol.is_empty():
			if float(vol["age"]) >= 0.0:
				p.position = (vol["n"] as Sprite2D).position
				p.emitting = true
			return
		e["suit"] = null
		p.emitting = false
		e["reste"] = float(e["vie"])
		return
	e["reste"] = float(e["reste"]) - delta
	if float(e["reste"]) <= 0.0:
		p.emitting = false


func _trouver(id: int) -> Dictionary:
	for e: Dictionary in _vivants:
		if int(e["id"]) == id:
			return e
	return {}


func _emetteur_libre() -> Dictionary:
	for e: Dictionary in _emetteurs:
		if float(e["reste"]) <= 0.0:
			return e
	if _emetteurs.size() >= PLAFOND_EMETTEURS:
		return {}
	var p := CPUParticles2D.new()
	p.name = "Particules"
	p.emitting = false
	p.local_coords = false
	p.texture = _texture_carre()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.direction = Vector2.UP
	p.spread = 180.0
	p.color_ramp = _degrade_fondu()
	p.use_fixed_seed = true
	p.z_index = 1
	add_child(p)
	var e := {"n": p, "reste": 0.0, "suit": null, "vie": 0.0}
	_emetteurs.append(e)
	return e


# --- Pool et textures --------------------------------------------------------------------------


func _prendre() -> Sprite2D:
	if not _libres.is_empty():
		return _libres.pop_back()
	var n := Sprite2D.new()
	n.name = "Attaque"
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(n)
	return n


func _liberer(i: int) -> void:
	var effet: Dictionary = _vivants[i]
	var n: Sprite2D = effet["n"]
	n.visible = false
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_libres.append(n)
	_vivants.remove_at(i)


func _texture(planche: String) -> Texture2D:
	if planche == "":
		return _texture_anneau()
	if not _textures.has(planche):
		_textures[planche] = load(DOSSIER + planche + ".png") as Texture2D
	return _textures[planche]


## Un anneau blanc fin (`modulate` le teinte), de 128 px.
func _texture_anneau() -> Texture2D:
	if _anneau == null:
		var image := Image.create(COTE_ANNEAU, COTE_ANNEAU, false, Image.FORMAT_RGBA8)
		var centre := Vector2(COTE_ANNEAU, COTE_ANNEAU) * 0.5
		var exterieur: float = COTE_ANNEAU * 0.5
		for y: int in COTE_ANNEAU:
			for x: int in COTE_ANNEAU:
				var d: float = (Vector2(x + 0.5, y + 0.5) - centre).length()
				if d <= exterieur and d >= exterieur - EPAISSEUR_ANNEAU:
					image.set_pixel(x, y, Color.WHITE)
		_anneau = ImageTexture.create_from_image(image)
	return _anneau


func _texture_carre() -> Texture2D:
	if _carre == null:
		var image := Image.create(COTE_CARRE, COTE_CARRE, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_carre = ImageTexture.create_from_image(image)
	return _carre


func _degrade_fondu() -> Gradient:
	if _degrade == null:
		_degrade = Gradient.new()
		_degrade.set_color(0, Color.WHITE)
		_degrade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return _degrade
