class_name VitrineArmes
extends Node2D
## Vitrine des armes réelles, à capturer par `tools/capturer.sh` : tire en boucle les six armes dont
## Phil juge le rendu (D22), avec les événements que la simulation émet (index de l'arme au
## catalogue, genre et statut en index, rayon lu dans l'effet), sans simulation ni réseau.
## Aucun texte affiché.
##
## Disposition (1152 × 648) : une bande horizontale de 108 px par arme, de haut en bas dans l'ordre
## de `ARMES` ; la tour à gauche, trois ennemis à droite (250 à 450 px), le tiré visant celui du
## milieu. Les bandes tirent toutes les `PERIODE` secondes, décalées de `DECALAGE` pour ne pas
## tout montrer dans la même image. Chaque tir émet les événements d'un tir réel : un projectile
## puis l'impact dans la même image ; un rebond = un impact par saut ; un barrage = plusieurs
## impacts pour un seul tir. `-- --mouvement-reduit` montre le mode réduit (D21).
## Le temps ne vient que de `_process(delta)` : à cadence fixe, deux captures sont identiques.

const ARMES: Array[String] = [
	"canon_de_cloche",
	"orbe_de_brume",
	"bombarde_de_poche",
	"cornue_instable",
	"chaine_d_arcanes",
	"etincelle_runique",
]

## Nombre de bandes, donc d'armes au plus.
const ARMES_MAX: int = 6
const OPTION_ARMES: String = "--armes"

const FOND := Color(0.24, 0.38, 0.27)
const COULEUR_SEPARATION := Color(0.16, 0.27, 0.19)
const COULEUR_TOUR := Color(0.9, 0.85, 0.6, 0.6)
const RAYON_TOUR_PX: float = 8.0
## Sprites des trois ennemis d'une bande, de gauche à droite (le tiré est celui du milieu).
const SPRITES_ENNEMIS: Array[String] = ["paysan_rouge", "guerrier_rouge", "archer_rouge"]
const ECHELLE_ENNEMI: float = 0.5

const LARGEUR_ECRAN: float = 1152.0
const HAUTEUR_ECRAN: float = 648.0
const HAUTEUR_BANDE: float = HAUTEUR_ECRAN / 6.0
const X_TOUR: float = 40.0
## Positions des ennemis dans la bande : abscisse depuis la gauche, décalage depuis le milieu.
const ENNEMIS_DANS_BANDE: Array[Vector2] = [
	Vector2(270.0, -22.0), Vector2(360.0, 0.0), Vector2(440.0, 20.0)
]
const INDEX_TIRE: int = 1

const PERIODE: float = 1.2
## Un piège ou une mine se déclenche quand un ennemi passe : la vitrine le laisse posé ce temps-là.
const DELAI_PIEGE: float = 0.6
const DECALAGE: float = 0.1
const GRAINE: int = 20261126
## Sauts d'un rebond après le premier impact : de l'ennemi du milieu au dernier, puis au premier.
const SAUTS_REBOND: int = 2
## Dispersion d'un barrage : les angles, en degrés, des projectiles autour de la ligne de tir.
const ANGLES_BARRAGE: Array[float] = [-9.0, -3.0, 3.0, 9.0]

## Les armes montrées, une bande chacune (`ARMES` par défaut).
var armes: Array[String] = ARMES.duplicate()
## Nombre d'effets créés par arme depuis le début (un impact en attente compte).
var crees: Dictionary = {}
var reactions: ReactionsCoups = ReactionsCoups.new()
## Plus grand nombre d'effets vivants vu depuis le début.
var pic_vivants: int = 0
var effets: Effets = null
## Montre le mode réduit ; posé avant l'entrée dans l'arbre, ou par `-- --mouvement-reduit`.
var mouvement_reduit: bool = false

var _donnees: Donnees = null
var _temps: float = 0.0
var _prochains: Array[float] = []
var _en_retard: Array[Dictionary] = []
var _sprites: Array[Sprite2D] = []
var _ids: PackedInt32Array = PackedInt32Array()
var _positions: PackedVector2Array = PackedVector2Array()


## Les armes demandées par `-- --armes id1,id2,…` parmi `ids` : celles de `ARMES` sans l'option.
## Un id inconnu, une liste vide ou plus de `ARMES_MAX` armes est refusé (message sur stderr) et
## on garde le défaut : une vitrine qui montre autre chose que prévu tromperait celui qui la lit.
static func lire_armes(args: PackedStringArray, ids: PackedStringArray) -> Array[String]:
	var defaut: Array[String] = ARMES.duplicate()
	var i: int = args.find(OPTION_ARMES)
	if i < 0:
		return defaut
	if i + 1 >= args.size():
		printerr("%s demande une liste d'armes séparées par des virgules" % OPTION_ARMES)
		return defaut
	var voulues: Array[String] = []
	for morceau: String in args[i + 1].split(",", false):
		var id: String = morceau.strip_edges()
		if not ids.has(id):
			printerr("Arme inconnue : %s" % id)
			return defaut
		voulues.append(id)
	if voulues.is_empty() or voulues.size() > ARMES_MAX:
		printerr("Entre 1 et %d armes attendues, %d données" % [ARMES_MAX, voulues.size()])
		return defaut
	return voulues


## Pixels de l'écran vers unités de jeu, ce que `Effets` attend dans les événements.
static func en_unites(pixels: Vector2) -> Vector2:
	return pixels / Apparence.PX_PAR_UNITE


## Index de la bande qui contient le point `pixels`.
static func bande_de(pixels: Vector2) -> int:
	return clampi(int(pixels.y / HAUTEUR_BANDE), 0, ARMES_MAX - 1)


## Position de la tour de la bande `bande`, en pixels.
static func position_tour(bande: int) -> Vector2:
	return Vector2(X_TOUR, (bande + 0.5) * HAUTEUR_BANDE)


## Position de l'ennemi `rang` (0 à 2) de la bande `bande`, en pixels.
static func position_ennemi(bande: int, rang: int) -> Vector2:
	var p: Vector2 = ENNEMIS_DANS_BANDE[rang]
	return Vector2(p.x, (bande + 0.5) * HAUTEUR_BANDE + p.y)


func _ready() -> void:
	seed(GRAINE)
	if OS.get_cmdline_user_args().has("--mouvement-reduit"):
		mouvement_reduit = true
	_donnees = Donnees.charger()
	armes = lire_armes(OS.get_cmdline_user_args(), _donnees.ids_catalogue)
	reactions.mouvement_reduit = mouvement_reduit
	effets = Effets.new()
	effets.mouvement_reduit = mouvement_reduit
	effets.catalogue = _donnees.ids_catalogue
	effets.name = "Effets"
	add_child(effets)
	effets.impact_visible.connect(_sur_impact_visible)
	for i: int in armes.size():
		_prochains.append(float(i) * DECALAGE)
	_poser_ennemis()


func _process(delta: float) -> void:
	avancer(delta)


## Fait avancer la vitrine (et ses effets) de `delta` secondes ; `_process` n'est que son appelant.
func avancer(delta: float) -> void:
	_temps += delta
	for bande: int in armes.size():
		while _temps >= _prochains[bande]:
			_prochains[bande] += PERIODE
			_tirer(bande)
	for i: int in range(_en_retard.size() - 1, -1, -1):
		_en_retard[i]["reste"] = float(_en_retard[i]["reste"]) - delta
		if float(_en_retard[i]["reste"]) <= 0.0:
			effets.ajouter(_en_retard[i]["evenement"])
			_en_retard.remove_at(i)
	effets.avancer(delta)
	reactions.avancer(delta)
	_animer_ennemis()
	pic_vivants = maxi(pic_vivants, effets.nombre_vivants())


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, LARGEUR_ECRAN, HAUTEUR_ECRAN), FOND)
	for bande: int in armes.size():
		if bande > 0:
			var y: float = float(bande) * HAUTEUR_BANDE
			draw_line(Vector2(0.0, y), Vector2(LARGEUR_ECRAN, y), COULEUR_SEPARATION)
		draw_circle(position_tour(bande), RAYON_TOUR_PX, COULEUR_TOUR)


func _poser_ennemis() -> void:
	for bande: int in armes.size():
		for rang: int in ENNEMIS_DANS_BANDE.size():
			var entree: Dictionary = Apparence.entree(SPRITES_ENNEMIS[rang])
			var case_px: Vector2i = entree["case"]
			var repos: Vector2i = entree["repos"]
			var sprite := Sprite2D.new()
			sprite.texture = load(String(entree["feuille"])) as Texture2D
			sprite.region_enabled = true
			sprite.region_rect = Rect2(
				0.0, float(repos.x * case_px.y), float(case_px.x), float(case_px.y)
			)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2.ONE * ECHELLE_ENNEMI
			# Les pieds de l'unité sur la position, pas le centre de sa case.
			sprite.offset = Vector2(0.0, case_px.y * 0.5 - float(entree["pieds"]))
			sprite.position = position_ennemi(bande, rang)
			add_child(sprite)
			move_child(sprite, 0)
			_sprites.append(sprite)
			_ids.append(_sprites.size())
			_positions.append(en_unites(sprite.position))


## Les ennemis de la bande de l'impact réagissent comme dans l'arène : recul à l'opposé de la tour.
func _sur_impact_visible(ou: Vector2, rayon: float, fort: bool) -> void:
	var bande: int = bande_de(ou * Apparence.PX_PAR_UNITE)
	reactions.toucher(ou, rayon, _ids, _positions, en_unites(position_tour(bande)), fort)


## Les identifiants des ennemis, dans l'ordre des bandes puis de gauche à droite.
func ids_cibles() -> PackedInt32Array:
	return _ids


func _animer_ennemis() -> void:
	for i: int in _sprites.size():
		var id: int = _ids[i]
		_sprites[i].position = reactions.position_affichee(
			id, _positions[i] * Apparence.PX_PAR_UNITE
		)
		var eclat: float = reactions.eclat(id)
		_sprites[i].modulate = Color(eclat, eclat, eclat)


func _tirer(bande: int) -> void:
	var id: String = armes[bande]
	var avant: int = _en_jeu()
	var piege: int = VueArene.genre_depuis_nom("piege")
	var mine: int = VueArene.genre_depuis_nom("mine")
	for evenement: Dictionary in evenements_du_cycle(id):
		if evenement["k"] == "impact" and int(evenement["genre"]) in [piege, mine]:
			_en_retard.append({"reste": DELAI_PIEGE, "evenement": evenement})
		else:
			effets.ajouter(evenement)
	crees[id] = int(crees.get(id, 0)) + _en_jeu() - avant


## Ce que `Effets` tient en jeu : les effets vivants et les impacts qui attendent leur projectile.
func _en_jeu() -> int:
	return effets.nombre_vivants() + effets.impacts_en_attente()


## L'événement `k` (« tir » ou « impact ») de l'arme `id` sur l'ennemi du milieu, avec la signature
## que `sim/tir.gd` émet : index de l'arme au catalogue, genre et statut en index.
func evenement_de(id: String, k: String) -> Dictionary:
	if _donnees == null:
		_donnees = Donnees.charger()
	var arme: Dictionary = _donnees.armes[id]
	var effet: Dictionary = (arme["effets"] as Array)[0]
	var statuts: Array = arme["statuts"]
	var bande: int = armes.find(id)
	return {
		"k": k,
		"t": 0,
		"de": en_unites(position_tour(bande)),
		"vers": en_unites(position_ennemi(bande, INDEX_TIRE)),
		"type_degats": int(arme["type_degats"]),
		"rayon": 0.0,
		"genre": VueArene.genre_depuis_nom(String(effet["kind"])),
		"statut":
		VueArene.statut_depuis_nom(String(statuts[0]["kind"])) if not statuts.is_empty() else 0,
		"arme": _donnees.ids_catalogue.find(id),
	}


## Les événements d'un tir de l'arme `id`, dans l'ordre où la simulation les émet.
func evenements_du_cycle(id: String) -> Array[Dictionary]:
	var arme: Dictionary = _donnees.armes[id] if _donnees != null else Donnees.charger().armes[id]
	var effet: Dictionary = (arme["effets"] as Array)[0]
	var bande: int = armes.find(id)
	var liste: Array[Dictionary] = [evenement_de(id, "tir")]
	var rayon: float = float(effet.get("rayon", 0.0))
	match String(effet["kind"]):
		"barrage":
			var tour: Vector2 = position_tour(bande)
			var cible: Vector2 = position_ennemi(bande, INDEX_TIRE)
			for angle: float in ANGLES_BARRAGE:
				var impact: Dictionary = evenement_de(id, "impact")
				var point: Vector2 = tour + (cible - tour).rotated(deg_to_rad(angle))
				impact["vers"] = en_unites(point)
				impact["rayon"] = rayon
				liste.append(impact)
		"rebond":
			var depart: Vector2 = position_tour(bande)
			var rang: int = INDEX_TIRE
			for saut: int in 1 + SAUTS_REBOND:
				var impact: Dictionary = evenement_de(id, "impact")
				var arrivee: Vector2 = position_ennemi(bande, rang)
				impact["de"] = en_unites(depart)
				impact["vers"] = en_unites(arrivee)
				liste.append(impact)
				depart = arrivee
				rang = (rang + 1) % ENNEMIS_DANS_BANDE.size()
		"aura", "onde":
			# Rien ne part vers un ennemi : l'impact est centré sur la tour, au rayon de l'effet
			# (celui de l'onde à son dernier pas). Une aura n'émet aucun tir.
			var impact: Dictionary = evenement_de(id, "impact")
			var tour: Vector2 = en_unites(position_tour(bande))
			impact["de"] = tour
			impact["vers"] = tour
			impact["rayon"] = float(effet.get("rayon_max", rayon))
			if String(effet["kind"]) == "aura":
				liste.clear()
			liste.append(impact)
		_:
			var impact: Dictionary = evenement_de(id, "impact")
			impact["rayon"] = rayon
			liste.append(impact)
	return liste
