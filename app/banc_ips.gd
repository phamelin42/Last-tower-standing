class_name BancIps
extends Node
## Banc d'essai des images par seconde (T5.1b), lancé par `--banc-ips [N]` à la place du menu :
## une `Arene2D` avec son décor, la tour et N ennemis des huit familles qui avancent vers elle
## (en tournant un peu), alimentés par des `VueArene` synthétiques à 15 Hz comme le ferait le
## réseau. Ce n'est pas une partie : ni simulation, ni score, ni réseau. Au bout de `duree`
## secondes, il écrit en bas de l'écran la moyenne et le minimum mesurés (les premières secondes
## de chauffe ne comptent pas : le premier affichage charge les textures), et les répète dans la
## console. Échap demande à quitter.

signal termine(resume: Dictionary)
signal quitter_demande

const SCENE_ARENE := "res://scenes/arene_2d.tscn"
const DUREE_S := 30.0
const CHAUFFE_S := 2.0
const PERIODE_MESURE_S := 0.25
const HZ_VUE := 15.0
## Couronne d'apparition des ennemis, et rayon où ils s'arrêtent devant la tour (unités de jeu).
const RAYON_MIN := 150.0
const RAYON_MAX := 1300.0
const RAYON_ARRET := 120.0
const VITESSE_APPROCHE := 30.0
const DERIVE_RAD_S := 0.04
## Graine fixe : deux bancs voient la même foule, donc des mesures comparables.
const GRAINE := 7
const HAUTEUR_BANDEAU := 56.0
const TAILLE_TEXTE := 20
const PV_PLEINS := 255

## Durée de la mesure ; les tests la raccourcissent.
var duree: float = DUREE_S
var arene: Arene2D = null

var _donnees: Donnees = null
var _nombre: int = 0
var _source: SourceVue = null
var _temps: float = 0.0
var _reste_vue: float = 0.0
var _reste_mesure: float = 0.0
var _tick: int = 0
var _fini: bool = false
var _resume: Dictionary = {}
var _echantillons: PackedFloat32Array = PackedFloat32Array()
var _dernier_ips: float = 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
var _rayons: PackedFloat32Array = PackedFloat32Array()
var _familles: PackedByteArray = PackedByteArray()
var _camera: CameraArene2D = null
var _texte: Label = null


## Monte le banc : faux, sans rien monter, si les données manquent.
func lancer(donnees: Donnees, nombre: int) -> bool:
	if donnees == null or nombre < 1:
		return false
	_donnees = donnees
	_nombre = nombre
	_tirer_la_foule()
	RenderingServer.set_default_clear_color(ThemeJeu.JAUGE_FOND)
	arene = (load(SCENE_ARENE) as PackedScene).instantiate() as Arene2D
	arene.donnees = donnees
	add_child(arene)
	_camera = arene.get_node("Camera") as CameraArene2D
	_source = SourceVue.new()
	_source.name = "SourceSynthetique"
	add_child(_source)
	arene.lier(_source)
	arene.reinitialiser()
	_construire_interface()
	_cadrer()
	get_viewport().size_changed.connect(_cadrer)
	_emettre_vue()
	_texte.text = tr("IPS_BANC_EN_COURS") % Nombres.groupe(_nombre)
	return true


func resume_visible() -> bool:
	return _fini


## Moyenne, minimum, nombre d'ennemis visibles et durée, une fois la mesure terminée.
func resume() -> Dictionary:
	return _resume


func texte_resume() -> String:
	if _resume.is_empty():
		return ""
	return (
		tr("IPS_BANC_RESUME")
		% [
			Nombres.groupe(roundi(float(_resume["moyenne"]))),
			Nombres.groupe(roundi(float(_resume["minimum"]))),
			Nombres.groupe(int(_resume["ennemis"])),
			Nombres.groupe(roundi(float(_resume["duree"]))),
			Nombres.groupe(roundi(CHAUFFE_S)),
		]
	)


## Fait avancer le banc de `delta` secondes ; `ips` est la mesure du moteur à cet instant.
func avancer(delta: float, ips: float) -> void:
	_temps += delta
	_dernier_ips = ips
	_reste_vue += delta
	if _reste_vue >= 1.0 / HZ_VUE:
		_reste_vue = fmod(_reste_vue, 1.0 / HZ_VUE)
		_emettre_vue()
	_reste_mesure += delta
	if _reste_mesure >= PERIODE_MESURE_S:
		_reste_mesure -= PERIODE_MESURE_S
		if _temps > CHAUFFE_S and not _fini:
			_echantillons.append(ips)
	if not _fini and _temps >= duree:
		_terminer()


func _process(delta: float) -> void:
	avancer(delta, Engine.get_frames_per_second())


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("menu_jeu") and event.is_action_pressed("menu_jeu"):
		get_viewport().set_input_as_handled()
		quitter_demande.emit()


func _terminer() -> void:
	_fini = true
	var somme: float = 0.0
	var plus_petit: float = _dernier_ips if _echantillons.is_empty() else _echantillons[0]
	for v: float in _echantillons:
		somme += v
		plus_petit = minf(plus_petit, v)
	var moyenne: float = _dernier_ips
	if not _echantillons.is_empty():
		moyenne = somme / float(_echantillons.size())
	_resume = {
		"moyenne": moyenne,
		"minimum": plus_petit,
		"ennemis": CompteurIps.ennemis_visibles(arene),
		"duree": duree,
	}
	_texte.text = texte_resume()
	print(_texte.text)
	termine.emit(_resume)


func _tirer_la_foule() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAINE
	var nb_familles: int = _donnees.familles.size()
	_angles.resize(_nombre)
	_rayons.resize(_nombre)
	_familles.resize(_nombre)
	for i: int in _nombre:
		_angles[i] = rng.randf() * TAU
		_rayons[i] = rng.randf_range(RAYON_MIN, RAYON_MAX)
		# Les familles se suivent en tourniquet : toutes sont là dès 8 ennemis.
		_familles[i] = i % nb_familles


func _emettre_vue() -> void:
	_tick += 1
	var v := VueArene.new()
	v.tick = _tick
	v.ennemis_id.resize(_nombre)
	v.ennemis_pos.resize(_nombre)
	v.ennemis_famille.resize(_nombre)
	v.ennemis_pv.resize(_nombre)
	v.ennemis_statuts.resize(_nombre)
	for i: int in _nombre:
		var r: float = maxf(RAYON_ARRET, _rayons[i] - VITESSE_APPROCHE * _temps)
		v.ennemis_id[i] = i + 1
		v.ennemis_pos[i] = Vector2.from_angle(_angles[i] + DERIVE_RAD_S * _temps) * r
		v.ennemis_famille[i] = _familles[i]
		v.ennemis_pv[i] = PV_PLEINS
		v.ennemis_statuts[i] = 0
	_source.vue_arene_recue.emit(v)


func _construire_interface() -> void:
	var couche := CanvasLayer.new()
	couche.name = "Interface"
	add_child(couche)
	var racine := Control.new()
	racine.name = "Racine"
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.theme = ThemeJeu.creer()
	couche.add_child(racine)
	var bandeau := PanelContainer.new()
	bandeau.name = "Bandeau"
	bandeau.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bandeau.custom_minimum_size.y = HAUTEUR_BANDEAU
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_theme_stylebox_override("panel", ThemeJeu.boite_barre())
	racine.add_child(bandeau)
	_texte = Label.new()
	_texte.name = "Texte"
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", TAILLE_TEXTE)
	_texte.add_theme_color_override("font_color", ThemeJeu.PARCHEMIN)
	bandeau.add_child(_texte)


## La tour est centrée dans la zone au-dessus du bandeau.
func _cadrer() -> void:
	if _camera == null:
		return
	var taille: Vector2 = get_viewport().get_visible_rect().size
	_camera.cadrer(Rect2(0.0, 0.0, taille.x, taille.y - HAUTEUR_BANDEAU), taille)
