extends RefCounted
## Les outils d'image de la planche des signatures (`tools/planche_signatures.gd`) : mélange alpha,
## image d'une planche de sprites, teinte, agrandissement au pixel près, texte par les glyphes du
## `TextServer` (le rendu d'un `Label` n'existe pas sans écran).

const Dessin := preload("res://tools/dessiner_effets_attaques.gd")
const POLICE := "res://assets/polices/dejavu-sans/dejavu-sans-latin-400-normal.woff2"


## Écrit du texte avec les glyphes de la police, par mélange alpha.
class Texte:
	extends RefCounted
	var _police: FontFile = FontFile.new()
	var _rid: RID
	var _serveur: TextServer

	## Mélange `c` (son alpha) sur le pixel `pos` de `dest`, sans sortir de l'image.
	static func melanger(dest: Image, pos: Vector2i, c: Color) -> void:
		if pos.x < 0 or pos.y < 0 or pos.x >= dest.get_width() or pos.y >= dest.get_height():
			return
		var d: Color = dest.get_pixelv(pos)
		dest.set_pixelv(
			pos,
			Color(d.r + (c.r - d.r) * c.a, d.g + (c.g - d.g) * c.a, d.b + (c.b - d.b) * c.a, 1.0)
		)

	## Vrai si la police est lisible.
	func charger(chemin: String) -> bool:
		if _police.load_dynamic_font(chemin) != OK:
			return false
		_serveur = TextServerManager.get_primary_interface()
		_rid = _police.get_rids()[0]
		return true

	## Largeur de `texte` en pixels, à la `taille` donnée.
	func largeur(texte: String, taille: int) -> float:
		var x: float = 0.0
		for k: int in texte.length():
			var glyphe: int = _serveur.font_get_glyph_index(_rid, taille, texte.unicode_at(k), 0)
			x += _serveur.font_get_glyph_advance(_rid, taille, glyphe).x
		return x

	## Écrit `texte` à partir de `pos` (coin haut gauche).
	func ecrire(dest: Image, texte: String, pos: Vector2i, taille: int, couleur: Color) -> void:
		var taille_v: Vector2i = Vector2i(taille, 0)
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
				var rgba: bool = (
					atlas.get_format() == Image.FORMAT_LA8
					or atlas.get_format() == Image.FORMAT_RGBA8
				)
				for gy: int in int(uv.size.y):
					for gx: int in int(uv.size.x):
						var c: Color = atlas.get_pixel(
							int(uv.position.x) + gx, int(uv.position.y) + gy
						)
						var a: float = c.a if rgba else c.r
						if a > 0.0:
							var cible: Vector2i = Vector2i(
								int(x + decalage.x) + gx, ligne_base + int(decalage.y) + gy
							)
							melanger(dest, cible, Color(couleur, a))
			x += _serveur.font_get_glyph_advance(_rid, taille, glyphe).x


## Mélange `c` (son alpha) sur le pixel `pos` de `dest`, sans sortir de l'image.
static func melanger(dest: Image, pos: Vector2i, c: Color) -> void:
	Texte.melanger(dest, pos, c)


## L'image `rang` de la planche de sprites `nom` (rendue par les fichiers de dessins).
static func image_de(nom: String, rang: int) -> Image:
	var taille: Vector2i = Dessin.PLANCHES[nom]["taille"]
	var bande: Image = Dessin.planche(nom)
	var cadre: Image = Image.create_empty(taille.x, taille.y, false, Image.FORMAT_RGBA8)
	cadre.blit_rect(bande, Rect2i(rang * taille.x, 0, taille.x, taille.y), Vector2i.ZERO)
	return cadre


## Le nombre d'images de la planche `nom`.
static func nombre_images(nom: String) -> int:
	return Dessin.PLANCHES[nom]["images"]


## `img` multipliée par `teinte`, l'alpha inchangé.
static func teinter(img: Image, teinte: Color) -> Image:
	var rendu: Image = img.duplicate()
	for y: int in rendu.get_height():
		for x: int in rendu.get_width():
			var c: Color = rendu.get_pixel(x, y)
			if c.a > 0.0:
				rendu.set_pixel(x, y, Color(c.r * teinte.r, c.g * teinte.g, c.b * teinte.b, c.a))
	return rendu


## `img` agrandie de `echelle` fois, pixels nets.
static func agrandir(img: Image, echelle: int) -> Image:
	var rendu: Image = img.duplicate()
	rendu.resize(img.get_width() * echelle, img.get_height() * echelle, Image.INTERPOLATE_NEAREST)
	return rendu


## Le plus grand agrandissement entier de `img` qui tient dans `cote` pixels (au moins 1).
static func echelle_pour(img: Image, cote: int) -> int:
	return maxi(1, cote / maxi(img.get_width(), img.get_height()))


## Pose `img` au centre de la case `case` de `dest`, par mélange alpha.
static func poser_centree(dest: Image, img: Image, case: Rect2i) -> void:
	var haut_gauche: Vector2i = case.position + (case.size - img.get_size()) / 2
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a > 0.0:
				melanger(dest, haut_gauche + Vector2i(x, y), p)
