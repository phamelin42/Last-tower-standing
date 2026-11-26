class_name SourceFactice
extends SourceVue
## Double de test de `SourceVue` : chaque intention est notée dans `appels` au lieu d'agir,
## et les signaux se déclenchent à la demande. Sert aux tests d'interface (HUD, boutique,
## arène) qui n'ont pas besoin d'une partie réelle.

var appels: Array[Dictionary] = []

var _id_local: int = 1
var _cible: int = -1
var _regarde: int = -1


## Règle les valeurs renvoyées par `id_local` et `cible_observee`.
func regler(id_local: int, cible: int) -> void:
	_id_local = id_local
	_cible = cible


func emettre_arene(vue: VueArene) -> void:
	vue_arene_recue.emit(vue)


func emettre_globale(vue: VueGlobale) -> void:
	vue_globale_recue.emit(vue)


func emettre_resultat(genre: String, code: int) -> void:
	resultat_intention.emit(genre, code)


func emettre_connexion_perdue(motif: String) -> void:
	connexion_perdue.emit(motif)


func id_local() -> int:
	return _id_local


func cible_observee() -> int:
	return _cible


func acheter(index_offre: int) -> void:
	_noter("acheter", [index_offre])


func relancer() -> void:
	_noter("relancer", [])


func vendre(index_arme: int) -> void:
	_noter("vendre", [index_arme])


func choisir_marche_noir(id_amelioration: String) -> void:
	_noter("choisir_marche_noir", [id_amelioration])


func observer(id_joueur: int) -> void:
	_noter("observer", [id_joueur])


func regarder(id_joueur: int) -> void:
	_regarde = id_joueur
	_noter("regarder", [id_joueur])


func id_regarde() -> int:
	return _regarde


func emettre_vue_regardee(id_joueur: int, vue: VueArene) -> void:
	vue_regardee_recue.emit(id_joueur, vue)


func continuer_sans_fin() -> void:
	_noter("continuer_sans_fin", [])


func quitter_partie() -> void:
	_noter("quitter_partie", [])


func _noter(nom: String, args: Array) -> void:
	appels.append({"nom": nom, "args": args})
