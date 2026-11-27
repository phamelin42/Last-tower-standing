class_name PlanchesEffets
extends RefCounted
## Les images des effets d'attaque et ce qu'on en sait (`data/assets.json`, section `effets`,
## T10.4) : pour le pack Tiny Swords (feu, explosion, flèche, dynamite) le chemin, la case, le
## nombre d'images, les régions, l'échelle et le diamètre visible ; pour les planches maison de
## `assets/maison/effets_attaques/` la case, le diamètre visible et la cadence de chacune.
## Remplacer ces images ne demande que de changer les fichiers et ces nombres, jamais le code.
## Les planches carrées d'impact ne sont pas décrites : `GeometriePlanches` lit leur case sur la
## texture.

static var _version: int = -1
static var _donnees: Dictionary = {}
static var _cases: Dictionary = {}
static var _visibles: Dictionary = {}


## Les données de la ppack `nom` (`feu`, `explosion`, `fleche`, `dynamite`), typées : `chemin`
## (relatif à `Apparence.RACINE`), `case` (`Vector2i`), `images`, `region` (`Rect2`), etc.
static func pack(nom: String) -> Dictionary:
	_lire()
	return (_donnees["pack"] as Dictionary).get(nom, {})


## Le chemin complet de l'image du pack `nom`.
static func chemin_pack(nom: String) -> String:
	return Apparence.RACINE + String(pack(nom).get("chemin", ""))


## Le dossier des planches maison (`res://…/`).
static func dossier() -> String:
	_lire()
	return String(_maison().get("dossier", ""))


## Le chemin de l'image de la planche maison `planche`.
static func chemin_planche(planche: String) -> String:
	_lire()
	return dossier() + planche + String(_maison().get("extension", ""))


## Combien de pixels d'écran fait un pixel d'une planche maison.
static func echelle() -> float:
	_lire()
	return float(_maison().get("echelle", 1.0))


## Taille d'une image de chaque planche décrite (communes et de chaque élément).
static func cases() -> Dictionary:
	_lire()
	return _cases


## Diamètre visible (pixels de planche) de la plus grande image des planches décrites qui en ont
## un.
static func visibles() -> Dictionary:
	_lire()
	return _visibles


## La taille d'une image de `planche`, `Vector2i.ZERO` si elle n'est pas décrite.
static func case_de(planche: String) -> Vector2i:
	_lire()
	return _cases.get(planche, Vector2i.ZERO)


## Images par seconde de l'animation de `planche` ; 0 si elle ne s'anime pas ou n'est pas décrite.
static func cadence_de(planche: String) -> float:
	_lire()
	var p: Dictionary = _planches().get(planche, {})
	return float(p.get("images_par_seconde", 0.0))


## Les planches communes à tous les éléments : taille de leur image.
static func cases_communes() -> Dictionary:
	_lire()
	return _extraire(_maison().get("communes", []), _cases)


## Le diamètre visible des planches communes qui en ont un.
static func visibles_communes() -> Dictionary:
	_lire()
	return _extraire(_maison().get("communes", []), _visibles)


## Les planches décrites que l'élément `element` dessine : taille de leur image.
static func cases_de(element: String) -> Dictionary:
	_lire()
	return _extraire((_maison().get("elements", {}) as Dictionary).get(element, []), _cases)


## Le diamètre visible de celles qui en ont un.
static func visibles_de(element: String) -> Dictionary:
	_lire()
	return _extraire((_maison().get("elements", {}) as Dictionary).get(element, []), _visibles)


## Les images de vol du projectile de `element` si `data/assets.json` en fixe le nombre
## (`effets.maison.images_vol`), 0 sinon : l'élément garde alors la durée de son genre de vol.
static func images_vol(element: String) -> int:
	_lire()
	return int((_maison().get("images_vol", {}) as Dictionary).get(element, 0))


## L'image sur laquelle se fige `element` en mouvement réduit (`decor`, `flamme_boss`, `crane`) :
## `data/assets.json`, `effets.mouvement_reduit`. La première image (0) si la donnée manque.
static func image_fixe(element: String) -> int:
	_lire()
	return int((_donnees.get("mouvement_reduit", {}) as Dictionary).get(element, 0))


## Le diamètre (px) d'un coup de siège sur une cible seule (`effets.impact_siege_cible_unique`) :
## le même pour toutes les armes de siège à cible seule. 48 px, l'ancienne taille, si la donnée
## manque.
static func diametre_impact_siege_seul() -> float:
	_lire()
	return float(
		(_donnees.get("impact_siege_cible_unique", {}) as Dictionary).get("diametre", 48.0)
	)


static func _extraire(noms: Array, table: Dictionary) -> Dictionary:
	var sortie: Dictionary = {}
	for nom: Variant in noms:
		if table.has(nom):
			sortie[nom] = table[nom]
	return sortie


static func _maison() -> Dictionary:
	return _donnees.get("maison", {})


static func _planches() -> Dictionary:
	return _maison().get("planches", {})


static func _lire() -> void:
	if _version == Assets.version:
		return
	_version = Assets.version
	_donnees = Assets.typee("effets")
	if not _donnees.has("pack"):
		_donnees["pack"] = {}
	_cases = {}
	_visibles = {}
	var planches: Dictionary = _planches()
	for nom: Variant in planches:
		var p: Dictionary = planches[nom]
		_cases[nom] = p["case"]
		if p.has("visible"):
			_visibles[nom] = float(p["visible"])
