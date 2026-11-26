extends SceneTree
## Dessine par script les sprites d'effets des attaques (boule de feu, éclat de glace, bombe, fiole,
## rune, étincelle…), dans le style et la palette de Tiny Swords : aplats de 3 à 4 teintes, gros
## pixels, contour sombre d'1 px, alpha 0 ou 1 seulement (une fumée se fait par tramage). Chaque
## planche est une bande horizontale d'images côte à côte, à la résolution native basse : le jeu les
## affiche à l'échelle 3 en `TEXTURE_FILTER_NEAREST`. Le hasard a une graine fixe : la même
## exécution sort toujours les mêmes octets, et le test compare le disque à `planche(nom)`.
##   godot --headless --path . --script res://tools/dessiner_effets_attaques.gd
##     [-- --sortie <dossier>]
##   ... -- --planche-contact <png absolu>        toutes les planches ×4 sur le vert de l'arène
##   ... -- --planche-projectiles <png absolu>    les projectiles seuls ×8

const SORTIE_DEFAUT := "res://assets/maison/effets_attaques"
const Commun := preload("res://tools/dessin/dessin_commun.gd")
## Un fichier de dessins par élément : une ligne ici pour en ajouter un.
const DESSINS: Array[GDScript] = [
	preload("res://tools/dessin/dessins_feu.gd"),
	preload("res://tools/dessin/dessins_glace.gd"),
	preload("res://tools/dessin/dessins_bombe.gd"),
	preload("res://tools/dessin/dessins_poison.gd"),
	preload("res://tools/dessin/dessins_arcane.gd"),
	preload("res://tools/dessin/dessins_acier.gd"),
	preload("res://tools/dessin/dessins_carreau.gd"),
	preload("res://tools/dessin/dessins_magique.gd"),
	preload("res://tools/dessin/dessins_siege.gd"),
	preload("res://tools/dessin/dessins_chaos.gd"),
	preload("res://tools/dessin/dessins_lot9_tranchant.gd"),
	preload("res://tools/dessin/dessins_lot9_percant.gd"),
	preload("res://tools/dessin/dessins_lot9_magique.gd"),
	preload("res://tools/dessin/dessins_lot9_marques.gd"),
	preload("res://tools/dessin/dessins_lot9_siege.gd"),
	preload("res://tools/dessin/dessins_lot9_chaos.gd"),
	preload("res://tools/dessin/dessins_partages.gd"),
]
const ECHELLE_CONTACT: int = 4
const ECHELLE_PROJECTILES: int = 8
const ECART: int = 4
const VERT_ARENE := Commun.VERT_ARENE
const VERT_CASE := Commun.VERT_CASE
## Nom de la planche : taille d'une image et nombre d'images (la liste complète).
const PLANCHES: Dictionary = Commun.PLANCHES
const PROJECTILES: PackedStringArray = [
	"boule_feu",
	"eclat_glace",
	"bombe",
	"fiole",
	"rune",
	"lame_croissant",
	"faucille",
	"disque_scie",
	"lame_tournante",
	"carreau",
	"carreau_baliste",
	"chausse_trape",
	"pique",
	"aiguille",
	"etoile_astrale",
	"petard",
	"rocher",
	"mine_forge",
	"de_pipe",
	"sablier",
	"eclat_miroir",
	"engrenage",
	"couperet",
	"rasoir",
	"serpe",
	"hache",
	"javeline",
	"fleche_marquante",
	"lance_epineuse",
	"siphon",
	"prisme",
	"lueur",
	"vasque",
	"baril",
	"maillet",
	"pierre_lestee",
	"obus",
	"brasero",
	"creneau",
	"gravats",
	"bloc_colosse",
	"urne",
	"goutte_sang",
	"engrenage_double",
	"serment",
	"fleche_spectre",
	"eclat_discorde",
	"coupe",
	"cendre",
	"malefice",
]


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	var options: Dictionary = _lire_options(args)
	if options.is_empty():
		return 1
	var contact: String = options["contact"]
	var projectiles: String = options["projectiles"]
	var ok: bool = true
	if contact != "" or projectiles != "":
		if contact != "":
			ok = _ecrire(contacts(PLANCHES.keys(), ECHELLE_CONTACT), contact)
		if ok and projectiles != "":
			ok = _ecrire(contacts(PROJECTILES, ECHELLE_PROJECTILES), projectiles)
		return 0 if ok else 1
	var sortie: String = options["sortie"]
	DirAccess.make_dir_recursive_absolute(sortie)
	for nom: String in PLANCHES:
		ok = ok and _ecrire(planche(nom), sortie.path_join(nom + ".png"))
	if ok:
		print("Planches écrites : %s" % sortie)
	return 0 if ok else 1


## Les options de la ligne de commande ; vide si l'une est inconnue ou sans valeur.
func _lire_options(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"sortie": ProjectSettings.globalize_path(SORTIE_DEFAUT), "contact": "", "projectiles": ""
	}
	var cles: Dictionary = {
		"--sortie": "sortie", "--planche-contact": "contact", "--planche-projectiles": "projectiles"
	}
	var i: int = 0
	while i < args.size():
		if not cles.has(args[i]) or i + 1 >= args.size():
			printerr("Argument inconnu ou sans valeur : %s" % args[i])
			return {}
		options[cles[args[i]]] = args[i + 1]
		i += 2
	return options


func _ecrire(img: Image, chemin: String) -> bool:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var erreur: int = img.save_png(chemin)
	if erreur != OK:
		printerr("Écriture impossible : %s (%d)" % [chemin, erreur])
		return false
	return true


## Une ligne par planche, chaque image agrandie sur le vert de l'arène, pour la relecture.
static func contacts(noms: Array, echelle: int) -> Image:
	var largeur: int = 0
	var hauteur: int = ECART
	var lignes: Array[Image] = []
	for nom: Variant in noms:
		var ligne: Image = _ligne_contact(planche(String(nom)), String(nom), echelle)
		lignes.append(ligne)
		largeur = maxi(largeur, ligne.get_width())
		hauteur += ligne.get_height() + ECART
	var feuille: Image = Image.create_empty(largeur + 2 * ECART, hauteur, false, Image.FORMAT_RGBA8)
	feuille.fill(VERT_ARENE)
	var y: int = ECART
	for ligne: Image in lignes:
		feuille.blit_rect(ligne, Rect2i(Vector2i.ZERO, ligne.get_size()), Vector2i(ECART, y))
		y += ligne.get_height() + ECART
	return feuille


static func _ligne_contact(bande: Image, nom: String, echelle: int) -> Image:
	var taille: Vector2i = PLANCHES[nom]["taille"]
	var n: int = PLANCHES[nom]["images"]
	var pas: int = taille.x * echelle + ECART
	var ligne: Image = Image.create_empty(
		pas * n - ECART, taille.y * echelle, false, Image.FORMAT_RGBA8
	)
	ligne.fill(VERT_ARENE)
	for k: int in n:
		var cadre: Image = Image.create_empty(taille.x, taille.y, false, Image.FORMAT_RGBA8)
		cadre.blit_rect(bande, Rect2i(k * taille.x, 0, taille.x, taille.y), Vector2i.ZERO)
		cadre.resize(taille.x * echelle, taille.y * echelle, Image.INTERPOLATE_NEAREST)
		var zone: Rect2i = Rect2i(Vector2i(k * pas, 0), cadre.get_size())
		ligne.fill_rect(zone, VERT_CASE)
		ligne.blend_rect(cadre, Rect2i(Vector2i.ZERO, cadre.get_size()), zone.position)
	return ligne


## La bande d'images de la planche `nom`, rendue en mémoire (les fichiers de dessins font foi).
static func planche(nom: String) -> Image:
	for dessins: GDScript in DESSINS:
		var noms: PackedStringArray = dessins.get_script_constant_map()["NOMS"]
		if noms.has(nom):
			return dessins.call("dessiner", nom) as Image
	push_error("Planche inconnue : %s" % nom)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
