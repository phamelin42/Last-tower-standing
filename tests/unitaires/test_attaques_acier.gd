extends CasDeTest
## Les six armes tranchantes (D22, famille acier), arme par arme : ce que le joueur voit part
## d'une anticipation, suit le genre de l'arme (cible unique, zone, rebond, aura, onde, barrage) et
## s'arrête au rayon réel de l'arme, lu dans `data/armes.json`. Durées en images à 60 i/s.

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


## Le premier effet de l'arme `id` dans `data/armes.json`.
func _effet(id: String) -> Dictionary:
	return (_donnees.armes[id]["effets"] as Array)[0]


## Vérifie que l'arme `id` est de ce genre et rendue par cet élément.
func _verifier_arme(id: String, element: String, genre: String) -> void:
	verifier(AttaquesElementaires.connait(element), "élément de %s" % id)
	verifier_egal(ElementsArmes.de(id), element, "table de %s" % id)
	verifier_egal(String(_effet(id)["kind"]), genre, "genre de %s" % id)
	verifier_egal(
		int(_donnees.armes[id]["type_degats"]), Types.TypeDegats.TRANCHANT, "type de %s" % id
	)


# --- Lame de fil : cible unique ----------------------------------------------------------------


func test_la_lame_de_fil_est_une_cible_unique() -> void:
	_verifier_arme("lame_de_fil", "lame", "cible_unique")


func test_la_lame_dure_dix_images_et_tourne_sur_elle_meme() -> void:
	verifier_proche(_a.tirer("lame", TOUR, CIBLE) / IMAGE, 10.0, 0.01)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var lame: Dictionary = _a.etats("lame_croissant")[0]
	verifier(lame["visible"], "la lame vole")
	var avant: int = lame["image"]
	_avancer(2)
	verifier(_a.etats("lame_croissant")[0]["image"] != avant, "elle tourne : une autre image")


func test_l_entaille_de_la_lame_reste_petite_et_jette_deux_eclats() -> void:
	_a.impacter("lame", CIBLE, 0.0)
	verifier_egal(_a.etats("entaille").size(), 1, "une entaille")
	verifier(_a.diametre_max() <= 60.0, "cible unique : au plus 60 px")
	verifier_egal(_a.particules_actives(), 1, "une salve d'éclats")
	_avancer(40)
	verifier_egal(_a.nombre_vivants(), 0, "tout se dissipe")


func test_mouvement_reduit_la_lame_ne_tourne_pas_et_sans_eclat() -> void:
	_a.mouvement_reduit = true
	_a.tirer("lame", TOUR, CIBLE)
	_avancer(AttaquesElementaires.IMAGES_ANTICIPATION + 1)
	var avant: int = _a.etats("lame_croissant")[0]["image"]
	_avancer(2)
	verifier_egal(_a.etats("lame_croissant")[0]["image"], avant, "ne tourne pas")
	_a.impacter("lame", CIBLE, 0.0)
	verifier_egal(_a.particules_actives(), 0)
