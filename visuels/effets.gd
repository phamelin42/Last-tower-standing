class_name Effets
extends Node3D
## Projectiles, impacts et morts : des formes légères et brèves, prises dans un pool plafonné.
## Au-delà de `PLAFOND` effets vivants, les nouveaux sont ignorés : une rafale ne coûte jamais
## plus que de remplir le pool, et les nœuds ne sont jamais créés ni libérés un par un.

const PLAFOND: int = 200
const DUREE_TIR: float = 0.15
const DUREE_IMPACT: float = 0.3
const DUREE_MORT: float = 0.3
## Altitude des effets, en mètres : à hauteur des ennemis.
const HAUTEUR: float = 1.0
## Taille de l'impact sans rayon (rebond) et de la mort, en mètres.
const RAYON_PAR_DEFAUT: float = 0.5
const RAYON_MORT: float = 0.8
const COULEUR_MORT := Color("#ffffff")
const COULEUR_IMPACT := Color("#ffe9a8")

var _libres: Array[MeshInstance3D] = []
var _vivants: Array[Dictionary] = []
var _nb_noeuds: int = 0
var _materiaux: Dictionary = {}


func nombre_vivants() -> int:
	return _vivants.size()


func taille_pool() -> int:
	return _nb_noeuds


## `evenement` : {k, de, vers, type_degats, rayon} d'une `VueArene`. Un genre inconnu est ignoré.
func ajouter(evenement: Dictionary) -> void:
	if _vivants.size() >= PLAFOND:
		return
	var genre: String = evenement.get("k", "")
	if genre != "tir" and genre != "impact" and genre != "mort":
		return
	var de: Vector2 = evenement.get("de", Vector2.ZERO)
	var vers: Vector2 = evenement.get("vers", Vector2.ZERO)
	var type_degats: int = evenement.get("type_degats", 0)
	var rayon: float = evenement.get("rayon", 0.0)
	var noeud: MeshInstance3D = _prendre()
	var effet := {"n": noeud, "k": genre, "age": 0.0}
	var depart: Vector3 = Apparence.position_monde(de, HAUTEUR)
	var arrivee: Vector3 = Apparence.position_monde(vers, HAUTEUR)
	match genre:
		"tir":
			noeud.mesh = Apparence.forme_projectile(type_degats)
			noeud.material_override = _materiau(Apparence.couleur_type(type_degats))
			effet["duree"] = DUREE_TIR
			effet["depart"] = depart
			effet["arrivee"] = arrivee
			var sens: Vector3 = arrivee - depart
			sens.y = 0.0
			noeud.basis = (
				Basis.looking_at(sens, Vector3.UP) if sens.length() > 0.001 else Basis.IDENTITY
			)
		"impact":
			# L'anneau du projectile chaos sert de forme ; son échelle donne le rayon réel.
			var anneau: Mesh = Apparence.forme_projectile(Types.TypeDegats.CHAOS)
			noeud.mesh = anneau
			noeud.material_override = _materiau(COULEUR_IMPACT)
			var cible: float = rayon * Apparence.ECHELLE if rayon > 0.0 else RAYON_PAR_DEFAUT
			effet["duree"] = DUREE_IMPACT
			effet["depart"] = arrivee
			effet["echelle"] = cible / (anneau.get_aabb().size.x * 0.5)
			noeud.basis = Basis.IDENTITY
		_:
			noeud.mesh = Apparence.forme_projectile(-1)
			noeud.material_override = _materiau(COULEUR_MORT)
			effet["duree"] = DUREE_MORT
			effet["depart"] = arrivee
			effet["echelle"] = RAYON_MORT / 0.2
			noeud.basis = Basis.IDENTITY
	noeud.position = effet["depart"]
	noeud.visible = true
	_vivants.append(effet)
	_poser(effet)


func avancer(delta: float) -> void:
	var i: int = _vivants.size() - 1
	while i >= 0:
		var effet: Dictionary = _vivants[i]
		var age: float = effet["age"]
		var duree: float = effet["duree"]
		age += delta
		effet["age"] = age
		if age >= duree:
			var noeud: MeshInstance3D = effet["n"]
			noeud.visible = false
			_libres.append(noeud)
			_vivants.remove_at(i)
		else:
			_poser(effet)
		i -= 1


func _poser(effet: Dictionary) -> void:
	var noeud: MeshInstance3D = effet["n"]
	var age: float = effet["age"]
	var duree: float = effet["duree"]
	var t: float = clampf(age / duree, 0.0, 1.0)
	var genre: String = effet["k"]
	if genre == "tir":
		var depart: Vector3 = effet["depart"]
		var arrivee: Vector3 = effet["arrivee"]
		noeud.position = depart.lerp(arrivee, t)
		return
	var echelle: float = effet["echelle"]
	# L'impact s'élargit, la mort grossit puis s'évanouit : l'échelle suffit, sans transparence.
	var facteur: float = lerpf(0.3, 1.0, t) if genre == "impact" else lerpf(1.0, 0.0, t)
	noeud.scale = Vector3.ONE * echelle * facteur


func _prendre() -> MeshInstance3D:
	if not _libres.is_empty():
		return _libres.pop_back()
	var noeud := MeshInstance3D.new()
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(noeud)
	_nb_noeuds += 1
	return noeud


func _materiau(couleur: Color) -> StandardMaterial3D:
	var clef: String = couleur.to_html()
	if not _materiaux.has(clef):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materiaux[clef] = m
	return _materiaux[clef] as StandardMaterial3D
