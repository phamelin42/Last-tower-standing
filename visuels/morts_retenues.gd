class_name MortsRetenues
extends RefCounted
## Les ennemis tués qu'`Arene2D` garde affichés jusqu'à l'impact visible qui les tue : figés là où
## ils étaient, ils clignotent et reculent à ce coup comme un ennemi touché (`ReactionsCoups`),
## puis le crâne prend leur place. Le crâne vient tout de suite quand aucun impact n'est en attente.
## Visuel seulement : la vue reçue n'est jamais modifiée. L'arène reste propriétaire de ses sprites,
## de ses réactions et de ses crânes ; cette classe n'en tient que la liste des retenus.

## Écart maximal (unités) entre une mort et la dernière position connue de l'ennemi mort : il a
## pu avancer entre deux vues.
const PORTEE: float = 40.0
## Un ennemi tué reste affiché jusqu'à l'impact visible qui le vise, pas plus de 20 images : le
## coup doit paraître le tuer, et un impact jamais joué ne doit pas le garder à l'écran.
const DELAI_MAX: float = 20.0 / 60.0
## Marge des sommes de `delta` : vingt images à 60 i/s font vingt images, pas vingt et une.
const MARGE_DELAI: float = 0.000001

## Un dictionnaire par ennemi retenu : `sprite`, `ou`, `id`, `debut`, `p`, `couleur`, `pixels`.
var liste: Array[Dictionary] = []

var _arene: Arene2D = null


func _init(arene: Arene2D) -> void:
	_arene = arene


## Le crâne tout de suite, ou, si un impact en attente vise l'ennemi, l'ennemi lui-même, figé là où
## il était affiché, jusqu'à cet impact. Sans vue précédente on ne sait pas qui est mort.
func annoncer(ou: Vector2, vue: VueArene) -> void:
	var rang: int = -1
	if _arene._effets.delai_avant_impact(ou) >= 0.0 and liste.size() < CranesArene.PLAFOND:
		rang = _disparu_proche(vue, ou)
	if rang < 0:
		_arene._montrer_crane(ou)
		return
	liste.append(_creer(_arene._vue_precedente, rang, ou))


## Les ennemis retenus passent les premiers parmi les candidats d'un impact : c'est lui qui les
## tue. Rend `[ids, positions]` avec les retenus en tête.
func candidats(ids: PackedInt32Array, positions: PackedVector2Array) -> Array:
	if liste.is_empty():
		return [ids, positions]
	var tous_ids: PackedInt32Array = PackedInt32Array()
	var toutes_positions: PackedVector2Array = PackedVector2Array()
	for mourant: Dictionary in liste:
		tous_ids.append(int(mourant["id"]))
		toutes_positions.append(mourant["p"])
	tous_ids.append_array(ids)
	toutes_positions.append_array(positions)
	return [tous_ids, toutes_positions]


## Rang, dans la vue précédente, de l'ennemi disparu de `vue` le plus proche de `ou` (à moins de
## `PORTEE`, ni explosif ni déjà retenu), -1 s'il n'y en a pas.
func _disparu_proche(vue: VueArene, ou: Vector2) -> int:
	var avant: VueArene = _arene._vue_precedente
	if avant == null:
		return -1
	var presents: Dictionary = {}
	for id: int in vue.ennemis_id:
		presents[id] = true
	for mourant: Dictionary in liste:
		presents[int(mourant["id"])] = true
	var total: int = mini(
		avant.ennemis_id.size(), mini(avant.ennemis_pos.size(), avant.ennemis_famille.size())
	)
	var meilleur: int = -1
	var distance: float = PORTEE
	for i: int in total:
		var f: int = avant.ennemis_famille[i]
		if (
			presents.has(avant.ennemis_id[i])
			or f >= _arene._explosives.size()
			or _arene._explosives[f] != 0
		):
			continue
		var d: float = avant.ennemis_pos[i].distance_to(ou)
		if d <= distance:
			distance = d
			meilleur = i
	return meilleur


## L'ennemi `rang` de `avant`, figé : même image, même teinte et même place que sur la dernière
## image affichée. Il n'est dans aucune liste d'`_afficher_echantillon` : aucun coup ne le touche.
func _creer(avant: VueArene, rang: int, ou: Vector2) -> Dictionary:
	var f: int = avant.ennemis_famille[rang]
	var id: int = avant.ennemis_id[rang]
	var p: Vector2 = avant.ennemis_pos[rang]
	var sprite := _arene._creer_sprite(f) as Arene2D.Lutin
	sprite.position = _arene._reactions.position_affichee(id, Apparence.vers_pixels(p))
	var miroir: bool = p.x > 0.0
	var cle: int = f * Arene2D.NB_ANIMATIONS + _arene._animation(f, p)
	var image_courante: int = int(_arene._horloge * Apparence.images_par_seconde)
	var phase: int = _arene._reactions.image_animation(id, image_courante) + id
	sprite.image = _arene._lignes[cle] * _arene._colonnes[f] + phase % _arene._images[cle]
	sprite.miroir = miroir
	sprite.flip_h = miroir
	_arene._poser_image(sprite, _arene._regions[f], _arene._decalages[f], sprite.image, miroir)
	var statut: int = avant.ennemis_statuts[rang] if rang < avant.ennemis_statuts.size() else 0
	var teinte: Color = Arene2D.teinte_statut(statut)
	var base: Color = _arene._entrees[f]["couleur"]
	var couleur := Color(base.r * teinte.r, base.g * teinte.g, base.b * teinte.b, 1.0)
	sprite.modulate = couleur
	return {
		"sprite": sprite,
		"ou": ou,
		"id": id,
		"debut": _arene._horloge,
		"p": p,
		"couleur": couleur,
		"pixels": Apparence.vers_pixels(p),
	}


## Le crâne remplace l'ennemi retenu une fois son flash fini, qui suit l'impact qui le tue (il
## s'éclaircit et recule comme un ennemi touché), ou dès qu'aucun impact ne le vise ; en tout cas
## au bout de `DELAI_MAX` : le flash est alors coupé, il ne rallonge jamais la mort.
func avancer() -> void:
	for i: int in range(liste.size() - 1, -1, -1):
		var mourant: Dictionary = liste[i]
		var ou: Vector2 = mourant["ou"]
		var id: int = int(mourant["id"])
		var attente: float = _arene._horloge - float(mourant["debut"])
		var impact_vu: bool = _arene._effets.delai_avant_impact(ou) < 0.0
		if attente >= DELAI_MAX - MARGE_DELAI or (impact_vu and _arene._reactions.eclat(id) <= 1.0):
			_liberer(i)
			_arene._montrer_crane(ou)
			continue
		var sprite: Sprite2D = mourant["sprite"]
		sprite.position = _arene._reactions.position_affichee(id, mourant["pixels"])
		var couleur: Color = mourant["couleur"]
		var eclat: float = _arene._reactions.eclat(id)
		sprite.modulate = Color(couleur.r * eclat, couleur.g * eclat, couleur.b * eclat, couleur.a)


func _liberer(i: int) -> void:
	var sprite: Sprite2D = liste[i]["sprite"]
	liste.remove_at(i)
	_arene._ennemis.remove_child(sprite)
	sprite.free()


## Une autre partie ou une autre arène : on n'attend plus aucun impact.
func vider() -> void:
	for i: int in range(liste.size() - 1, -1, -1):
		_liberer(i)


## Nombre d'ennemis tués encore affichés en attendant l'impact qui les tue.
func nombre() -> int:
	return liste.size()


## Le sprite du `i`-ème ennemi tué en attente de son impact.
func sprite_de(i: int) -> Sprite2D:
	return liste[i]["sprite"] if i >= 0 and i < liste.size() else null
