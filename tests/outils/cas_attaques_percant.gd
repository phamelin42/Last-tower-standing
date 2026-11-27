class_name CasAttaquesPercant
extends CasDeTest
## Ce que partagent les tests des armes perçantes du lot 9 (D22) : l'`AttaquesElementaires`
## d'essai, les données du catalogue et quelques vérifications de genre.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)
## Les neuf armes perçantes du lot 9 et leur élément.
const ARMES: Dictionary = {
	"javeline_de_jet": "javeline",
	"trait_en_gerbe": "trait_gerbe",
	"fleche_marquante": "fleche_marquante",
	"arc_de_remparts": "arc_remparts",
	"herse_de_pieux": "herse_pieux",
	"lance_epineuse": "lance_epineuse",
	"carquois_en_rafale": "carquois",
	"mur_de_pointes": "mur_pointes",
	"couronne_de_pointes": "couronne_pointes",
}

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()


func avant_chaque() -> void:
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null


func _avancer(images: int) -> void:
	for i: int in images:
		_a.avancer(IMAGE)


func _effet(id: String) -> Dictionary:
	return (_donnees.armes[id]["effets"] as Array)[0]


func _rayon_px(id: String, cle: String = "rayon") -> float:
	return float(_effet(id)[cle]) * Apparence.PX_PAR_UNITE


func _statut(id: String) -> String:
	var statuts: Array = _donnees.armes[id]["statuts"]
	return "" if statuts.is_empty() else String(statuts[0]["kind"])


## Vérifie que l'arme `id` est de ce genre, perçante, et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(
		int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.PERCANT, "type de %s" % id
	)


## Un `Effets` qui rend les événements de la vitrine pour l'arme `id`.
func _effets_de(id: String) -> Effets:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	for evenement: Dictionary in vitrine.evenements_du_cycle(id):
		effets.ajouter(evenement)
	vitrine.free()
	return effets


## Le nombre maximal d'effets d'une planche vus en même temps pendant `images` images d'`effets`.
func _pic_de(effets: Effets, planche: String, images: int) -> int:
	var pic: int = effets.elementaires().etats(planche).size()
	for _i: int in images:
		effets.avancer(IMAGE)
		pic = maxi(pic, effets.elementaires().etats(planche).size())
	return pic
