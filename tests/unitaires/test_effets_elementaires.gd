extends CasDeTest
## Les six armes à élément (D22) dans `Effets` : l'impact n'arrive jamais avant son projectile
## (anticipation et vol compris), un barrage lance ses boules l'une après l'autre, la zone dessinée
## est la zone touchée, et les 24 autres armes gardent leur rendu.

const IMAGE: float = 1.0 / 60.0
## Images entre le tir et l'impact : anticipation + vol (direct 3 + 7, cloche 3 + 11, foudre 3).
const IMAGES_AVANT_IMPACT: Dictionary = {
	"canon_de_cloche": 10,
	"orbe_de_brume": 10,
	"bombarde_de_poche": 14,
	"cornue_instable": 14,
	"chaine_d_arcanes": 3,
	"etincelle_runique": 10,
}
const FORTS: Array[String] = ["canon_de_cloche", "bombarde_de_poche"]

var _effets: Effets = null
var _vitrine: VitrineArmes = null
var _donnees: Donnees = null
## Images (depuis le tir) où chaque impact est devenu visible, et s'il était fort.
var _impacts: Array[int] = []
var _forts: Array[bool] = []
var _image: int = 0


func avant_chaque() -> void:
	_donnees = Donnees.charger()
	_effets = Effets.new()
	_effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(_effets)
	_vitrine = VitrineArmes.new()
	_effets.impact_visible.connect(_noter)
	_impacts = []
	_forts = []
	_image = 0


func apres_chaque() -> void:
	_vitrine.free()
	if is_instance_valid(_effets):
		_effets.free()


func _noter(_ou: Vector2, _rayon: float, fort: bool) -> void:
	_impacts.append(_image)
	_forts.append(fort)


## Joue le cycle d'un tir de `id` pendant `images` images ; l'image 0 est celle du tir.
func _jouer(id: String, images: int) -> void:
	for evenement: Dictionary in _vitrine.evenements_du_cycle(id):
		_effets.ajouter(evenement)
	for i: int in images:
		_image = i
		_effets.avancer(IMAGE)
		_verifier_invariants(id)


func _verifier_invariants(id: String) -> void:
	verifier_egal(Engine.time_scale, 1.0, "le temps de jeu n'est jamais touché")
	verifier(_effets.nombre_vivants() <= Effets.PLAFOND, "plafond tenu")
	var alpha: float = maxf(_effets.opacite_max(), _effets.elementaires().opacite_max())
	verifier(alpha <= Effets.ALPHA_MAX + 0.001, "aucun effet opaque (%s)" % id)


func test_l_impact_n_arrive_jamais_avant_le_projectile() -> void:
	for id: String in IMAGES_AVANT_IMPACT:
		avant_chaque_pour_boucle()
		_jouer(id, 40)
		verifier(not _impacts.is_empty(), "%s : un impact est visible" % id)
		# `avancer` d'une image rend l'impact visible à l'image attendue moins un.
		var attendu: int = int(IMAGES_AVANT_IMPACT[id])
		verifier(
			absi(_impacts[0] + 1 - attendu) <= 1,
			"%s : impact à l'image %d, attendu %d ± 1" % [id, _impacts[0] + 1, attendu]
		)


## Repart d'un `Effets` propre entre deux armes d'une boucle.
func avant_chaque_pour_boucle() -> void:
	apres_chaque()
	avant_chaque()


func test_un_barrage_lance_une_boule_toutes_les_deux_images() -> void:
	_jouer("canon_de_cloche", 40)
	verifier_egal(_impacts.size(), 4, "quatre boules, quatre impacts")
	for i: int in range(1, _impacts.size()):
		verifier_egal(_impacts[i] - _impacts[i - 1], 2, "décalage de 2 images (boule %d)" % i)


func test_seuls_les_coups_de_siege_gelent() -> void:
	for id: String in IMAGES_AVANT_IMPACT:
		avant_chaque_pour_boucle()
		_jouer(id, 40)
		for fort: bool in _forts:
			verifier_egal(fort, FORTS.has(id), "palier de %s" % id)


func test_la_zone_dessinee_est_la_zone_touchee() -> void:
	var rayons: Dictionary = {
		"canon_de_cloche": 120.0, "orbe_de_brume": 120.0, "cornue_instable": 140.0
	}
	for id: String in rayons:
		avant_chaque_pour_boucle()
		_jouer(id, 14)
		var attendu: float = float(rayons[id]) * Apparence.PX_PAR_UNITE * 2.0
		var vu: float = _effets.elementaires().diametre_max()
		verifier(absf(vu - attendu) <= attendu * 0.1, "%s : %f px pour %f" % [id, vu, attendu])


func test_la_bombe_garde_l_explosion_du_pack_au_rayon_exact() -> void:
	_jouer("bombarde_de_poche", 15)
	verifier_contient(_effets.formes_vivantes(), "explosion")
	var rayon_px: float = 130.0 * Apparence.PX_PAR_UNITE
	var diametre: float = _effets.echelle_de("explosion") * Effets.DIAMETRE_EXPLOSION
	verifier_proche(diametre, rayon_px * 2.0, rayon_px * 0.2, "diamètre = 2 × rayon")


func test_mouvement_reduit_aucune_particule_aucune_rotation() -> void:
	_effets.mouvement_reduit = true
	for id: String in IMAGES_AVANT_IMPACT:
		avant_chaque_pour_boucle()
		_effets.mouvement_reduit = true
		_jouer(id, 40)
		verifier_egal(_effets.elementaires().particules_actives(), 0, "particules de %s" % id)
		verifier_egal(_effets.etincelles_actives().size(), 0, "étincelles de %s" % id)
		verifier_egal(_effets.gel_restant(), 0.0, "pas de gel de %s" % id)


func test_une_arme_sans_element_garde_son_rendu() -> void:
	var autres: int = 0
	for id: String in SignaturesArmes.ids():
		if ElementsArmes.de(id) != "":
			continue
		autres += 1
		avant_chaque_pour_boucle()
		for evenement: Dictionary in _vitrine.evenements_du_cycle(id):
			_effets.ajouter(evenement)
		verifier(_effets.nombre_vivants() + _effets.impacts_en_attente() > 0, "%s : un rendu" % id)
		verifier_egal(_effets.elementaires().nombre_vivants(), 0, "%s : rien d'élémentaire" % id)
		_effets.avancer(0.5)
		verifier_egal(_effets.elementaires().nombre_vivants(), 0)
		verifier_egal(_effets.elementaires().particules_actives(), 0)
	verifier(autres >= 24, "au moins les 24 autres armes : %d" % autres)
