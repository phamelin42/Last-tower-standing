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
## L'ombre au sol d'une bombe ou d'une fiole : assez sombre et opaque pour se lire sur l'herbe.
const ALPHA_OMBRE: float = 0.55
const COULEUR_OMBRE := Color(0.5, 0.5, 0.55)
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
## Un piège posé reste au sol tant qu'il n'a pas servi.
const DUREE_PIEGE: float = 3600.0
## Écart (px) en deçà duquel un déclenchement « est » l'endroit d'un piège.
const TOLERANCE_PIEGE: float = 2.0

## Les planches partagées par plusieurs éléments ; celles d'un élément sont dans son fichier.
const PLANCHES_COMMUNES: Dictionary = {
	"depart": Vector2i(12, 12),
	"ombre": Vector2i(12, 6),
	"etincelle": Vector2i(8, 8),
}
const VISIBLES_COMMUNES: Dictionary = {"etincelle": 8.0}

## Image de planche à chaque image à 60 i/s : le pic est dans le premier quart de l'impact.
const SEQ_EXPLOSION: Array[int] = [0, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5]
const SEQ_ANTICIPATION: Array[int] = [0, 1, 2]

const FEU: String = ElementsArmes.FEU
const GLACE: String = ElementsArmes.GLACE
const BOMBE: String = ElementsArmes.BOMBE
const POISON: String = ElementsArmes.POISON
const FOUDRE: String = ElementsArmes.FOUDRE
const ARCANE: String = ElementsArmes.ARCANE
## Les points d'une orbite (rune) tournent à ce rayon, de ce nombre de tours sur le vol.
const RAYON_ORBITE: float = 15.0
const TOURS_ORBITE: float = 3.0
const IMAGE_POINT_RUNE: int = 2
## L'éclair : 6 à 8 segments, cœur blanc de 3 px dans un bord de 6 px, tracé de nouveau toutes les
## 2 images, visible 6 images puis 3 images d'effacement.
const SEGMENTS_MIN: int = 6
const SEGMENTS_MAX: int = 8
const EPAISSEUR_COEUR: float = 3.0
const EPAISSEUR_BORD: float = 6.0
const IMAGES_RETRACE: int = 2
const IMAGES_ECLAIR_VISIBLE: int = 6
const IMAGES_ECLAIR_EFFACEMENT: int = 3
const ECART_ECLAIR_MIN: float = 6.0
const ECART_ECLAIR_MAX: float = 16.0
## La bouffée grise de départ de la bombe et de la fiole.
const COULEUR_BOUFFEE := Color(0.7, 0.7, 0.72)
## Une couronne d'aura : elle s'ouvre en 7 images, tourne de 1,5 tour par seconde et dure 14 images.
const IMAGES_COURONNE: int = 14
const IMAGES_COURONNE_OUVERTURE: int = 7
const IMAGES_NUAGE: int = 36
const ALPHA_NUAGE: float = 0.6
const MONTEE_NUAGE: float = 24.0

static var _registre: Dictionary = {}
static var _planches: Dictionary = {}
static var _visibles: Dictionary = {}

## Chaque nœud est un `Sprite2D` du pool ; `vivants` : `{n, kind, age, duree, ...}`.
var mouvement_reduit: bool = false
## Nombre d'effets que ce pool peut encore créer (posé par `Effets` avant chaque appel).
var place: int = 200

var _vivants: Array[Dictionary] = []
var _libres: Array[Sprite2D] = []
var _eclairs_libres: Array[Node2D] = []
var _textures: Dictionary = {}
var _anneau: Texture2D = null
var _pause_eclat: float = 0.0
var _nb_salves: int = 0
var _nb_effets: int = 0
var _emetteurs: Array[Dictionary] = []
var _carre: Texture2D = null
var _degrade: Gradient = null


## Le décalage entre deux projectiles d'un barrage d'`element` : 2 images, sauf mention `retard`.
static func retard_barrage(element: String) -> float:
	var e: AttaqueElement = registre().get(element)
	return RETARD_BARRAGE if e == null else float(e.conf().get("retard", 2.0)) * IMAGE


## Un élément par fichier sous `visuels/attaques/` : une ligne ici suffit à en ajouter un.
static func _scripts() -> Array[GDScript]:
	return [
		AttaqueFeu,
		AttaqueGlace,
		AttaqueBombe,
		AttaquePoison,
		AttaqueFoudre,
		AttaqueArcane,
		AttaqueLame,
		AttaqueFaucille,
		AttaqueDisque,
		AttaqueMoulinet,
		AttaqueGuillotine,
		AttaqueTourbillon,
		AttaqueArbalete,
		AttaqueChausseTrape,
		AttaqueRicochet,
		AttaqueHerse,
		AttaqueBaliste,
		AttaquePluie,
		AttaqueCercleGivre,
		AttaqueNova,
		AttaqueTempete,
		AttaquePetard,
		AttaqueMineForge,
		AttaqueTrebuchet,
		AttaqueGrandeBombe,
		AttaqueDePipe,
		AttaqueSablier,
		AttaqueMiroir,
		AttaqueVortex,
		AttaqueHorloge,
		AttaqueSerpe,
		AttaqueRasoir,
		AttaqueCouperet,
		AttaqueBrume,
		AttaqueFaucheuse,
		AttaqueFleau,
		AttaqueHache,
		AttaqueScie,
		AttaqueMoissonneuse,
		AttaqueJaveline,
		AttaqueTraitGerbe,
		AttaqueFlecheMarquante,
		AttaqueArcRemparts,
		AttaqueHersePieux,
		AttaqueLanceEpineuse,
		AttaqueCarquois,
		AttaqueMurPointes,
		AttaqueCouronnePointes,
		AttaqueRuneVeille,
		AttaqueSiphonneur,
		AttaqueLueur,
	]


## Les éléments, par identifiant (créés une fois).
static func registre() -> Dictionary:
	if _registre.is_empty():
		_planches = PLANCHES_COMMUNES.duplicate()
		_visibles = VISIBLES_COMMUNES.duplicate()
		for script: GDScript in _scripts():
			var element: AttaqueElement = script.new()
			_registre[element.id()] = element
			_planches.merge(element.planches())
			_visibles.merge(element.visibles())
	return _registre


## Taille d'une image de chaque planche, en pixels (communes et de chaque élément).
static func planches() -> Dictionary:
	registre()
	return _planches


## Vrai si `element` a des attaques dessinées ici.
static func connait(element: String) -> bool:
	return registre().has(element)


## Vrai si l'explosion de `element` est celle du pack, dessinée par `Effets` au rayon réel.
static func explosion_du_pack(element: String) -> bool:
	var e: AttaqueElement = registre().get(element)
	return false if e == null else bool(e.conf().get("explosion", false))


## Nom de la planche du projectile de `element`, `""` sans projectile.
static func planche_projectile(element: String) -> String:
	var e: AttaqueElement = registre().get(element)
	return "" if e == null else String(e.conf()["projectile"])


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
					"image": int(e["image"]),
					"alpha": n.modulate.a,
					"teinte": Color(n.modulate, 1.0),
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


## Temps de gel d'impact qui reste au plus long gel en cours.
func gel_restant() -> float:
	var reste: float = 0.0
	for e: Dictionary in _vivants:
		reste = maxf(reste, float(e["gel"]))
	return reste


func opacite_max() -> float:
	var alpha: float = 0.0
	for e: Dictionary in _vivants:
		alpha = maxf(alpha, (e["n"] as Node2D).modulate.a)
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
	var el: AttaqueElement = registre().get(element)
	if el == null:
		return -1.0
	var conf: Dictionary = el.conf()
	# Une pluie tombe du haut : le projectile naît au-dessus de l'arrivée, pas à la tour.
	var chute: float = float(conf.get("chute", 0.0))
	if chute > 0.0:
		depart = arrivee - Vector2(0.0, chute)
	var cloche: bool = float(conf["cloche"]) > 0.0
	var images_vol: int = int(
		conf.get("images_vol", IMAGES_VOL_CLOCHE if cloche else IMAGES_VOL_DIRECT)
	)
	var attente: float = retard + IMAGES_ANTICIPATION * IMAGE
	var vol: float = images_vol * IMAGE
	var sens: Vector2 = (arrivee - depart).normalized()
	var anticipation: Dictionary = nouveau("anticipation", "depart", IMAGES_ANTICIPATION * IMAGE)
	if anticipation.is_empty():
		return -1.0
	anticipation["age"] = -retard
	anticipation["depart"] = depart + sens * DECALAGE_ANTICIPATION
	anticipation["sens"] = sens
	anticipation["couleur"] = conf.get("anticipation", conf["couleur"])
	anticipation["seq"] = _sequence(SEQ_ANTICIPATION, _eclat_permis())
	var planche: String = String(conf["projectile"])
	if planche != "":
		var projectile: Dictionary = nouveau("vol", planche, vol)
		if not projectile.is_empty():
			projectile["age"] = -attente
			projectile["depart"] = depart
			projectile["arrivee"] = arrivee
			projectile["couleur"] = conf.get("teinte", Color.WHITE)
			projectile["echelle"] = ECHELLE * float(conf.get("echelle", 1.0))
			projectile["fps"] = float(conf["fps"])
			projectile["cloche"] = float(conf["cloche"])
			projectile["tour"] = float(conf.get("tour", 0.0))
			projectile["bosse"] = float(conf.get("bosse", 0.0))
			projectile["vrille"] = float(conf.get("vrille", 0.0))
			projectile["fige_reduit"] = bool(conf.get("fige_reduit", false))
			projectile["vol"] = vol
			poser(projectile)
			el.suivre_vol(self, projectile, attente, vol)
			if cloche:
				_ombre(projectile, attente, vol)
	poser(anticipation)
	# Un éclair n'a pas de vol : il est tracé d'un coup, à la fin de l'anticipation.
	return attente + (vol if planche != "" else 0.0)


## Le projectile d'un saut de rebond, de `depart` à `arrivee`, sans anticipation : il part après
## `retard` et dure `IMAGES_VOL_DIRECT` images. Rend le temps jusqu'à l'arrivée, `retard` compris,
## ou -1 si l'élément n'a pas de projectile par saut (son impact garde alors son décalage).
func saut(element: String, depart: Vector2, arrivee: Vector2, retard: float) -> float:
	var el: AttaqueElement = registre().get(element)
	return -1.0 if el == null else MecaniquesGenres.saut(self, el, depart, arrivee, retard)


## Un piège d'`element` lancé de `depart` vers `arrivee`, qui reste ensuite au sol (pixels).
func piege(element: String, depart: Vector2, arrivee: Vector2) -> bool:
	var el: AttaqueElement = registre().get(element)
	return false if el == null else el.piege(self, depart, arrivee)


## Le piège posé en `ou` a servi : ses objets au sol disparaissent, ceux d'un autre piège restent.
func retirer_pieges(ou: Vector2) -> void:
	for i: int in range(_vivants.size() - 1, -1, -1):
		var effet: Dictionary = _vivants[i]
		if (
			String(effet["kind"]) == "piege"
			and (effet["arrivee"] as Vector2).distance_to(ou) <= TOLERANCE_PIEGE
		):
			_liberer(i)


## L'aura d'`element` en `centre` (pixels du monde), au rayon réel `rayon_px`.
func aura(element: String, centre: Vector2, rayon_px: float, age: float = 0.0) -> bool:
	var el: AttaqueElement = registre().get(element)
	return false if el == null else el.aura(self, centre, rayon_px, age)


## Le front de l'onde d'`element`, parti de `centre` (pixels du monde).
func onde(element: String, centre: Vector2, age: float = 0.0) -> bool:
	var el: AttaqueElement = registre().get(element)
	return false if el == null else el.onde(self, centre, age)


## Une couronne de `nombre` sprites de `planche` qui tournent autour de `centre` et s'écartent
## jusqu'à `rayon_px` en `IMAGES_COURONNE_OUVERTURE` images, puis s'effacent (`IMAGES_COURONNE`
## au total). Vrai si un sprite au moins a été créé.
func couronne(
	planche: String, centre: Vector2, rayon_px: float, nombre: int, age: float, couleur: Color
) -> bool:
	return MecaniquesGenres.couronne(self, planche, centre, rayon_px, nombre, age, couleur)


## Un front de `nombre` sprites de `planche`, en cercle autour de `centre`, qui avance de
## `vitesse_px` pixels par seconde jusqu'à `rayon_px`, puis s'efface sur son dernier quart.
func front(
	planche: String,
	centre: Vector2,
	rayon_px: float,
	vitesse_px: float,
	nombre: int,
	age: float,
	couleur: Color
) -> bool:
	return MecaniquesGenres.front(self, planche, centre, rayon_px, vitesse_px, nombre, age, couleur)


## Dessine l'impact de `element` en `ou` (pixels du monde). `rayon_px` : 0 pour une cible unique.
## `fort` : un coup de siège, dont le pic est tenu `GelImpact.DUREE_GEL`. `age` : le temps déjà
## écoulé depuis l'arrivée (un impact en retard). Rend vrai si un effet a été créé.
func impacter(
	element: String,
	ou: Vector2,
	rayon_px: float,
	fort: bool = false,
	de: Vector2 = Vector2.ZERO,
	age: float = 0.0
) -> bool:
	var el: AttaqueElement = registre().get(element)
	if el == null:
		return false
	return el.impacter(self, ou, rayon_px, fort, de, age)


## Comme `impacter`, pour un impact d'un barrage : l'anneau de zone n'est pas dessiné ici mais, une
## seule fois pour le tir, par `zone`.
func impacter_en_groupe(
	element: String,
	ou: Vector2,
	rayon_px: float,
	fort: bool = false,
	de: Vector2 = Vector2.ZERO,
	age: float = 0.0
) -> bool:
	var el: AttaqueElement = registre().get(element)
	return false if el == null else el.impacter_en_groupe(self, ou, rayon_px, fort, de, age)


## La zone d'un barrage d'`element`, centrée en `centre`, au rayon réel `rayon_px`.
func zone(element: String, centre: Vector2, rayon_px: float, age: float = 0.0) -> bool:
	var el: AttaqueElement = registre().get(element)
	return false if el == null else el.zone(self, centre, rayon_px, age)


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
			poser(effet)
	for e: Dictionary in _emetteurs:
		_avancer_emetteur(e, delta)


## Un éclair brisé de `de` à `ou`, visible 6 images puis effacé en 3 ; vrai s'il a été créé.
func eclair(de: Vector2, ou: Vector2, age: float, couleur: Color) -> bool:
	var duree: float = (IMAGES_ECLAIR_VISIBLE + IMAGES_ECLAIR_EFFACEMENT) * IMAGE
	if _vivants.size() >= place or age >= duree:
		return false
	var n: Node2D = _prendre_eclair(couleur)
	var effet: Dictionary = _fiche(n, "eclair", "eclair", duree)
	effet["age"] = age
	effet["depart"] = de
	effet["arrivee"] = ou
	_vivants.append(effet)
	poser(effet)
	return true


## Les points de l'éclair au tracé `rang` : une ligne brisée, tirée à la graine fixe.
func _points_eclair(effet: Dictionary, rang: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE + int(effet["id"]) * 7919 + rang * 104729
	var de: Vector2 = effet["depart"]
	var ou: Vector2 = effet["arrivee"]
	var segments: int = rng.randi_range(SEGMENTS_MIN, SEGMENTS_MAX)
	var longueur: float = de.distance_to(ou)
	var ecart: float = clampf(longueur * 0.1, ECART_ECLAIR_MIN, ECART_ECLAIR_MAX)
	var perpendiculaire: Vector2 = (ou - de).normalized().orthogonal()
	var points := PackedVector2Array([de])
	for i: int in range(1, segments):
		var milieu: Vector2 = de.lerp(ou, float(i) / segments)
		points.append(milieu + perpendiculaire * rng.randf_range(-ecart, ecart))
	points.append(ou)
	return points


## Les points des éclairs vivants (cœur), dans l'ordre de création.
func eclairs() -> Array[PackedVector2Array]:
	var liste: Array[PackedVector2Array] = []
	for e: Dictionary in _vivants:
		if String(e["kind"]) == "eclair":
			liste.append(((e["n"] as Node2D).get_node("Coeur") as Line2D).points)
	return liste


# --- Effets ------------------------------------------------------------------------------------


## Un effet du pool ; `{}` si `place` est atteint.
func nouveau(kind: String, planche: String, duree: float) -> Dictionary:
	if _vivants.size() >= place:
		return {}
	var n: Sprite2D = _prendre()
	var taille: Vector2i = planches().get(planche, Vector2i(COTE_ANNEAU, COTE_ANNEAU))
	n.texture = _texture(planche)
	n.region_enabled = true
	n.region_rect = Rect2(0.0, 0.0, taille.x, taille.y)
	n.rotation = 0.0
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.modulate = Color(1.0, 1.0, 1.0, ALPHA_MAX)
	n.visible = true
	n.z_index = -1 if kind == "sol" or kind == "ombre" else 0
	var effet: Dictionary = _fiche(n, kind, planche, duree)
	_vivants.append(effet)
	return effet


## L'état d'un effet qui naît sur le nœud `n`.
func _fiche(n: Node2D, kind: String, planche: String, duree: float) -> Dictionary:
	_nb_effets += 1
	return {
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
		"vol": duree,
		"suite": 0.0,
		"tour": 0.0,
		"bosse": 0.0,
		"vrille": 0.0,
		"fige_reduit": false,
		"rayon_px": 0.0,
		"vitesse": 0.0,
	}


## Une planche jouée image par image : `seq` donne l'image de planche à chaque image à 60 i/s.
func image_impact(
	planche: String, ou: Vector2, diametre: float, seq: Array[int], age: float
) -> Dictionary:
	var effet: Dictionary = nouveau("image", planche, seq.size() * IMAGE)
	if effet.is_empty() or age >= float(effet["duree"]):
		if not effet.is_empty():
			_liberer(_vivants.size() - 1)
		return {}
	effet["age"] = age
	effet["depart"] = ou
	effet["diametre"] = diametre
	effet["echelle"] = diametre / float(_visibles[planche])
	effet["seq"] = _sequence(seq, _eclat_permis())
	poser(effet)
	return effet


func anneau_impact(ou: Vector2, diametre: float, images: int, age: float, couleur: Color) -> bool:
	var effet: Dictionary = nouveau("anneau", "", images * IMAGE)
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
	poser(effet)
	return true


## Fige l'effet sur son pic pour le reste de `GelImpact.DUREE_GEL` (rien en mouvement réduit).
func geler(effet: Dictionary, age: float, age_pic: float) -> void:
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


## L'ombre d'un projectile en cloche : elle reste sur la ligne droite et rétrécit au sommet.
func _ombre(projectile: Dictionary, attente: float, vol: float) -> void:
	var ombre: Dictionary = nouveau("ombre", "ombre", vol)
	if ombre.is_empty():
		return
	ombre["age"] = -attente
	ombre["depart"] = projectile["depart"]
	ombre["arrivee"] = projectile["arrivee"]
	ombre["couleur"] = COULEUR_OMBRE
	poser(ombre)


# --- Mouvement ---------------------------------------------------------------------------------


func poser(effet: Dictionary) -> void:
	var n: Node2D = effet["n"]
	var age: float = effet["age"]
	if age < 0.0:
		n.visible = false
		return
	n.visible = true
	var duree: float = effet["duree"]
	var t: float = clampf(age / duree, 0.0, 1.0)
	if String(effet["kind"]) == "vol" or String(effet["kind"]) == "orbite":
		t = clampf((age - float(effet["suite"])) / float(effet["vol"]), 0.0, 1.0)
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
			n.visible = age >= float(effet["suite"])
			echelle = float(effet["echelle"]) * (1.0 + float(effet["bosse"]) * sin(t * PI))
		"orbite":
			var phase: float = float(effet["tour"]) + age * TAU * TOURS_ORBITE
			var base: Vector2 = (effet["depart"] as Vector2).lerp(effet["arrivee"], t)
			n.position = base + Vector2.from_angle(phase) * RAYON_ORBITE
			_image(effet, IMAGE_POINT_RUNE)
			echelle = ECHELLE
		"eclair":
			var retrace: int = 0 if mouvement_reduit else int(age / (IMAGES_RETRACE * IMAGE))
			if retrace != int(effet["image"]):
				effet["image"] = retrace
				var points: PackedVector2Array = _points_eclair(effet, retrace)
				(n.get_node("Coeur") as Line2D).points = points
				(n.get_node("Bord") as Line2D).points = points
			var fin: float = IMAGES_ECLAIR_VISIBLE * IMAGE
			alpha = ALPHA_MAX * (1.0 - maxf(age - fin, 0.0) / (IMAGES_ECLAIR_EFFACEMENT * IMAGE))
		"couronne":
			alpha = MecaniquesGenres.poser_couronne(effet, n, age, t, mouvement_reduit)
		"front":
			alpha = MecaniquesGenres.poser_front(effet, n, age, t)
		"ombre":
			n.position = (effet["depart"] as Vector2).lerp(effet["arrivee"], t)
			echelle = ECHELLE * lerpf(1.0, ECHELLE_OMBRE_SOMMET, sin(t * PI))
			alpha = ALPHA_OMBRE
		"nuage":
			var base: Vector2 = effet["depart"]
			n.position = base + Vector2(0.0, -MONTEE_NUAGE * t)
			_image(effet, mini(int(t * 3.0), 2))
			alpha = ALPHA_NUAGE * (1.0 - t)
		"sol":
			n.position = effet["depart"]
			alpha = ALPHA_MAX * (1.0 - t)
		"piege":
			echelle *= MecaniquesGenres.poser_piege(effet, n, age)
			# L'objet posé peut s'animer (la mèche qui crépite) ; figé en mouvement réduit.
			if float(effet["fps"]) > 0.0 and not mouvement_reduit:
				_image(effet, int(age * float(effet["fps"])) % _images_planche(effet))
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
	if String(effet["kind"]) != "eclair":
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
	if hauteur > 0.0:
		n.rotation = 0.0 if mouvement_reduit else t * float(effet["tour"])
	elif float(effet["vrille"]) > 0.0 and not mouvement_reduit:
		n.rotation += age * TAU * float(effet["vrille"])
	var fps: float = float(effet["fps"])
	if fps > 0.0 and not (mouvement_reduit and bool(effet["fige_reduit"])):
		var images: int = int(
			n.texture.get_width() / float((planches()[effet["planche"]] as Vector2i).x)
		)
		_image(effet, int(age * fps) % images)


func _images_planche(effet: Dictionary) -> int:
	var texture: Texture2D = (effet["n"] as Sprite2D).texture
	return int(texture.get_width() / float((planches()[effet["planche"]] as Vector2i).x))


func _image(effet: Dictionary, i: int) -> void:
	if i == int(effet["image"]):
		return
	effet["image"] = i
	var n: Sprite2D = effet["n"]
	var taille: Vector2i = planches().get(
		String(effet["planche"]), Vector2i(COTE_ANNEAU, COTE_ANNEAU)
	)
	n.region_rect = Rect2(i * taille.x, 0.0, taille.x, taille.y)


# --- Particules --------------------------------------------------------------------------------


## Une salve unique de `nombre` carrés, qui part de `ou` ; rien en mouvement réduit.
func salve(
	ou: Vector2,
	nombre: int,
	couleur: Color,
	vie: float,
	vmin: float,
	vmax: float,
	gravite: Vector2,
	echelle: float
) -> bool:
	if mouvement_reduit:
		return false
	var e: Dictionary = _emetteur_libre()
	if e.is_empty():
		return false
	_regler(e, ou, nombre, couleur, vie, vmin, vmax, gravite, echelle, true)
	e["reste"] = vie
	return true


## Une traînée : des carrés lâchés derrière le vol `vol` tant qu'il dure.
func trainee(vol: Dictionary, nombre: int, vie: float, couleur: Color, gravite: Vector2) -> void:
	if mouvement_reduit:
		return
	var e: Dictionary = _emetteur_libre()
	if e.is_empty():
		return
	_regler(e, vol["depart"], nombre, couleur, vie, 0.0, 20.0, gravite, 1.5, false)
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
	var n: Node2D = effet["n"]
	n.visible = false
	if String(effet["kind"]) == "eclair":
		_eclairs_libres.append(n)
	else:
		(n as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_libres.append(n as Sprite2D)
	_vivants.remove_at(i)


## Un nœud d'éclair : un bord coloré et un cœur blanc, plus fin.
func _prendre_eclair(couleur: Color) -> Node2D:
	var n: Node2D = null
	if _eclairs_libres.is_empty():
		n = Node2D.new()
		n.name = "Eclair"
		for nom: String in ["Bord", "Coeur"]:
			var ligne := Line2D.new()
			ligne.name = nom
			ligne.width = EPAISSEUR_BORD if nom == "Bord" else EPAISSEUR_COEUR
			ligne.joint_mode = Line2D.LINE_JOINT_SHARP
			ligne.begin_cap_mode = Line2D.LINE_CAP_BOX
			ligne.end_cap_mode = Line2D.LINE_CAP_BOX
			n.add_child(ligne)
		add_child(n)
	else:
		n = _eclairs_libres.pop_back()
	(n.get_node("Bord") as Line2D).default_color = couleur
	(n.get_node("Coeur") as Line2D).default_color = Color.WHITE
	n.modulate = Color(1.0, 1.0, 1.0, ALPHA_MAX)
	n.visible = true
	return n


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
