class_name Apparence
extends RefCounted
## Correspondance entité → sprite du pack Tiny Swords (Pixel Frog, CC0, ancienne version), réunie
## ici : feuille, taille de case, lignes d'animation, échelle, couleur. Les lignes viennent de
## `docs/tiny_swords.md` (section 2, mesurées) et la correspondance a été validée par Phil.
## Les identifiants sont ceux de `data/ennemis.json`. Réunit aussi ce que l'interface affiche de
## la rareté et de l'armure (symbole, couleur, clé de libellé).

const RACINE := "res://assets/tiny_swords/"
## Fond des cartes de la boutique (même valeur que `ThemeJeu.ENCRE_CARTE`, vérifiée par un test)
## sur lequel les textes de rareté doivent rester lisibles.
const FOND_INTERFACE := Color("#26343a")
## Couleur du repli : une valeur inconnue se voit tout de suite, elle ne disparaît pas.
const COULEUR_REPLI := Color("#ff00ff")
## Un pixel du monde vaut cette fraction d'unité de jeu : le cercle d'apparition (1 300 unités)
## fait ainsi 650 px de rayon, la tour (60 unités) une trentaine.
const PX_PAR_UNITE: float = 0.5
## Au-delà, l'ennemi tire de loin et s'arrête à sa portée (règle de `sim/ennemis.gd`).
const PORTEE_CORPS_A_CORPS: float = 60.0
const NB_TOURS: int = 8

const SHADER_TOUR := "res://visuels/teinte_tour.gdshader"

const COULEUR_CERCLE := Color(1.0, 1.0, 1.0, 0.55)
const COULEUR_NOM := Color(1.0, 1.0, 1.0, 1.0)
const COULEUR_CONTOUR_NOM := Color(0.1, 0.07, 0.15, 1.0)

static var images_par_seconde: float = float(_unites().get("images_par_seconde", 10.0))
## Les tables d'assets (modèles de feuilles, entités, alliés, mort, tour) vivent dans
## `data/assets.json`, lues par `Assets` (T10.4) : changer de pack ne demande que les fichiers et ce
## JSON. `pieds` est la ligne de pixels de la case où les pieds touchent le sol (ombre comprise).
static var modeles: Dictionary = _unites().get("modeles", {})
## Une entrée par entité (24 familles, convoi, boss) : le modèle du pack suit le modèle de jeu et
## la couleur du pack suit le palier. `echelle` agrandit le sprite.
static var entites: Dictionary = _unites().get("entites", {})
## Les alliés invoqués (`data/unites.json` `modele`) : feuille d'un modèle d'ennemi, teinte propre
## et anneau au sol. Un modèle inconnu n'a pas d'entrée.
static var allies: Dictionary = _unites().get("allies", {})
## L'anneau double au sol des alliés : couleur du trait extérieur et de l'intérieur.
static var anneau_allie_exterieur: Color = _anneau("exterieur", Color.WHITE)
static var anneau_allie_interieur: Color = _anneau("interieur", Color.WHITE)
static var contour_anneau_allie: Color = _anneau("contour", Color.BLACK)
## La mort de toutes les familles : 14 images lues ligne après ligne.
static var mort: Dictionary = _unites().get("mort", {})
## Grossissement de tous les sprites d'unités par rapport au pack.
static var echelle_unites: float = float(_unites().get("echelle", 1.0))
## La tour mesure environ 18 % de la hauteur de l'écran ; `pieds` : ligne de ses pieds.
static var tour_echelle: float = float(Assets.section("tour").get("echelle", 1.0))
static var tour_pieds: float = float(Assets.section("tour").get("pieds", 0.0))
## Sprite de tour dont on décale la teinte pour les joueurs 5 à 8.
static var tour_base: String = str(Assets.section("tour").get("fichier_base", ""))
static var tour_teinte_base: float = float(Assets.section("tour").get("teinte_base", 0.0))
## Joueurs 1 à 4 : les quatre couleurs du pack et la teinte dominante de leur pierre, en degrés.
static var tours_pack: Array[Dictionary] = _dictionnaires(
	Assets.section("tour").get("couleurs_pack", [])
)
## Joueurs 5 à 8 : teinte visée, en degrés.
static var teintes_calculees: Array[float] = _flottants(
	Assets.section("tour").get("teintes_calculees", [])
)

static var _entrees: Dictionary = {}


static func _unites() -> Dictionary:
	return Assets.typee("unites")


static func _anneau(cle: String, repli: Color) -> Color:
	var anneau: Dictionary = _unites().get("anneau_allie", {})
	return anneau.get(cle, repli)


static func _dictionnaires(liste: Array) -> Array[Dictionary]:
	var sortie: Array[Dictionary] = []
	for x: Variant in liste:
		var d: Dictionary = x
		sortie.append(d)
	return sortie


static func _flottants(liste: Array) -> Array[float]:
	var sortie: Array[float] = []
	for x: Variant in liste:
		sortie.append(float(x))
	return sortie


## Identifiants des entités dans l'ordre des index de `VueArene.ennemis_famille` : les familles,
## puis le convoi, puis le boss.
static func ids_entites(donnees: Donnees) -> PackedStringArray:
	var ids := PackedStringArray()
	for famille: Dictionary in donnees.familles:
		ids.append(String(famille["id"]))
	ids.append(String(donnees.convoi["id"]))
	ids.append(String(donnees.boss["id"]))
	return ids


## Feuille, case, lignes d'animation, échelle, couleur d'une entité ; vide si l'identifiant est
## inconnu.
static func entree(id: String) -> Dictionary:
	if _entrees.has(id):
		return _entrees[id]
	if not entites.has(id):
		return {}
	return _construire_entree(id, entites[id])


## Comme `entree`, pour un allié du modèle `modele` (`allies`) ; `couleur` est sa teinte. Vide si
## le modèle est inconnu.
static func entree_allie(modele: String) -> Dictionary:
	if not allies.has(modele):
		return {}
	var cle: String = "allie_" + modele
	if _entrees.has(cle):
		return _entrees[cle]
	var entree_pack: Dictionary = _construire_entree(cle, allies[modele])
	entree_pack["couleur"] = (allies[modele] as Dictionary)["teinte"]
	return entree_pack


static func _construire_entree(id: String, source: Dictionary) -> Dictionary:
	var modele: Dictionary = (modeles[source["modele"]] as Dictionary).duplicate()
	var couleur_pack: String = source["couleur_pack"]
	modele["feuille"] = chemin_feuille(String(source["modele"]), couleur_pack)
	modele.erase("chemin")
	modele.erase("noms_irreguliers")
	modele["echelle"] = source["echelle"]
	modele["couleur"] = Color.WHITE
	modele["cle_boites"] = source["modele"]
	if source.has("accessoire"):
		var accessoire: Dictionary = (source["accessoire"] as Dictionary).duplicate()
		accessoire["feuille"] = RACINE + String(accessoire["feuille"])
		modele["accessoire"] = accessoire
	_entrees[id] = modele
	return modele


## Chemin `res://` de la feuille du modèle `cle` dans la couleur du pack `couleur` (vide si le
## modèle est inconnu) ; une feuille sans couleur (le mouton) ignore `couleur`.
static func chemin_feuille(cle: String, couleur: String) -> String:
	if not modeles.has(cle):
		return ""
	var modele: Dictionary = modeles[cle]
	var chemin: String = modele["chemin"]
	if chemin.contains("%s"):
		var irreguliers: Dictionary = modele.get("noms_irreguliers", {})
		var nom: String = String(irreguliers.get(couleur, couleur))
		chemin = chemin % [couleur, nom]
	return chemin if chemin.begins_with("res://") else RACINE + chemin


## Pixels du monde pour une position de la vue (unités de jeu).
static func vers_pixels(p: Vector2) -> Vector2:
	return p * PX_PAR_UNITE


## Distance à la tour à laquelle un ennemi s'arrête (miroir de `sim/ennemis.gd`) : au bord de la
## tour au corps à corps, à sa portée pour un tireur.
static func distance_arret(portee: float, rayon_tour: float) -> float:
	if portee <= PORTEE_CORPS_A_CORPS:
		return rayon_tour + portee
	return portee


## Où poser une image d'une feuille : `region` (dans la feuille) et `offset` du `Sprite2D` centré
## sur cette région, tels que le pied (centre de la case, ligne `pieds`) tombe sur la position du
## sprite. Avec `recadre`, la région est réduite au contenu de l'image ; sans, c'est la case
## entière. En miroir (`flip_h`), le sprite utilise `-offset.x`.
static func placement(
	cle: String, image: int, case_px: Vector2i, colonnes: int, pieds: float, recadre: bool
) -> Dictionary:
	var origine := Vector2((image % colonnes) * case_px.x, (image / colonnes) * case_px.y)
	var boite := Rect2i(Vector2i.ZERO, case_px)
	if recadre:
		boite = Recadrages.boite(cle, image)
		if boite.size == Vector2i.ZERO:
			boite = Rect2i(0, 0, 1, 1)
	var region := Rect2(origine + Vector2(boite.position), Vector2(boite.size))
	var pied := origine + Vector2(float(case_px.x) * 0.5, pieds)
	return {"region": region, "offset": region.get_center() - pied}


## Numéro de joueur ramené à 1..8 (au-delà, on reboucle).
static func numero_valide(numero: int) -> int:
	return posmod(numero - 1, NB_TOURS) + 1


## Fichier d'une image de superposition de la tour : `dossier` vient de `data/apparence_tour.json`,
## `couche` est `arriere` ou `avant`, `image` l'image du tour lent (0 : l'image de base, dessinée
## au palier 3 seulement pour les statistiques animées).
static func fichier_superposition(
	dossier: String, stat: String, palier: int, couche: String, image: int = 0
) -> String:
	var suffixe := "" if image <= 0 else "_a%d" % image
	return "%s%s_%d_%s%s.png" % [dossier, stat, palier, couche, suffixe]


## `{fichier, decalage}` de la tour du joueur `numero` ; `decalage` est la rotation de teinte
## appliquée par le nuanceur, en fraction de tour (0 pour les couleurs du pack).
static func tour(numero: int) -> Dictionary:
	var n: int = numero_valide(numero)
	if n <= tours_pack.size():
		var couleur: String = tours_pack[n - 1]["couleur"]
		return {
			"fichier": RACINE + "Factions/Knights/Buildings/Tower/Tower_%s.png" % couleur,
			"decalage": 0.0,
		}
	var visee: float = teintes_calculees[n - tours_pack.size() - 1]
	return {
		"fichier": RACINE + tour_base, "decalage": fposmod(visee - tour_teinte_base, 360.0) / 360.0
	}


## Rotation de teinte (fraction de tour) qui donne au bleu du pack la couleur du joueur `numero` :
## celle de la marque d'un skin, pour les huit couleurs (0 pour le bleu).
static func decalage_marque(numero: int) -> float:
	return fposmod(teinte_tour(numero) - tour_teinte_base, 360.0) / 360.0


## Nuanceur de teinte réglé sur `decalage` ; `null` pour 0 (la couleur d'origine).
static func materiau_decalage(decalage: float) -> ShaderMaterial:
	if decalage == 0.0:
		return null
	var materiau := ShaderMaterial.new()
	materiau.shader = load(SHADER_TOUR) as Shader
	materiau.set_shader_parameter("decalage_teinte", decalage)
	return materiau


## Teinte dominante de la tour du joueur `numero`, en degrés : sert à vérifier que deux joueurs ne
## se confondent pas.
static func teinte_tour(numero: int) -> float:
	var n: int = numero_valide(numero)
	if n <= tours_pack.size():
		return tours_pack[n - 1]["teinte"]
	return teintes_calculees[n - tours_pack.size() - 1]


## Nuanceur de teinte pour les joueurs 5 à 8, `null` pour les couleurs du pack.
static func materiau_tour(numero: int) -> ShaderMaterial:
	var decalage: float = tour(numero)["decalage"]
	if decalage == 0.0:
		return null
	var materiau := ShaderMaterial.new()
	materiau.shader = load(SHADER_TOUR) as Shader
	materiau.set_shader_parameter("decalage_teinte", decalage)
	return materiau


# --- Rareté et armure : symbole, couleur et clé de libellé, partagés par l'interface -------------


static func couleur_rarete(r: int) -> Color:
	match r:
		Types.Rarete.COMMUNE:
			return Color("#c3c9cc")
		Types.Rarete.PEU_COMMUNE:
			return Color("#7bd88f")
		Types.Rarete.RARE:
			return Color("#72b8ff")
		Types.Rarete.EPIQUE:
			return Color("#d6a3ff")
		Types.Rarete.ANCESTRALE:
			return Color("#ffb54d")
		Types.Rarete.SOUVERAINE:
			return Color("#ff6f7d")
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
		Types.Rarete.ANCESTRALE:
			return "❖"
		Types.Rarete.SOUVERAINE:
			return "♛"
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
		Types.Rarete.ANCESTRALE:
			return "rarete.ancestrale"
		Types.Rarete.SOUVERAINE:
			return "rarete.souveraine"
	return ""


## Couleur d'un texte d'armure sur le fond des panneaux. Le nom et le symbole restent affichés
## avec elle.
static func couleur_texte_armure(a: int) -> Color:
	match a:
		Types.Armure.LEGERE:
			return Color("#8fd18b")
		Types.Armure.MOYENNE:
			return Color("#f0c85a")
		Types.Armure.LOURDE:
			return Color("#7bb8e6")
		Types.Armure.FORTIFIEE:
			return Color("#c79be6")
		Types.Armure.AUCUNE:
			return Color("#b5afc0")
		Types.Armure.BOSS:
			return Color("#ff8a78")
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
