class_name FormesEffets
extends RefCounted
## Les formes simples que `Effets` dessine lui-même (blanches : `modulate` les teinte) : trait,
## disque, halo, anneau, losange, entaille, pointes, étoile, flocon, croix, bulles, piège.


## Dessine la forme `nom` (une des `Effets.FORMES_PROPRES`).
static func image(nom: String) -> Image:
	var taille := Vector2i(64, 8) if nom.begins_with("trait") else Vector2i(32, 32)
	if nom == "anneau":
		taille = Vector2i(64, 64)
	var image := Image.create(taille.x, taille.y, false, Image.FORMAT_RGBA8)
	var centre := Vector2(taille) * 0.5
	for y: int in taille.y:
		for x: int in taille.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var plein: float = _couverture(nom, p, centre, taille)
			if plein > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(plein, 0.0, 1.0)))
	return image


## Opacité (0 à 1) de la forme `nom` au point `p`, bords adoucis sur un pixel.
static func _couverture(nom: String, p: Vector2, centre: Vector2, taille: Vector2i) -> float:
	var d: Vector2 = p - centre
	var rayon: float = centre.x
	match nom:
		"disque", "halo":
			var plein: float = rayon - d.length()
			return plein if nom == "disque" else minf(plein, 0.5 + 0.5 * plein / rayon)
		"anneau":
			return minf(rayon - d.length(), d.length() - (rayon - 4.0))
		"losange":
			return rayon - (absf(d.x) + absf(d.y))
		"trait":
			return minf(centre.y - absf(d.y) + 0.5, minf(p.x, taille.x - p.x))
		"trait_ondule":
			var y: float = sin(p.x / taille.x * TAU * 2.0) * 2.5
			return 1.6 - absf(d.y - y)
		"trait_zigzag":
			var y: float = absf(fposmod(p.x / taille.x * 6.0, 2.0) - 1.0) * 5.0 - 2.5
			return 1.6 - absf(d.y - y)
		"entaille":
			return 2.0 - minf(absf(d.x - d.y), absf(d.x + d.y)) * 0.7 if d.length() < rayon else 0.0
		"pointes", "piege":
			return _rayons(d, rayon, 8, 0.0, 1.6)
		"etoile":
			return _rayons(d, rayon, 4, PI * 0.25, 2.6)
		"flocon":
			return _rayons(d, rayon, 6, 0.0, 1.6)
		"croix_plus":
			return maxf(_rayons(d, rayon * 0.85, 4, 0.0, 3.0), 3.0 - d.length())
		"bulles":
			var meilleur: float = -1.0
			for c: Vector2 in [Vector2(-7, 5), Vector2(6, 2), Vector2(-1, -8)]:
				meilleur = maxf(meilleur, 5.0 - (d - c).length())
			return meilleur
	return 0.0


## Opacité d'une étoile à `n` branches : distance au plus proche rayon, de longueur `longueur`.
static func _rayons(
	d: Vector2, longueur: float, n: int, decalage: float, epaisseur: float
) -> float:
	var meilleur: float = -1.0
	var angle_pas: float = TAU / float(n) if n != 6 else PI / 3.0
	for k: int in n:
		var sens := Vector2.from_angle(decalage + angle_pas * k)
		var along: float = clampf(d.dot(sens), 0.0, longueur)
		meilleur = maxf(meilleur, epaisseur * 0.5 - (d - sens * along).length() + 0.5)
	return meilleur
