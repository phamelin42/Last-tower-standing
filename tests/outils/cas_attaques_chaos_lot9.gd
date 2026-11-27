class_name CasAttaquesChaosLot9
extends CasDeTest
## Ce que partagent les tests des neuf armes de chaos du lot 9 (D22) : l'`AttaquesElementaires`
## d'essai, les données du catalogue et la table de ce que chaque arme doit montrer. Les nombres
## attendus (images, diamètres) sont écrits ici, d'après la fiche, pas lus dans le code testé ; la
## géométrie des planches se lit sur les fichiers.

const IMAGE: float = 1.0 / 60.0
const TOUR := Vector2(40.0, 300.0)
const CIBLE := Vector2(360.0, 300.0)
## id d'arme → élément, genre de l'effet, planche d'impact (celle d'une cible, d'une zone ou d'une
## volute d'aura), longueur en images de la séquence de cet impact, planche du projectile (`""`
## sans) et durée du vol en images (anticipation de 3 images en plus).
const ARMES: Dictionary = {
	"urne_des_ombres":
	{
		"element": "urne",
		"genre": "invocation",
		"impact": "eclat_ombre",
		"total": 12,
		"projectile": "urne",
		"vol": 11
	},
	"pacte_de_sang":
	{
		"element": "pacte",
		"genre": "cible_unique",
		"impact": "eclat_sang",
		"total": 12,
		"projectile": "goutte_sang",
		"vol": 11
	},
	"engrenage_jumeau":
	{
		"element": "jumeau",
		"genre": "cible_unique",
		"impact": "eclat_jumeau",
		"total": 12,
		"projectile": "engrenage_double",
		"vol": 7
	},
	"serment_brise":
	{
		"element": "serment",
		"genre": "cible_unique",
		"impact": "eclat_serment",
		"total": 12,
		"projectile": "serment",
		"vol": 7
	},
	"archere_fantome":
	{
		"element": "archere",
		"genre": "invocation",
		"impact": "eclat_spectre",
		"total": 12,
		"projectile": "fleche_spectre",
		"vol": 7
	},
	"miroir_de_discorde":
	{
		"element": "discorde",
		"genre": "rebond",
		"impact": "pointes_discorde",
		"total": 12,
		"projectile": "eclat_discorde",
		"vol": 7
	},
	"coupe_d_oubli":
	{
		"element": "coupe",
		"genre": "aura",
		"impact": "volute_oubli",
		"total": 10,
		"projectile": "",
		"vol": 0
	},
	"legion_de_cendre":
	{
		"element": "legion",
		"genre": "zone",
		"impact": "nuage_cendre",
		"total": 24,
		"projectile": "cendre",
		"vol": 11
	},
	"tempete_de_malefices":
	{
		"element": "malefices",
		"genre": "barrage",
		"impact": "eclat_malefice",
		"total": 12,
		"projectile": "malefice",
		"vol": 7
	},
}
## Un coup sur une cible seule reste petit : jamais plus de ce diamètre (px).
const DIAMETRE_MAX_CIBLE_UNIQUE: float = 60.0
## Un coup courant ne lance pas plus de particules que cela.
const PARTICULES_MAX: int = 8

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


func _rayon_px(id: String) -> float:
	return float(_effet(id)["rayon"]) * Apparence.PX_PAR_UNITE


## Le rayon (px) de la zone de l'arme `id`, 0 sans zone.
func _zone_px(id: String) -> float:
	var effet: Dictionary = _effet(id)
	return float(effet["rayon"]) * Apparence.PX_PAR_UNITE if effet.has("rayon") else 0.0


func _element(id: String) -> String:
	return String((ARMES[id] as Dictionary)["element"])


func _impact(id: String) -> String:
	return String((ARMES[id] as Dictionary)["impact"])


## L'image la plus grande d'une planche (rang, côté de sa boîte de pixels opaques), lue sur le
## fichier : c'est là que l'impact est au pic.
func _pic_de_planche(planche: String) -> Vector2i:
	var img: Image = (load(AttaquesElementaires.DOSSIER + planche + ".png") as Texture2D).get_image()
	var cote: int = img.get_height()
	var meilleur: int = 0
	var plus_grand: int = -1
	for rang: int in img.get_width() / cote:
		var haut: int = cote
		var bas: int = -1
		var gauche: int = cote
		var droite: int = -1
		for y: int in cote:
			for x: int in cote:
				if img.get_pixel(rang * cote + x, y).a > 0.0:
					haut = mini(haut, y)
					bas = maxi(bas, y)
					gauche = mini(gauche, x)
					droite = maxi(droite, x)
		var cote_visible: int = maxi(bas - haut, droite - gauche)
		if cote_visible > plus_grand:
			plus_grand = cote_visible
			meilleur = rang
	return Vector2i(meilleur, plus_grand + 1)


func _image_du_pic(planche: String) -> int:
	return _pic_de_planche(planche).x


## Un `Effets` neuf qui rend les événements de la vitrine.
func _effets_neuf() -> Effets:
	var effets: Effets = Effets.new()
	effets.catalogue = _donnees.ids_catalogue
	arbre.root.add_child(effets)
	return effets


## Les événements d'un tir de l'arme `id`, comme la vitrine (donc la simulation) les émet.
func _cycle(id: String) -> Array[Dictionary]:
	var vitrine: VitrineArmes = VitrineArmes.new()
	vitrine.armes = [id] as Array[String]
	var liste: Array[Dictionary] = vitrine.evenements_du_cycle(id)
	vitrine.free()
	return liste


## La première image (à 60 i/s) où l'effet de `planche` montre l'image `pic` de sa planche, -1 s'il
## ne la montre jamais en `images` images.
func _rang_du_pic(planche: String, pic: int, images: int) -> int:
	for rang: int in images:
		for etat: Dictionary in _a.etats(planche):
			if etat["visible"] and int(etat["image"]) == pic:
				return rang
		_a.avancer(IMAGE)
	return -1


## La première image où un effet de `planche` est visible dans `effets`, -1 s'il n'en vient aucun.
func _premiere_apparition(effets: Effets, planche: String, images: int) -> int:
	for rang: int in images:
		for etat: Dictionary in effets.elementaires().etats(planche):
			if etat["visible"]:
				return rang
		effets.avancer(IMAGE)
	return -1


func _visibles(planche: String) -> int:
	var n: int = 0
	for e: Dictionary in _a.etats(planche):
		n += 1 if e["visible"] else 0
	return n
