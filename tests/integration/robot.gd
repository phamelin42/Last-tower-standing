extends SceneTree
## Client sans interface pour l'intégration (`tools/integration.sh`) : il rejoint un serveur par le
## même chemin que le jeu (`SessionReseau`), se met prêt, joue une stratégie d'`StrategiesJoueur`
## à partir des `VueArene` reçues, puis observe l'arène d'un autre joueur une fois éliminé.
##
## godot --headless --path . --script res://tests/integration/robot.gd -- \
##     --adresse 127.0.0.1 --port P --nom Robot1 --strategie raisonnable [--joueurs 2] [--delai 110]
##
## Le premier joueur du salon est l'hôte : il règle ×4 et lance quand les autres sont prêts.
## Codes de sortie : 0 fin de partie (ou victoire, il quitte alors), 1 erreur ou connexion perdue
## inattendue, 4 délai maximal dépassé.

const CODE_OK: int = 0
const CODE_ERREUR: int = 1
const CODE_DELAI: int = 4
## Pause entre deux actions : laisse revenir la vue qui montre l'effet de la précédente.
const PAUSE_ACTION_MS: int = 150
const VITESSE_X4: float = 0.25
const GRAINE: int = 7

var _adresse: String = "127.0.0.1"
var _port: int = 0
var _nom: String = "Robot"
var _strategie: String = StrategiesJoueur.RAISONNABLE
var _joueurs_attendus: int = 2
var _delai_ms: int = 110000

var _donnees: Donnees = null
var _session: SessionReseau = null
var _debut_ms: int = 0
var _derniere_action_ms: int = 0
var _fini: bool = false
var _pret_envoye: bool = false
var _options_envoyees: bool = false
var _manche_max: int = 0
var _derniere_manche: int = -1
var _eliminee: bool = false
var _global: VueGlobale = null


func _initialize() -> void:
	process_frame.connect(_demarrer, CONNECT_ONE_SHOT)


func _process(_delta: float) -> bool:
	if not _fini and _debut_ms > 0 and Time.get_ticks_msec() - _debut_ms > _delai_ms:
		_terminer(CODE_DELAI, "délai maximal dépassé en manche %d" % _manche_max)
	return false


func _demarrer() -> void:
	if not _lire_arguments(OS.get_cmdline_user_args()):
		_terminer(CODE_ERREUR, "arguments invalides")
		return
	_donnees = Donnees.charger()
	if _donnees == null:
		_terminer(CODE_ERREUR, "données du jeu absentes")
		return
	_debut_ms = Time.get_ticks_msec()
	_session = SessionReseau.new()
	root.add_child(_session)
	_session.salon_mis_a_jour.connect(_sur_salon)
	_session.connexion_perdue.connect(_sur_perte)
	var client_cree := _session.rejoindre(_donnees, _adresse, _port, _nom)
	if client_cree != OK:
		_terminer(CODE_ERREUR, "connexion impossible (%s)" % error_string(client_cree))
		return
	_session.client.vue_arene_recue.connect(_sur_arene)
	_session.client.vue_globale_recue.connect(_sur_globale)


func _lire_arguments(args: PackedStringArray) -> bool:
	var i := 0
	while i < args.size():
		if i + 1 >= args.size():
			printerr("Argument sans valeur : %s" % args[i])
			return false
		var valeur := args[i + 1]
		match args[i]:
			"--adresse":
				_adresse = valeur
			"--port":
				_port = valeur.to_int()
			"--nom":
				_nom = valeur
			"--strategie":
				_strategie = valeur
			"--joueurs":
				_joueurs_attendus = valeur.to_int()
			"--delai":
				_delai_ms = valeur.to_int() * 1000
			_:
				printerr("Argument inconnu : %s" % args[i])
				return false
		i += 2
	if _port < 1 or not StrategiesJoueur.TOUTES.has(_strategie) or _joueurs_attendus < 1:
		printerr("Port ou stratégie invalide.")
		return false
	return true


# --- Salon -----------------------------------------------------------------------------------


func _sur_salon(salon: Salon) -> void:
	if _fini:
		return
	var client := _session.client
	var moi := client.id_local()
	if moi < 1 or not salon.joueurs.has(moi) or salon.lancee:
		return
	if not client.est_hote():
		if not _pret_envoye:
			_pret_envoye = true
			client.pret(true)
		return
	if not _options_envoyees:
		_options_envoyees = true
		client.regler_options(VITESSE_X4, GRAINE, true)
	if _pret_envoye or salon.joueurs.size() < _joueurs_attendus:
		return
	for id: int in salon.joueurs:
		if id != moi and not bool((salon.joueurs[id] as Dictionary)["pret"]):
			return
	_pret_envoye = true
	client.lancer()


# --- Partie ----------------------------------------------------------------------------------


func _sur_globale(vue: VueGlobale) -> void:
	if _fini:
		return
	_global = vue
	var moi := _session.client.id_local()
	for j: Dictionary in vue.joueurs:
		if int(j["id"]) == moi and not bool(j["vivant"]):
			_eliminee = true
	if vue.termine:
		_terminer(CODE_OK, "fin de partie")
		return
	if _eliminee:
		_observer_un_vivant()


func _sur_arene(vue: VueArene) -> void:
	if _fini:
		return
	var client := _session.client
	if client.cible_observee() != client.id_local() and client.cible_observee() != -1:
		return
	_manche_max = maxi(_manche_max, vue.manche)
	if vue.manche != _derniere_manche:
		_derniere_manche = vue.manche
		print("Robot %s : manche %d" % [_nom, vue.manche])
	if vue.phase == Types.Phase.VICTOIRE:
		client.quitter_partie()
		_terminer(CODE_OK, "victoire")
		return
	if vue.phase == Types.Phase.DEFAITE:
		_eliminee = true
		_observer_un_vivant()
		return
	var maintenant := Time.get_ticks_msec()
	if maintenant - _derniere_action_ms < PAUSE_ACTION_MS:
		return
	_derniere_action_ms = maintenant
	_jouer(vue)


## Une action par vue au plus : marché noir, achat, sinon relance, comme `StrategiesJoueur.jouer`.
func _jouer(vue: VueArene) -> void:
	if _strategie == StrategiesJoueur.PASSIVE:
		return
	var client := _session.client
	if vue.marche_noir_ouvert:
		var meilleur := ""
		var valeur := -1.0
		for id_amelioration: String in _donnees.ameliorations:
			var a: Dictionary = _donnees.ameliorations[id_amelioration]
			var s := StrategiesJoueur._valeur_amelioration(
				a, PackedInt32Array([1, 1, 1, 1, 1]), _strategie, vue.manche
			)
			if s > valeur:
				valeur = s
				meilleur = id_amelioration
		client.choisir_marche_noir(meilleur)
		return
	var index := StrategiesJoueur._choisir(_strategie, vue, _donnees)
	if index >= 0:
		client.acheter(index)
	elif StrategiesJoueur._veut_relancer(vue, vue.phase == Types.Phase.PREPARATION):
		client.relancer()


func _observer_un_vivant() -> void:
	var client := _session.client
	if _global == null:
		return
	var moi := client.id_local()
	var courant := client.cible_observee()
	for j: Dictionary in _global.joueurs:
		if int(j["id"]) == courant and bool(j["vivant"]) and courant != moi:
			return
	for j: Dictionary in _global.joueurs:
		if int(j["id"]) != moi and bool(j["vivant"]):
			client.observer(int(j["id"]))
			return


# --- Fin -------------------------------------------------------------------------------------


func _sur_perte(motif: String) -> void:
	if not _fini:
		_terminer(CODE_ERREUR, "connexion perdue : %s" % motif)


func _terminer(code: int, raison: String) -> void:
	if _fini:
		return
	_fini = true
	var classement := _global.classement if _global != null else ([] as Array[int])
	var duree := float(Time.get_ticks_msec() - _debut_ms) / 1000.0
	var ligne := (
		"ROBOT nom=%s code=%d manche=%d classement=%s duree=%.1f raison=%s"
		% [_nom, code, _manche_max, str(classement), duree, raison]
	)
	if code == CODE_OK:
		print(ligne)
	else:
		printerr(ligne)
	# Souvent appelée depuis un signal de la session : on ne la libère qu'après son émission.
	_quitter.call_deferred(code)


func _quitter(code: int) -> void:
	if _session != null:
		_session.fermer()
		root.remove_child(_session)
		_session.queue_free()
		_session = null
	quit(code)
