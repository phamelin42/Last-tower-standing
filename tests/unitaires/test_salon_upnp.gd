extends CasDeTest
## Ce que l'hôte lit sur l'écran du salon quand sa box n'ouvre pas le port : une ligne d'état qui
## dit la conséquence, sans bloquer le salon local. Chemin réel : `Principal`, la session et un
## double de la box.

const TestUpnp := preload("res://tests/unitaires/test_upnp_hote.gd")
const ADRESSE := "127.0.0.1"
const DELAI_MS := 8000
const MESSAGE := (
	"Votre box n’a pas ouvert le port : " + "les joueurs extérieurs ne pourront pas vous rejoindre"
)

var _donnees: Donnees
var _principal: Principal = null
var _boxes: Array[TestUpnp.Double] = []
var _locale_avant: String = ""
var _port_jeu: int = 0
var _port_udp: int = 0


func avant_chaque() -> void:
	_locale_avant = TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	_donnees = Donnees.charger()
	_boxes = []
	_principal = null
	delai_max = 30.0
	_port_jeu = _port_libre(0)
	_port_udp = _port_libre(_port_jeu)


func apres_chaque() -> void:
	if _principal != null and is_instance_valid(_principal):
		_principal.get_parent().remove_child(_principal)
		_principal.queue_free()
	_principal = null
	TranslationServer.set_locale(_locale_avant)


func _port_libre(autre_que: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + autre_que
	for i: int in 40:
		var p := rng.randi_range(20000, 60000)
		var essai := PacketPeerUDP.new()
		var ok := p != autre_que and essai.bind(p, ADRESSE) == OK
		essai.close()
		if ok:
			return p
	return 0


func _jusqua(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + DELAI_MS
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await arbre.process_frame
	return condition.call()


## Une box par création de salon, dans l'ordre : la première échoue ou non selon `echecs`.
func _principal_neuf(echecs: Array[bool]) -> Principal:
	for echec: bool in echecs:
		var box := TestUpnp.Double.new()
		if echec:
			box.resultat_decouverte = UPNP.UPNP_RESULT_NO_GATEWAY
		_boxes.append(box)
	var p := (load("res://scenes/principal.tscn") as PackedScene).instantiate() as Principal
	p.arguments = Arguments.lire(PackedStringArray([]))
	p.donnees = _donnees
	p.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	p.port_decouverte = _port_udp
	p.cibles_decouverte = []
	var suivante: Array[int] = [0]
	p.fabrique_passerelle = func() -> UpnpHote.Passerelle:
		var i: int = suivante[0]
		suivante[0] += 1
		return _boxes[i]
	arbre.root.add_child(p)
	_principal = p
	return p


func _creer_salon(p: Principal) -> void:
	p.menu().champ_nom.text = "Mina"
	p.menu().bouton_creer.pressed.emit()
	p.connexion().champ_port_creer.text = str(_port_jeu)
	p.connexion().bouton_creer.pressed.emit()


func _hote_pret(p: Principal) -> bool:
	return await _jusqua(
		func() -> bool: return not p.salon().en_attente() and p.salon().lignes_joueurs().size() == 1
	)


func test_echec_de_la_box_affiche_la_ligne_exacte_sur_le_salon() -> void:
	var p := _principal_neuf([true])
	_creer_salon(p)
	verifier(p.salon().visible)
	verifier(await _jusqua(func() -> bool: return p.salon().avertissement() == MESSAGE))
	verifier(await _hote_pret(p), "le salon reste utilisable en local")
	verifier(p.salon().bouton_lancer.visible and not p.salon().bouton_lancer.disabled)
	verifier_egal(p.salon().avertissement(), MESSAGE)


func test_succes_de_la_box_n_affiche_aucune_ligne() -> void:
	var p := _principal_neuf([false])
	_creer_salon(p)
	verifier(await _jusqua(func() -> bool: return p.session().port_externe == _port_jeu))
	await attendre_images(3)
	verifier_egal(p.salon().avertissement(), "")


func test_echec_puis_retour_au_salon_reussi_efface_la_ligne() -> void:
	var p := _principal_neuf([true, false])
	_creer_salon(p)
	verifier(await _jusqua(func() -> bool: return p.salon().avertissement() == MESSAGE))
	verifier(await _hote_pret(p))
	p.salon().bouton_lancer.pressed.emit()
	verifier(await _jusqua(func() -> bool: return p.jeu() != null), "la partie s'ouvre")
	p.jeu().retour_salon.emit()
	verifier(await _jusqua(func() -> bool: return p.session().port_externe == _port_jeu))
	verifier_egal(p.salon().avertissement(), "", "la nouvelle redirection a réussi")
	verifier_egal(_boxes[1].appels_ajout.size(), 1, "la redirection est refaite")


func test_retour_au_salon_dont_la_box_echoue_encore_remontre_la_ligne() -> void:
	var p := _principal_neuf([false, true])
	_creer_salon(p)
	verifier(await _jusqua(func() -> bool: return p.session().port_externe == _port_jeu))
	verifier_egal(p.salon().avertissement(), "")
	verifier(await _hote_pret(p))
	p.salon().bouton_lancer.pressed.emit()
	verifier(await _jusqua(func() -> bool: return p.jeu() != null))
	p.jeu().retour_salon.emit()
	verifier(await _jusqua(func() -> bool: return p.salon().avertissement() == MESSAGE))


func test_le_texte_garde_l_apostrophe_typographique_et_l_espace_insecable() -> void:
	verifier_egal(String(TranslationServer.translate("CONNEXION_UPNP_ECHEC")), MESSAGE)
	verifier_contient(MESSAGE, "n’a")
	verifier_contient(MESSAGE, "port :")


func test_retour_au_salon_masque_la_ligne_des_la_nouvelle_tentative() -> void:
	var p := _principal_neuf([true, false])
	_boxes[1].barrage = Semaphore.new()
	_creer_salon(p)
	verifier(await _jusqua(func() -> bool: return p.salon().avertissement() == MESSAGE))
	verifier(await _hote_pret(p))
	p.salon().bouton_lancer.pressed.emit()
	verifier(await _jusqua(func() -> bool: return p.jeu() != null))
	p.jeu().retour_salon.emit()
	verifier_egal(p.salon().avertissement(), "", "l'ancienne alerte ne reste pas pendant l'attente")
	_boxes[1].barrage.post()
	verifier(await _jusqua(func() -> bool: return p.session().port_externe == _port_jeu))
