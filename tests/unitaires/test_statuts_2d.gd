extends CasDeTest
## Ce que la joueuse doit voir des trois nouveaux statuts d'ennemi (vulnérable, maudit, siphonné) :
## une teinte et un petit marqueur au-dessus de l'ennemi, différents entre eux et des cinq anciens.

const SCENE := "res://scenes/arene_2d.tscn"
const BITS_ANCIENS: Array[int] = [
	Types.STATUT_GELE,
	Types.STATUT_RALENTI,
	Types.STATUT_EMPOISONNE,
	Types.STATUT_BRULE,
	Types.STATUT_ETOURDI,
]
const BITS_NOUVEAUX: Array[int] = [
	Types.STATUT_VULNERABLE, Types.STATUT_MAUDIT, Types.STATUT_SIPHONNE
]

var _arene: Arene2D = null
var _donnees: Donnees = null
var _tick: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_arene = (load(SCENE) as PackedScene).instantiate() as Arene2D
	arbre.root.add_child(_arene)
	_arene.reinitialiser()
	_tick = 0


func apres_chaque() -> void:
	if is_instance_valid(_arene):
		if _arene.get_parent() != null:
			_arene.get_parent().remove_child(_arene)
		_arene.free()
	_arene = null


func _vue(nb: int, statut: int) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for k: int in nb:
		vue.ennemis_id.append(k + 1)
		vue.ennemis_pos.append(Vector2(200.0 + 30.0 * float(k % 40), 40.0 * float(k / 40)))
		vue.ennemis_famille.append(0)
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(statut)
	return vue


func _ecart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_les_trois_nouveaux_statuts_ont_des_teintes_distinctes_entre_elles_et_des_cinq_anciennes(
) -> void:
	var tous: Array[int] = []
	tous.append_array(BITS_ANCIENS)
	tous.append_array(BITS_NOUVEAUX)
	verifier_egal(tous.size(), 8, "huit bits sur huit")
	for i: int in tous.size():
		var a: Color = Arene2D.teinte_statut(tous[i])
		verifier(a != Color.WHITE, "le bit %d est teinté" % tous[i])
		for j: int in range(i + 1, tous.size()):
			var ecart: float = _ecart(a, Arene2D.teinte_statut(tous[j]))
			verifier(
				ecart >= 0.2,
				"bits %d et %d : teintes trop proches (%.2f)" % [tous[i], tous[j], ecart]
			)
	# Le plus gênant d'abord : un nouveau statut ne masque jamais un ancien.
	for bit: int in BITS_ANCIENS:
		for nouveau: int in BITS_NOUVEAUX:
			verifier_egal(
				Arene2D.teinte_statut(bit | nouveau),
				Arene2D.teinte_statut(bit),
				"l'ancien statut %d garde la teinte avec %d" % [bit, nouveau]
			)


func test_un_ennemi_porteur_d_un_nouveau_statut_est_teinte_dans_l_arene() -> void:
	for bit: int in BITS_NOUVEAUX:
		_arene.afficher(_vue(1, bit), 1.0)
		verifier_egal(_arene.teinte_instance(0, 0), Arene2D.teinte_statut(bit), "bit %d" % bit)


func test_chaque_nouveau_statut_pose_son_marqueur_au_dessus_de_l_ennemi() -> void:
	var formes: Dictionary = {}
	for bit: int in BITS_NOUVEAUX:
		_arene.afficher(_vue(1, bit), 1.0)
		var marques: MarquesStatut = _arene.marques_statut()
		verifier_egal(marques.nombre(), 1, "un marqueur pour le bit %d" % bit)
		if marques.nombre() != 1:
			continue
		var sprite: Sprite2D = _arene.sprite_instance(0, 0)
		verifier(marques.position_de(0).y < sprite.position.y, "au-dessus de l'ennemi")
		verifier_egal(marques.position_de(0).x, sprite.position.x, "centré sur l'ennemi")
		var forme: String = marques.forme_de(0)
		verifier(forme != "", "forme du bit %d" % bit)
		verifier(not formes.has(forme), "forme déjà prise : %s" % forme)
		formes[forme] = bit
	verifier_egal(formes.size(), 3, "trois marqueurs différents")


func test_les_cinq_anciens_statuts_n_ont_pas_de_marqueur_et_un_ennemi_sain_non_plus() -> void:
	for bit: int in BITS_ANCIENS:
		_arene.afficher(_vue(3, bit), 1.0)
		verifier_egal(_arene.marques_statut().nombre(), 0, "bit %d" % bit)
	_arene.afficher(_vue(3, 0), 1.1)
	verifier_egal(_arene.marques_statut().nombre(), 0)


func test_trois_nouveaux_statuts_sur_un_ennemi_donnent_trois_marqueurs_cotes_a_cotes() -> void:
	_arene.afficher(
		_vue(1, Types.STATUT_VULNERABLE | Types.STATUT_MAUDIT | Types.STATUT_SIPHONNE), 1.0
	)
	var marques: MarquesStatut = _arene.marques_statut()
	verifier_egal(marques.nombre(), 3)
	if marques.nombre() == 3:
		var xs: Dictionary = {}
		for i: int in 3:
			xs[marques.position_de(i).x] = true
		verifier_egal(xs.size(), 3, "pas l'un sur l'autre")


func test_les_marqueurs_disparaissent_avec_le_statut_et_restent_sous_un_plafond() -> void:
	_arene.afficher(_vue(1000, Types.STATUT_VULNERABLE | Types.STATUT_MAUDIT), 1.0)
	var marques: MarquesStatut = _arene.marques_statut()
	verifier(marques.nombre() > 0 and marques.nombre() <= MarquesStatut.PLAFOND, "plafonné")
	verifier(marques.noeuds() <= MarquesStatut.PLAFOND + MarquesStatut.RESERVE, "pool borné")
	_arene.afficher(_vue(1000, 0), 1.1)
	verifier_egal(marques.nombre(), 0, "le statut passé, plus de marqueur")
