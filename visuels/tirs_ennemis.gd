class_name TirsEnnemis
extends Node2D
## Les tirs des ennemis à distance : un Archer ou une Dynamite arrêtés à leur portée envoient un
## projectile visible vers la tour, une fois par `cadence_attaque` de leurs données. Purement
## visuel : la simulation n'émet aucun événement de tir ennemi, l'image se déduit de la vue (un
## ennemi à distance posé à son arrêt tire). Sans état par ennemi : la phase du tir se lit sur
## l'horloge d'affichage, décalée par l'identifiant pour que les tireurs ne tirent pas ensemble.
## Chemins des images, tailles, durée du vol et plafond viennent de `data/assets.json`
## (section `tirs_ennemis`) : changer de pack ne demande que de changer les fichiers et ce JSON.

## Par famille : secondes entre deux tirs (0 : ne tire pas), arrêt en unités de jeu, lancer en arc.
var _periodes: PackedFloat32Array = PackedFloat32Array()
var _arrets: PackedFloat32Array = PackedFloat32Array()
var _en_arc: PackedByteArray = PackedByteArray()
## `{pos, depart, vers, t, arc}` des projectiles en vol, positions en pixels.
var _tirs: Array[Dictionary] = []
var _horloge: float = 0.0

var _reglages: Dictionary = {}
var _tex_fleche: Texture2D = null
var _tex_bombe: Texture2D = null
var _plafond: int = 0
var _vol_s: float = 1.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Plus grand nombre de projectiles dessinés à la fois (`tirs_ennemis.plafond`).
func plafond() -> int:
	return _plafond


## Lit les familles des données : celles dont la portée dépasse le corps à corps tirent, la classe
## « moyenne » en arc (bombe), les autres en ligne droite (flèche). Charge les deux images.
func configurer(donnees: Donnees) -> void:
	_periodes.clear()
	_arrets.clear()
	_en_arc.clear()
	_reglages = Assets.typee("tirs_ennemis")
	_plafond = int(_reglages.get("plafond", 0))
	_vol_s = float(_reglages.get("vol_s", 1.0))
	_tex_fleche = _charger("fleche")
	_tex_bombe = _charger("bombe")
	var rayon_tour: float = float((donnees.partie["tour"] as Dictionary)["rayon"])
	for f: int in donnees.familles.size():
		var famille: Dictionary = donnees.familles[f]
		var portee: float = float(famille["portee_attaque"])
		var tire: bool = portee > Apparence.PORTEE_CORPS_A_CORPS
		var cadence: float = float(famille["cadence_attaque"])
		_periodes.append(1.0 / cadence if tire and cadence > 0.0 else 0.0)
		_arrets.append(Apparence.distance_arret(portee, rayon_tour))
		_en_arc.append(1 if int(famille["classe_portee"]) == Types.ClassePortee.MOYENNE else 0)


## Recalcule les projectiles à l'instant `horloge`. `positions` en unités de jeu.
func mettre_a_jour(
	horloge: float, ids: PackedInt32Array, positions: PackedVector2Array, familles: PackedByteArray
) -> void:
	_horloge = horloge
	var avant: int = _tirs.size()
	_tirs.clear()
	var marge: float = float(_reglages.get("marge_arret", 0.0))
	var decalage: float = float(_reglages.get("decalage_id_s", 0.0))
	var total: int = mini(ids.size(), mini(positions.size(), familles.size()))
	for i: int in total:
		if _tirs.size() >= _plafond:
			break
		var f: int = familles[i]
		if f >= _periodes.size() or _periodes[f] <= 0.0:
			continue
		var p: Vector2 = positions[i]
		if p.length() > _arrets[f] + marge:
			continue
		var phase: float = fposmod(horloge + float(ids[i]) * decalage, _periodes[f])
		if phase >= _vol_s:
			continue
		var depart: Vector2 = Apparence.vers_pixels(p)
		var t: float = phase / _vol_s
		(
			_tirs
			. append(
				{
					"pos": depart.lerp(Vector2.ZERO, t),
					"depart": depart,
					"vers": Vector2.ZERO,
					"t": t,
					"arc": _en_arc[f] != 0,
				}
			)
		)
	if avant > 0 or not _tirs.is_empty():
		queue_redraw()


func tirs() -> Array[Dictionary]:
	return _tirs


func _draw() -> void:
	for tir: Dictionary in _tirs:
		if bool(tir["arc"]):
			_dessiner_bombe(tir)
		else:
			_dessiner_fleche(tir)


func _dessiner_fleche(tir: Dictionary) -> void:
	if _tex_fleche == null:
		return
	var f: Dictionary = _reglages["fleche"]
	var region: Rect2 = f["region"]
	var echelle: float = float(f["echelle"])
	var sens: Vector2 = (tir["vers"] as Vector2) - (tir["depart"] as Vector2)
	# L'image de la flèche pointe vers la droite : on la tourne vers la tour.
	draw_set_transform(tir["pos"], sens.angle(), Vector2(echelle, echelle))
	draw_texture_rect_region(
		_tex_fleche, Rect2(-region.size * Vector2(1.0, 0.5), region.size), region
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dessiner_bombe(tir: Dictionary) -> void:
	if _tex_bombe == null:
		return
	var b: Dictionary = _reglages["bombe"]
	var region: Rect2 = b["region"]
	var case: Vector2i = b["case"]
	var echelle: float = float(b["echelle"])
	var t: float = tir["t"]
	var haut: float = float(b["arc"]) * 4.0 * t * (1.0 - t)
	var pos: Vector2 = (tir["pos"] as Vector2) + Vector2(0.0, -haut)
	# La mèche brûle : l'image avance avec l'horloge, décalée par la phase du vol.
	var image: int = int((_horloge + t) * float(b["images_par_seconde"])) % int(b["images"])
	var source := Rect2(region.position + Vector2(float(image * case.x), 0.0), region.size)
	draw_set_transform(pos, 0.0, Vector2(echelle, echelle))
	draw_texture_rect_region(_tex_bombe, Rect2(-region.size * 0.5, region.size), source)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _charger(cle: String) -> Texture2D:
	var section: Variant = _reglages.get(cle)
	if not section is Dictionary:
		return null
	return load(Apparence.RACINE + String((section as Dictionary)["chemin"])) as Texture2D
