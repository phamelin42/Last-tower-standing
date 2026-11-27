extends CasDeTest
## Ce que la joueuse doit voir des alliés invoqués : un guerrier ou un archer du pack, teinté et
## entouré d'un anneau au sol qu'aucun ennemi ne porte, qui glisse d'une vue à l'autre sans saut
## et qui disparaît avec la vue.

const SCENE := "res://scenes/arene_2d.tscn"
const SAUT_VISIBLE: float = 60.0

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


func _vue(allies: Array[Dictionary], familles: Array[int] = []) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	for f: int in familles.size():
		vue.ennemis_id.append(f + 1)
		vue.ennemis_pos.append(Vector2(300.0 + 40.0 * f, 20.0 * f))
		vue.ennemis_famille.append(familles[f])
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(0)
	vue.allies = allies
	return vue


func _allie(id: int, unite: int, pos: Vector2) -> Dictionary:
	return {"id": id, "pos": pos, "unite": unite}


func test_chaque_unite_s_affiche_avec_la_feuille_de_son_modele() -> void:
	verifier(_donnees.ids_unites.size() >= 2, "au moins deux unités dans les données")
	var liste: Array[Dictionary] = []
	for u: int in _donnees.ids_unites.size():
		liste.append(_allie(u + 1, u, Vector2(100.0 * u, 50.0)))
	_arene.afficher(_vue(liste), 1.0)
	verifier_egal(_arene.nombre_allies_visibles(), liste.size())
	for u: int in _donnees.ids_unites.size():
		var fiche: Dictionary = _donnees.unites[_donnees.ids_unites[u]]
		var attendu: Dictionary = Apparence.entree_allie(String(fiche["modele"]))
		verifier(not attendu.is_empty(), "%s : modèle d'allié connu" % fiche["modele"])
		var sprite: Sprite2D = _arene.sprite_allie(u)
		verifier_non_nul(sprite, "sprite de l'allié %d" % u)
		if sprite != null:
			verifier_egal(sprite.texture.resource_path, String(attendu["feuille"]))


func test_un_allie_n_a_ni_la_teinte_ni_le_marquage_d_un_ennemi() -> void:
	var nb: int = _donnees.familles.size()
	var familles: Array[int] = []
	for f: int in nb:
		familles.append(f)
	var liste: Array[Dictionary] = []
	for u: int in _donnees.ids_unites.size():
		liste.append(_allie(u + 1, u, Vector2(80.0, 40.0 * u)))
	_arene.afficher(_vue(liste, familles), 1.0)
	verifier_egal(nb, 24, "vingt-quatre familles d'ennemis")
	for f: int in nb:
		var ennemi: Sprite2D = _arene.sprite_instance(f, 0)
		verifier_non_nul(ennemi, "ennemi de la famille %d" % f)
		if ennemi == null:
			continue
		verifier_nul(ennemi.find_child("Anneau", true, false), "famille %d : aucun anneau" % f)
		for u: int in liste.size():
			var sprite: Sprite2D = _arene.sprite_allie(u)
			verifier(sprite.modulate != ennemi.modulate, "famille %d : même teinte qu'un allié" % f)
			verifier(
				_arene.teinte_allie(u) != _arene.teinte_instance(f, 0),
				"famille %d : même teinte lue" % f
			)
	for u: int in liste.size():
		var anneau: Node2D = _arene.anneau_allie(u)
		verifier_non_nul(anneau, "l'allié %d a son anneau" % u)
		# La teinte de l'allié ne ressemble à aucune teinte de statut non plus.
		var teinte: Color = _arene.teinte_allie(u)
		verifier(_ecart(teinte, Color.WHITE) >= 0.2, "l'allié n'est pas blanc")
		for bit: int in [1, 2, 4, 8, 16]:
			var statut: Color = Arene2D.teinte_statut(bit)
			verifier(_ecart(teinte, statut) >= 0.2, "l'allié ressemble au statut %d" % bit)


func _ecart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_les_allies_sont_interpoles_entre_deux_etats_sans_saut() -> void:
	var source := SourceFactice.new()
	_arene.lier(source)
	_arene.afficher_courant(0.0)
	source.emettre_arene(_vue([_allie(7, 0, Vector2(0.0, 0.0))]))
	_arene.afficher_courant(0.1)
	source.emettre_arene(_vue([_allie(7, 0, Vector2(100.0, 40.0))]))
	var precedent: float = -1.0
	for pas: int in range(0, 11):
		_arene.afficher_courant(0.1 + 0.2 * float(pas) / 10.0)
		var p: Vector2 = _arene.position_allie(0)
		verifier(p.x >= precedent - 0.001, "il ne recule jamais (pas %d)" % pas)
		if precedent >= 0.0:
			verifier(p.x - precedent <= SAUT_VISIBLE, "pas de saut au pas %d" % pas)
		precedent = p.x
	_arene.afficher_courant(0.15)
	var milieu: Vector2 = _arene.position_allie(0)
	verifier(milieu.x > 0.0 and milieu.x < Apparence.vers_pixels(Vector2(100.0, 0.0)).x, "en route")
	_arene.afficher_courant(0.5)
	verifier_egal(_arene.position_allie(0), Apparence.vers_pixels(Vector2(100.0, 40.0)))
	source.free()


func test_un_allie_qui_apparait_ailleurs_ne_glisse_pas() -> void:
	var source := SourceFactice.new()
	_arene.lier(source)
	_arene.afficher_courant(0.0)
	source.emettre_arene(_vue([_allie(7, 0, Vector2(0.0, 0.0))]))
	_arene.afficher_courant(0.1)
	source.emettre_arene(_vue([_allie(7, 0, Vector2(900.0, 0.0))]))
	_arene.afficher_courant(0.15)
	verifier_egal(_arene.position_allie(0), Apparence.vers_pixels(Vector2(900.0, 0.0)))
	source.free()


func test_les_allies_disparaissent_avec_la_vue_et_ne_laissent_aucun_noeud() -> void:
	var liste: Array[Dictionary] = []
	for k: int in 40:
		liste.append(_allie(k + 1, k % 2, Vector2(10.0 * k, 5.0 * k)))
	_arene.afficher(_vue(liste), 1.0)
	verifier_egal(_arene.nombre_allies_visibles(), 40)
	_arene.afficher(_vue([]), 1.1)
	verifier_egal(_arene.nombre_allies_visibles(), 0)
	verifier_nul(_arene.sprite_allie(0), "plus d'allié")


func test_une_unite_inconnue_ne_plante_pas_et_ne_dessine_rien() -> void:
	_arene.afficher(_vue([_allie(1, 99, Vector2.ZERO), _allie(2, -1, Vector2.ZERO)]), 1.0)
	verifier_egal(_arene.nombre_allies_visibles(), 0)
