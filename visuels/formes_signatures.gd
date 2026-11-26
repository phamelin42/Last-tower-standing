class_name FormesSignatures
extends RefCounted
## Dessin par code des formes de `SignaturesArmes` (projectiles, traînées, impacts, statuts), en
## blanc sur fond transparent : l'appelant les teinte. Aucune image tierce. Les traînées sont des
## bandeaux de 64 × 16 px, tout le reste tient dans 48 × 48 px.

const TAILLE: int = 48
const BANDEAU := Vector2i(64, 16)

static var _cache: Dictionary = {}


static func image(nom: String) -> Image:
	if not _cache.has(nom):
		_cache[nom] = _dessiner(nom)
	return (_cache[nom] as Image).duplicate()


static func _dessiner(nom: String) -> Image:
	var taille := BANDEAU if SignaturesArmes.TRAINEES.has(nom) else Vector2i(TAILLE, TAILLE)
	var img := Image.create(taille.x, taille.y, false, Image.FORMAT_RGBA8)
	var centre := Vector2(taille) * 0.5
	for y: int in taille.y:
		for x: int in taille.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var plein: float = clampf(_couverture(nom, p, centre, taille), 0.0, 1.0)
			if plein > 0.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, plein))
	return img


## Opacité (0 à 1) de la forme `nom` au point `p`, bords adoucis sur un pixel.
static func _couverture(nom: String, p: Vector2, c: Vector2, t: Vector2i) -> float:
	var d: Vector2 = p - c
	var r: float = minf(c.x, c.y) - 1.0
	match nom:
		"trait":
			return minf(3.0 - absf(d.y), r * 1.3 - absf(d.x))
		"fleche":
			var tige: float = minf(2.5 - absf(d.y), minf(d.x + r, r * 0.3 - d.x))
			var pointe: float = minf((r - d.x) * 0.67 - absf(d.y), d.x - r * 0.1)
			return maxf(tige, pointe)
		"disque":
			return r - d.length()
		"dynamite":
			var baton: float = minf(r * 0.3 - absf(d.x), minf(r * 0.9 - d.y, d.y + r * 0.6))
			var meche: float = minf(1.6 - absf(d.x - 3.0), minf(-d.y - r * 0.55, d.y + r))
			return maxf(baton, meche)
		"losange":
			return (r - absf(d.x) - absf(d.y)) * 0.8
		"croissant":
			var ext: float = r - d.length()
			var interieur: float = (d - Vector2(r * 0.4, 0.0)).length() - r * 0.78
			return minf(ext, interieur)
		"shuriken":
			return _rayons(d, r, 4, PI * 0.25, 5.5, 0.9)
		"goutte":
			var corps: float = r * 0.6 - (d - Vector2(0.0, r * 0.3)).length()
			var cou: float = minf((d.y + r) * 0.42 - absf(d.x), minf(d.y + r, r * 0.3 - d.y))
			return maxf(corps, cou)
		"carre":
			return minf(r * 0.78 - absf(d.x), r * 0.78 - absf(d.y))
		"triangle":
			return minf(minf(d.y + r * 0.8, (r * 0.85 - d.y) * 1.0 - absf(d.x) * 1.6), 8.0)
		"hexagone":
			var a: Vector2 = Vector2(absf(d.x), absf(d.y))
			return minf(r * 0.88 - a.x, r * 0.88 - (a.x * 0.5 + a.y * 0.866) * 1.0)
		"spirale":
			var rayon: float = d.length()
			var ang: float = fposmod(atan2(d.y, d.x) - rayon * 0.35, TAU)
			var bras: float = absf(fposmod(ang * 1.5 / TAU * 2.0, 2.0) - 1.0)
			return minf(r - rayon, minf(bras * 4.0 - 0.6, 5.0 - maxf(0.0, 2.0 - rayon)))
		"filet":
			return 1.6 - absf(d.y) if p.x > 2.0 else 0.0
		"ondule":
			return 1.6 - absf(d.y - sin(p.x / t.x * TAU * 2.0) * 4.0)
		"zigzag":
			return 1.6 - absf(d.y - (absf(fposmod(p.x / t.x * 6.0, 2.0) - 1.0) * 8.0 - 4.0))
		"pointille":
			return minf(2.0 - absf(d.y), 1.5 - absf(fposmod(p.x, 10.0) - 5.0) + 2.0)
		"etincelles":
			var m: float = -1.0
			for x0: float in [8.0, 24.0, 40.0, 56.0]:
				var y0: float = -4.0 if int(x0) % 16 == 8 else 4.0
				m = maxf(m, 2.6 - (p - Vector2(x0, c.y + y0)).length())
			return maxf(m, 0.8 - absf(d.y))
		"double":
			return 1.3 - minf(absf(d.y - 3.5), absf(d.y + 3.5))
		"entaille":
			return 2.4 - minf(absf(d.x - d.y), absf(d.x + d.y)) * 0.7 if d.length() < r else 0.0
		"pointes":
			return _rayons(d, r, 8, 0.0, 2.6, 0.55)
		"halo":
			return minf(r - d.length(), 0.5 + (r - d.length()) * 0.18)
		"explosion":
			var ang2: float = atan2(d.y, d.x)
			var bord: float = r * (0.72 + 0.28 * absf(sin(ang2 * 4.0)))
			return bord - d.length()
		"etoile":
			return _rayons(d, r, 4, PI * 0.25, 4.0, 0.45)
		"anneau":
			return minf(r - d.length(), d.length() - (r - 5.0))
		"croix":
			return minf(r - maxf(absf(d.x), absf(d.y)), 3.2 - minf(absf(d.x), absf(d.y)))
		"eclaboussure":
			var m2: float = -1.0
			for k: int in 7:
				var s := Vector2.from_angle(float(k) * 0.9 + 0.3) * (r * (0.35 + 0.1 * (k % 3)))
				m2 = maxf(m2, (4.5 - 0.4 * (k % 3)) - (d - s).length())
			return maxf(m2, r * 0.3 - d.length())
		"flocon":
			return _rayons(d, r, 6, 0.0, 2.2, 0.5)
		"bulles":
			var m3: float = -1.0
			for centre: Vector2 in [Vector2(-9, 8), Vector2(8, 3), Vector2(-2, -10)]:
				m3 = minf(1.0, maxf(m3, 1.6 - absf((d - centre).length() - 7.0)))
			return m3
		"croix_plus":
			return maxf(_rayons(d, r * 0.85, 4, 0.0, 3.4, 1.0), 3.4 - d.length())
		"feu":
			var f: float = r * 0.55 - (d - Vector2(0.0, r * 0.3)).length()
			var langue: float = minf(
				(d.y + r) * 0.38 - absf(d.x - d.y * 0.15), minf(d.y + r, r * 0.3 - d.y)
			)
			return maxf(f, langue)
		"soin":
			var croix: float = minf(
				r * 0.55 - maxf(absf(d.x), absf(d.y - r * 0.3)),
				4.0 - minf(absf(d.x), absf(d.y - r * 0.3))
			)
			var haut: float = minf((d.y + r) * 0.9 - absf(d.x), -d.y - r * 0.35)
			return maxf(croix, haut)
	return 0.0


## Étoile à `n` branches effilées : distance au plus proche rayon.
static func _rayons(
	d: Vector2, longueur: float, n: int, decalage: float, epais: float, fin: float
) -> float:
	var meilleur: float = -1.0
	for k: int in n:
		var sens := Vector2.from_angle(decalage + TAU / float(n) * k)
		var t: float = clampf(d.dot(sens), 0.0, longueur)
		var largeur: float = epais * (1.0 - fin * t / longueur)
		meilleur = maxf(meilleur, largeur - (d - sens * t).length())
	return meilleur
