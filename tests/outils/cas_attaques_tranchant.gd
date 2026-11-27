class_name CasAttaquesTranchant
extends CasDeTest
## Ce que partagent les tests des armes tranchantes du lot 9 (D22) : l'`AttaquesElementaires`
## d'essai, les données du catalogue et quelques vérifications de genre.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)

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


## Vérifie que l'arme `id` est de ce genre, tranchante, et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(
		int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.TRANCHANT, "type de %s" % id
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


## Les bouts des rayons d'un tir de l'arme `id` (pixels), tels que la vitrine les émet.
func _bouts(id: String) -> Array[Vector2]:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var bouts: Array[Vector2] = []
	for evenement: Dictionary in vitrine.evenements_du_cycle(id):
		bouts.append(Apparence.vers_pixels(evenement["vers"]))
	vitrine.free()
	return bouts


## Un tir tournant garde les rayons de sa marque ; chaque branche y ajoute une lame qui file
## jusqu'au bout du rayon et mord là, à l'arrivée du vol.
func _verifier_tournant_dans_effets(id: String, lame: String, impact: String) -> void:
	var branches: int = int(_effet(id)["branches"])
	var bouts: Array[Vector2] = _bouts(id)
	verifier_egal(bouts.size(), branches, "une branche par événement")
	var effets: Effets = _effets_de(id)
	verifier_egal(effets.elementaires().etats(lame).size(), branches, "une lame par branche")
	var rayons: int = 0
	for forme: String in effets.formes_vivantes():
		rayons += 1 if forme == "trait_rayon" else 0
	verifier_egal(rayons, branches, "les rayons de la marque restent")
	var arrivee: int = (
		AttaquesElementaires.IMAGES_ANTICIPATION + AttaquesElementaires.IMAGES_VOL_DIRECT
	)
	for _i: int in arrivee:
		effets.avancer(IMAGE)
	var coups: Array[Dictionary] = effets.elementaires().etats(impact)
	verifier_egal(coups.size(), branches, "un impact par bout")
	for coup: Dictionary in coups:
		var proche: float = INF
		for bout: Vector2 in bouts:
			proche = minf(proche, (coup["position"] as Vector2).distance_to(bout))
		verifier(proche < 1.0, "l'impact est au bout d'un rayon")
	effets.free()
