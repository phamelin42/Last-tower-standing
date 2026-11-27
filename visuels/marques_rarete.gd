class_name MarquesRarete
extends RefCounted
## La marque de rareté des armes de fin de partie (`AttaqueTardive`) : une petite forme neutre, dans
## l'effet lui-même, que la teinte de la rareté colore comme le reste. Elle suit le projectile
## (traînée de l'ancestrale, étoile de la souveraine) et naît à l'impact (braises, éclat d'étoile).
## Les planches, et l'image sur laquelle la marque se fige en mouvement réduit, sont dans
## `signatures.raretes_tardives.<rareté>.marque` de `data/assets.json`. Le scintillement est
## coupé en mouvement réduit (D21) ; la marque compte dans le plafond d'effets du pool.

## L'impact joue chaque image de sa planche pendant ce nombre d'images à 60 i/s.
const IMAGES_PAR_IMAGE_PLANCHE: int = 2


## La fiche de la marque de la rareté `rarete` (vide si elle n'en a pas).
static func donnees(rarete: String) -> Dictionary:
	var raretes: Dictionary = Assets.typee("signatures").get("raretes_tardives", {})
	return (raretes.get(rarete, {}) as Dictionary).get("marque", {})


## La marque qui suit le projectile `vol` (celui de l'arme), même trajectoire et même durée.
static func suivre_vol(
	m: AttaquesElementaires, rarete: String, vol: Dictionary, attente: float, duree_vol: float
) -> bool:
	var planche: String = str(donnees(rarete).get("vol", ""))
	if planche == "" or PlanchesEffets.case_de(planche) == Vector2i.ZERO:
		return false
	var effet: Dictionary = m.nouveau("vol", planche, duree_vol)
	if effet.is_empty():
		return false
	effet["age"] = -attente
	effet["depart"] = vol["depart"]
	effet["arrivee"] = vol["arrivee"]
	effet["echelle"] = PlanchesEffets.echelle()
	effet["fps"] = PlanchesEffets.cadence_de(planche)
	effet["cloche"] = vol["cloche"]
	# Figée sur sa première image en mouvement réduit : pas de scintillement.
	effet["fige_reduit"] = true
	effet["vol"] = duree_vol
	m.poser(effet)
	return true


## La marque qui naît en `ou` (impact, zone, aura, onde, piège), `age` après l'arrivée.
static func a_l_impact(m: AttaquesElementaires, rarete: String, ou: Vector2, age: float) -> bool:
	var fiche: Dictionary = donnees(rarete)
	var planche: String = str(fiche.get("impact", ""))
	if planche == "" or PlanchesEffets.case_de(planche) == Vector2i.ZERO:
		return false
	var images: int = AttaquesElementaires.images_de(planche)
	var duree: float = float(images * IMAGES_PAR_IMAGE_PLANCHE) * AttaquesElementaires.IMAGE
	if age >= duree:
		return false
	var effet: Dictionary = m.nouveau("image", planche, duree)
	if effet.is_empty():
		return false
	var seq: Array[int] = []
	for i: int in images * IMAGES_PAR_IMAGE_PLANCHE:
		var image: int = int(i / IMAGES_PAR_IMAGE_PLANCHE)
		seq.append(
			(
				clampi(int(fiche.get("impact_image_fixe", 0)), 0, images - 1)
				if m.mouvement_reduit
				else image
			)
		)
	effet["age"] = age
	effet["depart"] = ou
	effet["echelle"] = PlanchesEffets.echelle()
	effet["diametre"] = AttaquesElementaires.visible_de(planche) * PlanchesEffets.echelle()
	effet["seq"] = seq
	m.poser(effet)
	return true
