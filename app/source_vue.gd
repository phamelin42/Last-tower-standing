class_name SourceVue
extends Node
## Interface unique entre la simulation et sa présentation (`ui/`, `visuels/`).
## Abstraite : GDScript n'a pas de méthode abstraite, les implémentations redéfinissent tout.

signal vue_arene_recue(vue: VueArene)
signal vue_globale_recue(vue: VueGlobale)
signal resultat_intention(genre: String, code: int)  # Types.Resultat
signal connexion_perdue(motif: String)


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


func observer(_id_joueur: int) -> void:
	pass


func continuer_sans_fin() -> void:
	pass


func quitter_partie() -> void:
	pass
