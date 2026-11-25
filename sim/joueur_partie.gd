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
