extends CasDeTest
## Salon rouvert après une partie (serveur dédié) : les pairs de la partie précédente restent
## connectés sans être inscrits, et sans délai de bonjour tant qu'ils n'ont pas parlé. Un pair neuf
## qui reste muet est coupé comme avant, et un bonjour d'un ancien le traite en pair neuf. Sans
## socket : on présente des pairs et des octets.

var d: Donnees
var crees: Array[Serveur] = []


func avant_chaque() -> void:
	d = Donnees.charger()
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


func _inscrire(s: Serveur, pair: int, nom: String) -> void:
	s.pair_connecte(pair)
	s.traiter_bonjour(pair, Protocole.encoder_bonjour(nom, d.empreinte))


func _temps(s: Serveur, secondes: float) -> void:
	for _i: int in int(secondes / 0.5):
		s.tick(0.5)


func test_un_ancien_muet_reste_connecte_mais_hors_du_salon() -> void:
	var s := _serveur()
	_inscrire(s, 1, "A")
	s.rouvrir_salon()
	_temps(s, 20.0)
	verifier_egal(s.nb_pairs(), 1, "A n'est pas coupé par le délai de bonjour")
	verifier_faux(s.salon.joueurs.has(1), "A n'est pas dans le salon neuf")


func test_un_pair_neuf_muet_est_coupe_meme_dans_un_salon_rouvert() -> void:
	var s := _serveur()
	_inscrire(s, 1, "A")
	s.rouvrir_salon()
	s.pair_connecte(3)
	_temps(s, 6.0)
	verifier_egal(s.nb_pairs(), 1, "le muet neuf est coupé, l'ancien reste")
	s.pair_connecte(3)
	_temps(s, 6.0)
	verifier_egal(s.nb_pairs(), 1, "toujours : un pair qui se reconnecte est neuf")


func test_le_joueur_suivant_est_hote_et_peut_lancer_malgre_l_ancien() -> void:
	var s := _serveur()
	_inscrire(s, 1, "A")
	s.rouvrir_salon()
	_inscrire(s, 2, "B")
	verifier_egal(s.salon.hote, 2, "B est l'hôte")
	s.salon.marquer_pret(2, true)
	verifier(s.salon.peut_demarrer(), "A, non inscrit, ne bloque pas le lancement")


func test_un_ancien_qui_parle_est_un_pair_neuf_soumis_au_delai() -> void:
	var s := _serveur()
	_inscrire(s, 1, "A")
	s.rouvrir_salon()
	# Un bonjour d'une autre version : refusé, le pair part et ne garde aucune exemption.
	var mauvais := Protocole.encoder_bonjour("A", d.empreinte)
	mauvais[1] = Protocole.VERSION + 1
	s.traiter_bonjour(1, mauvais)
	verifier_egal(s.nb_pairs(), 0, "refusé : coupé")
	# Il se reconnecte : pair neuf, donc coupé s'il reste muet.
	s.pair_connecte(1)
	_temps(s, 6.0)
	verifier_egal(s.nb_pairs(), 0, "muet : coupé comme tout pair neuf")


func test_un_ancien_qui_dit_bonjour_entre_dans_le_salon() -> void:
	var s := _serveur()
	_inscrire(s, 1, "A")
	s.rouvrir_salon()
	s.traiter_bonjour(1, Protocole.encoder_bonjour("A", d.empreinte))
	verifier(s.salon.joueurs.has(1), "un bonjour l'inscrit dans le salon neuf")
	_temps(s, 20.0)
	verifier_egal(s.nb_pairs(), 1, "inscrit, il n'est plus soumis au délai")


func test_un_ancien_qui_envoie_un_bonjour_illisible_perd_son_exemption() -> void:
	var s := _serveur()
	_inscrire(s, 1, "A")
	s.rouvrir_salon()
	# Un octet de trop ou de moins : ni refusé ni inscrit, mais le pair a parlé.
	s.traiter_bonjour(1, PackedByteArray([1]))
	verifier_egal(s.nb_pairs(), 1, "pas coupé tout de suite")
	_temps(s, 6.0)
	verifier_egal(s.nb_pairs(), 0, "muet ensuite : coupé par le délai de bonjour")
