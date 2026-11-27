class_name PoseEffets
extends RefCounted
## Où et comment un effet d'`Effets` se dessine à son âge : position, rotation, échelle, image de
## planche et opacité, d'après sa fiche (`anim`, `age`, `duree`, `depart`, `arrivee`, `taille`…).
## Sans état : `Effets` garde le pool et le temps, et appelle `poser` après chaque changement d'âge.


static func poser(effet: Dictionary) -> void:
	var noeud: Sprite2D = effet["n"]
	var age: float = effet["age"]
	var t: float = clampf(age / float(effet["duree"]), 0.0, 1.0)
	var depart: Vector2 = effet["depart"]
	var arrivee: Vector2 = effet["arrivee"]
	var taille: float = effet["taille"]
	var forme: String = effet["forme"]
	var couleur: Color = effet["couleur"]
	var alpha: float = Effets.ALPHA_MAX
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
			alpha = lerpf(Effets.ALPHA_MAX, 0.0, t)
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
			if Effets.FORMES_PROPRES.has(forme):
				epaisseur = Effets.EPAISSEUR_TRAIT / 8.0
			else:
				epaisseur = Effets.ECHELLE_TRAINEE
			epaisseur *= float(effet.get("epaisseur", 1.0))
			noeud.scale = Vector2(maxf(sens.length(), 1.0) / 64.0, epaisseur)
			alpha = lerpf(Effets.ALPHA_MAX, 0.0, t)
			if String(effet["anim"]) == "saut":
				# Allumé blanc la première image, puis la couleur de l'arme qui s'éteint en t².
				if age < Effets.IMAGE:
					couleur = Color.WHITE
				alpha = lerpf(Effets.ALPHA_MAX, 0.0, t * t)
		"recul":
			# Les chevrons s'éloignent de la tour ; en mouvement réduit, ils restent à mi-chemin.
			noeud.position = depart.lerp(arrivee, 0.5 if reduit else t)
			noeud.rotation = (arrivee - depart).angle()
			noeud.scale = Vector2.ONE * _echelle(forme, taille)
			alpha = lerpf(Effets.ALPHA_MAX, 0.0, t)
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
			alpha = lerpf(Effets.ALPHA_MAX * 0.6, Effets.ALPHA_MAX, pouls)
	var voulue := Color(couleur, alpha)
	if noeud.modulate != voulue:
		noeud.modulate = voulue


static func _orienter_vol(
	noeud: Sprite2D, forme: String, sens: Vector2, t: float, taille: float
) -> void:
	var angle: float = sens.angle() if sens.length() > 0.001 else 0.0
	match forme:
		"fleche":
			noeud.rotation = angle
			noeud.scale = Vector2.ONE * Effets.ECHELLE_FLECHE
		"dynamite":
			noeud.position.y -= sin(t * PI) * Effets.ARC_DYNAMITE
			noeud.rotation = t * TAU * 2.0
			noeud.scale = Vector2.ONE * Effets.ECHELLE_DYNAMITE
		"trait":
			noeud.rotation = angle
			noeud.scale = Vector2(taille * 2.2 / 64.0, Effets.EPAISSEUR_TRAIT / 8.0)
		"losange", "shuriken", "spirale":
			noeud.rotation = t * TAU * 2.0
			noeud.scale = Vector2.ONE * _echelle(forme, taille)
		_:
			var pouls: float = 1.0 + 0.3 * sin(t * TAU * 2.0)
			noeud.scale = Vector2.ONE * _echelle(forme, taille) * pouls


## Images du pack lues d'un bout à l'autre sur la durée de l'effet.
static func _image(
	effet: Dictionary, noeud: Sprite2D, forme: String, t: float, taille: float
) -> void:
	var nb: int = Effets.IMAGES_EXPLOSION if forme == "explosion" else Effets.IMAGES_FEU
	var case_px: int = Effets.CASE_EXPLOSION if forme == "explosion" else Effets.CASE_FEU
	var image: int = mini(int(t * nb), nb - 1)
	if image != int(effet["image"]):
		effet["image"] = image
		noeud.region_rect = Rect2(image * case_px, 0.0, case_px, case_px)
	var visible_px: float = (
		Effets.DIAMETRE_EXPLOSION if forme == "explosion" else float(case_px) * 0.6
	)
	noeud.scale = Vector2.ONE * taille / visible_px


## Échelle qui donne à une forme (texture de 32 px, 64 px pour l'anneau) la taille voulue en pixels.
static func _echelle(forme: String, taille: float) -> float:
	match forme:
		"anneau":
			return taille / 64.0
		"mine", "dynamite":
			return taille / Effets.REGION_DYNAMITE.size.y
	if not Effets.FORMES_PROPRES.has(forme) and forme != "fleche" and forme != "explosion":
		return taille / float(FormesSignatures.taille)
	return taille / 32.0
