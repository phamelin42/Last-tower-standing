class_name ImpactsParType
extends RefCounted
## Les effets du rendu par type de dégâts qui naissent d'un impact d'arme et vivent dans le pool
## d'`Effets` (ils comptent donc dans son plafond) : l'éclat d'impact et l'explosion du pack, le
## trait d'un saut de rebond et la marque d'un statut. Sorti d'`Effets` pour le garder sous la
## limite de lignes de gdlint.

var _effets: Effets = null


func _init(effets: Effets) -> void:
	_effets = effets


func burst(
	type_degats: int,
	genre: String,
	ou: Vector2,
	rayon: float,
	couleur: Color,
	signature: Dictionary = {}
) -> bool:
	var taille: float = (
		rayon * Apparence.PX_PAR_UNITE * 2.0 if rayon > 0.0 else Effets.TAILLE_IMPACT
	)
	var forme: String = Effets.IMPACTS[type_degats]
	if not signature.is_empty():
		forme = signature["impact"]
	var explose: bool = (
		type_degats == Types.TypeDegats.SIEGE
		or genre == "zone"
		or rayon > 0.0
		or forme == "explosion"
	)
	var cree: bool = false
	_effets.coup_fort = explose
	if explose:
		cree = not explosion(ou, taille * 0.5 / Apparence.PX_PAR_UNITE).is_empty()
	# Le siège garde l'explosion du pack seule, sauf si sa signature a une autre forme d'impact.
	var dessine_forme: bool = type_degats != Types.TypeDegats.SIEGE
	if not signature.is_empty():
		dessine_forme = forme != "explosion"
	if dessine_forme:
		var effet: Dictionary = _effets.creer(forme, "burst", Effets.DUREE_IMPACT, couleur)
		if not effet.is_empty():
			effet["depart"] = ou
			effet["taille"] = taille if not explose else minf(taille, Effets.TAILLE_IMPACT)
			if explose:
				_effets.geler(effet, CourbesEffets.IMAGES_MONTEE_IMPACT * Effets.IMAGE)
			PoseEffets.poser(effet)
			cree = true
	return cree


func trait_saut(
	type_degats: int, depart: Vector2, arrivee: Vector2, couleur: Color, signature: Dictionary = {}
) -> bool:
	var forme: String = Effets.TRAITS[type_degats]
	if not signature.is_empty():
		forme = signature["trainee"]
	var effet: Dictionary = _effets.creer(forme, "saut", Effets.DUREE_TRAIT, couleur)
	if effet.is_empty():
		return false
	effet["depart"] = depart
	effet["arrivee"] = arrivee
	PoseEffets.poser(effet)
	return true


## La marque du statut `nom` sur l'ennemi touché en `ou` (pixels).
func statut(nom: String, ou: Vector2) -> bool:
	var forme: String = Effets.FORMES_STATUT[nom]
	if nom == "vol_de_vie":
		# Le soin remonte de l'ennemi touché vers la tour, à l'origine du monde.
		var soin: Dictionary = _effets.creer(forme, "vol", Effets.DUREE_SOIN, Effets.COULEUR_SOIN)
		if soin.is_empty():
			return false
		soin["depart"] = ou
		soin["arrivee"] = Vector2.ZERO
		soin["taille"] = Effets.TAILLE_IMPACT * 0.6
		PoseEffets.poser(soin)
		return true
	if nom == "brulure":
		var feu: Dictionary = _effets.creer("feu", "image", Effets.DUREE_FEU, Color.WHITE)
		if feu.is_empty():
			return false
		feu["depart"] = ou
		feu["taille"] = Effets.TAILLE_IMPACT
		PoseEffets.poser(feu)
		return true
	var couleur: Color = Effets.couleur_statut(nom)
	var effet: Dictionary = _effets.creer(forme, "statut", Effets.DUREE_STATUT, couleur)
	if effet.is_empty():
		return false
	effet["depart"] = ou
	effet["taille"] = Effets.TAILLE_IMPACT
	PoseEffets.poser(effet)
	return true


## `rayon` en unités de jeu. Rend un dictionnaire vide si le plafond est atteint.
func explosion(ou: Vector2, rayon: float) -> Dictionary:
	var effet: Dictionary = _effets.creer("explosion", "image", Effets.DUREE_EXPLOSION, Color.WHITE)
	if effet.is_empty():
		return {}
	effet["depart"] = ou
	effet["taille"] = rayon * Apparence.PX_PAR_UNITE * 2.0
	_effets.geler(effet, Effets.age_pic_explosion())
	PoseEffets.poser(effet)
	return effet
