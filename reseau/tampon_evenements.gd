class_name TamponEvenements
extends RefCounted
## Événements de tir, d'impact et de mort d'UNE arène, lus une seule fois dans `Partie` puis servis
## à chaque observateur depuis son propre curseur. Un événement porte un numéro d'ordre croissant ;
## le curseur d'un observateur est le numéro du dernier événement qu'il a reçu. Borné : sous une
## rafale, les plus anciens sont oubliés (ce ne sont que des effets visuels).

const CAPACITE: int = 256
## Plafond du protocole par envoi.
const PAR_ENVOI: int = Protocole.MAX_EVENEMENTS

## Numéro du dernier événement ajouté (0 : aucun).
var dernier: int = 0
var _evenements: Array[Dictionary] = []


class Lot:
	extends RefCounted
	var evenements: Array[Dictionary] = []
	## Nouveau curseur de l'observateur après ce lot.
	var curseur: int = 0


func taille() -> int:
	return _evenements.size()


func ajouter(nouveaux: Array[Dictionary]) -> void:
	if nouveaux.is_empty():
		return
	dernier += nouveaux.size()
	_evenements.append_array(nouveaux)
	if _evenements.size() > CAPACITE:
		_evenements = _evenements.slice(_evenements.size() - CAPACITE)


## Au plus `maximum` événements plus récents que `curseur`, les plus anciens d'abord.
func prendre(curseur: int, maximum: int) -> Lot:
	var lot := Lot.new()
	var premier := dernier - _evenements.size() + 1
	var debut := maxi(curseur + 1, premier)
	var n := clampi(dernier - debut + 1, 0, maxi(maximum, 0))
	lot.curseur = curseur
	if n > 0:
		lot.evenements.assign(_evenements.slice(debut - premier, debut - premier + n))
		lot.curseur = debut + n - 1
	return lot
