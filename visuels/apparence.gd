class_name Apparence
extends RefCounted
## Seul endroit qui connaît les formes et couleurs du jeu : entité → primitive Godot. Les
## maillages et matériaux sont intégrés à Godot (aucun fichier externe), créés une seule fois
## puis partagés : un même objet pour chaque appel, ce qui évite de recréer des milliers de
## ressources par seconde quand les ennemis affluent.

const ECHELLE: float = 0.02
## Fond d'interface (washi clair) sur lequel les textes de rareté doivent rester lisibles.
const FOND_INTERFACE := Color("#faf7f0")
## Altitude d'un volant au-dessus du sol, en mètres.
const FLOTTAISON_VOLANT: float = 1.5
## Couleur du repli : une entité sans apparence se voit tout de suite, elle ne disparaît pas.
const COULEUR_REPLI := Color("#ff00ff")
const COULEUR_CONVOI := Color("#8a5a3c")
const FACTEUR_BOSS: float = 3.0
const PV_REFERENCE: float = 40.0

static var _cache: Dictionary = {}
static var _donnees: Donnees = null
static var _donnees_chargees: bool = false


## Position d'une entité dans le monde 3D. Le plan de jeu (x, y) devient le sol (x, z).
static func position_monde(p: Vector2, hauteur: float = 0.0) -> Vector3:
	return Vector3(p.x * ECHELLE, hauteur, p.y * ECHELLE)


## Altitude du centre d'une famille. Un volant flotte ; un marcheur, le convoi et le boss
## restent au sol. Un index hors bornes est traité comme au sol.
static func hauteur_famille(index: int) -> float:
	var e := _entite(index)
	if e.is_empty():
		return 0.0
	var volant: bool = e["volant"]
	return FLOTTAISON_VOLANT if volant else 0.0


## Index 0 à n-1 : les familles ; n : le convoi ; n+1 : le boss. Un autre index, ou des données
## absentes, renvoie un dictionnaire vide.
static func maillage_famille(index: int) -> Mesh:
	var clef := "famille:%d" % index
	if not _cache.has(clef):
		_cache[clef] = _construire_maillage(index)
	return _cache[clef] as Mesh


static func materiau_famille(index: int) -> StandardMaterial3D:
	var clef := "materiau:%d" % index
	if not _cache.has(clef):
		_cache[clef] = _construire_materiau(index)
	return _cache[clef] as StandardMaterial3D


static func maillage_tour() -> Mesh:
	if not _cache.has("tour:maillage"):
		var cylindre := CylinderMesh.new()
		cylindre.top_radius = 1.2
		cylindre.bottom_radius = 1.2
		cylindre.height = 2.5
		_cache["tour:maillage"] = cylindre
	return _cache["tour:maillage"] as Mesh


static func materiau_tour() -> StandardMaterial3D:
	if not _cache.has("tour:materiau"):
		_cache["tour:materiau"] = _materiau(Color("#e8e2d0"))
	return _cache["tour:materiau"] as StandardMaterial3D


static func couleur_type(type_degats: int) -> Color:
	match type_degats:
		Types.TypeDegats.TRANCHANT:
			return Color("#c9d1d9")
		Types.TypeDegats.PERCANT:
			return Color("#f2c94c")
		Types.TypeDegats.MAGIQUE:
			return Color("#9b59b6")
		Types.TypeDegats.SIEGE:
			return Color("#d35400")
		Types.TypeDegats.CHAOS:
			return Color("#2ecc71")
	return COULEUR_REPLI


static func forme_projectile(type_degats: int) -> Mesh:
	var clef := "projectile:%d" % type_degats
	if not _cache.has(clef):
		_cache[clef] = _construire_projectile(type_degats)
	return _cache[clef] as Mesh


static func couleur_rarete(r: int) -> Color:
	match r:
		Types.Rarete.COMMUNE:
			return Color("#4a4458")
		Types.Rarete.PEU_COMMUNE:
			return Color("#2e6b3a")
		Types.Rarete.RARE:
			return Color("#1f5f8b")
		Types.Rarete.EPIQUE:
			return Color("#7a2e8e")
	return COULEUR_REPLI


## Le symbole porte la rareté avec la couleur ; le libellé (clé de traduction) la porte
## aussi en texte, pour qu'aucune information ne tienne à la couleur seule.
static func symbole_rarete(r: int) -> String:
	match r:
		Types.Rarete.COMMUNE:
			return "●"
		Types.Rarete.PEU_COMMUNE:
			return "◆"
		Types.Rarete.RARE:
			return "★"
		Types.Rarete.EPIQUE:
			return "✦"
	return "?"


## Clé dans `i18n/*.csv` : le texte visible n'est jamais écrit dans ce fichier.
static func cle_libelle_rarete(r: int) -> String:
	match r:
		Types.Rarete.COMMUNE:
			return "rarete.commune"
		Types.Rarete.PEU_COMMUNE:
			return "rarete.peu_commune"
		Types.Rarete.RARE:
			return "rarete.rare"
		Types.Rarete.EPIQUE:
			return "rarete.epique"
	return ""


static func couleur_armure(a: int) -> Color:
	match a:
		Types.Armure.LEGERE:
			return Color("#7fb27e")
		Types.Armure.MOYENNE:
			return Color("#e0b43a")
		Types.Armure.LOURDE:
			return Color("#3a7ca5")
		Types.Armure.FORTIFIEE:
			return Color("#7d4e9c")
		Types.Armure.AUCUNE:
			return Color("#9a94a6")
		Types.Armure.BOSS:
			return Color("#c0392b")
	return COULEUR_REPLI


static func symbole_armure(a: int) -> String:
	match a:
		Types.Armure.LEGERE:
			return "○"
		Types.Armure.MOYENNE:
			return "△"
		Types.Armure.LOURDE:
			return "□"
		Types.Armure.FORTIFIEE:
			return "◇"
		Types.Armure.AUCUNE:
			return "∅"
		Types.Armure.BOSS:
			return "★"
	return "?"


static func cle_libelle_armure(a: int) -> String:
	match a:
		Types.Armure.LEGERE:
			return "armure.legere"
		Types.Armure.MOYENNE:
			return "armure.moyenne"
		Types.Armure.LOURDE:
			return "armure.lourde"
		Types.Armure.FORTIFIEE:
			return "armure.fortifiee"
		Types.Armure.AUCUNE:
			return "armure.aucune"
		Types.Armure.BOSS:
			return "armure.boss"
	return ""


## Forme propre à chaque armure : deux armures différentes ne se confondent jamais, même
## à couleur voisine. Partagée par toutes les familles de cette armure.
static func forme_armure(a: int) -> Mesh:
	var clef := "forme_armure:%d" % a
	if not _cache.has(clef):
		_cache[clef] = _primitive_armure(a, 1.0)
	return _cache[clef] as Mesh


static func _donnees_reelles() -> Donnees:
	if not _donnees_chargees:
		_donnees = Donnees.charger()
		_donnees_chargees = true
	return _donnees


## Description minimale d'une entité : son genre, son armure, son altitude et sa taille. Vide
## pour un index sans entité.
static func _entite(index: int) -> Dictionary:
	var d := _donnees_reelles()
	if d == null or index < 0:
		return {}
	var nb := d.familles.size()
	if index < nb:
		var famille: Dictionary = d.familles[index]
		var pv: float = famille["pv"]
		return {
			"genre": "famille",
			"armure": famille["armure"],
			"volant": famille["volant"],
			"facteur": clampf(sqrt(pv / PV_REFERENCE), 0.8, 2.0),
		}
	if index == nb:
		return {"genre": "convoi", "armure": Types.Armure.AUCUNE, "volant": false, "facteur": 2.0}
	if index == nb + 1:
		return {
			"genre": "boss",
			"armure": Types.Armure.BOSS,
			"volant": false,
			"facteur": FACTEUR_BOSS,
		}
	return {}


static func _construire_maillage(index: int) -> Mesh:
	var e := _entite(index)
	if e.is_empty():
		return _sphere(0.5)
	var genre: String = e["genre"]
	var facteur: float = e["facteur"]
	if genre == "convoi":
		var charrette := BoxMesh.new()
		charrette.size = Vector3(1.6, 0.8, 1.0) * facteur * 0.5
		return charrette
	var armure: int = e["armure"]
	return _primitive_armure(armure, facteur)


static func _construire_materiau(index: int) -> StandardMaterial3D:
	var e := _entite(index)
	if e.is_empty():
		return _materiau(COULEUR_REPLI)
	var genre: String = e["genre"]
	if genre == "convoi":
		return _materiau(COULEUR_CONVOI)
	var armure: int = e["armure"]
	return _materiau(couleur_armure(armure))


static func _primitive_armure(a: int, facteur: float) -> Mesh:
	match a:
		Types.Armure.LEGERE:
			return _sphere(0.5 * facteur)
		Types.Armure.MOYENNE:
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.4 * facteur
			capsule.height = 1.2 * facteur
			return capsule
		Types.Armure.LOURDE:
			var boite := BoxMesh.new()
			boite.size = Vector3.ONE * facteur
			return boite
		Types.Armure.FORTIFIEE:
			var colonne := CylinderMesh.new()
			colonne.top_radius = 0.6 * facteur
			colonne.bottom_radius = 0.6 * facteur
			colonne.height = facteur
			return colonne
		Types.Armure.AUCUNE:
			var prisme := PrismMesh.new()
			prisme.size = Vector3.ONE * facteur
			return prisme
		Types.Armure.BOSS:
			var anneau := TorusMesh.new()
			anneau.inner_radius = 0.4 * facteur
			anneau.outer_radius = 1.0 * facteur
			return anneau
	return _sphere(0.5 * facteur)


static func _construire_projectile(type_degats: int) -> Mesh:
	match type_degats:
		Types.TypeDegats.TRANCHANT:
			var lame := BoxMesh.new()
			lame.size = Vector3(0.6, 0.1, 0.2)
			return lame
		Types.TypeDegats.PERCANT:
			var fleche := CylinderMesh.new()
			fleche.top_radius = 0.05
			fleche.bottom_radius = 0.05
			fleche.height = 0.8
			return fleche
		Types.TypeDegats.SIEGE:
			var obus := CapsuleMesh.new()
			obus.radius = 0.25
			obus.height = 0.7
			return obus
		Types.TypeDegats.CHAOS:
			var anneau := TorusMesh.new()
			anneau.inner_radius = 0.05
			anneau.outer_radius = 0.2
			return anneau
	return _sphere(0.2)


static func _sphere(rayon: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	return s


static func _materiau(couleur: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	return m
