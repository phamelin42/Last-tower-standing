extends CasDeTest
## Le skin de tour dans la partie (T11.7) : en solo, celui du profil (sans salon, il faut le lui
## donner) ; en réseau, celui de chaque joueur, lu dans la vue globale, pour sa tour comme pour
## celle qu'on regarde. Un skin pas débloqué, inconnu ou vide donne le skin par défaut.

const LOCAL := 665857105
const AUTRE := 1450001237

var d: Donnees
var _jeu: Jeu = null
var _source: SourceFactice = null


func avant_chaque() -> void:
	d = Donnees.charger()
	_jeu = null
	_source = null


func apres_chaque() -> void:
	if is_instance_valid(_jeu):
		if _jeu.get_parent() != null:
			_jeu.get_parent().remove_child(_jeu)
		_jeu.free()
	_jeu = null


func _nouveau_jeu() -> Jeu:
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.chemin_progression = dossier_temporaire().path_join("progression.json")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	return jeu


func _texture_de_la_tour() -> String:
	return (_jeu.arene.get_node("Ennemis/Tour") as Sprite2D).texture.resource_path


func _sprite_du_skin(id: String) -> String:
	return String((d.skins_tour[id] as Dictionary)["sprite"])


func _profil(choisi: String, debloques: Array[String]) -> void:
	var p := Profil.new()
	p.skin_choisi = choisi
	p.skins_debloques = debloques
	verifier(
		Sauvegarde.enregistrer(p, dossier_temporaire().path_join("progression.json")),
		"profil écrit"
	)


## La vue globale arrive à 2 Hz du temps réel : on attend (au plus quelques secondes) que la tour
## prenne `attendue`, ou, pour le skin par défaut, qu'une vue globale soit arrivée.
func _solo(attendue: String = "") -> void:
	_jeu = _nouveau_jeu()
	verifier(_jeu.demarrer_solo(d, 20261127, 1.0), "solo démarré")
	var fin := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < fin:
		await attendre_images(1)
		if _jeu._globale != null and (attendue.is_empty() or _texture_de_la_tour() == attendue):
			break


func test_en_solo_le_skin_du_profil_se_dessine() -> void:
	var skin := "tour_de_guet"
	_profil(skin, [skin] as Array[String])
	await _solo(_sprite_du_skin(skin))
	verifier_egal(_texture_de_la_tour(), _sprite_du_skin(skin), "la tour porte le skin du profil")


func test_en_solo_un_skin_pas_debloque_inconnu_ou_vide_donne_le_skin_par_defaut() -> void:
	var defaut := String(Apparence.tour(1)["fichier"])
	for cas: Array in [["tour_de_guet", []], ["n_existe_pas", ["n_existe_pas"]], ["", []]]:
		_profil(String(cas[0]), [] as Array[String])
		var debloques: Array[String] = []
		for x: Variant in cas[1]:
			debloques.append(String(x))
		_profil(String(cas[0]), debloques)
		await _solo()
		verifier_egal(_texture_de_la_tour(), defaut, "« %s » : skin par défaut" % cas[0])
		apres_chaque()


func _globale(skin_local: int, skin_autre: int) -> VueGlobale:
	var g := VueGlobale.new()
	for i: int in 2:
		(
			g
			. joueurs
			. append(
				{
					"id": LOCAL if i == 0 else AUTRE,
					"nom": "Joueuse %d" % i,
					"manche": 3,
					"eliminations": 0,
					"degats": 5.0,
					"revenu": 10,
					"vivant": true,
					"victorieux": false,
					"skin": skin_local if i == 0 else skin_autre,
				}
			)
		)
	return g


func _reseau(skin_local: int, skin_autre: int) -> void:
	_jeu = _nouveau_jeu()
	_source = SourceFactice.new()
	_source.regler(LOCAL, LOCAL)
	_jeu.add_child(_source)
	verifier(_jeu.demarrer_reseau(d, _source), "réseau démarré")
	var vue := VueArene.new()
	vue.tick = 1
	_source.emettre_arene(vue)
	_source.emettre_globale(_globale(skin_local, skin_autre))
	await attendre_images(4)


func test_en_reseau_la_tour_porte_le_skin_de_son_joueur_lu_dans_la_vue_globale() -> void:
	var ids := d.ids_skins()
	await _reseau(0, 0)
	for index: int in range(1, ids.size()):
		_source.emettre_globale(_globale(index, 0))
		await attendre_images(1)
		verifier_egal(_texture_de_la_tour(), _sprite_du_skin(ids[index]), "skin %d" % index)
	_source.emettre_globale(_globale(ids.size() + 7, 0))
	await attendre_images(1)
	verifier_egal(
		_texture_de_la_tour(),
		String(Apparence.tour(1)["fichier"]),
		"index inconnu : skin par défaut"
	)


func test_la_tour_regardee_porte_le_skin_de_l_autre_joueur() -> void:
	var ids := d.ids_skins()
	await _reseau(0, 2)
	var propre := _texture_de_la_tour()
	_jeu._regarder(AUTRE)
	verifier_egal(_texture_de_la_tour(), _sprite_du_skin(ids[2]), "l'arène regardée : son skin")
	_jeu.arene.montrer_arene(-1, "", 0)
	verifier_egal(_texture_de_la_tour(), propre, "retour à sa tour")
