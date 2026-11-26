class_name SourceLocale
extends SourceVue
## Source de vue du solo : une `Partie` tourne dans le même processus. Chaque vue passe par
## `to_dict()` puis `from_dict()` avant d'être émise, pour que l'interface reçoive exactement ce
## qu'elle recevrait du réseau.

## Identifiant du joueur local : toujours le même en solo, il n'y a personne d'autre.
const ID_LOCAL := 1
## Cadences d'émission (spec §4) : au plus 15 vues d'arène et 2 vues globales par seconde.
const HZ_ARENE := 15.0
const HZ_GLOBAL := 2.0

var _partie: Partie = null
var _cible: int = ID_LOCAL
var _attente_arene: float = 0.0
var _attente_globale: float = 0.0


func _init() -> void:
	set_process(false)


## Crée la partie, y ajoute le joueur local et la démarre. Faux (sans exception) si les données
## manquent, si une partie tourne déjà ou si la partie refuse de démarrer.
func demarrer(donnees: Donnees, config: Partie.Config, nom_joueur: String) -> bool:
	if donnees == null or _partie != null:
		return false
	var partie := Partie.new(donnees, config)
	if not partie.ajouter_joueur(ID_LOCAL, nom_joueur) or not partie.demarrer():
		return false
	_partie = partie
	_cible = ID_LOCAL
	_attente_arene = 0.0
	_attente_globale = 0.0
	set_process(true)
	return true


func _process(delta: float) -> void:
	if _partie == null:
		return
	_partie.avancer(delta)
	_attente_arene += delta
	_attente_globale += delta
	var fini := _partie.est_terminee()
	# À la fin, la dernière vue globale part tout de suite : elle porte le classement.
	if _attente_arene >= 1.0 / HZ_ARENE and not fini:
		_attente_arene = fmod(_attente_arene, 1.0 / HZ_ARENE)
		_emettre_arene()
	if _attente_globale >= 1.0 / HZ_GLOBAL or fini:
		_attente_globale = fmod(_attente_globale, 1.0 / HZ_GLOBAL)
		_emettre_globale()
	if fini:
		_arreter()


func id_local() -> int:
	return ID_LOCAL


func cible_observee() -> int:
	return _cible


func acheter(index_offre: int) -> void:
	_intention("acheter", func() -> int: return _partie.intention_acheter(ID_LOCAL, index_offre))


func relancer() -> void:
	_intention("relancer", func() -> int: return _partie.intention_relancer(ID_LOCAL))


func vendre(index_arme: int) -> void:
	_intention("vendre", func() -> int: return _partie.intention_vendre(ID_LOCAL, index_arme))


func choisir_marche_noir(id_amelioration: String) -> void:
	_intention(
		"choisir_marche_noir",
		func() -> int: return _partie.intention_marche_noir(ID_LOCAL, id_amelioration)
	)


func continuer_sans_fin() -> void:
	_intention(
		"continuer_sans_fin", func() -> int: return _partie.intention_continuer_sans_fin(ID_LOCAL)
	)


## Refusé tant que le joueur local est en jeu. La cible ne change jamais d'elle-même : c'est
## l'interface d'observation qui le demande.
func observer(id_joueur: int) -> void:
	if _partie == null or not _partie.observation_permise(ID_LOCAL):
		return
	if _partie.vue_arene(ID_LOCAL, id_joueur) == null:
		return
	_cible = id_joueur


## Sans effet : en solo, il n'y a aucune autre arène à regarder. `id_regarde` reste à -1.
func regarder(_id_joueur: int) -> void:
	pass


## Arrête tout : plus de vue, plus de partie. Sans effet si rien ne tourne.
func quitter_partie() -> void:
	if _partie == null:
		return
	_intention("quitter_partie", func() -> int: return _partie.intention_quitter(ID_LOCAL))
	_arreter()


func _intention(genre: String, appel: Callable) -> void:
	var code: int = Types.Resultat.ARENE_MORTE
	if _partie != null:
		code = appel.call()
	resultat_intention.emit(genre, code)


func _arreter() -> void:
	_partie = null
	set_process(false)


func _emettre_arene() -> void:
	var brute := _partie.vue_arene(ID_LOCAL, _cible)
	if brute == null:
		return
	var vue := VueArene.from_dict(brute.to_dict())
	if vue != null:
		vue_arene_recue.emit(vue)


func _emettre_globale() -> void:
	var vue := VueGlobale.from_dict(_partie.vue_globale().to_dict())
	if vue != null:
		vue_globale_recue.emit(vue)
