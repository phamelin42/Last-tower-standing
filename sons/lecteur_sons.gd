class_name LecteurSons
extends Node
## Joue les sons de l'arène. Il reçoit des vues, jamais la simulation : `DetecteurSons` dit ce qu'il
## faut jouer entre deux vues, et le lecteur le joue sur le bus des effets, ou la musique sur le
## bus de musique. `derniers_sons` garde les identifiants du dernier pas, pour les tests.

const POLYPHONIE := 8
## Écart de hauteur d'un tir à l'autre (± 5 %), pour qu'une rafale ne sonne pas en machine à écrire.
const VARIATION_HAUTEUR := 0.05

## Intervalle minimal (s) entre deux sons d'impact du même type : un pas de simulation, la cadence
## à laquelle `DetecteurSons` limitait déjà les impacts (un par type et par vue).
const INTERVALLE_IMPACT := 0.05

var derniers_sons: Array[String] = []
## Hauteurs (1,0 = normale) des tirs joués au dernier pas, pour les tests.
var derniere_hauteur: Array[float] = []
## `Donnees.ids_catalogue` : traduit l'index d'arme d'un tir en son. Vide, il est chargé de `data/`
## au premier pas (le client et le serveur ont la même empreinte de données).
var catalogue: PackedStringArray = PackedStringArray()

var _joueurs: Array[AudioStreamPlayer] = []
var _ambiance: AudioStreamPlayer = null
var _precedente: VueArene = null
var _hasard := RandomNumberGenerator.new()
## Dernier instant (s) où le son d'impact de chaque identifiant a été joué.
var _dernier_impact: Dictionary = {}


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


## Fixe la graine des variations de hauteur (les tests en veulent une).
func graine(valeur: int) -> void:
	_hasard.seed = valeur


## Joue ce que la transition de la vue précédente vers `vue` demande. Une vue qui n'avance pas
## (même `tick`, ou plus ancienne, reçue deux fois) ne rejoue pas ses événements.
func traiter(vue: VueArene) -> void:
	derniers_sons.clear()
	derniere_hauteur.clear()
	if vue == null or (_precedente != null and vue.tick <= _precedente.tick):
		return
	if catalogue.is_empty():
		var donnees: Donnees = Donnees.charger()
		if donnees != null:
			catalogue = donnees.ids_catalogue
	for identifiant: String in DetecteurSons.sons_du_pas(_precedente, vue, catalogue):
		_jouer(identifiant)
	_precedente = vue


## Un impact vient de devenir visible : on joue le son de son type de dégâts, au plus une fois par
## `INTERVALLE_IMPACT` et par type. `maintenant` (s) ne sert qu'aux tests ; sans lui, l'horloge.
func jouer_impact(type_degats: int, maintenant: float = -1.0) -> void:
	var instant: float = maintenant if maintenant >= 0.0 else Time.get_ticks_usec() / 1000000.0
	var identifiant: String = CatalogueSons.id_impact(type_degats)
	if _dernier_impact.has(identifiant):
		if instant - float(_dernier_impact[identifiant]) < INTERVALLE_IMPACT:
			return
	_dernier_impact[identifiant] = instant
	_jouer(identifiant)


func demarrer_ambiance() -> void:
	_ambiance.stream = CatalogueSons.flux(CatalogueSons.AMBIANCE)
	_ambiance.play()


func ambiance_active() -> bool:
	return _ambiance != null and _ambiance.playing


func arreter() -> void:
	_precedente = null
	_dernier_impact.clear()
	for joueur: AudioStreamPlayer in _joueurs:
		joueur.stop()
	if _ambiance != null:
		_ambiance.stop()


func _jouer(identifiant: String) -> void:
	derniers_sons.append(identifiant)
	var libre := _joueur_libre()
	libre.stream = CatalogueSons.flux(identifiant)
	libre.pitch_scale = 1.0
	if identifiant.begins_with(CatalogueSons.TIR):
		libre.pitch_scale = 1.0 + _hasard.randf_range(-VARIATION_HAUTEUR, VARIATION_HAUTEUR)
		derniere_hauteur.append(libre.pitch_scale)
	libre.play()


## Le premier lecteur libre ; s'ils jouent tous, le plus ancien est coupé pour le nouveau son.
func _joueur_libre() -> AudioStreamPlayer:
	for joueur: AudioStreamPlayer in _joueurs:
		if not joueur.playing:
			return joueur
	return _joueurs[0]
