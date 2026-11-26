class_name JoueurPartie
extends RefCounted
## Ce que `Partie` retient d'un joueur : son arène, son état et ses statistiques figées. Interne à
## la simulation : ni le réseau ni l'interface ne le voient, ils passent par `VueGlobale`.

var id: int
var nom: String
## Nulle avant le démarrage et après le départ du joueur ; une arène détruite reste en place pour
## que les autres puissent l'observer.
var arene: Arene = null
var elimine: bool = false
var victorieux: bool = false
var parti: bool = false
## Plus rien à simuler : tour détruite, boss vaincu ou joueur parti.
var fige: bool = false
var pas_fin: int = -1
## Mode sans fin : après le boss, ce joueur rejoue des manches à son propre rythme. Il n'est plus
## « victorieux » (il est de nouveau en train de jouer) ; sa manche et sa prochaine famille sont
## les siennes, les autres arènes n'en savent rien.
var sans_fin: bool = false
var manche_sans_fin: int = 0
var pas_manche_sans_fin: int = 0
var composition_suivante_sans_fin: Composition = null
var planning_sans_fin: Planning = null
var cause: int = Classement.Cause.DEFAITE
var manche: int = 0
var eliminations: int = 0
var degats: float = 0.0
var revenu: int = 0
## Évènements lus par la vue globale pour ses statistiques, rendus à la prochaine vue d'arène.
var evenements_en_attente: Array[Dictionary] = []


func _init(id_joueur: int, nom_joueur: String) -> void:
	id = id_joueur
	nom = nom_joueur


## Vivant et pas parti : le joueur compte encore dans la partie (un vainqueur y reste jusqu'à ce
## qu'il quitte).
func en_jeu() -> bool:
	return not elimine and not parti
