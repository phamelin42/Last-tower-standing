extends CasDeTest
## Les événements de tir et d'impact d'une arène vont à chaque client qui la regarde : tous, depuis
## son propre dernier envoi, sans rien voler au propriétaire ni aux autres observateurs.

var d: Donnees
var sorties: Array[Dictionary] = []
var crees: Array[Serveur] = []


func avant_chaque() -> void:
	d = Donnees.charger()
	sorties = []
	crees = []


func apres_chaque() -> void:
	for s: Serveur in crees:
		s.free()


func _serveur(acceleration: int = 1) -> Serveur:
	var s := Serveur.new()
	crees.append(s)
	s.emetteur = func(pair: int, rpc: String, octets: PackedByteArray) -> void:
		sorties.append({"pair": pair, "rpc": rpc, "octets": octets})
	s.preparer(d, acceleration)
	return s


func _intention(s: Serveur, pair: int, genre: int, arg: int = 0) -> int:
	return s.traiter_intention(pair, Protocole.encoder_intention(genre, arg))


## `n` pairs 11, 12… prêts, graine fixe : la partie démarre au dernier.
func _lancer(s: Serveur, n: int) -> Array[int]:
	var ids: Array[int] = []
	for i: int in n:
		ids.append(11 + i)
		s.pair_connecte(11 + i)
		s.traiter_bonjour(11 + i, Protocole.encoder_bonjour("Joueur %d" % i, d.empreinte))
	s.traiter_intention(ids[0], Serveur.encoder_options(1.0, 777, true))
	for pair: int in ids:
		verifier_egal(_intention(s, pair, Protocole.Intention.PRET, 1), Types.Resultat.OK)
	return ids


func _etats(pair: int) -> Array[VueArene]:
	var out: Array[VueArene] = []
	for e: Dictionary in sorties:
		if int(e["pair"]) == pair and String(e["rpc"]) == "rpc_etat_arene":
			var v := Protocole.decoder_etat_arene(e["octets"], d.ids_catalogue)
			verifier_non_nul(v, "tout état émis se décode")
			out.append(v)
	return out


## Somme des événements des états d'arène émis pour ce pair depuis le dernier `sorties.clear()`.
func _evenements_recus(pair: int) -> int:
	var total := 0
	for v: VueArene in _etats(pair):
		verifier(v.evenements.size() <= Protocole.MAX_EVENEMENTS)
		total += v.evenements.size()
	return total


## Le premier pair garde sa tour et achète des armes ; les autres quittent et observent son arène.
func _observateurs_de(s: Serveur, ids: Array[int]) -> void:
	BotAchat.jouer(s.partie, ids[0], 4)
	for k: int in range(1, ids.size()):
		_intention(s, ids[k], Protocole.Intention.QUITTER)
		verifier_egal(
			_intention(s, ids[k], Protocole.Intention.OBSERVER, ids[0]), Types.Resultat.OK
		)


func _jouer_secondes(s: Serveur, secondes: float) -> void:
	for i: int in roundi(secondes * 60.0):
		s.tick(1.0 / 60.0)


func test_chaque_observateur_recoit_tous_les_evenements_de_l_arene_regardee() -> void:
	delai_max = 60.0
	for n: int in range(2, 9):
		sorties.clear()
		var s := _serveur(4)
		var ids := _lancer(s, n)
		_observateurs_de(s, ids)
		_jouer_secondes(s, 55.0)
		var lus := s.evenements_lus(ids[0])
		verifier(lus > 100, "%d clients : l'arène a produit des événements (%d)" % [n, lus])
		for pair: int in ids:
			verifier_egal(
				_evenements_recus(pair) + s.en_attente(pair),
				lus,
				"%d clients, pair %d : tout reçu ou en attente, rien perdu ni dupliqué" % [n, pair]
			)
			verifier(s.en_attente(pair) <= Serveur.TAMPON_PAR_ENVOI * 2, "peu de retard")


func test_un_observateur_qui_change_d_arene_ne_recoit_pas_les_anciens_evenements() -> void:
	delai_max = 60.0
	var s := _serveur(4)
	var ids := _lancer(s, 3)
	BotAchat.jouer(s.partie, ids[0], 4)
	BotAchat.jouer(s.partie, ids[1], 4)
	_intention(s, ids[2], Protocole.Intention.QUITTER)
	_intention(s, ids[2], Protocole.Intention.OBSERVER, ids[0])
	# Les premières familles marchent lentement : on laisse la manche avancer jusqu'au premier
	# événement plutôt que de supposer qu'un ennemi arrive à portée en 12 s.
	var ecoule := 0.0
	while s.evenements_lus(ids[1]) == 0 and ecoule < 60.0:
		_jouer_secondes(s, 3.0)
		ecoule += 3.0
	verifier(s.evenements_lus(ids[1]) > 0, "l'arène suivante produit des événements")
	var lus_avant := s.evenements_lus(ids[1])
	verifier_egal(_intention(s, ids[2], Protocole.Intention.OBSERVER, ids[1]), Types.Resultat.OK)
	verifier_egal(s.en_attente(ids[2]), 0, "rien d'ancien en attente après le changement")
	var lus_au_changement := s.evenements_lus(ids[1])
	sorties.clear()
	_jouer_secondes(s, 3.0)
	var neufs := s.evenements_lus(ids[1]) - lus_au_changement
	verifier(neufs > 0, "de nouveaux événements arrivent")
	verifier_egal(
		_evenements_recus(ids[2]) + s.en_attente(ids[2]),
		neufs,
		"seuls les événements postérieurs au changement sont reçus (%d avant)" % lus_avant
	)


func test_le_tampon_d_une_arene_reste_borne_sous_une_longue_partie() -> void:
	delai_max = 60.0
	var s := _serveur(4)
	var ids := _lancer(s, 1)
	BotAchat.jouer(s.partie, ids[0], 8)
	for i: int in 60:
		_jouer_secondes(s, 3.0)
		verifier(s.taille_tampon(ids[0]) <= TamponEvenements.CAPACITE)
