class_name Arene2D
extends Node2D
## L'arène vue de dessus en pixel art : sol et décor du pack (`Decor`, dessinés sous tout le
## reste), cercle d'apparition, tour au centre avec le nom du joueur dessous, un sprite du pack
## Tiny Swords par ennemi (réserve de sprites par famille,
## triés en profondeur par Y), morts animées. Elle ne lit que `VueArene`, reçue par les signaux
## d'une `SourceVue`, et `Donnees`. Index d'entité : 0 à n-1 les familles, n le convoi, n+1 le boss
## (voir `Apparence`). Contrat : `donnees`, `lier`, `reinitialiser`, `afficher`,
## `afficher_courant`.

## Sprites gardés d'avance au-delà du besoin : évite de créer et libérer à chaque apparition.
## Fin du regard sur l'arène d'un autre (Espace) : l'Interface répond en appelant
## `SourceVue.regarder(-1)`.
signal arene_regardee_quittee
## Un impact de sa propre arène devient visible : le son d'impact part à cette image, pas à
## l'événement. Muet quand on regarde l'arène d'un autre joueur (seuls ses propres sons jouent).
signal son_impact_demande(type_degats: int)
## Une mort devient visible (crâne ou explosion) : le son de mort part à cette image, pas à
## l'événement. Muet, lui aussi, quand on regarde l'arène d'un autre joueur.
signal son_mort_demande

const RESERVE_POOL: int = 16
## Morts affichées en même temps au plus (crânes, ennemis qui attendent leur impact).
const PLAFOND_MORTS: int = CranesArene.PLAFOND
## Au-delà du bord d'arrêt, un ennemi n'est plus « au contact » : marge de lissage (unités).
const MARGE_CONTACT: float = 10.0
const POINTS_CERCLE: int = 96
const LARGEUR_CERCLE: float = 4.0
## Écart maximal (unités) entre une mort et la dernière position connue de l'ennemi mort : il a
## pu avancer entre deux vues.
const PORTEE_MORT: float = 40.0
## Un ennemi tué reste affiché jusqu'à l'impact visible qui le vise, pas plus de 20 images : le
## coup doit paraître le tuer, et un impact jamais joué ne doit pas le garder à l'écran.
const DELAI_MORT_MAX: float = 20.0 / 60.0
## Marge des sommes de `delta` : vingt images à 60 i/s font vingt images, pas vingt et une.
const MARGE_DELAI: float = 0.000001

## Opacité d'un ennemi qui recouvre la tour : elle reste visible dessous.
const ALPHA_RECOUVRE: float = 0.4

## Ordre des animations dans les tableaux à plat.
const REPOS: int = 0
const COURSE: int = 1
const ATTAQUE: int = 2
const ATTAQUE_BAS: int = 3
const ATTAQUE_HAUT: int = 4
const NB_ANIMATIONS: int = 5
const NOMS_ANIMATIONS: Array[String] = ["repos", "course", "attaque", "attaque_bas", "attaque_haut"]

## Demi-largeur visible de la tour dans sa feuille, en pixels de feuille.
static var tour_demi_largeur: float = float(Assets.section("tour").get("demi_largeur", 0.0))

## Injectable avant l'entrée dans l'arbre (tests) ; sinon chargé depuis `data/`.
var donnees: Donnees = null
## Mouvement réduit (D21) : ni gel d'impact, ni recul, ni rebond d'échelle, ni étincelles ; l'éclat
## bref et le flash de la cible restent. Peut changer en cours de partie.
var mouvement_reduit: bool = false:
	set(valeur):
		mouvement_reduit = valeur
		_reactions.mouvement_reduit = valeur
		if _effets != null:
			_effets.mouvement_reduit = valeur
		if _poses != null:
			_poses.mouvement_reduit = valeur
		if _sol != null:
			_sol.mouvement_reduit = valeur
		if _cranes != null:
			_cranes.mouvement_reduit = valeur
		_figer_flammes()

var _interpolation := Interpolation.new()
var _horloge: float = 0.0
var _dernier_tick: int = -1
var _source: SourceVue = null
var _construite: bool = false
var _ennemis: Node2D = null
var _tirs_ennemis: TirsEnnemis = null
var _sol: Decor = null
## Graine de la partie, mêlée au numéro du joueur : le décor de chaque arène est le sien et ne
## bouge pas pendant la partie.
var _graine_partie: int = 0
var _graine_decor: int = 0
var _tour: Sprite2D = null
var _superpositions: SuperpositionsTour = null
## Index (dans `Donnees.ids_skins`) du skin de la tour affichée et de celui du joueur local, gardé
## pendant le regard sur l'arène d'un autre.
var _skin: int = 0
var _skin_propre: int = 0
var _noms: NomTour = null
var _camera: CameraArene = null
var _zoom_vu: float = 0.0
var _numero: int = 1
## Par entité : sprites (`Array[Sprite2D]`), nombre affiché, et ce qu'il faut pour les animer.
var _pools: Array = []
var _visibles: PackedInt32Array = PackedInt32Array()
var _entrees: Array[Dictionary] = []
var _textures: Array[Texture2D] = []
var _colonnes: PackedInt32Array = PackedInt32Array()
var _lignes: PackedInt32Array = PackedInt32Array()
var _images: PackedInt32Array = PackedInt32Array()
var _arrets: PackedFloat32Array = PackedFloat32Array()
var _a_distance: PackedByteArray = PackedByteArray()
var _combat: PackedByteArray = PackedByteArray()
var _explosives: PackedByteArray = PackedByteArray()
var _regions: Array[PackedFloat32Array] = []
var _decalages: Array[PackedFloat32Array] = []
var _couvre_x: PackedFloat32Array = PackedFloat32Array()
var _couvre_h: PackedFloat32Array = PackedFloat32Array()
var _cranes: CranesArene = null
## Les ennemis tués dont l'impact n'est pas encore visible : `{sprite, ou, id, debut}`.
var _mourants: Array[Dictionary] = []
var _effets: Effets = null
## Les alliés invoqués, posés dans le nœud des ennemis pour se trier en profondeur avec eux.
var _allies := Allies2D.new()
## Marqueurs des statuts du lot 9, au-dessus des ennemis.
var _marques: MarquesStatut = null
## Zones posées et bombes de la vue, au sol sous les ennemis.
var _poses: ZonesBombes2D = null
## Ennemis touchés : flash et recul, par id d'ennemi (purement visuel).
var _reactions: ReactionsCoups = ReactionsCoups.new()
## L'échantillon affiché cette image (positions lissées) : une seule fois par image, partagé entre
## l'affichage des sprites et le choix des ennemis qu'un impact fait réagir.
var _echantillon_affiche: Dictionary = {}
var _barres: BarresArene = null
## Teinte posée sur chaque ennemi affiché, par famille puis par rang dans la famille.
var _teintes: Array[PackedColorArray] = []
## Joueur dont on regarde l'arène (-1 : la sienne) ; la couleur de tour et le nom du joueur local
## sont gardés pour y revenir.
var _regarde: int = -1
var _numero_propre: int = 1
var _nom_propre: String = ""
## Vue reçue avant la courante : on y retrouve la famille d'un ennemi qui vient de mourir.
var _vue_precedente: VueArene = null


## Un sprite d'ennemi : retient l'image et le sens affichés pour ne recalculer sa région que
## lorsqu'ils changent.
class Lutin:
	extends Sprite2D
	var image: int = -1
	var miroir: bool = false


## Les sprites sont nets : plus proche voisin sur toute l'arène.
func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_assurer_construite()


## Construction paresseuse : une arène doit répondre dès qu'on lui parle, `_ready` ou non.
func _assurer_construite() -> void:
	if _construite:
		return
	_construite = true
	if donnees == null:
		donnees = Donnees.charger()
	_camera = get_node_or_null("Camera") as CameraArene
	_construire_sol()
	_construire_cercle()
	_poses = ZonesBombes2D.new()
	_poses.name = "Poses"
	_poses.donnees = donnees
	_poses.mouvement_reduit = mouvement_reduit
	add_child(_poses)
	_ennemis = Node2D.new()
	_ennemis.name = "Ennemis"
	_ennemis.y_sort_enabled = true
	add_child(_ennemis)
	_tirs_ennemis = TirsEnnemis.new()
	add_child(_tirs_ennemis)
	_allies.parent = _ennemis
	_allies.donnees = donnees
	_effets = Effets.new()
	_effets.name = "Effets"
	_effets.parent_sol = _ennemis
	_effets.mouvement_reduit = mouvement_reduit
	if donnees != null:
		_effets.catalogue = donnees.ids_catalogue
	_effets.impact_visible.connect(_sur_impact_visible)
	_effets.impact_visible_de_type.connect(_sur_impact_de_type)
	add_child(_effets)
	_marques = MarquesStatut.new()
	_marques.name = "Marques"
	add_child(_marques)
	_construire_tour()
	_barres = BarresArene.new()
	_barres.name = "Barres"
	add_child(_barres)
	_noms = NomTour.new()
	add_child(_noms)
	if donnees != null:
		_preparer_entites()
		_tirs_ennemis.configurer(donnees)
		_barres.indice_boss = _pools.size() - 1
	_cranes = CranesArene.new(_ennemis)
	_cranes.mouvement_reduit = mouvement_reduit


## S'abonne aux vues reçues. Un nouveau `lier` remplace le précédent.
func lier(source: SourceVue) -> void:
	_assurer_construite()
	if _source != null and _source.vue_arene_recue.is_connected(_sur_vue):
		_source.vue_arene_recue.disconnect(_sur_vue)
	if _source != null and _source.vue_regardee_recue.is_connected(_sur_vue_regardee):
		_source.vue_regardee_recue.disconnect(_sur_vue_regardee)
	_source = source
	if _source != null:
		_source.vue_arene_recue.connect(_sur_vue)
		_source.vue_regardee_recue.connect(_sur_vue_regardee)


## Oublie les vues reçues : à appeler quand une autre partie commence (les ticks repartent de 0).
func reinitialiser() -> void:
	_assurer_construite()
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_vue_precedente = null
	_effets.vider()
	_vider_mourants()
	_allies.vider()
	_poses.vider()
	_marques.debut()
	_marques.fin()
	_reactions.reinitialiser()
	_echantillon_affiche = {}
	_barres.reinitialiser()
	_superpositions.reinitialiser()
	_afficher_echantillon()


## Affiche `vue` telle quelle, sans lissage ni délai, à l'instant `temps_rendu`.
func afficher(vue: VueArene, temps_rendu: float) -> void:
	_assurer_construite()
	if vue == null:
		return
	_horloge = temps_rendu
	_echantillon_affiche = {}
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_recevoir(vue, temps_rendu)
	_superpositions.avancer(0.0, mouvement_reduit)
	_afficher_echantillon()


## Rend l'état lissé à l'instant `temps_rendu` (l'horloge interne en jeu).
func afficher_courant(temps_rendu: float) -> void:
	_assurer_construite()
	_horloge = temps_rendu
	_echantillon_affiche = {}
	_afficher_echantillon()


## Joueur local : sa couleur de tour (1 à 8) et son nom écrit sous la tour. Un nom vide n'écrit
## rien. Pendant le regard sur l'arène d'un autre, ils sont gardés pour le retour.
func definir_joueur(numero: int, nom: String) -> void:
	_assurer_construite()
	_numero_propre = numero
	_nom_propre = nom
	if _regarde < 0:
		_poser_joueur(numero, nom)


## Le skin de tour du joueur local (index du catalogue de `data/skins_tour.json`, lu dans la vue
## globale ou au profil) ; un index inconnu se dessine avec le skin par défaut. Pendant le regard
## sur l'arène d'un autre, il est gardé pour le retour.
func definir_skin(index: int) -> void:
	_assurer_construite()
	_skin_propre = index
	if _regarde < 0:
		_skin = index
		_poser_skin()


func _poser_skin() -> void:
	var ids := donnees.ids_skins()
	var id := ids[_skin] if _skin >= 0 and _skin < ids.size() else "defaut"
	_superpositions.definir_skin(id, _numero)


func _poser_joueur(numero: int, nom: String) -> void:
	if numero != _numero or _tour.texture == null:
		_numero = numero
		_poser_le_decor()
	_poser_skin()
	_noms.ecrire(numero, nom)


## Affiche l'arène du joueur `id_joueur` (sa tour, son nom, ses vues `vue_regardee_recue`) à la
## place de la sienne, tant qu'on ne revient pas ; `-1` revient à sa propre arène. Les vues
## propres sont ignorées pendant le regard.
func montrer_arene(id_joueur: int, nom: String, numero: int, skin: int = 0) -> void:
	_assurer_construite()
	var voulu: int = id_joueur if id_joueur >= 0 else -1
	if voulu == _regarde:
		return
	_regarde = voulu
	_vider_les_vues()
	_skin = skin if _regarde >= 0 else _skin_propre
	if _regarde >= 0:
		_poser_joueur(numero, nom)
	else:
		_poser_joueur(_numero_propre, _nom_propre)


func regarde_un_autre() -> bool:
	return _regarde >= 0


## Le dessin de l'apparence de la tour (lecture seule, pour les tests).
func superpositions() -> SuperpositionsTour:
	_assurer_construite()
	return _superpositions


func camera() -> CameraArene:
	_assurer_construite()
	return _camera


## Espace : la vue revient sur la tour ; si on regarde l'arène d'un autre, on la quitte aussi.
func recentrer_ou_quitter() -> void:
	_assurer_construite()
	if _camera != null:
		_camera.recentrer()
	if _regarde >= 0:
		montrer_arene(-1, "", 0)
		arene_regardee_quittee.emit()


## Les ticks, les positions et les effets d'une arène n'ont rien à voir avec ceux d'une autre.
func _vider_les_vues() -> void:
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_vue_precedente = null
	_effets.vider()
	_vider_mourants()
	_reactions.reinitialiser()
	_echantillon_affiche = {}
	_barres.reinitialiser()
	_superpositions.reinitialiser()
	_afficher_echantillon()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_recentrer") and not event.is_echo():
		recentrer_ou_quitter()
		get_viewport().set_input_as_handled()


## Graine de la partie : change la disposition du décor de tous les joueurs, pas leur différence.
func definir_graine(graine_partie: int) -> void:
	_assurer_construite()
	_graine_partie = graine_partie
	_poser_le_decor()


## La disposition du terrain et du décor actuellement dessinée.
func plan_decor() -> PlanDecor:
	_assurer_construite()
	return _sol.plan


func nombre_instances_visibles(famille: int) -> int:
	_assurer_construite()
	if famille < 0 or famille >= _visibles.size():
		return 0
	return _visibles[famille]


## Position (pixels du monde) du i-ème sprite affiché de la famille, pour les tests et captures.
func position_instance(famille: int, i: int) -> Vector2:
	var sprite := sprite_instance(famille, i)
	return sprite.position if sprite != null else Vector2.ZERO


## Image (ligne × colonnes + colonne dans la feuille) affichée par le i-ème sprite de la famille.
func image_instance(famille: int, i: int) -> int:
	var lutin := sprite_instance(famille, i) as Lutin
	return lutin.image if lutin != null else -1


func ligne_instance(famille: int, i: int) -> int:
	return image_instance(famille, i) / _colonnes[famille]


func colonne_instance(famille: int, i: int) -> int:
	return image_instance(famille, i) % _colonnes[famille]


func sprite_instance(famille: int, i: int) -> Sprite2D:
	_assurer_construite()
	if famille < 0 or famille >= _pools.size() or i < 0 or i >= nombre_instances_visibles(famille):
		return null
	var pool: Array[Sprite2D] = _pools[famille]
	return pool[i]


func tirs_ennemis() -> TirsEnnemis:
	return _tirs_ennemis


func nombre_morts_visibles() -> int:
	return _cranes.nombre_visibles() if _cranes != null else 0


func sprite_mort(i: int) -> Sprite2D:
	return _cranes.sprite(i) if _cranes != null else null


## La teinte posée sur le rang `i` de la famille `famille` à la dernière image : `Color.WHITE` sans
## statut, ou pour un ennemi qui n'existe pas.
func teinte_instance(famille: int, i: int) -> Color:
	_assurer_construite()
	if (
		famille < 0
		or famille >= _teintes.size()
		or i < 0
		or i >= nombre_instances_visibles(famille)
	):
		return Color.WHITE
	var teintes: PackedColorArray = _teintes[famille]
	return teintes[i] if i < teintes.size() else Color.WHITE


## Les zones posées et les bombes affichées (lecture, pour les tests et les vitrines).
func zones_bombes() -> ZonesBombes2D:
	_assurer_construite()
	return _poses


## Les marqueurs des statuts du lot 9 (lecture, pour les tests et les vitrines).
func marques_statut() -> MarquesStatut:
	_assurer_construite()
	return _marques


func nombre_allies_visibles() -> int:
	_assurer_construite()
	return _allies.nombre_visibles()


## Le sprite de l'allié de rang `i` (`null` s'il n'existe pas).
func sprite_allie(i: int) -> Sprite2D:
	var a: Allies2D.Allie = _allies.allie(i)
	return a.sprite if a != null else null


## L'anneau au sol de l'allié de rang `i` : les ennemis n'en ont pas.
func anneau_allie(i: int) -> Node2D:
	var a: Allies2D.Allie = _allies.allie(i)
	return a.anneau if a != null else null


## La teinte posée sur l'allié de rang `i` (`Color.WHITE` s'il n'existe pas).
func teinte_allie(i: int) -> Color:
	var a: Allies2D.Allie = _allies.allie(i)
	return a.sprite.modulate if a != null else Color.WHITE


## Où l'allié de rang `i` est posé dans le monde, en pixels (`Vector2.ZERO` s'il n'existe pas).
func position_allie(i: int) -> Vector2:
	var a: Allies2D.Allie = _allies.allie(i)
	return a.position if a != null else Vector2.ZERO


## La teinte d'un octet de statuts (`Types.STATUT_*`) : voir `TeintesStatut`.
static func teinte_statut(octet: int) -> Color:
	return TeintesStatut.teinte(octet)


func _process(delta: float) -> void:
	_assurer_construite()
	_horloge += delta
	_echantillon_affiche = {}
	_effets.avancer(delta)
	_poses.avancer(delta)
	_superpositions.avancer(delta, mouvement_reduit)
	_avancer_mourants()
	_reactions.avancer(delta)
	_sol.avancer(delta)
	_afficher_echantillon()
	_ajuster_nom()


func _sur_vue(vue: VueArene) -> void:
	if _regarde >= 0:
		return
	_recevoir(vue, _horloge)


func _sur_vue_regardee(id_joueur: int, vue: VueArene) -> void:
	if _regarde < 0 or id_joueur != _regarde:
		return
	_recevoir(vue, _horloge)


## Une vue plus ancienne que la dernière reçue (réseau non fiable) est ignorée, morts comprises.
func _recevoir(vue: VueArene, temps: float) -> void:
	if vue == null or vue.tick <= _dernier_tick:
		return
	_dernier_tick = vue.tick
	_interpolation.pousser(vue, temps)
	_superpositions.viser(vue)
	_echantillon_affiche = {}
	var explosifs: Array[Vector2] = []
	var tues: Array[Vector2] = []
	var cherche: bool = false
	for evenement: Dictionary in vue.evenements:
		match String(evenement.get("k", "")):
			"mort":
				if not cherche:
					cherche = true
					explosifs = _explosifs_disparus(vue)
				var ou: Vector2 = evenement.get("de", Vector2.ZERO)
				var rang: int = _plus_proche(explosifs, ou)
				if rang >= 0:
					explosifs.remove_at(rang)
					if _effets.exploser(ou):
						_signaler_mort()
				else:
					tues.append(ou)
			"tir", "impact", "absorption":
				_effets.ajouter(evenement)
	# Après la boucle : l'impact qui tue peut suivre l'événement de mort dans la même vue.
	for ou: Vector2 in tues:
		_annoncer_mort(ou, vue)
	# Après les événements : le tir qui pose une bombe dit si son projectile est encore en vol.
	_poses.afficher(vue, _effets)
	_barres.afficher(vue)
	_vue_precedente = vue


## Positions, dans la vue précédente, des tonneaux et des artificiers absents de `vue` : ceux
## qui viennent de mourir (l'événement de mort ne dit pas de quelle famille).
func _explosifs_disparus(vue: VueArene) -> Array[Vector2]:
	var liste: Array[Vector2] = []
	var avant: VueArene = _vue_precedente
	if avant == null:
		return liste
	var presents: Dictionary = {}
	for id: int in vue.ennemis_id:
		presents[id] = true
	var total: int = mini(
		avant.ennemis_id.size(), mini(avant.ennemis_pos.size(), avant.ennemis_famille.size())
	)
	for i: int in total:
		var f: int = avant.ennemis_famille[i]
		if f < _explosives.size() and _explosives[f] != 0 and not presents.has(avant.ennemis_id[i]):
			liste.append(avant.ennemis_pos[i])
	return liste


## Rang de la position la plus proche de `ou` à moins de `PORTEE_MORT` unités, -1 s'il n'y en a pas.
func _plus_proche(positions: Array[Vector2], ou: Vector2) -> int:
	var meilleur: int = -1
	var distance: float = PORTEE_MORT
	for i: int in positions.size():
		var d: float = positions[i].distance_to(ou)
		if d <= distance:
			distance = d
			meilleur = i
	return meilleur


## Un impact devient visible : les ennemis affichés à cet endroit réagissent (flash et recul).
func _sur_impact_visible(ou: Vector2, rayon: float, fort: bool) -> void:
	var echantillon: Dictionary = _echantillon_courant()
	var ids: PackedInt32Array = echantillon["ids"]
	var positions: PackedVector2Array = echantillon["pos"]
	if not _mourants.is_empty():
		# Les ennemis retenus en attendant ce coup passent les premiers : c'est lui qui les tue.
		var avec_morts: PackedInt32Array = PackedInt32Array()
		var positions_avec: PackedVector2Array = PackedVector2Array()
		for mourant: Dictionary in _mourants:
			avec_morts.append(int(mourant["id"]))
			positions_avec.append(mourant["p"])
		avec_morts.append_array(ids)
		positions_avec.append_array(positions)
		ids = avec_morts
		positions = positions_avec
	_reactions.toucher(ou, rayon, ids, positions, Vector2.ZERO, fort)


func _sur_impact_de_type(type_degats: int) -> void:
	if _regarde < 0:
		son_impact_demande.emit(type_degats)


func _echantillon_courant() -> Dictionary:
	if _echantillon_affiche.is_empty():
		_echantillon_affiche = _interpolation.echantillon(_horloge)
	return _echantillon_affiche


func _afficher_echantillon() -> void:
	var echantillon: Dictionary = _echantillon_courant()
	var vue: VueArene = echantillon["vue"] as VueArene
	var positions: PackedVector2Array = echantillon["pos"]
	var ids: PackedInt32Array = echantillon["ids"]
	var nb: int = _pools.size()
	var decompte: PackedInt32Array = PackedInt32Array()
	decompte.resize(nb)
	var familles: PackedByteArray = PackedByteArray()
	if vue != null:
		familles = vue.ennemis_famille
	var statuts: PackedByteArray = vue.ennemis_statuts if vue != null else PackedByteArray()
	var total: int = mini(familles.size(), mini(positions.size(), ids.size()))
	for i: int in total:
		var f: int = familles[i]
		if f < nb:
			decompte[f] += 1
	for f: int in nb:
		_dimensionner(f, decompte[f])
		decompte[f] = 0
	var image_courante: int = int(_horloge * Apparence.images_par_seconde)
	_marques.debut()
	for i: int in total:
		var f: int = familles[i]
		if f >= nb:
			continue
		var pool: Array[Sprite2D] = _pools[f]
		var sprite: Sprite2D = pool[decompte[f]]
		decompte[f] += 1
		var p: Vector2 = positions[i]
		sprite.position = _reactions.position_affichee(ids[i], Apparence.vers_pixels(p))
		var miroir: bool = p.x > 0.0
		var cle: int = f * NB_ANIMATIONS + _animation(f, p)
		var phase: int = _reactions.image_animation(ids[i], image_courante) + ids[i]
		var image: int = _lignes[cle] * _colonnes[f] + phase % _images[cle]
		var lutin: Lutin = sprite as Lutin
		if lutin.image != image or lutin.miroir != miroir:
			lutin.image = image
			lutin.miroir = miroir
			sprite.flip_h = miroir
			_poser_image(sprite, _regions[f], _decalages[f], image, miroir)
		var couvre: bool = p.y >= 0.0 and absf(p.x) < _couvre_x[f] and p.y < _couvre_h[f]
		var alpha: float = ALPHA_RECOUVRE if couvre else 1.0
		var octet: int = statuts[i] if i < statuts.size() else 0
		var teinte: Color = teinte_statut(octet)
		_marques.poser(sprite.position, _couvre_h[f] * Apparence.PX_PAR_UNITE, octet)
		var base: Color = _entrees[f]["couleur"]
		var eclat: float = _reactions.eclat(ids[i])
		var voulue := Color(
			base.r * teinte.r * eclat, base.g * teinte.g * eclat, base.b * teinte.b * eclat, alpha
		)
		if sprite.modulate != voulue:
			sprite.modulate = voulue
		var teintes: PackedColorArray = _teintes[f]
		var rang: int = decompte[f] - 1
		if teintes.size() <= rang:
			teintes.resize(rang + 1)
		teintes[rang] = teinte
		_teintes[f] = teintes
	_marques.fin()
	_tirs_ennemis.mettre_a_jour(_horloge, ids, positions, familles)
	_allies.afficher(_interpolation.echantillon_allies(_horloge), image_courante)
	_cranes.animer(_horloge)


## Quelle animation joue un ennemi à la position `p` : course tant qu'il avance, puis repos s'il
## tire de loin, attaque (selon l'angle vers la tour) s'il est au corps à corps. Le convoi ne
## combat pas : il marche toujours.
func _animation(f: int, p: Vector2) -> int:
	if _combat[f] == 0 or p.length() > _arrets[f] + MARGE_CONTACT:
		return COURSE
	if _a_distance[f] != 0:
		return REPOS
	if absf(p.y) > absf(p.x):
		return ATTAQUE_BAS if p.y < 0.0 else ATTAQUE_HAUT
	return ATTAQUE


## Pose la région de l'image sur le sprite et décale celui-ci pour que le pied reste sur sa
## position ; en miroir, le décalage horizontal change de sens.
func _poser_image(
	sprite: Sprite2D,
	regions: PackedFloat32Array,
	decalages: PackedFloat32Array,
	image: int,
	miroir: bool
) -> void:
	sprite.region_rect = Rect2(
		regions[image * 4], regions[image * 4 + 1], regions[image * 4 + 2], regions[image * 4 + 3]
	)
	var dx: float = decalages[image * 2]
	sprite.offset = Vector2(-dx if miroir else dx, decalages[image * 2 + 1])


## N'agrandit que si le nombre demandé dépasse ce qui existe ; masque le surplus et ne libère que
## ce qui dépasse la réserve (tout, quand il n'y a plus un seul ennemi de la famille).
func _dimensionner(famille: int, voulu: int) -> void:
	var pool: Array[Sprite2D] = _pools[famille]
	while pool.size() < voulu:
		pool.append(_creer_sprite(famille))
	var avant: int = _visibles[famille]
	for k: int in range(voulu, mini(avant, pool.size())):
		pool[k].visible = false
	for k: int in range(avant, voulu):
		pool[k].visible = true
	var garder: int = 0 if voulu == 0 else voulu + RESERVE_POOL
	while pool.size() > garder:
		var surplus: Sprite2D = pool.pop_back()
		_ennemis.remove_child(surplus)
		surplus.free()
	_visibles[famille] = voulu


func _creer_sprite(famille: int) -> Sprite2D:
	var e: Dictionary = _entrees[famille]
	var sprite := Lutin.new()
	sprite.texture = _textures[famille]
	sprite.region_enabled = true
	sprite.scale = Vector2.ONE * float(e["echelle"]) * Apparence.echelle_unites
	sprite.modulate = e["couleur"]
	if e.has("accessoire"):
		var a: Dictionary = e["accessoire"]
		var accessoire := Sprite2D.new()
		accessoire.name = "Accessoire"
		accessoire.texture = load(String(a["feuille"])) as Texture2D
		accessoire.position = a["decalage"]
		accessoire.scale = Vector2.ONE * float(a["echelle"])
		sprite.add_child(accessoire)
	if famille == _entrees.size() - 1:
		var flamme := Effets.creer_flamme() as FlammeBoss
		flamme.mouvement_reduit = mouvement_reduit
		sprite.add_child(flamme)
	_ennemis.add_child(sprite)
	return sprite


## Le crâne tout de suite, ou, si un impact en attente vise l'ennemi, l'ennemi lui-même, figé là où
## il était affiché, jusqu'à cet impact. Sans vue précédente on ne sait pas qui est mort.
func _annoncer_mort(ou: Vector2, vue: VueArene) -> void:
	var rang: int = -1
	if _effets.delai_avant_impact(ou) >= 0.0 and _mourants.size() < PLAFOND_MORTS:
		rang = _disparu_proche(vue, ou)
	if rang < 0:
		_montrer_crane(ou)
		return
	_mourants.append(_creer_mourant(_vue_precedente, rang, ou))


## Rang, dans la vue précédente, de l'ennemi disparu de `vue` le plus proche de `ou` (à moins de
## `PORTEE_MORT`, ni explosif ni déjà retenu), -1 s'il n'y en a pas.
func _disparu_proche(vue: VueArene, ou: Vector2) -> int:
	var avant: VueArene = _vue_precedente
	if avant == null:
		return -1
	var presents: Dictionary = {}
	for id: int in vue.ennemis_id:
		presents[id] = true
	for mourant: Dictionary in _mourants:
		presents[int(mourant["id"])] = true
	var total: int = mini(
		avant.ennemis_id.size(), mini(avant.ennemis_pos.size(), avant.ennemis_famille.size())
	)
	var meilleur: int = -1
	var distance: float = PORTEE_MORT
	for i: int in total:
		var f: int = avant.ennemis_famille[i]
		if presents.has(avant.ennemis_id[i]) or f >= _explosives.size() or _explosives[f] != 0:
			continue
		var d: float = avant.ennemis_pos[i].distance_to(ou)
		if d <= distance:
			distance = d
			meilleur = i
	return meilleur


## L'ennemi `rang` de `avant`, figé : même image, même teinte et même place que sur la dernière
## image affichée. Il n'est dans aucune liste d'`_afficher_echantillon` : aucun coup ne le touche.
func _creer_mourant(avant: VueArene, rang: int, ou: Vector2) -> Dictionary:
	var f: int = avant.ennemis_famille[rang]
	var id: int = avant.ennemis_id[rang]
	var p: Vector2 = avant.ennemis_pos[rang]
	var sprite := _creer_sprite(f) as Lutin
	sprite.position = _reactions.position_affichee(id, Apparence.vers_pixels(p))
	var miroir: bool = p.x > 0.0
	var cle: int = f * NB_ANIMATIONS + _animation(f, p)
	var image_courante: int = int(_horloge * Apparence.images_par_seconde)
	var phase: int = _reactions.image_animation(id, image_courante) + id
	sprite.image = _lignes[cle] * _colonnes[f] + phase % _images[cle]
	sprite.miroir = miroir
	sprite.flip_h = miroir
	_poser_image(sprite, _regions[f], _decalages[f], sprite.image, miroir)
	var statut: int = avant.ennemis_statuts[rang] if rang < avant.ennemis_statuts.size() else 0
	var teinte: Color = teinte_statut(statut)
	var base: Color = _entrees[f]["couleur"]
	var couleur := Color(base.r * teinte.r, base.g * teinte.g, base.b * teinte.b, 1.0)
	sprite.modulate = couleur
	return {
		"sprite": sprite,
		"ou": ou,
		"id": id,
		"debut": _horloge,
		"p": p,
		"couleur": couleur,
		"pixels": Apparence.vers_pixels(p),
	}


## Le crâne remplace l'ennemi retenu une fois son flash fini, qui suit l'impact qui le tue (il
## s'éclaircit et recule comme un ennemi touché), ou dès qu'aucun impact ne le vise ; en tout cas
## au bout de `DELAI_MORT_MAX` : le flash est alors coupé, il ne rallonge jamais la mort.
func _avancer_mourants() -> void:
	for i: int in range(_mourants.size() - 1, -1, -1):
		var mourant: Dictionary = _mourants[i]
		var ou: Vector2 = mourant["ou"]
		var id: int = int(mourant["id"])
		var attente: float = _horloge - float(mourant["debut"])
		var impact_vu: bool = _effets.delai_avant_impact(ou) < 0.0
		if attente >= DELAI_MORT_MAX - MARGE_DELAI or (impact_vu and _reactions.eclat(id) <= 1.0):
			_liberer_mourant(i)
			_montrer_crane(ou)
			continue
		var sprite: Sprite2D = mourant["sprite"]
		sprite.position = _reactions.position_affichee(id, mourant["pixels"])
		var couleur: Color = mourant["couleur"]
		var eclat: float = _reactions.eclat(id)
		sprite.modulate = Color(couleur.r * eclat, couleur.g * eclat, couleur.b * eclat, couleur.a)


## Le crâne en `ou`, et le son de mort avec lui s'il est montré.
func _montrer_crane(ou: Vector2) -> void:
	if _cranes.ajouter(ou, _horloge):
		_signaler_mort()


func _signaler_mort() -> void:
	if _regarde < 0:
		son_mort_demande.emit()


func _liberer_mourant(i: int) -> void:
	var sprite: Sprite2D = _mourants[i]["sprite"]
	_mourants.remove_at(i)
	_ennemis.remove_child(sprite)
	sprite.free()


## Une autre partie ou une autre arène : on n'attend plus aucun impact.
func _vider_mourants() -> void:
	for i: int in range(_mourants.size() - 1, -1, -1):
		_liberer_mourant(i)


## Nombre d'ennemis tués encore affichés en attendant l'impact qui les tue.
func nombre_mourants() -> int:
	return _mourants.size()


## Le sprite du `i`-ème ennemi tué en attente de son impact.
func sprite_mourant(i: int) -> Sprite2D:
	return _mourants[i]["sprite"] if i >= 0 and i < _mourants.size() else null


## Garde le nom à taille d'écran constante, quel que soit le zoom.
func _ajuster_nom() -> void:
	if _camera == null:
		return
	var grossissement: float = _camera.zoom.x
	if is_equal_approx(grossissement, _zoom_vu) or grossissement <= 0.0:
		return
	_zoom_vu = grossissement
	_barres.zoom = grossissement
	_noms.ajuster(grossissement)


func _preparer_entites() -> void:
	var ids: PackedStringArray = Apparence.ids_entites(donnees)
	var rayon_tour: float = float((donnees.partie["tour"] as Dictionary)["rayon"])
	var nb_familles: int = donnees.familles.size()
	for f: int in ids.size():
		var e: Dictionary = Apparence.entree(ids[f])
		if e.is_empty():
			push_error("Aucun sprite 2D pour l'entité « %s »" % ids[f])
			e = Apparence.entree(String(Apparence.ids_entites(donnees)[0]))
		_entrees.append(e)
		_textures.append(load(String(e["feuille"])) as Texture2D)
		_colonnes.append(int(e["colonnes"]))
		_lignes.append(0)
		_pools.append(Array([], TYPE_OBJECT, &"Sprite2D", null))
		_teintes.append(PackedColorArray())
		_visibles.append(0)
		var portee: float = 0.0
		if f < nb_familles:
			portee = float((donnees.familles[f] as Dictionary)["portee_attaque"])
		elif f == nb_familles + 1:
			portee = float(donnees.boss["portee_attaque"])
		var au_contact := Apparence.attaque_au_contact(donnees, f)
		# Le convoi (index n) n'a pas de classe : sa portée nulle le met au contact.
		_arrets.append(
			Apparence.distance_arret(
				portee, rayon_tour, -1 if f == nb_familles else int(au_contact)
			)
		)
		_explosives.append(1 if Effets.famille_explosive(ids[f]) else 0)
		_preparer_images(e)
		_a_distance.append(0 if au_contact or f == nb_familles else 1)
		# Le convoi (index n) ne combat pas.
		_combat.append(0 if f == nb_familles else 1)
	_lignes.resize(ids.size() * NB_ANIMATIONS)
	_images.resize(ids.size() * NB_ANIMATIONS)
	for f: int in ids.size():
		for a: int in NB_ANIMATIONS:
			var anim: Vector2i = _entrees[f][NOMS_ANIMATIONS[a]]
			_lignes[f * NB_ANIMATIONS + a] = anim.x
			_images[f * NB_ANIMATIONS + a] = anim.y


## Régions recadrées et décalages de chaque image d'une feuille, calculés une fois ; la couverture
## de la tour (largeur et hauteur de l'ennemi, en unités de jeu) vient de son image au repos.
func _preparer_images(e: Dictionary) -> void:
	var regions := PackedFloat32Array()
	var decalages := PackedFloat32Array()
	var cle: String = e["cle_boites"]
	var case_px: Vector2i = e["case"]
	var colonnes: int = e["colonnes"]
	for image: int in colonnes * int(e["lignes"]):
		var p: Dictionary = Apparence.placement(
			cle, image, case_px, colonnes, float(e["pieds"]), true
		)
		var r: Rect2 = p["region"]
		var d: Vector2 = p["offset"]
		regions.append_array([r.position.x, r.position.y, r.size.x, r.size.y])
		decalages.append_array([d.x, d.y])
	_regions.append(regions)
	_decalages.append(decalages)
	var repos: Vector2i = e["repos"]
	var boite: Rect2i = Recadrages.boite(cle, repos.x * colonnes)
	var echelle: float = float(e["echelle"]) * Apparence.echelle_unites
	var tour: float = tour_demi_largeur * Apparence.tour_echelle
	_couvre_x.append((tour + float(boite.size.x) * echelle * 0.5) / Apparence.PX_PAR_UNITE)
	_couvre_h.append(float(boite.size.y) * echelle / Apparence.PX_PAR_UNITE)


## La flamme de chaque sprite du boss suit le réglage de mouvement réduit.
func _figer_flammes() -> void:
	if _pools.is_empty():
		return
	for sprite: Sprite2D in _pools[_pools.size() - 1]:
		var flamme := sprite.get_node_or_null("Flamme") as FlammeBoss
		if flamme != null:
			flamme.mouvement_reduit = mouvement_reduit


func _construire_sol() -> void:
	_sol = Decor.new()
	_sol.mouvement_reduit = mouvement_reduit
	_sol.name = "Sol"
	add_child(_sol)
	_poser_le_decor()


## Redessine le décor seulement si la graine de l'arène a changé.
func _poser_le_decor() -> void:
	var graine: int = PlanDecor.graine_arene(_graine_partie, _numero)
	if _sol.plan != null and graine == _graine_decor:
		return
	_graine_decor = graine
	_sol.construire(PlanDecor.generer(graine))


func _construire_cercle() -> void:
	var cercle := Line2D.new()
	cercle.name = "CercleApparition"
	var rayon: float = Apparence.vers_pixels(Vector2(CameraArene.RAYON_APPARITION, 0.0)).x
	for i: int in POINTS_CERCLE:
		cercle.add_point(Vector2.from_angle(TAU * float(i) / float(POINTS_CERCLE)) * rayon)
	cercle.closed = true
	cercle.width = LARGEUR_CERCLE
	cercle.default_color = Apparence.COULEUR_CERCLE
	add_child(cercle)


func _construire_tour() -> void:
	_tour = Sprite2D.new()
	_tour.name = "Tour"
	var t: Dictionary = Apparence.tour(_numero)
	_tour.texture = load(String(t["fichier"])) as Texture2D
	_tour.scale = Vector2.ONE * Apparence.tour_echelle
	# Le pied de la tour (ombre du pack comprise) repose sur l'origine du monde.
	var hauteur: float = _tour.texture.get_height() if _tour.texture != null else 256.0
	_tour.offset = Vector2(0.0, hauteur * 0.5 - Apparence.tour_pieds)
	_ennemis.add_child(_tour)
	_superpositions = SuperpositionsTour.new()
	_superpositions.construire(_tour, donnees)
