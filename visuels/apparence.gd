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
const IMAGES_PAR_SECONDE: float = 10.0
## Au-delà, l'ennemi tire de loin et s'arrête à sa portée (règle de `sim/ennemis.gd`).
const PORTEE_CORPS_A_CORPS: float = 60.0
const NB_TOURS: int = 8

## Feuilles par type d'unité : `{chemin}` prend la couleur du pack. `pieds` est la ligne de pixels
## de la case où les pieds touchent le sol (ombre du pack comprise).
const MODELES: Dictionary = {
	"torch":
	{
		"chemin": "Factions/Goblins/Troops/Torch/%s/Torch_%s.png",
		"case": Vector2i(192, 192),
		"colonnes": 7,
		"lignes": 5,
		"repos": Vector2i(0, 7),
		"course": Vector2i(1, 6),
		"attaque": Vector2i(2, 6),
		"attaque_bas": Vector2i(3, 6),
		"attaque_haut": Vector2i(4, 6),
		"pieds": 126.0,
	},
	"pawn":
	{
		"chemin": "Factions/Knights/Troops/Pawn/%s/Pawn_%s.png",
		"case": Vector2i(192, 192),
		"colonnes": 6,
		"lignes": 6,
		"repos": Vector2i(0, 6),
		"course": Vector2i(1, 6),
		"attaque": Vector2i(2, 6),
		"attaque_bas": Vector2i(2, 6),
		"attaque_haut": Vector2i(2, 6),
		"pieds": 122.0,
	},
	"archer":
	{
		"chemin": "Factions/Knights/Troops/Archer/%s/Archer_%s.png",
		"case": Vector2i(192, 192),
		"colonnes": 8,
		"lignes": 7,
		"repos": Vector2i(0, 6),
		"course": Vector2i(1, 6),
		"attaque": Vector2i(4, 8),
		"attaque_bas": Vector2i(6, 8),
		"attaque_haut": Vector2i(2, 8),
		"pieds": 128.0,
		# Le pack écrit « Purlple » dans le nom de la feuille violette de l'archer.
		"noms_irreguliers": {"Purple": "Purlple"},
	},
	"warrior":
	{
		"chemin": "Factions/Knights/Troops/Warrior/%s/Warrior_%s.png",
		"case": Vector2i(192, 192),
		"colonnes": 6,
		"lignes": 8,
		"repos": Vector2i(0, 6),
		"course": Vector2i(1, 6),
		"attaque": Vector2i(2, 6),
		"attaque_bas": Vector2i(4, 6),
		"attaque_haut": Vector2i(6, 6),
		"pieds": 130.0,
	},
	"barrel":
	{
		"chemin": "Factions/Goblins/Troops/Barrel/%s/Barrel_%s.png",
		"case": Vector2i(128, 128),
		"colonnes": 6,
		"lignes": 6,
		"repos": Vector2i(2, 1),
		"course": Vector2i(4, 3),
		"attaque": Vector2i(5, 3),
		"attaque_bas": Vector2i(5, 3),
		"attaque_haut": Vector2i(5, 3),
		"pieds": 94.0,
	},
	"tnt":
	{
		"chemin": "Factions/Goblins/Troops/TNT/%s/TNT_%s.png",
		"case": Vector2i(192, 192),
		"colonnes": 7,
		"lignes": 3,
		"repos": Vector2i(0, 6),
		"course": Vector2i(1, 6),
		"attaque": Vector2i(2, 7),
		"attaque_bas": Vector2i(2, 7),
		"attaque_haut": Vector2i(2, 7),
		"pieds": 130.0,
	},
	"mouton":
	{
		"chemin": "Resources/Sheep/HappySheep_All.png",
		"case": Vector2i(128, 128),
		"colonnes": 8,
		"lignes": 2,
		"repos": Vector2i(0, 8),
		"course": Vector2i(1, 6),
		"attaque": Vector2i(1, 6),
		"attaque_bas": Vector2i(1, 6),
		"attaque_haut": Vector2i(1, 6),
		"pieds": 85.0,
	},
}

## Une entrée par entité (24 familles, convoi, boss) : le modèle du pack suit le modèle de jeu et
## la couleur du pack suit le palier (jaune, rouge, violet, bleu). `couleur_pack` est la couleur du
## pack ; `echelle` agrandit le sprite.
const ENTITES: Dictionary = {
	"torche_jaune": {"modele": "torch", "couleur_pack": "Yellow", "echelle": 1.0},
	"torche_rouge": {"modele": "torch", "couleur_pack": "Red", "echelle": 1.0},
	"torche_violet": {"modele": "torch", "couleur_pack": "Purple", "echelle": 1.0},
	"torche_bleu": {"modele": "torch", "couleur_pack": "Blue", "echelle": 1.0},
	"paysan_jaune": {"modele": "pawn", "couleur_pack": "Yellow", "echelle": 1.0},
	"paysan_rouge": {"modele": "pawn", "couleur_pack": "Red", "echelle": 1.0},
	"paysan_violet": {"modele": "pawn", "couleur_pack": "Purple", "echelle": 1.0},
	"paysan_bleu": {"modele": "pawn", "couleur_pack": "Blue", "echelle": 1.0},
	"guerrier_jaune": {"modele": "warrior", "couleur_pack": "Yellow", "echelle": 1.0},
	"guerrier_rouge": {"modele": "warrior", "couleur_pack": "Red", "echelle": 1.0},
	"guerrier_violet": {"modele": "warrior", "couleur_pack": "Purple", "echelle": 1.0},
	"guerrier_bleu": {"modele": "warrior", "couleur_pack": "Blue", "echelle": 1.0},
	"tonneau_jaune": {"modele": "barrel", "couleur_pack": "Yellow", "echelle": 1.5},
	"tonneau_rouge": {"modele": "barrel", "couleur_pack": "Red", "echelle": 1.5},
	"tonneau_violet": {"modele": "barrel", "couleur_pack": "Purple", "echelle": 1.5},
	"tonneau_bleu": {"modele": "barrel", "couleur_pack": "Blue", "echelle": 1.5},
	"dynamite_jaune": {"modele": "tnt", "couleur_pack": "Yellow", "echelle": 1.0},
	"dynamite_rouge": {"modele": "tnt", "couleur_pack": "Red", "echelle": 1.0},
	"dynamite_violet": {"modele": "tnt", "couleur_pack": "Purple", "echelle": 1.0},
	"dynamite_bleu": {"modele": "tnt", "couleur_pack": "Blue", "echelle": 1.0},
	"archer_jaune": {"modele": "archer", "couleur_pack": "Yellow", "echelle": 1.0},
	"archer_rouge": {"modele": "archer", "couleur_pack": "Red", "echelle": 1.0},
	"archer_violet": {"modele": "archer", "couleur_pack": "Purple", "echelle": 1.0},
	"archer_bleu": {"modele": "archer", "couleur_pack": "Blue", "echelle": 1.0},
	"troupeau_du_colporteur":
	{
		"modele": "mouton",
		"couleur_pack": "",
		"echelle": 2.0,
		"accessoire":
		{
			"feuille": "Resources/Resources/G_Idle_(NoShadow).png",
			"decalage": Vector2(0.0, -42.0),
			"echelle": 0.5,
		},
	},
	"aieul_de_fer": {"modele": "warrior", "couleur_pack": "Blue", "echelle": 3.0},
}

## Les alliés invoqués (`data/unites.json` `modele`) : la feuille du pack d'un modèle d'ennemi, mais
## une teinte (`teinte`, posée sur le sprite) qu'aucune famille ni aucun statut n'a, et un anneau
## au sol (`anneau`) que les ennemis n'ont pas. Un modèle inconnu n'a pas d'entrée.
const ALLIES: Dictionary = {
	"guerrier":
	{
		"modele": "warrior",
		"couleur_pack": "Blue",
		"echelle": 1.0,
		"teinte": Color(1.0, 0.72, 0.96),
	},
	"archer":
	{
		"modele": "archer",
		"couleur_pack": "Blue",
		"echelle": 1.0,
		"teinte": Color(1.0, 0.72, 0.96),
	},
	"paysan":
	{
		"modele": "pawn",
		"couleur_pack": "Blue",
		"echelle": 1.0,
		"teinte": Color(1.0, 0.72, 0.96),
	},
}
## L'anneau double au sol des alliés : couleur du trait extérieur et de l'intérieur.
const ANNEAU_ALLIE_EXTERIEUR := Color(1.0, 0.95, 0.75)
const ANNEAU_ALLIE_INTERIEUR := Color(0.62, 0.3, 0.85)
const CONTOUR_ANNEAU_ALLIE := Color(0.1, 0.07, 0.15, 0.9)

## La mort de toutes les familles : le crâne de `Dead.png`, 14 images lues ligne après ligne.
const MORT: Dictionary = {
	"feuille": "res://assets/tiny_swords/Factions/Knights/Troops/Dead/Dead.png",
	"case": Vector2i(128, 128),
	"colonnes": 7,
	"lignes": 2,
	"images": 14,
	"pieds": 92.0,
	"echelle": 1.0,
	"images_par_seconde": 14.0,
	"cle_boites": "mort",
}

## Grossissement de tous les sprites d'unités par rapport au pack : à 720p, au zoom par défaut, un
## ennemi ordinaire mesure environ 6 à 7 % de la hauteur de l'écran.
const ECHELLE_UNITES: float = 1.9
## La tour mesure environ 18 % de la hauteur de l'écran.
const TOUR_ECHELLE: float = 2.1
const TOUR_PIEDS: float = 228.0
## Sprite de tour dont on décale la teinte pour les joueurs 5 à 8.
const TOUR_BASE := "Factions/Knights/Buildings/Tower/Tower_Blue.png"
const TOUR_TEINTE_BASE: float = 190.0
const SHADER_TOUR := "res://visuels/teinte_tour.gdshader"
## Joueurs 1 à 4 : les quatre couleurs du pack et la teinte dominante de leur pierre, en degrés.
const TOURS_PACK: Array[Dictionary] = [
	{"couleur": "Blue", "teinte": 190.0},
	{"couleur": "Red", "teinte": 355.0},
	{"couleur": "Yellow", "teinte": 55.0},
	{"couleur": "Purple", "teinte": 280.0},
]
## Joueurs 5 à 8 : vert, orange, turquoise, rose (teinte visée, en degrés).
const TEINTES_CALCULEES: Array[float] = [125.0, 28.0, 160.0, 325.0]

const COULEUR_CERCLE := Color(1.0, 1.0, 1.0, 0.55)
const COULEUR_NOM := Color(1.0, 1.0, 1.0, 1.0)
const COULEUR_CONTOUR_NOM := Color(0.1, 0.07, 0.15, 1.0)

static var _entrees: Dictionary = {}


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
	if not ENTITES.has(id):
		return {}
	return _construire_entree(id, ENTITES[id])


## Comme `entree`, pour un allié du modèle `modele` (`ALLIES`) ; `couleur` est sa teinte. Vide si
## le modèle est inconnu.
static func entree_allie(modele: String) -> Dictionary:
	if not ALLIES.has(modele):
		return {}
	var cle: String = "allie_" + modele
	if _entrees.has(cle):
		return _entrees[cle]
	var entree_pack: Dictionary = _construire_entree(cle, ALLIES[modele])
	entree_pack["couleur"] = (ALLIES[modele] as Dictionary)["teinte"]
	return entree_pack


static func _construire_entree(id: String, source: Dictionary) -> Dictionary:
	var modele: Dictionary = (MODELES[source["modele"]] as Dictionary).duplicate()
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
	if not MODELES.has(cle):
		return ""
	var modele: Dictionary = MODELES[cle]
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


## `{fichier, decalage}` de la tour du joueur `numero` ; `decalage` est la rotation de teinte
## appliquée par le nuanceur, en fraction de tour (0 pour les couleurs du pack).
static func tour(numero: int) -> Dictionary:
	var n: int = numero_valide(numero)
	if n <= TOURS_PACK.size():
		var couleur: String = TOURS_PACK[n - 1]["couleur"]
		return {
			"fichier": RACINE + "Factions/Knights/Buildings/Tower/Tower_%s.png" % couleur,
			"decalage": 0.0,
		}
	var visee: float = TEINTES_CALCULEES[n - TOURS_PACK.size() - 1]
	return {
		"fichier": RACINE + TOUR_BASE, "decalage": fposmod(visee - TOUR_TEINTE_BASE, 360.0) / 360.0
	}


## Teinte dominante de la tour du joueur `numero`, en degrés : sert à vérifier que deux joueurs ne
## se confondent pas.
static func teinte_tour(numero: int) -> float:
	var n: int = numero_valide(numero)
	if n <= TOURS_PACK.size():
		return TOURS_PACK[n - 1]["teinte"]
	return TEINTES_CALCULEES[n - TOURS_PACK.size() - 1]


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
