class_name LecteurSons
extends Node
## Joue les sons de l'arène. Il reçoit des vues, jamais la simulation : `DetecteurSons` dit ce qu'il
## faut jouer entre deux vues, et le lecteur le joue sur le bus des effets, ou la musique sur le
## bus de musique. `derniers_sons` garde les identifiants du dernier pas, pour les tests.

const POLYPHONIE := 8

var derniers_sons: Array[String] = []

var _joueurs: Array[AudioStreamPlayer] = []
var _ambiance: AudioStreamPlayer = null
var _precedente: VueArene = null


func _ready() -> void:
	BusAudio.assurer_bus()
	for i: int in POLYPHONIE:
		var joueur := AudioStreamPlayer.new()
		joueur.bus = BusAudio.BUS_EFFETS
		add_child(joueur)
		_joueurs.append(joueur)
	_ambiance = AudioStreamPlayer.new()
	_ambiance.bus = BusAudio.BUS_MUSIQUE
	add_child(_ambiance)


## Joue ce que la transition de la vue précédente vers `vue` demande. Une vue qui n'avance pas
## (même `tick`, ou plus ancienne, reçue deux fois) ne rejoue pas ses événements.
func traiter(vue: VueArene) -> void:
	derniers_sons.clear()
	if vue == null or (_precedente != null and vue.tick <= _precedente.tick):
		return
	for identifiant: String in DetecteurSons.sons_du_pas(_precedente, vue):
		_jouer(identifiant)
	_precedente = vue


func demarrer_ambiance() -> void:
	_ambiance.stream = CatalogueSons.flux(CatalogueSons.AMBIANCE)
	_ambiance.play()


func ambiance_active() -> bool:
	return _ambiance != null and _ambiance.playing


func arreter() -> void:
	_precedente = null
	for joueur: AudioStreamPlayer in _joueurs:
		joueur.stop()
	if _ambiance != null:
		_ambiance.stop()


func _jouer(identifiant: String) -> void:
	derniers_sons.append(identifiant)
	var libre := _joueur_libre()
	libre.stream = CatalogueSons.flux(identifiant)
	libre.play()


## Le premier lecteur libre ; s'ils jouent tous, le plus ancien est coupé pour le nouveau son.
func _joueur_libre() -> AudioStreamPlayer:
	for joueur: AudioStreamPlayer in _joueurs:
		if not joueur.playing:
			return joueur
	return _joueurs[0]
