extends CasDeTest
## Un contour clair d'un pixel de planche autour des tirs fins à cible unique (décision de Phil du
## 27/11/2026). Au zoom de jeu le plus lointain, dans une foule de 700 ennemis, ces projectiles
## disparaissaient. Le contour est calculé au chargement, sur l'alpha de la planche (elle reste
## remplaçable) ; la liste des planches, la couleur et l'épaisseur viennent de `data/assets.json`
## (`effets.contour_tirs`). La chaîne d'arcanes est un trait tracé en code : même principe, un
## liseré clair, même donnée.
##
## La règle qui fixe la liste (écrite ici, vérifiée sur tout le catalogue) : une arme de genre cible
## unique ou rebond, hors siège, qui tire une lame ou une pointe (dégâts tranchants ou perçants),
## dont l'empreinte mesurée au zoom de jeu le plus lointain (2,0, foule de 700 ennemis, revue du
## 27/11/2026) est sous `SEUIL_EMPREINTE`, et dont la planche de projectile n'est partagée qu'avec
## des armes de ces mêmes genres (une planche partagée avec un tir tournant ou un barrage, dont
## l'image est grande, n'est pas touchée).

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)
## Au-dessous, en pixels d'écran au zoom 2,0, un coup disparaît dans la foule.
const SEUIL_EMPREINTE: int = 100
## Empreinte maximale (px) mesurée le 27/11/2026 pour chaque arme de cible unique ou de rebond, hors
## siège : une vraie `Arene2D`, 700 ennemis, zoom 2,0, l'arme seule contre la foule seule.
const EMPREINTES: Dictionary = {
	"lame_de_fil": 45,
	"lame_des_aieux": 45,
	"arbalete_de_bureau": 46,
	"pacte_de_sang": 46,
	"eclat_siphonneur": 54,
	"carreau_ricochet": 56,
	"fleche_marquante": 57,
	"prisme_de_faille": 60,
	"couperet_a_epines": 62,
	"lance_epineuse": 62,
	"miroir_brise": 63,
	"engrenage_jumeau": 70,
	"serment_brise": 70,
	"de_pipe": 71,
	"javeline_de_jet": 77,
	"sceptre_des_astres": 82,
	"baliste_de_guet": 84,
	"etincelle_runique": 84,
	"fleau_de_rasoirs": 90,
	"tempete_astrale": 90,
	"chaine_d_arcanes": 95,
	"arc_de_remparts": 98,
	"disque_scie": 101,
	"lame_de_brume": 114,
	"miroir_de_discorde": 122,
}
const GENRES_FINS: Array[String] = ["cible_unique", "rebond"]
const TYPES_FINS: Array[int] = [Types.TypeDegats.TRANCHANT, Types.TypeDegats.PERCANT]

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()


func avant_chaque() -> void:
	Assets.reinitialiser()
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null
	Assets.reinitialiser()


func _genre(id: String) -> String:
	return String(((_donnees.armes[id] as Dictionary)["effets"] as Array)[0]["kind"])


func _type(id: String) -> int:
	return int((_donnees.armes[id] as Dictionary)["type_degats"])


## Les armes du périmètre de la règle : cible unique ou rebond, hors siège.
func _perimetre() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _donnees.armes:
		if GENRES_FINS.has(_genre(id)) and _type(id) != Types.TypeDegats.SIEGE:
			ids.append(id)
	return ids


## Les planches que la règle désigne, calculées sur le catalogue et la table des empreintes.
func _planches_de_la_regle() -> Array[String]:
	var voulues: Array[String] = []
	for id: String in _perimetre():
		var planche: String = AttaquesElementaires.planche_projectile(ElementsArmes.de(id))
		if planche == "" or not TYPES_FINS.has(_type(id)):
			continue
		if int(EMPREINTES[id]) >= SEUIL_EMPREINTE or voulues.has(planche):
			continue
		if _planche_partagee_avec_un_autre_genre(planche):
			continue
		voulues.append(planche)
	voulues.sort()
	return voulues


func _planche_partagee_avec_un_autre_genre(planche: String) -> bool:
	for id: String in _donnees.armes:
		if AttaquesElementaires.planche_projectile(ElementsArmes.de(id)) != planche:
			continue
		if not GENRES_FINS.has(_genre(id)):
			return true
	return false


## La texture d'une planche telle que le pool d'effets la pose sur un projectile.
func _texture_posee(planche: String) -> Texture2D:
	var effet: Dictionary = _a.nouveau("vol", planche, 7.0 * IMAGE)
	verifier(not effet.is_empty(), "un projectile de %s" % planche)
	return (effet["n"] as Sprite2D).texture


## Deux couleurs à un octet près : une image les garde sur 8 bits.
func _meme_couleur(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) <= 0.005
		and absf(a.g - b.g) <= 0.005
		and absf(a.b - b.b) <= 0.005
		and a.a > 0.99
	)


func _liste() -> Array[String]:
	var liste: Array[String] = []
	for nom: String in ContoursTirs.planches():
		liste.append(nom)
	liste.sort()
	return liste


# --- Le calcul du contour ------------------------------------------------------------------------


func test_le_contour_entoure_chaque_pixel_opaque_d_un_pixel_clair_sans_toucher_au_reste() -> void:
	var image := Image.create(6, 3, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 1, Color.RED)
	image.set_pixel(4, 1, Color.BLUE)
	var clair := Color8(255, 250, 224)
	var habille: Image = ContoursTirs.habiller(image, Vector2i(3, 3), 1, clair)
	verifier_egal(
		habille.get_size(), Vector2i(10, 5), "chaque image de 3 x 3 gagne un pixel par côté"
	)
	verifier_egal(habille.get_pixel(2, 2), Color.RED, "le pixel d'origine est intact, décalé de 1")
	verifier_egal(habille.get_pixel(7, 2), Color.BLUE, "le second aussi")
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx != 0 or dy != 0:
				verifier_egal(
					habille.get_pixel(2 + dx, 2 + dy), clair, "contour (%d, %d)" % [dx, dy]
				)
	verifier_egal(habille.get_pixel(0, 0).a, 0.0, "à deux pixels, rien")
	verifier_egal(habille.get_pixel(4, 2).a, 0.0, "entre les deux cellules, rien")


func test_le_contour_deborde_de_l_image_d_origine_sur_un_sprite_qui_touche_son_bord() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var habille: Image = ContoursTirs.habiller(image, Vector2i(2, 2), 1, Color.WHITE)
	verifier_egal(habille.get_size(), Vector2i(4, 4))
	verifier_egal(habille.get_pixel(0, 0), Color.WHITE, "le contour passe hors de l'ancienne case")
	verifier_egal(habille.get_pixel(3, 3), Color.WHITE)


func test_une_epaisseur_de_deux_ajoute_deux_pixels_de_contour() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var habille: Image = ContoursTirs.habiller(image, Vector2i(1, 1), 2, Color.WHITE)
	verifier_egal(habille.get_size(), Vector2i(5, 5))
	verifier_egal(habille.get_pixel(0, 0), Color.WHITE, "à deux pixels du cœur")
	verifier_egal(habille.get_pixel(2, 2), Color.RED)


# --- La donnée et la règle -----------------------------------------------------------------------


func test_la_liste_des_planches_suit_la_regle_ecrite() -> void:
	verifier_egal(_liste(), _planches_de_la_regle(), "la liste de data/assets.json")
	verifier(_liste().size() >= 5, "au moins les cinq tirs de la revue")


func test_toute_arme_du_perimetre_a_son_empreinte_mesuree() -> void:
	for id: String in _perimetre():
		verifier(EMPREINTES.has(id), "empreinte de %s" % id)


func test_les_cinq_tirs_de_la_revue_ont_leur_contour() -> void:
	for id: String in ["arbalete_de_bureau", "lame_de_fil", "baliste_de_guet", "javeline_de_jet"]:
		var planche: String = AttaquesElementaires.planche_projectile(ElementsArmes.de(id))
		verifier(_liste().has(planche), "%s : planche %s" % [id, planche])
	verifier(ContoursTirs.eclairs(), "le trait de la chaîne d'arcanes a son liseré")


func test_la_couleur_et_l_epaisseur_viennent_des_donnees() -> void:
	verifier(ContoursTirs.couleur().get_luminance() > 0.8, "un contour clair")
	verifier_egal(ContoursTirs.epaisseur(), 1, "un pixel de planche")


# --- Les planches posées -------------------------------------------------------------------------


func test_chaque_planche_de_la_liste_a_son_contour_et_les_autres_non() -> void:
	var liste: Array[String] = _liste()
	var vues: int = 0
	for id: String in _donnees.armes:
		var planche: String = AttaquesElementaires.planche_projectile(ElementsArmes.de(id))
		if planche == "":
			continue
		vues += 1
		var original: Texture2D = AttaquesElementaires.texture_de(planche)
		var cellule: Vector2i = AttaquesElementaires.planches()[planche]
		var posee: Texture2D = _texture_posee(planche)
		if liste.has(planche):
			var marge: int = ContoursTirs.epaisseur()
			verifier_egal(
				posee.get_width(),
				original.get_width() / cellule.x * (cellule.x + 2 * marge),
				"%s : une cellule plus large" % planche
			)
			verifier_egal(posee.get_height(), cellule.y + 2 * marge, "%s : plus haute" % planche)
			verifier(
				posee.get_image().get_pixel(0, posee.get_height() / 2).a >= 0.0,
				"%s : lisible" % planche
			)
		else:
			verifier_egal(posee.get_size(), original.get_size(), "%s : sans contour" % planche)
	verifier(vues > 40, "assez de planches de projectile vues (%d)" % vues)


func test_un_projectile_contoure_garde_la_meme_taille_a_l_ecran() -> void:
	for planche: String in _liste():
		var cellule: Vector2i = AttaquesElementaires.planches()[planche]
		var effet: Dictionary = _a.nouveau("vol", planche, 7.0 * IMAGE)
		var n: Sprite2D = effet["n"]
		verifier_egal(
			n.region_rect.size,
			Vector2(cellule + Vector2i.ONE * 2 * ContoursTirs.epaisseur()),
			"%s : la case est élargie" % planche
		)
		verifier_egal(n.region_rect.position, Vector2.ZERO, "%s : première image" % planche)


func test_le_contour_est_dessine_dans_la_couleur_des_donnees() -> void:
	var planche: String = _liste()[0]
	var posee: Image = _texture_posee(planche).get_image()
	var trouvee: bool = false
	for y: int in posee.get_height():
		for x: int in posee.get_width():
			if _meme_couleur(posee.get_pixel(x, y), ContoursTirs.couleur()):
				trouvee = true
	verifier(trouvee, "un pixel de la couleur du contour")


func test_changer_la_donnee_change_le_contour() -> void:
	var planche: String = "carreau"
	var avant: Vector2i = Vector2i(_texture_posee(planche).get_size())
	var tout: Dictionary = Assets.tout().duplicate(true)
	var contour: Dictionary = (tout["effets"] as Dictionary)["contour_tirs"]
	contour["epaisseur"] = 2
	contour["contour"] = [1.0, 0.0, 1.0]
	Assets.remplacer(tout)
	var neuf: AttaquesElementaires = AttaquesElementaires.new()
	arbre.root.add_child(neuf)
	var effet: Dictionary = neuf.nouveau("vol", planche, 7.0 * IMAGE)
	var texture: Texture2D = (effet["n"] as Sprite2D).texture
	verifier_egal(texture.get_height(), avant.y + 2, "deux pixels de contour au lieu d'un")
	var rose: bool = false
	var image: Image = texture.get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _meme_couleur(image.get_pixel(x, y), Color(1.0, 0.0, 1.0)):
				rose = true
	verifier(rose, "la nouvelle couleur")
	contour["planches"] = []
	Assets.remplacer(tout)
	var vide: AttaquesElementaires = AttaquesElementaires.new()
	arbre.root.add_child(vide)
	var sans: Dictionary = vide.nouveau("vol", planche, 7.0 * IMAGE)
	verifier_egal(
		(sans["n"] as Sprite2D).texture.get_size(),
		AttaquesElementaires.texture_de(planche).get_size(),
		"une liste vide : plus de contour"
	)
	neuf.free()
	vide.free()


func test_l_animation_d_un_projectile_contoure_parcourt_ses_images() -> void:
	# Une planche animée garde ses images : le nombre se compte sur la cellule élargie.
	var planche: String = "lame_croissant"
	var effet: Dictionary = _a.nouveau("vol", planche, 7.0 * IMAGE)
	effet["fps"] = 30.0
	var n: Sprite2D = effet["n"]
	var cellule: Vector2i = AttaquesElementaires.planches()[planche]
	var largeur: int = cellule.x + 2 * ContoursTirs.epaisseur()
	var vues: Dictionary = {}
	for i: int in 30:
		effet["age"] = i * IMAGE
		_a._poser_vol(effet, n, 0.5, i * IMAGE)
		vues[int(n.region_rect.position.x)] = true
		verifier_egal(int(n.region_rect.position.x) % largeur, 0, "image %d alignée" % i)
	verifier_egal(vues.size(), 4, "les quatre images de la lame")


# --- Le trait de la chaîne d'arcanes -------------------------------------------------------------


func _eclair() -> Node2D:
	_a.eclair(TOUR, CIBLE, 0.0, Color(0.78, 0.7, 1.0))
	return _a._vivants[_a._vivants.size() - 1]["n"] as Node2D


func test_l_eclair_a_un_lisere_clair_sous_son_bord() -> void:
	var n: Node2D = _eclair()
	var lisere: Line2D = n.get_node_or_null("Lisere") as Line2D
	verifier_non_nul(lisere, "un liseré")
	var bord: Line2D = n.get_node("Bord") as Line2D
	var attendu: float = bord.width + 2.0 * ContoursTirs.epaisseur() * PlanchesEffets.echelle()
	verifier_egal(lisere.width, attendu, "un pixel de planche de chaque côté du bord")
	verifier_egal(lisere.default_color, ContoursTirs.couleur(), "la couleur des données")
	verifier(lisere.get_index() < bord.get_index(), "dessiné sous le bord")
	verifier_egal(lisere.points, bord.points, "même tracé que le bord")


func test_le_lisere_de_l_eclair_se_coupe_par_la_donnee() -> void:
	var tout: Dictionary = Assets.tout().duplicate(true)
	((tout["effets"] as Dictionary)["contour_tirs"] as Dictionary)["eclairs"] = false
	Assets.remplacer(tout)
	var n: Node2D = _eclair()
	var lisere: Line2D = n.get_node_or_null("Lisere") as Line2D
	verifier(lisere == null or not lisere.visible, "pas de liseré")


func test_le_lisere_de_l_eclair_suit_le_trace_et_reste_sous_le_plafond_d_opacite() -> void:
	var n: Node2D = _eclair()
	_a.avancer(IMAGE)
	verifier(n.modulate.a <= AttaquesElementaires.ALPHA_MAX + 0.0001, "ALPHA_MAX tenu")
	var lisere: Line2D = n.get_node("Lisere") as Line2D
	verifier_egal(lisere.points, (n.get_node("Coeur") as Line2D).points, "même tracé")


func test_une_image_plus_petite_que_sa_case_est_rendue_telle_quelle() -> void:
	# Une planche remplacée sans que sa case l'ait suivie : pas d'exception, pas de contour.
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var habille: Image = ContoursTirs.habiller(image, Vector2i(8, 8), 1, Color.WHITE)
	verifier_egal(habille.get_size(), Vector2i(4, 4))
