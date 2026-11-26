extends SceneTree
## Compose la planche avant/après des superpositions de la tour (D19) : par statistique, la tour
## nue puis ses trois paliers, côte à côte à l'échelle du jeu (zoom 1) ; la tour entièrement
## améliorée ; les huit couleurs de joueur. Rendu par `Image`, sans fenêtre ni hasard. Les
## paliers sont ceux de `ApparenceTour` sur les seuils de `data/apparence_tour.json`, les images
## celles de `assets/tour_apparence/`, les points de pose ceux de `data/skins_tour.json`.
##   godot --headless --path . --script res://tools/planche_apparence_tour.gd [-- --sortie <f>]

const SORTIE_DEFAUT := "res://docs/planche_apparence_tour.png"
const POLICE := "res://assets/polices/dejavu-sans/dejavu-sans-latin-400-normal.woff2"
const DOSSIER_IMAGES := "res://assets/tour_apparence/"
const FOND := Color("161c2e")
const CELLULE_FOND := Color("232b45")
const TEXTE := Color("f2f4ff")
const TEXTE_DISCRET := Color("9aa6d0")
const MARGE: int = 10
## Une cellule contient la tour à l'échelle 1,25 au plus.
const CELLULE := Vector2i(160, 330)
## Pied de la tour dans son image de 128 × 256 ; la mise à l'échelle pivote autour de lui.
const PIED := Vector2(64.0, 235.0)
const PIED_CELLULE := Vector2(80.0, 300.0)
const ENTETE: int = 56
const MARGE_GAUCHE: int = 96
const HAUT_TITRE_LIGNE: int = 24
## Ordre des colonnes de la grille : les sept statistiques. Lignes : nue, palier 1, 2, 3.
const COLONNES: Array[String] = [
	"epines", "pv_max", "mana", "armure", "esquive", "regen", "vol_de_vie"
]
const NOMS: Dictionary = {
	"epines": "Épines",
	"pv_max": "PV maximum",
	"mana": "Mana",
	"armure": "Armure",
	"esquive": "Esquive",
	"regen": "Régénération",
	"vol_de_vie": "Vol de vie",
}
## Ordre de pose des superpositions : du fond vers le dessus.
const ORDRE_POSE: Array[String] = ["esquive", "regen", "mana", "armure", "epines", "vol_de_vie"]

var _police := FontFile.new()
var _rid: RID
var _serveur: TextServer
var _donnees: Donnees
var _images: Dictionary = {}


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


## Coin haut gauche de la cellule de la colonne `c` (0 à 6) et de la ligne `r` (0 : nue, 1 à 3 :
## paliers) de la grille.
static func origine_cellule(c: int, r: int) -> Vector2i:
	var x: int = MARGE_GAUCHE + c * (CELLULE.x + MARGE)
	var y: int = ENTETE + HAUT_TITRE_LIGNE + r * (CELLULE.y + MARGE)
	return Vector2i(x, y)


func _lancer(args: PackedStringArray) -> int:
	var sortie: String = ProjectSettings.globalize_path(SORTIE_DEFAUT)
	var i: int = 0
	while i < args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
			i += 2
		else:
			printerr("Argument inconnu : %s" % args[i])
			return 1
	if _police.load_dynamic_font(POLICE) != OK:
		printerr("Police illisible : %s" % POLICE)
		return 1
	_serveur = TextServerManager.get_primary_interface()
	_rid = _police.get_rids()[0]
	_donnees = Donnees.charger()
	if _donnees == null:
		return 1
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		for p: int in range(1, 4):
			var chemin := "%s%s_%d.png" % [DOSSIER_IMAGES, stat, p]
			var img := Image.load_from_file(ProjectSettings.globalize_path(chemin))
			if img == null:
				printerr("Image illisible : %s" % chemin)
				return 1
			img.convert(Image.FORMAT_RGBA8)
			_images["%s_%d" % [stat, p]] = img
	var largeur: int = MARGE_GAUCHE + COLONNES.size() * (CELLULE.x + MARGE)
	var bas_grille: int = origine_cellule(0, 4).y
	var rangee_couleurs: int = bas_grille + 30
	var largeur_couleurs: int = MARGE + 9 * (CELLULE.x + MARGE)
	var hauteur: int = rangee_couleurs + CELLULE.y + 2 * MARGE
	var planche := Image.create(maxi(largeur, largeur_couleurs), hauteur, false, Image.FORMAT_RGBA8)
	planche.fill(FOND)
	_texte(planche, "Apparence de la tour : avant et après", Vector2i(MARGE, 8), 22, TEXTE)
	_texte(
		planche,
		"Échelle du jeu (zoom 1). Les seuils sont dans data/apparence_tour.json.",
		Vector2i(MARGE, 34),
		13,
		TEXTE_DISCRET
	)
	for c: int in COLONNES.size():
		var stat: String = COLONNES[c]
		_texte(planche, NOMS[stat], origine_cellule(c, 0) + Vector2i(4, -22), 15, TEXTE)
		for r: int in 4:
			var o: Vector2i = origine_cellule(c, r)
			planche.fill_rect(Rect2i(o, CELLULE), CELLULE_FOND)
			var paliers: Dictionary = {}
			if r > 0:
				paliers[stat] = r
			_tour(planche, o, 1, paliers)
	var libelles: Array[String] = ["nue", "palier 1", "palier 2", "palier 3"]
	for r: int in 4:
		_texte(
			planche,
			libelles[r],
			origine_cellule(0, r) + Vector2i(-MARGE_GAUCHE + 8, 140),
			14,
			TEXTE_DISCRET
		)
	_texte(
		planche,
		"Tout au maximum, puis les huit couleurs de joueur",
		Vector2i(MARGE, bas_grille + 4),
		15,
		TEXTE
	)
	var maximum: Dictionary = {}
	for stat: String in COLONNES:
		maximum[stat] = 3
	for k: int in 9:
		var o := Vector2i(MARGE + k * (CELLULE.x + MARGE), rangee_couleurs)
		planche.fill_rect(Rect2i(o, CELLULE), CELLULE_FOND)
		_tour(planche, o, maxi(k, 1), maximum)
		var legende: String = "bleu (jeu)" if k == 0 else "joueur %d" % k
		_texte(planche, legende, o + Vector2i(6, CELLULE.y - 20), 12, TEXTE_DISCRET)
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	var erreur: int = planche.save_png(sortie)
	if erreur != OK:
		printerr("Écriture impossible : %s (%d)" % [sortie, erreur])
		return 1
	print("Planche écrite : %s" % sortie)
	return 0


## Pose dans la cellule `origine` la tour du joueur `numero` et les superpositions de `paliers`
## (statistique → palier), l'ensemble agrandi par le palier de `pv_max`.
func _tour(planche: Image, origine: Vector2i, numero: int, paliers: Dictionary) -> void:
	var t: Dictionary = Apparence.tour(numero)
	var tour := Image.load_from_file(ProjectSettings.globalize_path(String(t["fichier"])))
	tour.convert(Image.FORMAT_RGBA8)
	_teinter(tour, float(t["decalage"]))
	var composite := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	composite.fill(Color(0, 0, 0, 0))
	var skin: Dictionary = _donnees.skins_tour["defaut"]
	var ancrages: Dictionary = skin["ancrages"]
	for stat: String in ORDRE_POSE:
		if stat == "esquive" and int(paliers.get(stat, 0)) > 0:
			_poser(composite, _images["esquive_%d" % int(paliers[stat])], ancrages[stat])
	_poser_tour(composite, tour)
	for stat: String in ORDRE_POSE:
		var p: int = int(paliers.get(stat, 0))
		if stat != "esquive" and p > 0:
			_poser(composite, _images["%s_%d" % [stat, p]], ancrages[stat])
	var echelle: float = ApparenceTour.echelle(paliers, _donnees)
	if echelle != 1.0:
		composite.resize(
			roundi(128.0 * echelle), roundi(256.0 * echelle), Image.INTERPOLATE_NEAREST
		)
	var haut_gauche: Vector2i = origine + Vector2i((PIED_CELLULE - PIED * echelle).round())
	for y: int in composite.get_height():
		for x: int in composite.get_width():
			var c: Color = composite.get_pixel(x, y)
			if c.a > 0.0:
				_melanger(planche, haut_gauche + Vector2i(x, y), c)


func _poser_tour(dest: Image, tour: Image) -> void:
	for y: int in 256:
		for x: int in 128:
			var c: Color = tour.get_pixel(x, y)
			if c.a > 0.0:
				_melanger_alpha(dest, Vector2i(x, y), c)


## Pose `img` par son centre sur l'ancrage `{x, y}`, en gardant l'alpha accumulé.
func _poser(dest: Image, img: Image, ancrage: Dictionary) -> void:
	var haut_gauche := Vector2i(
		roundi(float(ancrage["x"])) - img.get_width() / 2,
		roundi(float(ancrage["y"])) - img.get_height() / 2
	)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.0:
				_melanger_alpha(dest, haut_gauche + Vector2i(x, y), c)


## Même règle que `teinte_tour.gdshader` : seules les pierres bleu-vert bougent.
func _teinter(img: Image, decalage: float) -> void:
	if decalage == 0.0:
		return
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.s > 0.2 and c.h >= 0.375 and c.h <= 0.75:
				img.set_pixel(x, y, Color.from_hsv(fposmod(c.h + decalage, 1.0), c.s, c.v, c.a))


## Mélange alpha sur une image elle-même transparente (le composite de la tour).
func _melanger_alpha(dest: Image, pos: Vector2i, c: Color) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= dest.get_width() or pos.y >= dest.get_height():
		return
	dest.set_pixelv(pos, dest.get_pixelv(pos).blend(c))


func _melanger(dest: Image, pos: Vector2i, c: Color) -> void:
	if pos.x < 0 or pos.y < 0 or pos.x >= dest.get_width() or pos.y >= dest.get_height():
		return
	var d: Color = dest.get_pixelv(pos)
	dest.set_pixelv(
		pos, Color(d.r + (c.r - d.r) * c.a, d.g + (c.g - d.g) * c.a, d.b + (c.b - d.b) * c.a, 1.0)
	)


## Écrit `texte` à partir de `pos` (coin haut gauche) avec les glyphes de la police.
func _texte(dest: Image, texte: String, pos: Vector2i, taille: int, couleur: Color) -> void:
	var taille_v := Vector2i(taille, 0)
	var x: float = pos.x
	var ligne_base: int = pos.y + int(taille * 0.9)
	for k: int in texte.length():
		var glyphe: int = _serveur.font_get_glyph_index(_rid, taille, texte.unicode_at(k), 0)
		_serveur.font_render_glyph(_rid, taille_v, glyphe)
		var uv: Rect2 = _serveur.font_get_glyph_uv_rect(_rid, taille_v, glyphe)
		var tex: int = _serveur.font_get_glyph_texture_idx(_rid, taille_v, glyphe)
		var decalage: Vector2 = _serveur.font_get_glyph_offset(_rid, taille_v, glyphe)
		if tex >= 0 and uv.size.x > 0.0:
			var atlas: Image = _serveur.font_get_texture_image(_rid, taille_v, tex)
			for gy: int in int(uv.size.y):
				for gx: int in int(uv.size.x):
					var a: float = (
						atlas.get_pixel(int(uv.position.x) + gx, int(uv.position.y) + gy).r
					)
					if (
						atlas.get_format() == Image.FORMAT_LA8
						or atlas.get_format() == Image.FORMAT_RGBA8
					):
						a = atlas.get_pixel(int(uv.position.x) + gx, int(uv.position.y) + gy).a
					if a > 0.0:
						_melanger(
							dest,
							Vector2i(int(x + decalage.x) + gx, ligne_base + int(decalage.y) + gy),
							Color(couleur, a)
						)
		x += _serveur.font_get_glyph_advance(_rid, taille, glyphe).x
