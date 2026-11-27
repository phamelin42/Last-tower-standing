class_name CasAttaquesSiegeLot9
extends CasDeTest
## Ce que partagent les tests des armes de siège du lot 9 (D22) : l'`AttaquesElementaires`
## d'essai, les données du catalogue, les événements d'un tir comme la simulation les émet et
## quelques vérifications de genre. Les images de pic des planches viennent des planches elles-mêmes
## (la plus grande image de chaque impact), pas du code testé.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)
## Les neuf armes de siège du lot 9 et leur élément.
const ARMES: Dictionary = {
	"baril_a_retardement": "baril",
	"maillet_de_rempart": "maillet",
	"catapulte_a_contrepoids": "catapulte",
	"obusier_de_breche": "obusier",
	"braise_de_siege": "braise",
	"ecrasement_de_tour": "ecrasement",
	"champ_de_ruines": "ruines",
	"salve_du_rempart": "salve",
	"colosse_de_pierre": "colosse",
}
## L'image la plus grande de chaque planche d'impact : c'est là que le coup est au pic.
const PIC: Dictionary = {"explosion_feu": 2, "pop_petard": 3, "cratere": 3, "onde_choc": 3}
## Un coup sur une cible seule reste petit : jamais plus de ce diamètre (px)... sauf le coup de
## siège, que Phil a voulu plus grand (27/11/2026) : sa taille est une donnée.
const DIAMETRE_MAX_CIBLE_UNIQUE: float = 60.0

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()


func avant_chaque() -> void:
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	if is_instance_valid(_a):
		_a.free()
	_a = null


## Le diamètre d'un coup de siège sur une cible seule : `data/assets.json`, pas une constante.
func _diametre_siege_seul() -> float:
	return PlanchesEffets.diametre_impact_siege_seul()


## Le plus petit diamètre (px) d'une zone, d'une bombe ou d'une mine de siège : un coup sur une
## cible seule, même agrandi, reste au-dessous (sinon il se lirait comme une zone).
func _plus_petite_zone_de_siege_px() -> float:
	var plus_petit: float = INF
	for id: String in _donnees.armes:
		var arme: Dictionary = _donnees.armes[id]
		if int(arme["type_degats"]) != Types.TypeDegats.SIEGE:
			continue
		var effet: Dictionary = (arme["effets"] as Array)[0]
		if effet.has("rayon"):
			plus_petit = minf(plus_petit, float(effet["rayon"]) * Apparence.PX_PAR_UNITE * 2.0)
	return plus_petit


func _avancer(images: int) -> void:
	for i: int in images:
		_a.avancer(IMAGE)


func _effet(id: String) -> Dictionary:
	return (_donnees.armes[id]["effets"] as Array)[0]


func _rayon_px(id: String) -> float:
	return float(_effet(id)["rayon"]) * Apparence.PX_PAR_UNITE


func _statut(id: String) -> String:
	var statuts: Array = _donnees.armes[id]["statuts"]
	return "" if statuts.is_empty() else String(statuts[0]["kind"])


## Vérifie que l'arme `id` est de ce genre, de siège, sans élément partagé, rendue par `element`.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.SIEGE, "type de %s" % id)


## Un `Effets` neuf qui rend les événements `k` de la vitrine pour l'arme `id`.
func _effets_neuf() -> Effets:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	return effets


## L'événement `k` (« tir » ou « impact ») que la simulation émet pour l'arme `id`, au rayon de son
## effet pour un impact.
func _evenement(id: String, k: String) -> Dictionary:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var evenement: Dictionary = vitrine.evenement_de(id, k)
	vitrine.free()
	evenement["rayon"] = float(_effet(id).get("rayon", 0.0))
	return evenement


## Le nombre d'effets d'une planche vus en même temps (au plus) pendant `images` images.
func _pic_de(effets: Effets, planche: String, images: int) -> int:
	var pic: int = effets.elementaires().etats(planche).size()
	for _i: int in images:
		effets.avancer(IMAGE)
		pic = maxi(pic, effets.elementaires().etats(planche).size())
	return pic


## La première image (à 60 i/s) où l'effet de `planche` montre l'image `pic` de sa planche, -1 s'il
## ne la montre jamais en `images` images.
func _rang_du_pic(planche: String, pic: int, images: int) -> int:
	for rang: int in images:
		for etat: Dictionary in _a.etats(planche):
			if int(etat["image"]) == pic:
				return rang
		_a.avancer(IMAGE)
	return -1


func _visibles(planche: String) -> int:
	var n: int = 0
	for e: Dictionary in _a.etats(planche):
		n += 1 if e["visible"] else 0
	return n
