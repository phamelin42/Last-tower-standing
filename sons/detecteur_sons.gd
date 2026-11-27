class_name DetecteurSons
extends RefCounted
## Dit quels sons jouer entre deux vues d'arène. Pure : elle ne lit que les vues, n'écrit rien
## dans la simulation et ne joue rien. Les événements (tir, mort) se jouent une fois par vue ;
## l'impact n'en fait pas partie : son son suit l'effet (`LecteurSons.jouer_impact`), car le
## projectile retient l'impact visible de 50 à 233 ms après l'événement.
## Les transitions (seuil de PV, manche, phase, achat, relance) se jouent au passage seul.

## Sous ce ratio de PV de la tour, un son d'alerte se joue une fois, au franchissement.
const SEUIL_PV_BAS := 0.3


## Renvoie les identifiants de sons, sans doublon, à jouer pour passer de `precedente` à
## `courante`. Sans vue précédente, seuls les événements de `courante` se jouent. `catalogue`
## (`Donnees.ids_catalogue`) traduit l'index `arme` d'un événement de tir en identifiant d'arme.
static func sons_du_pas(
	precedente: VueArene, courante: VueArene, catalogue: PackedStringArray = PackedStringArray()
) -> Array[String]:
	var sons: Array[String] = []
	if courante == null:
		return sons
	_ajouter_evenements(courante, sons, catalogue)
	if precedente == null:
		return sons
	if courante.manche > precedente.manche:
		_ajouter(sons, CatalogueSons.DEBUT_MANCHE)
	if courante.phase != precedente.phase:
		_ajouter_phase(courante.phase, sons)
	if _franchit_seuil(precedente, courante):
		_ajouter(sons, CatalogueSons.PV_BAS)
	_ajouter_inventaire(precedente, courante, sons)
	return sons


static func _ajouter_evenements(
	courante: VueArene, sons: Array[String], catalogue: PackedStringArray
) -> void:
	for evenement: Dictionary in courante.evenements:
		match str(evenement.get("k", "")):
			"tir":
				_ajouter(sons, CatalogueSons.id_tir(_arme_de(evenement, catalogue)))
			"mort":
				_ajouter(sons, CatalogueSons.MORT)


## L'arme de l'événement, `""` sans arme ou avec un index hors catalogue.
static func _arme_de(evenement: Dictionary, catalogue: PackedStringArray) -> String:
	var index: int = int(evenement.get("arme", -1))
	if index < 0 or index >= catalogue.size():
		return ""
	return catalogue[index]


static func _ajouter_phase(phase: int, sons: Array[String]) -> void:
	match phase:
		Types.Phase.BOSS:
			_ajouter(sons, CatalogueSons.BOSS)
		Types.Phase.VICTOIRE:
			_ajouter(sons, CatalogueSons.VICTOIRE)
		Types.Phase.DEFAITE:
			_ajouter(sons, CatalogueSons.DEFAITE)


static func _franchit_seuil(precedente: VueArene, courante: VueArene) -> bool:
	if precedente.tour_pv_max <= 0.0 or courante.tour_pv_max <= 0.0:
		return false
	var avant := precedente.tour_pv / precedente.tour_pv_max
	var apres := courante.tour_pv / courante.tour_pv_max
	return avant >= SEUIL_PV_BAS and apres < SEUIL_PV_BAS


## Un objet qui entre dans l'inventaire fait un achat. Des offres renouvelées sans rien d'acheté
## font une relance. Ce critère se relit en jeu : une relance gratuite qui coïncide avec un achat
## ne se distingue pas ici.
static func _ajouter_inventaire(
	precedente: VueArene, courante: VueArene, sons: Array[String]
) -> void:
	var inventaire_grandi: bool = (
		courante.armes.size() > precedente.armes.size()
		or courante.ameliorations.size() > precedente.ameliorations.size()
	)
	if inventaire_grandi:
		_ajouter(sons, CatalogueSons.ACHAT)
	elif courante.offres != precedente.offres:
		_ajouter(sons, CatalogueSons.RELANCE)


static func _ajouter(sons: Array[String], identifiant: String) -> void:
	if not sons.has(identifiant):
		sons.append(identifiant)
