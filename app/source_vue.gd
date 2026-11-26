class_name SourceVue
extends Node
## Interface unique entre la simulation et sa présentation (`ui/`, `visuels/`).
## Abstraite : GDScript n'a pas de méthode abstraite, les implémentations redéfinissent tout.

signal vue_arene_recue(vue: VueArene)
signal vue_globale_recue(vue: VueGlobale)
signal resultat_intention(genre: String, code: int)  # Types.Resultat
signal connexion_perdue(motif: String)
## L'arène d'un autre joueur, regardée de son vivant (`regarder`) ; `vue_arene_recue` reste celle
## du joueur local, ou de la cible observée après sa mort.
signal vue_regardee_recue(id_joueur: int, vue: VueArene)
## Le bilan de la partie, une fois, à sa fin (`BilanPartie.noms()` → valeur), celui du joueur local.
signal bilan_recu(bilan: Dictionary)


## Le dernier bilan de fin de partie reçu, `{}` tant qu'il n'est pas arrivé.
func bilan() -> Dictionary:
	return {}


## Identifiant du joueur local ; -1 tant que la base n'est pas redéfinie.
func id_local() -> int:
	return -1


## Identifiant du joueur dont l'arène est affichée ; -1 tant que la base n'est pas redéfinie.
func cible_observee() -> int:
	return -1


func acheter(_index_offre: int) -> void:
	pass


func relancer() -> void:
	pass


func vendre(_index_arme: int) -> void:
	pass


func choisir_marche_noir(_id_amelioration: String) -> void:
	pass


## `observer` reste réservé au joueur mort.
func observer(_id_joueur: int) -> void:
	pass


## Regarde l'arène d'un autre joueur sans quitter la sienne ; -1 : cesser. Sans effet en solo.
## Stub : T8.10 le relie au réseau et à la simulation.
func regarder(_id_joueur: int) -> void:
	pass


## Identifiant du joueur regardé ; -1 si aucun.
func id_regarde() -> int:
	return -1


func continuer_sans_fin() -> void:
	pass


func quitter_partie() -> void:
	pass
