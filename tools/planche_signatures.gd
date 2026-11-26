extends SceneTree
## Compose la planche des signatures d'armes : une carte par arme (nom, projectile à sa couleur
## avec sa traînée, impact, statut), une ligne par type de dégâts. Rendu par `Image`, sans fenêtre
## ni hasard : la même exécution sort les mêmes octets. Les formes viennent de
## `visuels/formes_signatures.gd`, la table de `visuels/signatures_armes.gd`, les noms de `data/`.
##   godot --headless --path . --script res://tools/planche_signatures.gd [-- --sortie <fichier>]

const SORTIE_DEFAUT := "res://docs/planche_signatures.png"
const POLICE := "res://assets/polices/dejavu-sans/dejavu-sans-latin-400-normal.woff2"
const CARTE := Vector2i(230, 150)
const MARGE: int = 10
const COLONNES: int = 6
const FOND := Color("161c2e")
const CARTE_FOND := Color("232b45")
const CARTE_BORD := Color("3b4670")
const TEXTE := Color("f2f4ff")
const TEXTE_DISCRET := Color("9aa6d0")
const TITRE_HAUT: int = 34
const ECHELLE_PROJECTILE: float = 1.5
const TYPES: Array[String] = ["tranchant", "perçant", "magique", "siège", "chaos"]
const NOMS_TYPES: Array[String] = ["Tranchant", "Perçant", "Magique", "Siège", "Chaos"]

var _police := FontFile.new()
var _rid: RID
var _serveur: TextServer


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


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
	var donnees: Donnees = Donnees.charger()
	# Une ligne par type de dégâts, dans l'ordre de `data/armes.json`.
	var lignes: Array[Array] = []
	for _t: String in TYPES:
		lignes.append([])
	for id: String in SignaturesArmes.ids():
		var arme: Dictionary = donnees.armes[id]
		var rang: int = int(arme["type_degats"])
		if rang < 0 or rang >= TYPES.size():
			printerr("Type inconnu : %s" % arme["type_degats"])
			return 1
		lignes[rang].append(id)
	var largeur_ligne: int = 0
	for ligne: Array in lignes:
		largeur_ligne = maxi(largeur_ligne, ligne.size())
	largeur_ligne = maxi(largeur_ligne, COLONNES)
	var entete: int = 48
	var largeur: int = MARGE + largeur_ligne * (CARTE.x + MARGE)
	var hauteur: int = entete + lignes.size() * (CARTE.y + MARGE + 22) + MARGE
	var planche := Image.create(largeur, hauteur, false, Image.FORMAT_RGBA8)
	planche.fill(FOND)
	_texte(planche, "Signatures d’armes", Vector2i(MARGE, 8), 22, TEXTE)
	for r: int in lignes.size():
		var y: int = entete + r * (CARTE.y + MARGE + 22)
		_texte(planche, NOMS_TYPES[r], Vector2i(MARGE, y), 15, TEXTE_DISCRET)
		for c: int in lignes[r].size():
			var id: String = lignes[r][c]
			var x: int = MARGE + c * (CARTE.x + MARGE)
			_carte(
				planche, Vector2i(x, y + 22), id, String((donnees.armes[id] as Dictionary)["nom"])
			)
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	var erreur: int = planche.save_png(sortie)
	if erreur != OK:
		printerr("Écriture impossible : %s (%d)" % [sortie, erreur])
		return 1
	print("Planche écrite : %s" % sortie)
	return 0


func _carte(planche: Image, origine: Vector2i, id: String, nom: String) -> void:
	var s: Dictionary = SignaturesArmes.de(id)
	var couleur: Color = s["couleur"]
	planche.fill_rect(Rect2i(origine, CARTE), CARTE_BORD)
	planche.fill_rect(Rect2i(origine + Vector2i(2, 2), CARTE - Vector2i(4, 4)), CARTE_FOND)
	_texte(planche, nom, origine + Vector2i(10, 8), 14, TEXTE)
	var milieu: int = origine.y + TITRE_HAUT + (CARTE.y - TITRE_HAUT - 22) / 2
	# Traînée puis projectile (vers la droite), puis impact.
	var trainee: Image = FormesSignatures.image(s["trainee"])
	_poser(planche, trainee, Vector2i(origine.x + 12 + 32, milieu), couleur, 1.0, 0.9)
	var projectile: Image = FormesSignatures.image(s["projectile"])
	_poser(
		planche,
		projectile,
		Vector2i(origine.x + 12 + 64 + 14, milieu),
		couleur,
		ECHELLE_PROJECTILE,
		1.0
	)
	var impact: Image = FormesSignatures.image(s["impact"])
	_poser(planche, impact, Vector2i(origine.x + 12 + 64 + 14 + 40 + 14, milieu), couleur, 1.0, 1.0)
	var statut: String = s["statut"]
	var legende: String = (
		"statut : aucun" if statut.is_empty() else "statut : %s" % statut.replace("_", " ")
	)
	if not statut.is_empty():
		var forme: Image = FormesSignatures.image(String(SignaturesArmes.STATUTS[statut]))
		_poser(
			planche,
			forme,
			Vector2i(origine.x + CARTE.x - 28, origine.y + 22),
			_couleur_statut(statut),
			0.6,
			1.0
		)
	_texte(planche, legende, origine + Vector2i(10, CARTE.y - 22), 12, TEXTE_DISCRET)


func _couleur_statut(statut: String) -> Color:
	match statut:
		"givre":
			return Color(0.7, 0.9, 1.0)
		"poison":
			return Color(0.5, 0.82, 0.35)
		"etourdissement":
			return Color(1.0, 0.88, 0.35)
		"brulure":
			return Color(1.0, 0.55, 0.2)
	return Color(0.45, 0.9, 0.5)


## Pose `forme` (blanc) teintée, centrée sur `centre`, à l'échelle donnée, par mélange alpha.
func _poser(
	dest: Image, forme: Image, centre: Vector2i, teinte: Color, echelle: float, opacite: float
) -> void:
	var img: Image = forme.duplicate()
	if echelle != 1.0:
		img.resize(
			int(img.get_width() * echelle),
			int(img.get_height() * echelle),
			Image.INTERPOLATE_BILINEAR
		)
	var haut_gauche: Vector2i = centre - img.get_size() / 2
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			_melanger(dest, haut_gauche + Vector2i(x, y), Color(teinte, p.a * opacite))


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
