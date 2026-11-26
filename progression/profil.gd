class_name Profil
extends RefCounted
## Ce que le joueur a gardé d'une partie à l'autre (D20, B1) : défis réussis, skins débloqués et
## choisi, statistiques. Donnée pure, sans fichier : `Sauvegarde` la lit et l'écrit. La progression
## est cosmétique et non vérifiée (B2) ; aucun nom de joueur ni donnée personnelle n'y entre.

## Clés du fichier, dans l'ordre d'écriture : la liste blanche de ce que `Sauvegarde` écrit.
const CLES: Array[String] = [
	"version",
	"defis_reussis",
	"skins_debloques",
	"skin_choisi",
	"parties",
	"meilleure_manche",
]
const IDENTIFIANT_MAX := 64
const LISTE_MAX := 256
const PARTIES_MAX := 1000000
const MANCHE_MAX := 10000

var defis_reussis: Array[String] = []
var skins_debloques: Array[String] = []
## Identifiant du skin choisi ; vide : le skin par défaut.
var skin_choisi: String = ""
var parties: int = 0
var meilleure_manche: int = 0
## Version du format dont ce profil est issu (`Sauvegarde.VERSION` à l'écriture).
var version: int = Sauvegarde.VERSION
## Vrai quand le fichier vient d'une version plus récente du jeu : `Sauvegarde` ne l'écrasera pas.
var verrouille: bool = false


## Les champs du fichier, rangés comme `CLES`. Les bornes sont appliquées avant l'écriture.
func a_dict() -> Dictionary:
	normaliser()
	return {
		"version": version,
		"defis_reussis": defis_reussis.duplicate(),
		"skins_debloques": skins_debloques.duplicate(),
		"skin_choisi": skin_choisi,
		"parties": parties,
		"meilleure_manche": meilleure_manche,
	}


## Profil d'un dictionnaire lu dans un fichier, ou `null` si un champ manque ou a un mauvais type :
## c'est l'entrée d'un tiers. Une valeur hors bornes est ramenée dans ses bornes, une clé inconnue
## ignorée.
static func depuis_dict(brut: Dictionary) -> Profil:
	var p := Profil.new()
	var defis: Variant = _liste_de_textes(brut.get("defis_reussis"))
	var skins: Variant = _liste_de_textes(brut.get("skins_debloques"))
	var choisi: Variant = brut.get("skin_choisi")
	var nb_parties: Variant = _entier(brut.get("parties"))
	var manche: Variant = _entier(brut.get("meilleure_manche"))
	if defis == null or skins == null or not choisi is String:
		return null
	if nb_parties == null or manche == null:
		return null
	p.defis_reussis.assign(defis as Array)
	p.skins_debloques.assign(skins as Array)
	p.skin_choisi = choisi
	p.parties = nb_parties
	p.meilleure_manche = manche
	p.normaliser()
	return p


## Ramène chaque valeur dans ses bornes : identifiants courts, sans doublon ni caractère de
## contrôle, listes bornées, compteurs entre 0 et leur maximum.
func normaliser() -> void:
	defis_reussis = _identifiants_propres(defis_reussis)
	skins_debloques = _identifiants_propres(skins_debloques)
	skin_choisi = _identifiant_propre(skin_choisi)
	parties = clampi(parties, 0, PARTIES_MAX)
	meilleure_manche = clampi(meilleure_manche, 0, MANCHE_MAX)


static func _identifiant_propre(brut: String) -> String:
	var sortie := ""
	for i: int in brut.length():
		var code: int = brut.unicode_at(i)
		if code < 0x20 or (code >= 0x7F and code <= 0x9F):
			continue
		sortie += brut[i]
	return sortie.strip_edges().left(IDENTIFIANT_MAX)


static func _identifiants_propres(liste: Array[String]) -> Array[String]:
	var sortie: Array[String] = []
	for brut: String in liste:
		var propre := _identifiant_propre(brut)
		if propre.is_empty() or sortie.has(propre):
			continue
		sortie.append(propre)
		if sortie.size() >= LISTE_MAX:
			break
	return sortie


## Les textes d'un tableau JSON, ou `null` si ce n'est pas un tableau de textes.
static func _liste_de_textes(brut: Variant) -> Variant:
	if not brut is Array:
		return null
	var sortie: Array[String] = []
	var tableau: Array = brut
	for element: Variant in tableau:
		if not element is String:
			return null
		sortie.append(element)
	return sortie


## Un entier fini (JSON les lit en flottants), ou `null` : texte, booléen, infini ou absent.
## Un flottant à virgule perd sa partie décimale ; un énorme est ramené par `normaliser`.
static func _entier(brut: Variant) -> Variant:
	if brut is int:
		return brut
	if brut is float:
		var x: float = brut
		if not is_finite(x):
			return null
		return int(clampf(floorf(x), -1.0e9, 1.0e9))
	return null
