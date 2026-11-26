extends CasDeTest
## Les sprites d'effets des attaques sont dessinés par `tools/dessiner_effets_attaques.gd` : chaque
## planche écrite sur le disque est identique, pixel pour pixel, à ce que rend le script, elle
## respecte le style de Tiny Swords (alpha 0 ou 1, peu de teintes) et la forme dit l'élément, pas
## seulement la couleur.

const Dessin := preload("res://tools/dessiner_effets_attaques.gd")
const DOSSIER := "res://assets/maison/effets_attaques/"
const TEINTES_MAX: int = 6
const COTE_SILHOUETTE: int = 16
## Part minimale de pixels qui diffèrent entre deux silhouettes ramenées à la même taille.
const DIFFERENCE_MIN: float = 0.08
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
]


func _charger(nom: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(DOSSIER + nom + ".png"))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _taille(nom: String) -> Vector2i:
	return Dessin.PLANCHES[nom]["taille"]


func _images(nom: String) -> int:
	return Dessin.PLANCHES[nom]["images"]


func test_la_liste_des_planches_compte_les_trente_trois_effets() -> void:
	verifier_egal(Dessin.PLANCHES.size(), 33, "planches")


func test_chaque_planche_existe_a_la_taille_taille_fois_nombre_d_images() -> void:
	for nom: String in Dessin.PLANCHES:
		var img: Image = _charger(nom)
		verifier_non_nul(img, "%s : fichier lisible" % nom)
		if img == null:
			continue
		var attendu: Vector2i = Vector2i(_taille(nom).x * _images(nom), _taille(nom).y)
		verifier_egal(img.get_size(), attendu, "%s : taille" % nom)


func test_chaque_planche_du_disque_est_identique_au_pixel_a_celle_du_script() -> void:
	for nom: String in Dessin.PLANCHES:
		var disque: Image = _charger(nom)
		if disque == null:
			verifier(false, "%s : fichier absent" % nom)
			continue
		var rendu: Image = Dessin.planche(nom)
		verifier_egal(disque.get_size(), rendu.get_size(), "%s : taille du rendu" % nom)
		verifier(disque.get_data() == rendu.get_data(), "%s : pixels différents du script" % nom)


func test_le_rendu_du_script_est_le_meme_a_chaque_appel() -> void:
	for nom: String in Dessin.PLANCHES:
		var premier: PackedByteArray = Dessin.planche(nom).get_data()
		var second: PackedByteArray = Dessin.planche(nom).get_data()
		verifier(premier == second, "%s : hasard" % nom)


func test_alpha_zero_ou_un_seulement_et_au_plus_six_teintes() -> void:
	for nom: String in Dessin.PLANCHES:
		var img: Image = Dessin.planche(nom)
		var teintes: Dictionary = {}
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				verifier(c.a == 0.0 or c.a == 1.0, "%s (%d,%d) : alpha %s" % [nom, x, y, c.a])
				if c.a == 1.0:
					teintes[c.to_html(false)] = true
		verifier(teintes.size() <= TEINTES_MAX, "%s : %d teintes" % [nom, teintes.size()])
		verifier(teintes.size() >= 1, "%s : aucune teinte" % nom)


func test_aucune_image_n_est_vide() -> void:
	for nom: String in Dessin.PLANCHES:
		var img: Image = Dessin.planche(nom)
		var t: Vector2i = _taille(nom)
		for i: int in _images(nom):
			var opaques: int = 0
			for y: int in t.y:
				for x: int in t.x:
					if img.get_pixel(i * t.x + x, y).a > 0.0:
						opaques += 1
			verifier(opaques > 0, "%s : image %d vide" % [nom, i + 1])


func _silhouette(nom: String) -> Image:
	var t: Vector2i = _taille(nom)
	var premiere: Image = Image.create_empty(t.x, t.y, false, Image.FORMAT_RGBA8)
	premiere.blit_rect(Dessin.planche(nom), Rect2i(0, 0, t.x, t.y), Vector2i.ZERO)
	premiere.resize(COTE_SILHOUETTE, COTE_SILHOUETTE, Image.INTERPOLATE_NEAREST)
	return premiere


func test_les_silhouettes_des_projectiles_different_deux_a_deux() -> void:
	for i: int in PROJECTILES.size():
		for j: int in range(i + 1, PROJECTILES.size()):
			var a: Image = _silhouette(PROJECTILES[i])
			var b: Image = _silhouette(PROJECTILES[j])
			var diff: int = 0
			for y: int in COTE_SILHOUETTE:
				for x: int in COTE_SILHOUETTE:
					if (a.get_pixel(x, y).a > 0.0) != (b.get_pixel(x, y).a > 0.0):
						diff += 1
			var part: float = float(diff) / (COTE_SILHOUETTE * COTE_SILHOUETTE)
			verifier(
				part >= DIFFERENCE_MIN,
				(
					"%s et %s : silhouettes trop proches (%.3f)"
					% [PROJECTILES[i], PROJECTILES[j], part]
				)
			)
