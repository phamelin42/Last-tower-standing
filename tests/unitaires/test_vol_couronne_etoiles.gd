extends CasDeTest
## La durée de vol du projectile d'un élément se lit dans `data/assets.json` (`effets.maison.
## images_vol`) : l'étoile de la couronne, qui parcourt toute sa portée, vole plus longtemps que
## les autres vols directs (7 images), sans dépasser la borne de la mort retardée. Images à 60 i/s.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(100.0, 300.0)
const CIBLE := Vector2(1100.0, 300.0)
const ELEMENT: String = "couronne_etoiles"
const ARME: String = "couronne_d_etoiles"

var _a: AttaquesElementaires = null
var _donnees: Donnees = Donnees.charger()
var _origine: Dictionary = {}


func avant_chaque() -> void:
	_origine = Assets.tout().duplicate(true)
	_a = AttaquesElementaires.new()
	arbre.root.add_child(_a)


func apres_chaque() -> void:
	Assets.remplacer(_origine)
	if is_instance_valid(_a):
		_a.free()
	_a = null


func _images_vol_donnees() -> int:
	return int(Assets.section("effets")["maison"]["images_vol"][ELEMENT])


func test_le_vol_de_l_etoile_est_celui_des_donnees_et_depasse_celui_des_autres_vols_directs(
) -> void:
	var vol: int = _images_vol_donnees()
	verifier(vol > AttaquesElementaires.IMAGES_VOL_DIRECT, "plus lent que 7 images : %d" % vol)
	var fin: float = _a.tirer(ELEMENT, TOUR, CIBLE)
	verifier_proche(fin / IMAGE, float(AttaquesElementaires.IMAGES_ANTICIPATION + vol), 0.01)


func test_l_anticipation_et_le_vol_tiennent_dans_la_borne_de_la_mort_retardee() -> void:
	var total: int = AttaquesElementaires.IMAGES_ANTICIPATION + _images_vol_donnees()
	verifier(
		total * IMAGE <= Arene2D.DELAI_MORT_MAX,
		"%d images au plus %f s" % [total, Arene2D.DELAI_MORT_MAX]
	)


func test_les_autres_vols_directs_gardent_sept_images() -> void:
	for element: String in ["arbalete", "baliste", "arcane", "prisme", "tempete"]:
		_a.vider()
		var fin: float = _a.tirer(element, TOUR, CIBLE)
		verifier_proche(
			fin / IMAGE, float(AttaquesElementaires.IMAGES_ANTICIPATION + 7), 0.01, element
		)


func test_une_valeur_changee_dans_les_donnees_change_la_duree_du_vol() -> void:
	var autre: Dictionary = Assets.tout().duplicate(true)
	autre["effets"]["maison"]["images_vol"][ELEMENT] = 9
	Assets.remplacer(autre)
	verifier_proche(
		_a.tirer(ELEMENT, TOUR, CIBLE) / IMAGE,
		float(AttaquesElementaires.IMAGES_ANTICIPATION + 9),
		0.01
	)


func test_l_eclat_de_la_couronne_tombe_a_la_fin_du_vol_a_une_image_pres() -> void:
	var effets := Effets.new()
	arbre.root.add_child(effets)
	effets.catalogue = _donnees.ids_catalogue
	(
		effets
		. ajouter(
			{
				"k": "tir",
				"t": 0,
				"de": Vector2.ZERO,
				"vers": Vector2(1000.0, 0.0),
				"type_degats": int(_donnees.armes[ARME]["type_degats"]),
				"rayon": 40.0,
				"genre": "tournant",
				"arme": _donnees.ids_catalogue.find(ARME),
			}
		)
	)
	var vue: int = -1
	for i: int in 40:
		effets.avancer(IMAGE)
		if vue < 0 and not effets.elementaires().etats("eclat_astral").is_empty():
			vue = i + 1
	var attendu: int = AttaquesElementaires.IMAGES_ANTICIPATION + _images_vol_donnees()
	verifier(vue > 0, "l'éclat apparaît")
	verifier(absi(vue - attendu) <= 1, "éclat à l'image %d, fin du vol à %d" % [vue, attendu])
	effets.free()
