class_name Arene2D
extends Node2D
## L'arène vue de dessus en pixel art : sol, cercle d'apparition, tour au centre avec le nom du
## joueur dessous, un sprite du pack Tiny Swords par ennemi (réserve de sprites par famille,
## triés en profondeur par Y), morts animées. Elle ne lit que `VueArene`, reçue par les signaux
## d'une `SourceVue`, et `Donnees`. Index d'entité : 0 à n-1 les familles, n le convoi, n+1 le boss
## (voir `Apparence2D`). Contrat identique à `Arene3D` : `donnees`, `lier`, `reinitialiser`,
## `afficher`, `afficher_courant`.

## Sprites gardés d'avance au-delà du besoin : évite de créer et libérer à chaque apparition.
const RESERVE_POOL: int = 16
## Morts affichées en même temps au plus ; les suivantes de la même vue sont ignorées.
const PLAFOND_MORTS: int = 64
## Au-delà du bord d'arrêt, un ennemi n'est plus « au contact » : marge de lissage (unités).
const MARGE_CONTACT: float = 10.0
## Étendue du sol, en pixels du monde de part et d'autre de la tour : couvre l'écran le plus large.
const RAYON_SOL: float = 6000.0
const POINTS_CERCLE: int = 96
const LARGEUR_CERCLE: float = 4.0
const VITESSE_VOL: float = 3.0
const NOM_LARGEUR: float = 260.0
const NOM_TAILLE: int = 18
const NOM_CONTOUR: int = 6
## Écart entre le pied de la tour et le haut du nom, en pixels d'écran.
const NOM_ECART: float = 8.0

## Ordre des animations dans les tableaux à plat.
const REPOS: int = 0
const COURSE: int = 1
const ATTAQUE: int = 2
const ATTAQUE_BAS: int = 3
const ATTAQUE_HAUT: int = 4
const NB_ANIMATIONS: int = 5
const NOMS_ANIMATIONS: Array[String] = ["repos", "course", "attaque", "attaque_bas", "attaque_haut"]

## Injectable avant l'entrée dans l'arbre (tests) ; sinon chargé depuis `data/`.
var donnees: Donnees = null

var _interpolation := Interpolation.new()
var _horloge: float = 0.0
var _dernier_tick: int = -1
var _source: SourceVue = null
var _construite: bool = false
var _ennemis: Node2D = null
var _tour: Sprite2D = null
var _noms: Node2D = null
var _nom: Label = null
var _camera: CameraArene2D = null
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
var _flottements: PackedFloat32Array = PackedFloat32Array()
var _morts: Array[Sprite2D] = []
var _morts_debut: PackedFloat64Array = PackedFloat64Array()
var _texture_mort: Texture2D = null


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
	_camera = get_node_or_null("Camera") as CameraArene2D
	_construire_sol()
	_construire_cercle()
	_ennemis = Node2D.new()
	_ennemis.name = "Ennemis"
	_ennemis.y_sort_enabled = true
	add_child(_ennemis)
	_construire_tour()
	_construire_nom()
	if donnees != null:
		_preparer_entites()
	_texture_mort = load(String(Apparence2D.MORT["feuille"])) as Texture2D


## S'abonne aux vues reçues. Un nouveau `lier` remplace le précédent.
func lier(source: SourceVue) -> void:
	_assurer_construite()
	if _source != null and _source.vue_arene_recue.is_connected(_sur_vue):
		_source.vue_arene_recue.disconnect(_sur_vue)
	_source = source
	if _source != null:
		_source.vue_arene_recue.connect(_sur_vue)


## Oublie les vues reçues : à appeler quand une autre partie commence (les ticks repartent de 0).
func reinitialiser() -> void:
	_assurer_construite()
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_afficher_echantillon()


## Affiche `vue` telle quelle, sans lissage ni délai, à l'instant `temps_rendu`.
func afficher(vue: VueArene, temps_rendu: float) -> void:
	_assurer_construite()
	if vue == null:
		return
	_horloge = temps_rendu
	_interpolation.reinitialiser()
	_dernier_tick = -1
	_recevoir(vue, temps_rendu)
	_afficher_echantillon()


## Rend l'état lissé à l'instant `temps_rendu` (l'horloge interne en jeu).
func afficher_courant(temps_rendu: float) -> void:
	_assurer_construite()
	_horloge = temps_rendu
	_afficher_echantillon()


## Joueur dont on regarde l'arène : sa couleur de tour (1 à 8) et son nom écrit sous la tour. Un
## nom vide n'écrit rien.
func definir_joueur(numero: int, nom: String) -> void:
	_assurer_construite()
	if numero != _numero or _tour.texture == null:
		_numero = numero
		var t: Dictionary = Apparence2D.tour(numero)
		_tour.texture = load(String(t["fichier"])) as Texture2D
		_tour.material = Apparence2D.materiau_tour(numero)
	_nom.text = "%d. %s" % [Apparence2D.numero_valide(numero), nom] if nom != "" else ""


func nombre_instances_visibles(famille: int) -> int:
	_assurer_construite()
	if famille < 0 or famille >= _visibles.size():
		return 0
	return _visibles[famille]


## Position (pixels du monde) du i-ème sprite affiché de la famille, pour les tests et captures.
func position_instance(famille: int, i: int) -> Vector2:
	var sprite := sprite_instance(famille, i)
	return sprite.position if sprite != null else Vector2.ZERO


func sprite_instance(famille: int, i: int) -> Sprite2D:
	_assurer_construite()
	if famille < 0 or famille >= _pools.size() or i < 0 or i >= nombre_instances_visibles(famille):
		return null
	var pool: Array[Sprite2D] = _pools[famille]
	return pool[i]


func nombre_morts_visibles() -> int:
	var n: int = 0
	for mort: Sprite2D in _morts:
		if mort.visible:
			n += 1
	return n


func sprite_mort(i: int) -> Sprite2D:
	return _morts[i] if i >= 0 and i < _morts.size() else null


func _process(delta: float) -> void:
	_assurer_construite()
	_horloge += delta
	_afficher_echantillon()
	_ajuster_nom()


func _sur_vue(vue: VueArene) -> void:
	_recevoir(vue, _horloge)


## Une vue plus ancienne que la dernière reçue (réseau non fiable) est ignorée, morts comprises.
func _recevoir(vue: VueArene, temps: float) -> void:
	if vue == null or vue.tick <= _dernier_tick:
		return
	_dernier_tick = vue.tick
	_interpolation.pousser(vue, temps)
	for evenement: Dictionary in vue.evenements:
		if String(evenement.get("k", "")) == "mort":
			var ou: Vector2 = evenement.get("de", Vector2.ZERO)
			_ajouter_mort(ou)


func _afficher_echantillon() -> void:
	var echantillon: Dictionary = _interpolation.echantillon(_horloge + Interpolation.DELAI_S)
	var vue: VueArene = echantillon["vue"] as VueArene
	var positions: PackedVector2Array = echantillon["pos"]
	var ids: PackedInt32Array = echantillon["ids"]
	var nb: int = _pools.size()
	var decompte: PackedInt32Array = PackedInt32Array()
	decompte.resize(nb)
	var familles: PackedByteArray = PackedByteArray()
	if vue != null:
		familles = vue.ennemis_famille
	var total: int = mini(familles.size(), mini(positions.size(), ids.size()))
	for i: int in total:
		var f: int = familles[i]
		if f < nb:
			decompte[f] += 1
	for f: int in nb:
		_dimensionner(f, decompte[f])
		decompte[f] = 0
	var image_courante: int = int(_horloge * Apparence2D.IMAGES_PAR_SECONDE)
	for i: int in total:
		var f: int = familles[i]
		if f >= nb:
			continue
		var pool: Array[Sprite2D] = _pools[f]
		var sprite: Sprite2D = pool[decompte[f]]
		decompte[f] += 1
		var p: Vector2 = positions[i]
		sprite.position = Apparence2D.vers_pixels(p)
		sprite.flip_h = p.x > 0.0
		var cle: int = f * NB_ANIMATIONS + _animation(f, p)
		sprite.frame = _lignes[cle] * _colonnes[f] + (image_courante + ids[i]) % _images[cle]
		if _flottements[f] > 0.0:
			_faire_flotter(sprite, f, ids[i])
	_animer_morts()


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


## Le volant monte et descend doucement ; chaque volant a sa phase.
func _faire_flotter(sprite: Sprite2D, f: int, id: int) -> void:
	var case_px: Vector2i = _entrees[f]["case"]
	var base: float = float(case_px.y) * 0.5 - float(_entrees[f]["pieds"])
	sprite.offset.y = base - sin(_horloge * VITESSE_VOL + float(id)) * _flottements[f]


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
	var case_px: Vector2i = e["case"]
	var sprite := Sprite2D.new()
	sprite.texture = _textures[famille]
	sprite.hframes = _colonnes[famille]
	sprite.vframes = int(e["lignes"])
	sprite.offset = Vector2(0.0, float(case_px.y) * 0.5 - float(e["pieds"]))
	sprite.scale = Vector2.ONE * float(e["echelle"])
	sprite.modulate = e["couleur"]
	if e.has("accessoire"):
		var a: Dictionary = e["accessoire"]
		var accessoire := Sprite2D.new()
		accessoire.name = "Accessoire"
		accessoire.texture = load(String(a["feuille"])) as Texture2D
		accessoire.position = a["decalage"]
		accessoire.scale = Vector2.ONE * float(a["echelle"])
		sprite.add_child(accessoire)
	_ennemis.add_child(sprite)
	return sprite


func _ajouter_mort(ou: Vector2) -> void:
	var sprite: Sprite2D = null
	for mort: Sprite2D in _morts:
		if not mort.visible:
			sprite = mort
			break
	if sprite == null:
		if _morts.size() >= PLAFOND_MORTS:
			return
		sprite = _creer_mort()
		_morts.append(sprite)
		_morts_debut.append(0.0)
	var index: int = _morts.find(sprite)
	_morts_debut[index] = _horloge
	sprite.position = Apparence2D.vers_pixels(ou)
	sprite.frame = 0
	sprite.visible = true


func _creer_mort() -> Sprite2D:
	var m: Dictionary = Apparence2D.MORT
	var case_px: Vector2i = m["case"]
	var sprite := Sprite2D.new()
	sprite.name = "Mort"
	sprite.texture = _texture_mort
	sprite.hframes = int(m["colonnes"])
	sprite.vframes = int(m["lignes"])
	sprite.offset = Vector2(0.0, float(case_px.y) * 0.5 - float(m["pieds"]))
	sprite.scale = Vector2.ONE * float(m["echelle"])
	sprite.visible = false
	_ennemis.add_child(sprite)
	return sprite


func _animer_morts() -> void:
	var images: int = Apparence2D.MORT["images"]
	var par_seconde: float = Apparence2D.MORT["images_par_seconde"]
	for i: int in _morts.size():
		var mort: Sprite2D = _morts[i]
		if not mort.visible:
			continue
		var image: int = int((_horloge - _morts_debut[i]) * par_seconde)
		if image >= images or image < 0:
			mort.visible = false
		else:
			mort.frame = image


## Garde le nom à taille d'écran constante, quel que soit le zoom.
func _ajuster_nom() -> void:
	if _camera == null:
		return
	var grossissement: float = _camera.zoom.x
	if is_equal_approx(grossissement, _zoom_vu) or grossissement <= 0.0:
		return
	_zoom_vu = grossissement
	_noms.scale = Vector2.ONE / grossissement
	_noms.position = Vector2(0.0, NOM_ECART / grossissement)


func _preparer_entites() -> void:
	var ids: PackedStringArray = Apparence2D.ids_entites(donnees)
	var rayon_tour: float = float((donnees.partie["tour"] as Dictionary)["rayon"])
	var nb_familles: int = donnees.familles.size()
	for f: int in ids.size():
		var e: Dictionary = Apparence2D.entree(ids[f])
		if e.is_empty():
			push_error("Aucun sprite 2D pour l'entité « %s »" % ids[f])
			e = Apparence2D.entree(String(Apparence2D.ids_entites(donnees)[0]))
		_entrees.append(e)
		_textures.append(load(String(e["feuille"])) as Texture2D)
		_colonnes.append(int(e["colonnes"]))
		_lignes.append(0)
		_pools.append(Array([], TYPE_OBJECT, &"Sprite2D", null))
		_visibles.append(0)
		var portee: float = 0.0
		if f < nb_familles:
			portee = float((donnees.familles[f] as Dictionary)["portee_attaque"])
		elif f == nb_familles + 1:
			portee = float(donnees.boss["portee_attaque"])
		_arrets.append(Apparence2D.distance_arret(portee, rayon_tour))
		_flottements.append(float(e["flottement"]))
		_a_distance.append(1 if portee > Apparence2D.PORTEE_CORPS_A_CORPS else 0)
		# Le convoi (index n) ne combat pas.
		_combat.append(0 if f == nb_familles else 1)
	_lignes.resize(ids.size() * NB_ANIMATIONS)
	_images.resize(ids.size() * NB_ANIMATIONS)
	for f: int in ids.size():
		for a: int in NB_ANIMATIONS:
			var anim: Vector2i = _entrees[f][NOMS_ANIMATIONS[a]]
			_lignes[f * NB_ANIMATIONS + a] = anim.x
			_images[f * NB_ANIMATIONS + a] = anim.y


func _construire_sol() -> void:
	var s: Dictionary = Apparence2D.SOL
	var texture := load(String(s["feuille"])) as Texture2D
	var sol := Sprite2D.new()
	sol.name = "Sol"
	sol.texture = texture
	var taille := Vector2(texture.get_size())
	sol.scale = Vector2.ONE * (2.0 * RAYON_SOL) / taille
	var origine: Vector2 = s["origine"]
	var tuile: Vector2 = s["taille"]
	var materiau := ShaderMaterial.new()
	materiau.shader = load(Apparence2D.SHADER_SOL) as Shader
	materiau.set_shader_parameter("origine_uv", origine / taille)
	materiau.set_shader_parameter("taille_uv", tuile / taille)
	materiau.set_shader_parameter("repetitions", Vector2.ONE * (2.0 * RAYON_SOL) / tuile)
	sol.material = materiau
	add_child(sol)


func _construire_cercle() -> void:
	var cercle := Line2D.new()
	cercle.name = "CercleApparition"
	var rayon: float = Apparence2D.vers_pixels(Vector2(CameraArene2D.RAYON_APPARITION, 0.0)).x
	for i: int in POINTS_CERCLE:
		cercle.add_point(Vector2.from_angle(TAU * float(i) / float(POINTS_CERCLE)) * rayon)
	cercle.closed = true
	cercle.width = LARGEUR_CERCLE
	cercle.default_color = Apparence2D.COULEUR_CERCLE
	add_child(cercle)


func _construire_tour() -> void:
	_tour = Sprite2D.new()
	_tour.name = "Tour"
	var t: Dictionary = Apparence2D.tour(_numero)
	_tour.texture = load(String(t["fichier"])) as Texture2D
	_tour.scale = Vector2.ONE * Apparence2D.TOUR_ECHELLE
	# Le pied de la tour (ombre du pack comprise) repose sur l'origine du monde.
	var hauteur: float = _tour.texture.get_height() if _tour.texture != null else 256.0
	_tour.offset = Vector2(0.0, hauteur * 0.5 - Apparence2D.TOUR_PIEDS)
	_ennemis.add_child(_tour)


func _construire_nom() -> void:
	_noms = Node2D.new()
	_noms.name = "Noms"
	add_child(_noms)
	_nom = Label.new()
	_nom.name = "NomJoueur"
	_nom.position = Vector2(-NOM_LARGEUR * 0.5, 0.0)
	_nom.custom_minimum_size = Vector2(NOM_LARGEUR, 0.0)
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_nom.add_theme_font_size_override("font_size", NOM_TAILLE)
	_nom.add_theme_color_override("font_color", Apparence2D.COULEUR_NOM)
	_nom.add_theme_color_override("font_outline_color", Apparence2D.COULEUR_CONTOUR_NOM)
	_nom.add_theme_constant_override("outline_size", NOM_CONTOUR)
	_noms.add_child(_nom)
