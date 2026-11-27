class_name VitrineBoutique
extends Node
## Vitrine de la boutique réelle (S25), à capturer par `tools/capturer.sh` : une vraie partie solo
## (`scenes/jeu.tscn`) dont la boutique montre quatre offres choisies (trois armes de types, de
## mécaniques et de statuts différents, une amélioration) et les armes équipées. `-- --sans-reperes`
## cache les repères d'arme (icônes de la carte et du type dans la grille) : l'état d'avant.
## `-- --echelle 1.25` règle la taille de l'interface, `-- --offres a,b,c,d` choisit les offres.

const OPTION_SANS := "--sans-reperes"
const OPTION_ECHELLE := "--echelle"
const OPTION_OFFRES := "--offres"
const OFFRES_DEFAUT: Array[String] = [
	"lame_de_fil", "tempete_de_malefices", "colosse_de_pierre", "affutage_fin"
]
const ARMES_EQUIPEES := 6
const OR := 5000
const ZONE := Vector2(1152.0, 648.0)

var _jeu: Jeu
var _sans_reperes := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_sans_reperes = OPTION_SANS in args
	var echelle := _valeur(args, OPTION_ECHELLE, "1.0").to_float()
	var ids: PackedStringArray = _valeur(args, OPTION_OFFRES, ",".join(OFFRES_DEFAUT)).split(",")
	var donnees := Donnees.charger()
	_jeu = (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	_jeu.chemin_reglages = "user://vitrine_boutique.cfg"
	_jeu.nom_joueur = "Mina"
	add_child(_jeu)
	_jeu.demarrer_solo(donnees, 2024, 0.5)
	var zone := ZONE / echelle
	var racine := _jeu.get_node("Interface/Racine") as Control
	racine.scale = Vector2(echelle, echelle)
	racine.anchor_right = 0.0
	racine.anchor_bottom = 0.0
	racine.offset_right = zone.x
	racine.offset_bottom = zone.y
	_jeu.source._process(1.0)
	_jeu.source.set_process(false)
	await get_tree().process_frame
	_jeu.placer_dans(zone)
	var vue := VueArene.new()
	vue.argent = OR
	vue.cout_relance = 50
	for id: String in ids:
		var genre: int = Types.Genre.ARME if donnees.armes.has(id) else Types.Genre.AMELIORATION
		var entree: Dictionary = (
			donnees.armes[id] if genre == Types.Genre.ARME else donnees.ameliorations[id]
		)
		(
			vue
			. offres
			. append(
				{
					"id": id,
					"genre": genre,
					"rarete": int(entree["rarete"]),
					"prix": int(entree["prix"]),
					"vendu": false,
				}
			)
		)
	var armes: Array = donnees.armes.keys()
	for i: int in ARMES_EQUIPEES:
		vue.armes.append({"id": armes[i * 11 % armes.size()], "recharge_ratio": 0.0})
	_jeu.boutique.afficher(vue)
	await get_tree().process_frame
	if _sans_reperes:
		_cacher()


func _cacher() -> void:
	for noeud: Node in _jeu.boutique.find_children("Reperes*", "Control", true, false):
		(noeud as Control).visible = false
	for noeud: Node in _jeu.boutique.find_children("TypeDegats", "Control", true, false):
		(noeud as Control).visible = false


func _valeur(args: PackedStringArray, option: String, defaut: String) -> String:
	var i := args.find(option)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else defaut
