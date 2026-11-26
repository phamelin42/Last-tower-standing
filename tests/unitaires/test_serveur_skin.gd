extends CasDeTest
## Le serveur et le skin de tour (T11.5) : choisi au salon par une intention `SKIN`, borné au
## catalogue, rangé avec le joueur dès le lancement, jamais accepté en partie. Sans socket : on
## présente des pairs et des octets, les envois sont captés.

const NB_SKINS := 4

var d: Donnees
var crees: Array[Serveur] = []


func avant_chaque() -> void:
	var brut := AidesPartie.brut()
	var skins: Dictionary = brut["skins_tour.json"]
	for i: int in range(1, NB_SKINS):
		skins["essai_%d" % i] = (skins["defaut"] as Dictionary).duplicate(true)
	d = Donnees.depuis_brut(brut)
	crees = []


func apres_chaque() -> void:
	for s: Serveur in crees:
		s.free()


func _serveur() -> Serveur:
	var s := Serveur.new()
	crees.append(s)
	s.emetteur = func(_pair: int, _rpc: String, _octets: PackedByteArray) -> void: pass
	s.preparer(d, 1)
	return s


func _connecter(s: Serveur, pair: int) -> void:
	s.pair_connecte(pair)
	s.traiter_bonjour(pair, Protocole.encoder_bonjour("Joueur %d" % pair, d.empreinte))


func _skin(s: Serveur, pair: int, index: int) -> int:
	return s.traiter_intention(pair, Protocole.encoder_intention(Protocole.Intention.SKIN, index))


func _pret_tous(s: Serveur, pairs: Array[int]) -> void:
	s.traiter_intention(pairs[0], Serveur.encoder_options(1.0, 777, true))
	for p: int in pairs:
		s.traiter_intention(p, Protocole.encoder_intention(Protocole.Intention.PRET, 1))


func _skin_en_partie(s: Serveur, pair: int) -> int:
	for j: Dictionary in s.partie.vue_globale().joueurs:
		if int(j["id"]) == pair:
			return int(j["skin"])
	return -99


func test_chaque_skin_choisi_au_salon_arrive_dans_la_partie() -> void:
	for index: int in d.ids_skins().size():
		var s := _serveur()
		_connecter(s, 11)
		_connecter(s, 12)
		verifier_egal(_skin(s, 12, index), Types.Resultat.OK, "skin %d accepté" % index)
		_pret_tous(s, [11, 12] as Array[int])
		verifier_non_nul(s.partie, "partie lancée")
		if s.partie == null:
			continue
		verifier_egal(_skin_en_partie(s, 12), index, "skin %d en partie" % index)
		verifier_egal(_skin_en_partie(s, 11), 0, "l'autre joueur : skin par défaut")


func test_un_nouveau_client_a_le_skin_par_defaut_tant_qu_il_n_en_choisit_pas() -> void:
	var s := _serveur()
	_connecter(s, 11)
	_pret_tous(s, [11] as Array[int])
	verifier_egal(_skin_en_partie(s, 11), 0)


func test_un_index_hors_catalogue_vaut_le_skin_par_defaut() -> void:
	var n := d.ids_skins().size()
	for index: int in [-1, n, n + 1, 255, 256, 2147483647, -2147483648]:
		var s := _serveur()
		_connecter(s, 11)
		_skin(s, 11, 2)
		verifier_egal(_skin(s, 11, index), Types.Resultat.OK, "index %d" % index)
		_pret_tous(s, [11] as Array[int])
		verifier_egal(_skin_en_partie(s, 11), 0, "index %d vaut le skin par défaut" % index)


func test_le_dernier_choix_du_salon_l_emporte() -> void:
	var s := _serveur()
	_connecter(s, 11)
	_skin(s, 11, 1)
	_skin(s, 11, 3)
	_pret_tous(s, [11] as Array[int])
	verifier_egal(_skin_en_partie(s, 11), 3)


func test_le_skin_ne_change_qu_au_salon() -> void:
	var s := _serveur()
	_connecter(s, 11)
	_skin(s, 11, 2)
	_pret_tous(s, [11] as Array[int])
	verifier_egal(_skin(s, 11, 3), Types.Resultat.MAUVAISE_PHASE, "refusé en partie")
	verifier_egal(_skin_en_partie(s, 11), 2, "le skin du salon reste")


func test_un_pair_inconnu_ne_peut_pas_choisir_de_skin() -> void:
	var s := _serveur()
	verifier_egal(_skin(s, 77, 1), Types.Resultat.NON_DISPONIBLE)
