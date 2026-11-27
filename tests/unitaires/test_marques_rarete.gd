extends CasDeTest
## Marque de rareté des armes de fin de partie (T10, point 12 de la revue visuelle) : une forme non
## colorée dans l'effet lui-même (traînée pour l'ancestrale, étoile pour la souveraine), qui se lit
## sans la teinte, que les armes d'avant n'ont pas, qui vient de `data/assets.json`, et un tapis
## propre à la couronne du vide.

const RAYON_PX: float = 200.0
const IMAGE: float = 1.0 / 60.0
const MARQUES_MAX_PAR_TIR: int = 4
const PART_MARQUES_MAX: float = 0.25
const OPAQUE_MIN: int = 6
const CONTRASTE_MIN: float = 0.45
const SATURATION_MAX: float = 0.2
const DIFFERENCE_MIN: int = 8
const DIFFERENCE_TAPIS_MIN: float = 0.2

var d: Donnees
var m: AttaquesElementaires
var _origine: Dictionary = {}


func avant_chaque() -> void:
	d = Donnees.charger()
	_origine = Assets.tout().duplicate(true)
	m = AttaquesElementaires.new()
	m.place = 200
	arbre.root.add_child(m)


func apres_chaque() -> void:
	Assets.remplacer(_origine)
	if is_instance_valid(m):
		m.free()


func _raretes() -> Dictionary:
	return Assets.typee("signatures").get("raretes_tardives", {})


func _marque(rarete: String) -> Dictionary:
	return (_raretes().get(rarete, {}) as Dictionary).get("marque", {})


func _planches_marque() -> Array[String]:
	var noms: Array[String] = []
	for rarete: String in _raretes():
		for cle: String in ["vol", "impact"]:
			noms.append(str(_marque(rarete).get(cle, "")))
	return noms


func _tardives() -> Array[String]:
	var ids: Array[String] = []
	for id: String in d.armes:
		if int((d.armes[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
			ids.append(id)
	return ids


func _rarete_de(id: String) -> String:
	return Types.NOMS_RARETES[int((d.armes[id] as Dictionary)["rarete"])]


## Joue la mécanique de l'arme `id` comme le fait le rendu (tir, impact, zone, aura, onde, piège).
func _jouer(id: String) -> void:
	var kind: String = str(((d.armes[id] as Dictionary)["effets"] as Array)[0]["kind"])
	var depart := Vector2(0.0, 0.0)
	var arrivee := Vector2(240.0, 60.0)
	match kind:
		"aura":
			m.aura(id, depart, 300.0)
		"onde":
			m.onde(id, depart)
		"piege", "mine":
			m.piege(id, depart, arrivee)
		"zone", "barrage":
			m.tirer(id, depart, arrivee)
			m.impacter(id, arrivee, RAYON_PX, false, depart, 0.0)
		_:
			m.tirer(id, depart, arrivee)
			m.impacter(id, arrivee, 0.0, false, depart, 0.0)


## Les planches des effets vivants.
func _planches_vivantes() -> Array[String]:
	var noms: Array[String] = []
	for e: Dictionary in m._vivants:
		noms.append(str(e["planche"]))
	return noms


func _image(planche: String) -> Image:
	return Image.load_from_file(
		ProjectSettings.globalize_path(PlanchesEffets.chemin_planche(planche))
	)


## Les pixels opaques de l'image `i` de `planche`, en grille de booléens.
func _masque(planche: String, i: int) -> Array[bool]:
	var img: Image = _image(planche)
	var taille: Vector2i = PlanchesEffets.case_de(planche)
	var sortie: Array[bool] = []
	for y: int in taille.y:
		for x: int in taille.x:
			sortie.append(img.get_pixel(i * taille.x + x, y).a > 0.5)
	return sortie


func _difference(a: Array[bool], b: Array[bool]) -> int:
	var n: int = 0
	for k: int in mini(a.size(), b.size()):
		n += 1 if a[k] != b[k] else 0
	return n + absi(a.size() - b.size())


func test_chaque_rarete_tardive_a_sa_marque_dans_les_donnees_avec_des_planches_decrites() -> void:
	var vues: Array[String] = []
	for rarete: int in range(Types.Rarete.ANCESTRALE, Types.NOMS_RARETES.size()):
		var nom: String = Types.NOMS_RARETES[rarete]
		var marque: Dictionary = _marque(nom)
		verifier(marque.has("vol") and marque.has("impact"), "%s : marque dans les données" % nom)
		for cle: String in ["vol", "impact"]:
			var planche: String = str(marque.get(cle, ""))
			verifier(
				PlanchesEffets.case_de(planche) != Vector2i.ZERO, "%s : %s décrite" % [nom, planche]
			)
			verifier(not vues.has(planche), "%s : %s propre à sa rareté" % [nom, planche])
			vues.append(planche)
			verifier(
				FileAccess.file_exists(PlanchesEffets.chemin_planche(planche)),
				"%s : %s existe" % [nom, planche]
			)


func test_chaque_arme_tardive_porte_la_marque_de_sa_rarete_et_d_elle_seule() -> void:
	verifier_egal(_tardives().size(), 15, "quinze armes de fin de partie")
	for id: String in _tardives():
		m.vider()
		_jouer(id)
		var propres: Array[String] = [
			str(_marque(_rarete_de(id)).get("vol", "")),
			str(_marque(_rarete_de(id)).get("impact", ""))
		]
		var vues: Array[String] = _planches_vivantes()
		var trouvees: int = 0
		for planche: String in propres:
			trouvees += 1 if vues.has(planche) else 0
		verifier(trouvees > 0, "%s : un effet porte la marque de sa rareté" % id)
		for planche: String in _planches_marque():
			if not propres.has(planche):
				verifier(
					not vues.has(planche),
					"%s : pas la marque d'une autre rareté (%s)" % [id, planche]
				)
	m.vider()


func test_aucune_arme_d_avant_n_a_la_marque() -> void:
	var marques: Array[String] = _planches_marque()
	var n: int = 0
	for id: String in d.armes:
		if int((d.armes[id] as Dictionary)["rarete"]) >= Types.Rarete.ANCESTRALE:
			continue
		n += 1
		m.vider()
		_jouer(id)
		for planche: String in _planches_vivantes():
			verifier(not marques.has(planche), "%s : une arme de base n'a pas de marque" % id)
	verifier(n > 50, "toutes les armes de base sont passées en revue")
	m.vider()


func test_la_marque_vient_des_donnees() -> void:
	var autre: Dictionary = _origine.duplicate(true)
	var marque: Dictionary = (
		((autre["signatures"] as Dictionary)["raretes_tardives"] as Dictionary)["ancestrale"]
		as Dictionary
	)["marque"]
	marque["vol"] = "etincelle"
	marque["impact"] = "etincelle"
	Assets.remplacer(autre)
	m.vider()
	m.tirer("lame_des_aieux", Vector2.ZERO, Vector2(240.0, 60.0))
	m.impacter("lame_des_aieux", Vector2(240.0, 60.0), 0.0, false, Vector2.ZERO, 0.0)
	verifier(_planches_vivantes().count("etincelle") >= 2, "la marque suit les données")
	verifier(not _planches_vivantes().has("marque_traine"), "plus l'ancienne marque")


func test_la_marque_se_lit_en_niveaux_de_gris() -> void:
	for planche: String in _planches_marque():
		var img: Image = _image(planche)
		var taille: Vector2i = PlanchesEffets.case_de(planche)
		var images: int = int(img.get_width() / float(taille.x))
		for i: int in images:
			var opaques: int = 0
			var clair: float = 0.0
			var sombre: float = 1.0
			for y: int in taille.y:
				for x: int in taille.x:
					var c: Color = img.get_pixel(i * taille.x + x, y)
					if c.a < 0.5:
						continue
					opaques += 1
					clair = maxf(clair, c.get_luminance())
					sombre = minf(sombre, c.get_luminance())
					if c.get_luminance() >= 0.5:
						verifier(
							c.s <= SATURATION_MAX, "%s : clair neutre (la teinte colore)" % planche
						)
			verifier(opaques >= OPAQUE_MIN, "%s image %d : une forme visible" % [planche, i])
			verifier(
				clair - sombre >= CONTRASTE_MIN, "%s image %d : contraste en gris" % [planche, i]
			)


func test_ancestrale_et_souveraine_se_distinguent_par_la_forme() -> void:
	var a: Dictionary = _marque("ancestrale")
	var s: Dictionary = _marque("souveraine")
	for cle: String in ["vol", "impact"]:
		var pa: String = str(a[cle])
		var ps: String = str(s[cle])
		verifier_egal(
			PlanchesEffets.case_de(pa), PlanchesEffets.case_de(ps), "%s : même case" % cle
		)
		var images: int = int(_image(pa).get_width() / float(PlanchesEffets.case_de(pa).x))
		var ecart: int = 0
		for i: int in images:
			ecart += _difference(_masque(pa, i), _masque(ps, mini(i, images - 1)))
		verifier(
			ecart >= DIFFERENCE_MIN * images, "%s : silhouettes différentes (%d)" % [cle, ecart]
		)


func test_la_marque_est_pixel_art_nearest_et_sous_l_opacite_max() -> void:
	for id: String in _tardives():
		m.vider()
		_jouer(id)
		m.avancer(IMAGE * 2.0)
		for e: Dictionary in m._vivants:
			if not _planches_marque().has(str(e["planche"])):
				continue
			var n: Sprite2D = e["n"]
			verifier_egal(n.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "%s : nearest" % id)
			verifier(n.modulate.a <= AttaquesElementaires.ALPHA_MAX + 0.0001, "%s : ALPHA_MAX" % id)
	m.vider()


func test_en_mouvement_reduit_la_marque_ne_scintille_pas() -> void:
	m.mouvement_reduit = true
	for id: String in _tardives():
		m.vider()
		_jouer(id)
		var images: Dictionary = {}
		for k: int in 90:
			for e: Dictionary in m._vivants:
				if _planches_marque().has(str(e["planche"])):
					var cle: String = "%s#%d" % [str(e["planche"]), int(e["id"])]
					if not images.has(cle):
						images[cle] = {}
					(images[cle] as Dictionary)[int(e["image"])] = true
			m.avancer(IMAGE)
		for cle: String in images:
			verifier((images[cle] as Dictionary).size() <= 1, "%s : %s figée" % [id, cle])
	m.vider()


func test_hors_mouvement_reduit_la_marque_de_la_souveraine_scintille() -> void:
	m.tirer("faux_du_dernier_jour", Vector2.ZERO, Vector2(240.0, 60.0))
	m.tirer("canon_du_dernier_rempart", Vector2.ZERO, Vector2(240.0, 60.0))
	var planche: String = str(_marque("souveraine")["vol"])
	var images: Dictionary = {}
	for k: int in 40:
		for etat: Dictionary in m.etats(planche):
			images[int(etat["image"])] = true
		m.avancer(IMAGE)
	verifier(images.size() >= 2, "la marque change d'image : %s" % str(images.keys()))


func _marques_vivantes() -> int:
	var n: int = 0
	for planche: String in _planches_vivantes():
		n += 1 if _planches_marque().has(planche) else 0
	return n


func test_la_marque_reste_discrete_et_le_plafond_de_200_tient() -> void:
	for id: String in _tardives():
		m.vider()
		m.place = 200
		_jouer(id)
		verifier(_marques_vivantes() >= 1, "%s : une marque" % id)
		verifier(
			_marques_vivantes() <= MARQUES_MAX_PAR_TIR,
			"%s : %d marques par tir" % [id, _marques_vivantes()]
		)
		m.vider()
		m.place = 1
		_jouer(id)
		verifier(m.nombre_vivants() <= 1, "%s : la place demandée est respectée" % id)
	m.vider()


func test_la_marque_ne_sature_pas_le_plafond() -> void:
	# Un tir de chaque arme tardive : la part des marques parmi les effets reste faible.
	m.place = 200
	for id: String in _tardives():
		_jouer(id)
	var pic_marques: int = 0
	var pic: int = 0
	for i: int in 30:
		m.avancer(IMAGE)
		pic = maxi(pic, m.nombre_vivants())
		pic_marques = maxi(pic_marques, _marques_vivantes())
	verifier(pic <= 200, "plafond : %d effets" % pic)
	verifier(
		float(pic_marques) <= PART_MARQUES_MAX * float(pic),
		"marques : %d sur %d effets" % [pic_marques, pic]
	)


func test_couronne_du_vide_a_un_tapis_propre_different_de_celui_du_champ_de_ruines() -> void:
	var vide: String = AttaquesElementaires.disque_de(ElementsArmes.de("couronne_du_vide"))
	var ruines: String = AttaquesElementaires.disque_de(ElementsArmes.de("champ_de_ruines"))
	verifier(vide != "" and vide != ruines, "tapis propre : %s contre %s" % [vide, ruines])
	verifier(AttaquesElementaires.planches().has(vide), "planche du tapis déclarée")
	verifier(AttaquesElementaires.visible_de(vide) > 0.0, "diamètre visible du tapis")
	verifier_egal(PlanchesEffets.case_de(vide), PlanchesEffets.case_de(ruines), "même case")
	var images: int = int(_image(vide).get_width() / float(PlanchesEffets.case_de(vide).x))
	for i: int in images:
		var a: Array[bool] = _masque(vide, i)
		var ecart: float = float(_difference(a, _masque(ruines, i))) / float(a.size())
		verifier(ecart >= DIFFERENCE_TAPIS_MIN, "image %d : motif différent (%.2f)" % [i, ecart])


func test_le_tapis_propre_ne_touche_que_la_couronne_du_vide() -> void:
	for id: String in _tardives():
		var element: AttaqueElement = AttaquesElementaires.registre().get(id)
		var base: AttaqueElement = AttaquesElementaires.registre().get(
			str((Assets.typee("signatures")["familles_tardives"] as Dictionary)[id]["famille"])
		)
		if id == "couronne_du_vide":
			continue
		verifier_egal(
			element.conf().get("disque", ""), base.conf().get("disque", ""), "%s : tapis" % id
		)
