class_name SuperpositionsTour
extends RefCounted
## Dessine l'apparence de la tour (D19) : pour chaque statistique qui se voit, une couche arrière
## (derrière le sprite de la tour) et une couche avant (devant), à son palier et à son ancrage. Les
## sprites sont des enfants directs du sprite de la tour, qu'elles suivent donc quand elle grandit.
## Tout nombre vient des données (`data/apparence_tour.json`, `data/skins_tour.json`) ou se lit sur
## la texture : un pack d'images se remplace sans toucher à ce fichier. Purement visuel : rien de
## ce qui est dessiné ici ne revient dans la simulation, le rayon de la tour et la distance d'arrêt
## des ennemis ne changent pas.

const COUCHES: Array[String] = ["arriere", "avant"]
## Ordre de pose : les couches arrière du fond vers la tour, les couches avant de la plus proche de
## la tour à la plus lointaine (le film de mana et la lueur couvrent le reste).
const ORDRE_ARRIERE: Array[String] = ["esquive", "regen", "mana", "vol_de_vie", "armure", "epines"]
const ORDRE_AVANT: Array[String] = ["esquive", "armure", "epines", "vol_de_vie", "regen", "mana"]
## Statistiques dont le palier le plus haut a des images d'un tour lent.
const ANIMEES: Array[String] = ["epines", "vol_de_vie"]
## Opacité fixe de l'esquive en mouvement réduit (aucune pulsation).
const ESQUIVE_FIXE := 0.35
## Part de la hauteur de la bulle sous laquelle on la tient pour vide.
const MANA_VIDE := 0.01

var _parent: Sprite2D = null
var _donnees: Donnees = null
var _base: Vector2 = Vector2.ONE
var _ancrages: Dictionary = {}
## "statistique|couche" → {courant, ancien} : deux sprites pour fondre un palier dans l'autre.
var _sprites: Dictionary = {}
## Statistique → {palier, ancien, fondu} ; `fondu` va de 0 (début) à 1 (fini).
var _etat: Dictionary = {}
var _cible: VueArene = null
var _paliers: Dictionary = {}
var _initialise: bool = false
var _temps: float = 0.0
var _echelle_visee: float = 1.0
var _echelle: float = 1.0
var _textures: Dictionary = {}


## Crée les sprites sous `parent` (la tour) ; l'échelle de départ de `parent` est sa taille de
## repos. Le skin posé est `defaut` : le choix d'un autre skin passe par `definir_skin`.
func construire(parent: Sprite2D, donnees: Donnees) -> void:
	_parent = parent
	_donnees = donnees
	_base = parent.scale
	definir_skin("defaut")
	for couche: String in COUCHES:
		var ordre: Array[String] = ORDRE_ARRIERE if couche == "arriere" else ORDRE_AVANT
		for stat: String in ordre:
			var paire: Dictionary = {}
			for slot: String in ["courant", "ancien"]:
				var s := Sprite2D.new()
				s.name = "%s_%s_%s" % [stat, couche, slot]
				s.visible = false
				s.show_behind_parent = couche == "arriere"
				s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				parent.add_child(s)
				paire[slot] = s
			_sprites["%s|%s" % [stat, couche]] = paire
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		_etat[stat] = {"palier": 0, "ancien": 0, "fondu": 1.0}


## Les ancrages du skin `id` de `data/skins_tour.json` (le skin par défaut si l'id est inconnu).
func definir_skin(id: String) -> void:
	var skins: Dictionary = _donnees.skins_tour
	var skin: Dictionary = skins.get(id, skins.get("defaut", {}))
	_ancrages = skin.get("ancrages", {})


## Le sprite d'une statistique et d'une couche : `ancien` est celui qui s'efface pendant un fondu.
func sprite(stat: String, couche: String, ancien: bool = false) -> Sprite2D:
	var paire: Dictionary = _sprites["%s|%s" % [stat, couche]]
	return paire["ancien" if ancien else "courant"]


## Cache tout et oublie la vue : une autre arène n'a rien à voir avec celle qu'on quitte.
func reinitialiser() -> void:
	_cible = null
	_paliers = {}
	_initialise = false
	_echelle_visee = 1.0
	_echelle = 1.0
	for cle: String in _sprites:
		var paire: Dictionary = _sprites[cle]
		for slot: String in paire:
			(paire[slot] as Sprite2D).visible = false
	for stat: String in _etat:
		_etat[stat] = {"palier": 0, "ancien": 0, "fondu": 1.0}
	if _parent != null:
		_parent.scale = _base


## La vue à montrer : les paliers qui changent se fondent (le premier affichage est immédiat).
func viser(vue: VueArene) -> void:
	if vue == null or _donnees == null:
		return
	_cible = vue
	_paliers = ApparenceTour.paliers(vue, _donnees)
	_echelle_visee = ApparenceTour.echelle(_paliers, _donnees)
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		var nouveau: int = int(_paliers.get(stat, 0))
		var e: Dictionary = _etat[stat]
		if not _initialise:
			e["palier"] = nouveau
			e["ancien"] = 0
			e["fondu"] = 1.0
		elif nouveau != int(e["palier"]):
			e["ancien"] = e["palier"]
			e["palier"] = nouveau
			e["fondu"] = 0.0
	if not _initialise:
		_echelle = _echelle_visee
	_initialise = true


## Avance les fondus et l'animation de `delta` secondes, puis pose chaque sprite. En mouvement
## réduit : ni pulsation de l'esquive ni tour lent, seulement l'état.
func avancer(delta: float, mouvement_reduit: bool) -> void:
	if _cible == null or _parent == null or _parent.texture == null:
		return
	var duree := _duree_fondu()
	_temps += delta
	for stat: String in _etat:
		var e: Dictionary = _etat[stat]
		e["fondu"] = minf(float(e["fondu"]) + delta / duree, 1.0)
	_echelle = move_toward(_echelle, _echelle_visee, delta / duree * ApparenceTour.ECHELLE_MAX_PART)
	_parent.scale = _base * _echelle
	var haut_gauche := _parent.offset - _parent.texture.get_size() / 2.0
	var cumul := ApparenceTour.opacite_cumul(_paliers)
	for stat: String in ApparenceTour.SUPERPOSITIONS:
		var e: Dictionary = _etat[stat]
		var modulation := _modulation(stat, mouvement_reduit)
		var image := _image_animee(stat, int(e["palier"]), mouvement_reduit)
		for couche: String in COUCHES:
			var paire: Dictionary = _sprites["%s|%s" % [stat, couche]]
			var a: Dictionary = _ancrages.get(stat, {})
			var centre := haut_gauche + Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
			_poser(
				paire["courant"],
				stat,
				int(e["palier"]),
				couche,
				image,
				centre,
				float(e["fondu"]) * cumul * modulation
			)
			var vieux_visible := float(e["fondu"]) < 1.0
			_poser(
				paire["ancien"],
				stat,
				int(e["ancien"]) if vieux_visible else 0,
				couche,
				0,
				centre,
				(1.0 - float(e["fondu"])) * cumul * modulation
			)


## Pose `s` à `palier` (0 : caché) centré sur `centre`, à l'opacité `alpha`. La bulle de mana ne
## montre que sa part pleine, depuis le bas : elle disparaît à zéro.
func _poser(
	s: Sprite2D,
	stat: String,
	palier: int,
	couche: String,
	image: int,
	centre: Vector2,
	alpha: float
) -> void:
	var tex := _texture(stat, palier, couche, image) if palier > 0 else null
	if tex == null:
		s.visible = false
		return
	s.texture = tex
	s.modulate.a = alpha
	s.region_enabled = false
	s.position = centre
	s.visible = true
	if stat != "mana":
		return
	var plein := ApparenceTour.remplissage_mana(_cible)
	if plein <= MANA_VIDE:
		s.visible = false
		return
	var taille := tex.get_size()
	s.region_enabled = true
	s.region_rect = Rect2(0.0, taille.y * (1.0 - plein), taille.x, taille.y * plein)
	s.position = centre + Vector2(0.0, taille.y * (1.0 - plein) / 2.0)


## L'esquive passe un instant à intervalles réguliers (jamais plus de trois éclairs par seconde,
## borné par les données) ; les autres effets restent posés.
func _modulation(stat: String, mouvement_reduit: bool) -> float:
	if stat != "esquive":
		return 1.0
	if mouvement_reduit:
		return ESQUIVE_FIXE
	var regle: Dictionary = _donnees.apparence_tour.get("esquive", {})
	var periode := float(regle.get("periode_s", 3.0))
	var duree := float(regle.get("duree_s", 0.45))
	var x := fposmod(_temps, maxf(periode, 0.001))
	return sin(PI * x / duree) if x < duree else 0.0


## L'image du tour lent des piques et des filets au palier le plus haut ; 0 ailleurs.
func _image_animee(stat: String, palier: int, mouvement_reduit: bool) -> int:
	if mouvement_reduit or not ANIMEES.has(stat):
		return 0
	var anim: Dictionary = _donnees.apparence_tour.get("animation", {})
	var images := int(anim.get("images", 1))
	if palier < ApparenceTour.PALIERS_MAX or images <= 1:
		return 0
	return int(_temps * float(anim.get("par_seconde", 1.0))) % images


func _duree_fondu() -> float:
	return maxf(float(_donnees.apparence_tour.get("fondu_s", 0.3)), 0.001)


func _texture(stat: String, palier: int, couche: String, image: int) -> Texture2D:
	var dossier := String(_donnees.apparence_tour.get("dossier", ""))
	var chemin := Apparence.fichier_superposition(dossier, stat, palier, couche, image)
	if not _textures.has(chemin):
		_textures[chemin] = load(chemin) as Texture2D if ResourceLoader.exists(chemin) else null
	return _textures[chemin]
