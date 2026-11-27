class_name VitrineMecaniques
extends Node2D
## Vitrine des mécaniques du lot 9 (T9.19), à capturer par `tools/capturer.sh` : une vraie
## `Arene2D` à laquelle on envoie, dix fois par seconde, des vues faites à la main (sans simulation
## ni réseau), pour juger comment se lisent les alliés, les zones posées, les bombes, le tir
## tournant, le repoussement et les trois nouveaux statuts d'ennemi. Aucun texte affiché.
##
## Ce qu'on y voit, en unités de jeu autour de la tour (origine) : huit alliés, guerriers et
## archers, qui tournent autour d'elle ; deux zones posées à gauche et à droite, qui se
## renouvellent ; deux bombes décalées qui explosent chacune à la fin de leur délai ; un tir
## tournant à quatre branches ; un ennemi repoussé à droite ; et des ennemis porteurs de chacun
## des trois nouveaux statuts, d'un ancien statut et de rien, pour comparer. Le cycle dure
## `PERIODE` secondes.
## `-- --mouvement-reduit` montre le mode réduit (D21). `-- --charge` pose 64 alliés, 32 zones et
## 32 bombes et fait tirer 255 armes (le plafond d'effets).
## Le temps ne vient que de `_process(delta)` : à cadence fixe, deux captures sont identiques.

const SCENE_ARENE := "res://scenes/arene_2d.tscn"
const OPTION_REDUIT := "--mouvement-reduit"
const OPTION_CHARGE := "--charge"

const LARGEUR_ECRAN: float = 1152.0
const HAUTEUR_ECRAN: float = 648.0
## Niveau de la caméra de l'arène (1 : tout le cercle d'apparition) : plus près pour le détail.
const NIVEAU_CAMERA: float = 0.6

## Armes qui tirent en même temps avec `-- --charge`, une salve toutes les `PAS_CHARGE` secondes.
const ARMES_CHARGE: int = 255
const PAS_CHARGE: float = 0.5
## Les positions ci-dessous sont écrites pour un petit cercle ; cette échelle les écarte pour que
## les sprites, plus grands que des unités de jeu, ne se recouvrent pas.
const ECARTEMENT: float = 1.9
const PERIODE: float = 4.0
## Les vues partent à 10 Hz, comme les vues réseau de l'arène regardée.
const INTERVALLE_VUE: float = 0.1
const GRAINE: int = 20261127

const NB_ALLIES: int = 8
const RAYON_ALLIES: float = 170.0
## Vitesse angulaire des alliés autour de la tour (radians par seconde).
const VITESSE_ALLIES: float = 0.6

const ZONES: Array[Dictionary] = [
	{"pos": Vector2(-330.0, -150.0), "rayon": 140.0, "decalage": 0.0},
	{"pos": Vector2(330.0, 170.0), "rayon": 100.0, "decalage": 2.0},
]
const BOMBES: Array[Dictionary] = [
	{"pos": Vector2(-300.0, 170.0), "rayon": 110.0, "debut": 0.0},
	{"pos": Vector2(230.0, -190.0), "rayon": 90.0, "debut": 1.2},
]
const DELAI_BOMBE: float = 2.5
## Tir tournant : quatre branches, une salve toutes les `PAS_TOURNANT` secondes, la phase avançant
## de `ECART_PHASE` degrés à chaque salve.
const BRANCHES: int = 4
const PAS_TOURNANT: float = 0.3
const ECART_PHASE: float = 20.0
const PORTEE_TOURNANT: float = 420.0
const LARGEUR_TOURNANT: float = 18.0
const REPOUSSE := Vector2(470.0, 30.0)
const INSTANTS_REPOUSSEMENT: Array[float] = [0.5, 2.1]

## Ennemis : position, famille, bits de statut.
const ENNEMIS: Array[Dictionary] = [
	{"pos": Vector2(380.0, -100.0), "famille": 0, "statut": Types.STATUT_VULNERABLE},
	{"pos": Vector2(440.0, -60.0), "famille": 4, "statut": Types.STATUT_VULNERABLE},
	{"pos": Vector2(380.0, 60.0), "famille": 8, "statut": Types.STATUT_MAUDIT},
	{"pos": Vector2(440.0, 110.0), "famille": 12, "statut": Types.STATUT_MAUDIT},
	{"pos": Vector2(-400.0, -60.0), "famille": 16, "statut": Types.STATUT_SIPHONNE},
	{"pos": Vector2(-450.0, 0.0), "famille": 20, "statut": Types.STATUT_SIPHONNE},
	{
		"pos": Vector2(-400.0, 60.0),
		"famille": 3,
		"statut": Types.STATUT_VULNERABLE | Types.STATUT_MAUDIT | Types.STATUT_SIPHONNE,
	},
	{"pos": Vector2(-450.0, 110.0), "famille": 7, "statut": Types.STATUT_GELE},
	{"pos": Vector2(-380.0, -130.0), "famille": 11, "statut": 0},
	{"pos": Vector2(-120.0, 250.0), "famille": 15, "statut": 0},
	{"pos": Vector2(120.0, -260.0), "famille": 19, "statut": Types.STATUT_VULNERABLE},
	{"pos": Vector2(300.0, 260.0), "famille": 23, "statut": 0},
]

## Montre le mode réduit ; posé avant l'entrée dans l'arbre, ou par `-- --mouvement-reduit`.
var mouvement_reduit: bool = false
## Charge maximale : posée avant l'entrée dans l'arbre, ou par `-- --charge`.
var charge: bool = false
var arene: Arene2D = null
## Plus grand nombre d'effets vivants vu depuis le début.
var pic_vivants: int = 0
## Vues envoyées à l'arène depuis le début.
var vues_envoyees: int = 0

var _donnees: Donnees = null
var _source: SourceVue = SourceVue.new()
var _temps: float = 0.0
var _prochaine_vue: float = 0.0
var _tick: int = 0
var _phase: float = 0.0
var _prochain_tournant: float = 0.0
var _repousse_fait: Array[bool] = [false, false]
var _explose_fait: Array[bool] = [false, false]
var _prochaine_charge: float = 0.0
var _armes_charge: Array[int] = []


func _ready() -> void:
	seed(GRAINE)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	mouvement_reduit = mouvement_reduit or args.has(OPTION_REDUIT)
	charge = charge or args.has(OPTION_CHARGE)
	_donnees = Donnees.charger()
	arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene2D
	arene.mouvement_reduit = mouvement_reduit
	add_child(arene)
	arene.lier(_source)
	arene.set_process(false)
	var camera: CameraArene = arene.camera()
	camera.cadrer(
		Rect2(0.0, 0.0, LARGEUR_ECRAN, HAUTEUR_ECRAN), Vector2(LARGEUR_ECRAN, HAUTEUR_ECRAN)
	)
	camera.zoomer(NIVEAU_CAMERA - camera.niveau)
	arene.reinitialiser()
	var catalogue: PackedStringArray = _donnees.ids_catalogue
	(arene.get_node("Effets") as Effets).catalogue = catalogue
	for index: int in catalogue.size():
		if _donnees.armes.has(catalogue[index]):
			_armes_charge.append(index)


func _exit_tree() -> void:
	if is_instance_valid(_source):
		_source.free()


func _process(delta: float) -> void:
	avancer(delta)


## Fait avancer la vitrine (et son arène) de `delta` secondes ; `_process` n'est que son appelant.
func avancer(delta: float) -> void:
	_temps += delta
	while _temps >= _prochaine_vue:
		_prochaine_vue += INTERVALLE_VUE
		_source.vue_arene_recue.emit(_vue(_prochaine_vue - INTERVALLE_VUE))
		vues_envoyees += 1
	arene._process(delta)
	pic_vivants = maxi(pic_vivants, (arene.get_node("Effets") as Effets).nombre_vivants())


## La vue à l'instant `t` de la vitrine.
func _vue(t: float) -> VueArene:
	var vue := VueArene.new()
	_tick += 1
	vue.tick = _tick
	var cycle: float = fmod(t, PERIODE)
	_poser_ennemis(vue)
	_poser_allies(vue, t)
	_poser_zones(vue, t)
	_poser_bombes(vue, cycle)
	_evenements(vue, t, cycle)
	if charge:
		_evenements_charge(vue, t)
	return vue


func _poser_ennemis(vue: VueArene) -> void:
	for k: int in ENNEMIS.size():
		vue.ennemis_id.append(k + 1)
		vue.ennemis_pos.append((ENNEMIS[k]["pos"] as Vector2) * ECARTEMENT)
		vue.ennemis_famille.append(int(ENNEMIS[k]["famille"]))
		vue.ennemis_pv.append(255)
		vue.ennemis_statuts.append(int(ENNEMIS[k]["statut"]))


func _poser_allies(vue: VueArene, t: float) -> void:
	var nombre: int = VueArene.ALLIES_MAX if charge else NB_ALLIES
	for k: int in nombre:
		var anneau: int = k / NB_ALLIES
		var angle: float = TAU * float(k % NB_ALLIES) / float(NB_ALLIES) + VITESSE_ALLIES * t
		var rayon: float = RAYON_ALLIES + 60.0 * float(anneau)
		(
			vue
			. allies
			. append(
				{
					"id": k + 1,
					"pos": Vector2.from_angle(angle) * rayon * ECARTEMENT,
					"unite": k % maxi(_donnees.ids_unites.size(), 1),
				}
			)
		)


func _poser_zones(vue: VueArene, t: float) -> void:
	var nombre: int = VueArene.ZONES_MAX if charge else ZONES.size()
	for k: int in nombre:
		var zone: Dictionary = ZONES[k % ZONES.size()]
		var decalage: float = float(zone["decalage"]) + float(k / ZONES.size()) * 0.5
		var reste: float = PERIODE - fmod(t + decalage, PERIODE)
		var pos: Vector2 = (zone["pos"] as Vector2) * ECARTEMENT
		pos += Vector2(40.0, 30.0) * float(k / ZONES.size())
		vue.zones.append({"pos": pos, "rayon": zone["rayon"], "reste": reste, "arme": 0})


func _poser_bombes(vue: VueArene, cycle: float) -> void:
	var nombre: int = VueArene.BOMBES_MAX if charge else BOMBES.size()
	for k: int in nombre:
		var bombe: Dictionary = BOMBES[k % BOMBES.size()]
		var ecoule: float = cycle - float(bombe["debut"]) - 0.4 * float(k / BOMBES.size())
		if ecoule < 0.0 or ecoule >= DELAI_BOMBE:
			continue
		var pos: Vector2 = (bombe["pos"] as Vector2) * ECARTEMENT
		pos += Vector2(-30.0, 40.0) * float(k / BOMBES.size())
		vue.bombes.append({"pos": pos, "rayon": bombe["rayon"], "reste": DELAI_BOMBE - ecoule})


func _evenements(vue: VueArene, t: float, cycle: float) -> void:
	var genre_tournant: int = VueArene.GENRES_ARME.find("tournant")
	while t >= _prochain_tournant:
		_prochain_tournant += PAS_TOURNANT
		for k: int in BRANCHES:
			var angle: float = deg_to_rad(_phase + 360.0 * float(k) / float(BRANCHES))
			(
				vue
				. evenements
				. append(
					{
						"k": "tir",
						"t": _tick,
						"de": Vector2.ZERO,
						"vers": Vector2.from_angle(angle) * PORTEE_TOURNANT * ECARTEMENT,
						"type_degats": Types.TypeDegats.TRANCHANT,
						"rayon": LARGEUR_TOURNANT,
						"genre": genre_tournant,
					}
				)
			)
		_phase = fmod(_phase + ECART_PHASE, 360.0)
	for k: int in INSTANTS_REPOUSSEMENT.size():
		var arrive: bool = cycle >= INSTANTS_REPOUSSEMENT[k]
		if arrive and not _repousse_fait[k]:
			(
				vue
				. evenements
				. append(
					{
						"k": "impact",
						"t": _tick,
						"de": Vector2.ZERO,
						"vers": REPOUSSE * ECARTEMENT,
						"type_degats": Types.TypeDegats.PERCANT,
						"rayon": 0.0,
						"statut": VueArene.STATUTS_ARME.find("repoussement"),
					}
				)
			)
		_repousse_fait[k] = arrive
	for k: int in BOMBES.size():
		var bombe: Dictionary = BOMBES[k]
		var arrive: bool = cycle >= float(bombe["debut"]) + DELAI_BOMBE
		if arrive and not _explose_fait[k]:
			(
				vue
				. evenements
				. append(
					{
						"k": "impact",
						"t": _tick,
						"de": Vector2.ZERO,
						"vers": (bombe["pos"] as Vector2) * ECARTEMENT,
						"type_degats": Types.TypeDegats.SIEGE,
						"rayon": float(bombe["rayon"]),
						"genre": VueArene.GENRES_ARME.find("bombe"),
					}
				)
			)
		_explose_fait[k] = arrive
	for zone: Dictionary in ZONES:
		if fmod(t, 1.0) < INTERVALLE_VUE:
			(
				vue
				. evenements
				. append(
					{
						"k": "impact",
						"t": _tick,
						"de": Vector2.ZERO,
						"vers": (zone["pos"] as Vector2) * ECARTEMENT,
						"type_degats": Types.TypeDegats.MAGIQUE,
						"rayon": float(zone["rayon"]),
						"genre": VueArene.GENRES_ARME.find("zone_posee"),
					}
				)
			)


## `ARMES_CHARGE` armes du catalogue tirent à la fois, chacune un tir et son impact au hasard autour
## de la tour, avec le genre, le statut et le type de dégâts de sa fiche.
func _evenements_charge(vue: VueArene, t: float) -> void:
	if t < _prochaine_charge or _armes_charge.is_empty():
		return
	_prochaine_charge = t + PAS_CHARGE
	for k: int in ARMES_CHARGE:
		var index: int = _armes_charge[k % _armes_charge.size()]
		var fiche: Dictionary = _donnees.armes[_donnees.ids_catalogue[index]]
		var genre: int = VueArene.GENRES_ARME.find(String((fiche["effets"] as Array)[0]["kind"]))
		var statut: int = 0
		if not (fiche["statuts"] as Array).is_empty():
			statut = VueArene.STATUTS_ARME.find(String((fiche["statuts"] as Array)[0]["kind"]))
		var cible := Vector2(randf_range(-900.0, 900.0), randf_range(-500.0, 500.0))
		for nom: String in ["tir", "impact"]:
			(
				vue
				. evenements
				. append(
					{
						"k": nom,
						"t": _tick,
						"de": Vector2.ZERO,
						"vers": cible,
						"type_degats": int(fiche["type_degats"]),
						"rayon": 90.0 if nom == "impact" else 0.0,
						"genre": maxi(genre, 0),
						"statut": maxi(statut, 0),
						"arme": index,
					}
				)
			)
