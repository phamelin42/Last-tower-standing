class_name Allies2D
extends RefCounted
## Les alliés invoqués dans l'arène 2D : la feuille d'un guerrier, d'un archer ou d'un paysan du
## pack (`Apparence.ALLIES`), la teinte de l'allié, et un anneau double au sol qu'aucun ennemi n'a.
## Ils sont posés dans le même nœud trié en profondeur que les ennemis (`parent`) et lissés entre
## deux vues comme eux (`Interpolation.echantillon_allies`). Ne lit que la vue.

## Conteneurs gardés d'avance au-delà du besoin, comme la réserve des ennemis.
const RESERVE: int = 8
## Demi-hauteur de l'anneau par rapport à sa demi-largeur : le sol se voit de dessus en perspective.
const APLATI_ANNEAU: float = 0.5
## Part de la largeur du sprite que couvre l'anneau extérieur, et rapport de l'anneau intérieur.
const COUVERTURE_ANNEAU: float = 0.75
const RAPPORT_INTERIEUR: float = 0.72
const POINTS_ANNEAU: int = 40
const EPAISSEUR_TRAIT: float = 3.0
const EPAISSEUR_CONTOUR: float = 6.0
## Un déplacement plus petit (pixels) ne change pas le sens du regard.
const SEUIL_SENS: float = 0.5

## Où poser les alliés (le nœud trié par Y des ennemis).
var parent: Node2D = null
var donnees: Donnees = null

var _pool: Array[Allie] = []
var _visibles: int = 0
var _modeles: Dictionary = {}


## Un allié affiché : l'anneau d'abord (dessous), le sprite ensuite.
class Allie:
	extends Node2D
	var anneau: Anneau = null
	var sprite: Sprite2D = null
	var modele: String = ""
	var image: int = -1
	var miroir: bool = false


## L'anneau double au sol : une ellipse extérieure et une intérieure, cernées de sombre.
class Anneau:
	extends Node2D
	var demi_largeur: float = 20.0:
		set(valeur):
			if valeur != demi_largeur:
				demi_largeur = valeur
				queue_redraw()

	func _draw() -> void:
		_ellipse(1.0, Apparence.ANNEAU_ALLIE_EXTERIEUR)
		_ellipse(Allies2D.RAPPORT_INTERIEUR, Apparence.ANNEAU_ALLIE_INTERIEUR)

	func _ellipse(rapport: float, couleur: Color) -> void:
		var points := PackedVector2Array()
		for k: int in Allies2D.POINTS_ANNEAU + 1:
			var angle: float = TAU * float(k) / float(Allies2D.POINTS_ANNEAU)
			points.append(
				Vector2(
					cos(angle) * demi_largeur * rapport,
					sin(angle) * demi_largeur * rapport * Allies2D.APLATI_ANNEAU
				)
			)
		draw_polyline(points, Apparence.CONTOUR_ANNEAU_ALLIE, Allies2D.EPAISSEUR_CONTOUR)
		draw_polyline(points, couleur, Allies2D.EPAISSEUR_TRAIT)


func nombre_visibles() -> int:
	return _visibles


func allie(i: int) -> Allie:
	return _pool[i] if i >= 0 and i < _visibles else null


## Pose les alliés de `echantillon` (`Interpolation.echantillon_allies`) ; `image_courante` est
## l'image d'animation (10 par seconde). Une unité inconnue ou sans modèle n'est pas dessinée.
func afficher(echantillon: Dictionary, image_courante: int) -> void:
	if parent == null or donnees == null:
		return
	var ids: PackedInt32Array = echantillon["ids"]
	var positions: PackedVector2Array = echantillon["pos"]
	var unites: PackedInt32Array = echantillon["unite"]
	var deplaces: PackedByteArray = echantillon["deplace"]
	var rang: int = 0
	for k: int in ids.size():
		var info: Dictionary = _info(unites[k])
		if info.is_empty():
			continue
		var a: Allie = _prendre(rang)
		rang += 1
		a.visible = true
		_habiller(a, info)
		var p: Vector2 = Apparence.vers_pixels(positions[k])
		var dx: float = p.x - a.position.x
		if absf(dx) > SEUIL_SENS:
			a.miroir = dx < 0.0
		a.position = p
		var cle: int = Arene2D.COURSE if deplaces[k] != 0 else Arene2D.REPOS
		var anim: Vector2i = (info["entree"] as Dictionary)[Arene2D.NOMS_ANIMATIONS[cle]]
		var image: int = anim.x * int(info["colonnes"]) + (image_courante + ids[k]) % anim.y
		if a.image != image or a.sprite.flip_h != a.miroir:
			a.image = image
			a.sprite.flip_h = a.miroir
			var regions: PackedFloat32Array = info["regions"]
			var decalages: PackedFloat32Array = info["decalages"]
			a.sprite.region_rect = Rect2(
				regions[image * 4],
				regions[image * 4 + 1],
				regions[image * 4 + 2],
				regions[image * 4 + 3]
			)
			var dec_x: float = decalages[image * 2]
			a.sprite.offset = Vector2(-dec_x if a.miroir else dec_x, decalages[image * 2 + 1])
	for k: int in range(rang, _visibles):
		_pool[k].visible = false
	_visibles = rang
	_alleger()


## Retire tous les alliés (nouvelle partie).
func vider() -> void:
	for a: Allie in _pool:
		if is_instance_valid(a):
			if a.get_parent() != null:
				a.get_parent().remove_child(a)
			a.free()
	_pool.clear()
	_visibles = 0


## Libère les conteneurs qui dépassent le besoin d'une réserve.
func _alleger() -> void:
	var garder: int = 0 if _visibles == 0 else _visibles + RESERVE
	while _pool.size() > garder:
		var surplus: Allie = _pool.pop_back()
		surplus.get_parent().remove_child(surplus)
		surplus.free()


func _prendre(rang: int) -> Allie:
	while _pool.size() <= rang:
		var a := Allie.new()
		a.name = "Allie"
		a.anneau = Anneau.new()
		a.anneau.name = "Anneau"
		a.add_child(a.anneau)
		a.sprite = Sprite2D.new()
		a.sprite.name = "Sprite"
		a.sprite.region_enabled = true
		a.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		a.add_child(a.sprite)
		parent.add_child(a)
		_pool.append(a)
	return _pool[rang]


## Feuille, échelle, teinte et anneau selon le modèle ; refaits seulement quand il change.
func _habiller(a: Allie, info: Dictionary) -> void:
	var modele: String = info["modele"]
	if a.modele == modele:
		return
	a.modele = modele
	a.image = -1
	var entree: Dictionary = info["entree"]
	a.sprite.texture = info["texture"]
	a.sprite.scale = Vector2.ONE * float(entree["echelle"]) * Apparence.ECHELLE_UNITES
	a.sprite.modulate = entree["couleur"]
	a.anneau.demi_largeur = float(info["largeur_pixels"]) * COUVERTURE_ANNEAU * 0.5


## Ce qu'il faut pour dessiner l'unité d'index `unite` (vide si elle n'existe pas ou si son modèle
## n'a pas d'apparence), calculé une fois par modèle.
func _info(unite: int) -> Dictionary:
	if unite < 0 or unite >= donnees.ids_unites.size():
		return {}
	var fiche: Dictionary = donnees.unites[donnees.ids_unites[unite]]
	var modele: String = String(fiche.get("modele", ""))
	if _modeles.has(modele):
		return _modeles[modele]
	var entree: Dictionary = Apparence.entree_allie(modele)
	var info: Dictionary = {}
	if not entree.is_empty():
		info = _preparer(modele, entree)
	_modeles[modele] = info
	return info


func _preparer(modele: String, entree: Dictionary) -> Dictionary:
	var regions := PackedFloat32Array()
	var decalages := PackedFloat32Array()
	var case_px: Vector2i = entree["case"]
	var colonnes: int = entree["colonnes"]
	var cle: String = entree["cle_boites"]
	for image: int in colonnes * int(entree["lignes"]):
		var p: Dictionary = Apparence.placement(
			cle, image, case_px, colonnes, float(entree["pieds"]), true
		)
		var r: Rect2 = p["region"]
		var d: Vector2 = p["offset"]
		regions.append_array([r.position.x, r.position.y, r.size.x, r.size.y])
		decalages.append_array([d.x, d.y])
	var repos: Vector2i = entree["repos"]
	var boite: Rect2i = Recadrages.boite(cle, repos.x * colonnes)
	var echelle: float = float(entree["echelle"]) * Apparence.ECHELLE_UNITES
	return {
		"modele": modele,
		"entree": entree,
		"texture": load(String(entree["feuille"])) as Texture2D,
		"colonnes": colonnes,
		"regions": regions,
		"decalages": decalages,
		"largeur_pixels": float(boite.size.x) * echelle,
	}
