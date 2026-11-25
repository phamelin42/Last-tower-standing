class_name Partie
extends RefCounted
## La partie : le seul point d'entrée public de la simulation. Elle tient une arène par joueur,
## fait avancer le temps à pas fixe, enchaîne préparation, manches et boss, applique la difficulté
## et juge la fin. Le réseau et la source locale n'appellent que ces méthodes.
##
## Déroulement : préparation (manche 0), manches 1 à `manche_boss - 1`, puis le boss. Toutes les
## arènes jouent la même famille. Un joueur dont le boss est tombé est « victorieux » : son arène
## est figée en phase VICTOIRE et il reste en jeu jusqu'à ce qu'il quitte. La partie se termine
## quand plus personne n'est en jeu.
##
## Mode sans fin : un vainqueur peut reprendre les manches (32, 33…) seul, à son rythme, avec sa
## propre suite de familles ; la difficulté continue de monter par `apres_table`.
##
## Ajouts à l'interface du plan : `PAS_MAX_PAR_APPEL` ; un id négatif est refusé à l'ajout (−1 dit
## « aucun joueur » ailleurs).

signal manche_commencee(numero: int)
signal joueur_elimine(id: int)
signal joueur_victorieux(id: int)
signal partie_terminee(classement: Array)

## Pas simulés au plus par appel d'`avancer` (10 s de jeu) : un `dt` démesuré ne gèle pas la boucle.
## Le retard au-delà est abandonné, pas rattrapé.
const PAS_MAX_PAR_APPEL := 200
const JOUEURS_MAX := 8
## Gros à côté des erreurs d'arrondi du cumulateur, petit devant un pas.
const EPSILON_TEMPS := 1e-9
## Écart entre la graine du hasard de la partie et celle de la première arène.
const DECALAGE_GRAINE_PARTIE := 1000003
const PAS_GRAINE_ARENE := 7919

var _donnees: Donnees
var _graine: int
var _facteur: float
var _pas_s: float
var _joueurs: Dictionary = {}
var _ordre: Array[JoueurPartie] = []
var _planning: Planning
var _demarree: bool = false
var _terminee: bool = false
var _cumul: float = 0.0
var _pas_total: int = 0
var _phase: int = Types.Phase.PREPARATION
var _manche: int = 0
var _pas_phase: int = 0
var _pas_preparation: int
var _pas_manche: int
var _manche_boss: int
var _famille_suivante: int = -1
var _classement: Array[int] = []
var _dernier_rempart: int = -1


class Config:
	extends RefCounted
	var graine: int = 0
	## Multiplie toutes les durées : 1,0 / 0,66 / 0,5. Un facteur invalide vaut 1.
	var facteur_duree: float = 1.0


func _init(donnees: Donnees, config: Config) -> void:
	_donnees = donnees
	var c := config if config != null else Config.new()
	_graine = c.graine
	_facteur = c.facteur_duree if (is_finite(c.facteur_duree) and c.facteur_duree > 0.0) else 1.0
	var p: Dictionary = donnees.partie
	_pas_s = float(p["pas_s"])
	_pas_preparation = roundi(float(p["preparation_s"]) / _pas_s)
	_pas_manche = roundi(float(p["manche_s"]) / _pas_s)
	_manche_boss = int(p["manche_boss"])
	_planning = Planning.new(donnees, _graine + DECALAGE_GRAINE_PARTIE)


# --- Salon -------------------------------------------------------------------------------------


func ajouter_joueur(id: int, nom: String) -> bool:
	if _demarree or id < 0 or _joueurs.has(id) or _ordre.size() >= JOUEURS_MAX:
		return false
	var j := JoueurPartie.new(id, nom)
	_joueurs[id] = j
	_ordre.append(j)
	return true


## Au salon : le joueur disparaît. En partie : il est éliminé et son arène retirée.
func retirer_joueur(id: int) -> void:
	var j := _joueur(id)
	if j == null:
		return
	if not _demarree:
		_joueurs.erase(id)
		_ordre.erase(j)
		return
	_partir(j)


## Les arènes naissent ici : la graine de chacune vient de son rang d'arrivée (0 pour le premier).
func demarrer() -> bool:
	if _demarree or _ordre.is_empty():
		return false
	_demarree = true
	for rang: int in _ordre.size():
		var j := _ordre[rang]
		j.arene = Arene.new(_donnees, _graine + PAS_GRAINE_ARENE * rang)
	_famille_suivante = _planning.tirer(1) if _manche_boss > 1 else -1
	return true


# --- Temps -------------------------------------------------------------------------------------


## Nombre de pas simulés. Le temps réel est divisé par le facteur de durée avant d'être cumulé.
func avancer(dt_reel: float) -> int:
	if not _demarree or _terminee or not is_finite(dt_reel) or not dt_reel > 0.0:
		return 0
	_cumul += dt_reel / _facteur
	var faits := 0
	while _cumul >= _pas_s - EPSILON_TEMPS and faits < PAS_MAX_PAR_APPEL and not _terminee:
		_cumul -= _pas_s
		_un_pas()
		faits += 1
	_cumul = maxf(_cumul, 0.0) if _cumul < _pas_s - EPSILON_TEMPS else 0.0
	return faits


func temps_ecoule() -> float:
	return float(_pas_total) * _pas_s


func est_terminee() -> bool:
	return _terminee


func _un_pas() -> void:
	_pas_total += 1
	for j: JoueurPartie in _ordre:
		if j.arene != null and not j.fige:
			j.arene.avancer(_pas_s)
	for j: JoueurPartie in _ordre:
		if j.arene == null or j.fige:
			continue
		if j.arene.est_detruite():
			_eliminer(j, Classement.Cause.DEFAITE)
		elif j.arene.boss_vaincu():
			_vaincre(j)
	for j: JoueurPartie in _ordre:
		if j.sans_fin and not j.fige:
			j.pas_manche_sans_fin += 1
			if j.pas_manche_sans_fin >= _pas_manche:
				_commencer_manche_sans_fin(j)
	_pas_phase += 1
	if _phase == Types.Phase.PREPARATION and _pas_phase >= _pas_preparation:
		_commencer_manche(1)
	elif _phase == Types.Phase.MANCHE and _pas_phase >= _pas_manche:
		_commencer_manche(_manche + 1)
	_verifier_fin()


func _commencer_manche(numero: int) -> void:
	_manche = numero
	_pas_phase = 0
	var mult := Planning.multiplicateurs(_donnees, numero, temps_ecoule())
	if numero >= _manche_boss:
		_phase = Types.Phase.BOSS
		for j: JoueurPartie in _ordre:
			if j.arene != null and not j.fige and not j.sans_fin:
				j.arene.demarrer_boss(mult)
	else:
		_phase = Types.Phase.MANCHE
		var famille := _famille_suivante
		_famille_suivante = _planning.tirer(numero + 1) if numero + 1 < _manche_boss else -1
		for j: JoueurPartie in _ordre:
			if j.arene != null and not j.fige and not j.sans_fin:
				j.arene.demarrer_manche(numero, famille, mult)
	manche_commencee.emit(numero)


## Manche suivante d'un joueur en sans fin : sa famille annoncée, puis la suivante tirée.
func _commencer_manche_sans_fin(j: JoueurPartie) -> void:
	j.manche_sans_fin += 1
	j.pas_manche_sans_fin = 0
	var mult := Planning.multiplicateurs(_donnees, j.manche_sans_fin, temps_ecoule())
	var famille := j.famille_suivante_sans_fin
	j.famille_suivante_sans_fin = j.planning_sans_fin.tirer(j.manche_sans_fin + 1)
	j.arene.demarrer_manche(j.manche_sans_fin, famille, mult)


# --- Fin de joueur, fin de partie --------------------------------------------------------------


func _eliminer(j: JoueurPartie, cause: int) -> void:
	_figer(j)
	j.elimine = true
	j.cause = cause
	joueur_elimine.emit(j.id)


func _vaincre(j: JoueurPartie) -> void:
	_figer(j)
	j.victorieux = true
	joueur_victorieux.emit(j.id)


## Prend les statistiques une dernière fois et arrête la simulation de cette arène.
func _figer(j: JoueurPartie) -> void:
	if j.arene != null:
		_lire_statistiques(j)
	j.fige = true
	j.pas_fin = _pas_total


## Départ (déconnexion ou « quitter ») : l'arène disparaît. Un joueur encore en jeu et non
## vainqueur est éliminé ; un vainqueur ou un joueur déjà tombé est simplement « terminé ».
func _partir(j: JoueurPartie) -> void:
	if j.parti:
		return
	if j.en_jeu() and not j.victorieux:
		_eliminer(j, Classement.Cause.DECONNEXION)
	elif not j.fige:
		_figer(j)
	if j.victorieux:
		j.pas_fin = _pas_total
	j.parti = true
	j.arene = null
	_verifier_fin()


func _verifier_fin() -> void:
	if _terminee or not _demarree:
		return
	for j: JoueurPartie in _ordre:
		if j.en_jeu():
			return
	_terminee = true
	var entrees: Array[Dictionary] = []
	for j: JoueurPartie in _ordre:
		if j.manche <= 0:
			continue
		var cause := Classement.Cause.VICTOIRE if j.victorieux else j.cause
		(
			entrees
			. append(
				{
					"id": j.id,
					"manche": j.manche,
					"degats": j.degats,
					"pas_fin": j.pas_fin,
					"cause": cause,
				}
			)
		)
	_classement = Classement.ordonner(entrees)
	_dernier_rempart = Classement.dernier_rempart(entrees)
	partie_terminee.emit(_classement.duplicate())


# --- Intentions --------------------------------------------------------------------------------


func intention_acheter(id: int, index: int) -> int:
	var j := _cible_intention(id)
	if j.code != Types.Resultat.OK:
		return j.code
	return j.joueur.arene.acheter(index)


func intention_relancer(id: int) -> int:
	var j := _cible_intention(id)
	if j.code != Types.Resultat.OK:
		return j.code
	return j.joueur.arene.relancer()


func intention_vendre(id: int, index_arme: int) -> int:
	var j := _cible_intention(id)
	if j.code != Types.Resultat.OK:
		return j.code
	return j.joueur.arene.vendre(index_arme)


func intention_marche_noir(id: int, ami: String) -> int:
	var j := _cible_intention(id)
	if j.code != Types.Resultat.OK:
		return j.code
	return j.joueur.arene.choisir_marche_noir(ami)


## Réservé à un vainqueur encore en jeu : son arène repart à la manche qui suit le boss. Les
## autres joueurs ne sont pas touchés.
func intention_continuer_sans_fin(id: int) -> int:
	var j := _joueur(id)
	if j == null or not j.en_jeu():
		return Types.Resultat.ARENE_MORTE
	if not _demarree or _terminee or not j.victorieux:
		return Types.Resultat.MAUVAISE_PHASE
	j.victorieux = false
	j.sans_fin = true
	j.fige = false
	j.pas_fin = -1
	j.planning_sans_fin = Planning.new(
		_donnees, _graine + DECALAGE_GRAINE_PARTIE + PAS_GRAINE_ARENE * (_ordre.find(j) + 1)
	)
	j.manche_sans_fin = _manche_boss
	j.famille_suivante_sans_fin = j.planning_sans_fin.tirer(_manche_boss + 1)
	_commencer_manche_sans_fin(j)
	return Types.Resultat.OK


## Quitter en cours de partie vaut élimination ; un vainqueur ou un joueur tombé est
## « terminé ».
func intention_quitter(id: int) -> int:
	var j := _joueur(id)
	if j == null or j.parti:
		return Types.Resultat.ARENE_MORTE
	if not _demarree:
		retirer_joueur(id)
		return Types.Resultat.OK
	_partir(j)
	return Types.Resultat.OK


class CibleIntention:
	extends RefCounted
	var code: int = Types.Resultat.OK
	var joueur: JoueurPartie = null


## Un joueur inconnu, tombé ou parti n'a plus d'arène à qui parler ; avant le démarrage ou après
## la victoire, la boutique est fermée.
func _cible_intention(id: int) -> CibleIntention:
	var c := CibleIntention.new()
	var j := _joueur(id)
	if j == null or not j.en_jeu():
		c.code = Types.Resultat.ARENE_MORTE
	elif not _demarree or j.victorieux or _terminee:
		c.code = Types.Resultat.MAUVAISE_PHASE
	else:
		c.joueur = j
	return c


# --- Lecture -----------------------------------------------------------------------------------


## L'arène de `cible` vue par `demandeur`. Un joueur en jeu ne voit que la sienne ; un joueur
## tombé ou parti peut observer toute arène qui existe encore. `null` sinon.
func vue_arene(demandeur: int, cible: int) -> VueArene:
	var d := _joueur(demandeur)
	var c := _joueur(cible)
	if d == null or c == null or c.arene == null:
		return null
	if d.en_jeu() and cible != demandeur:
		return null
	var v := c.arene.vue(_phase_vue(c), _temps_restant(c), _famille_annoncee(c), c.sans_fin)
	_enregistrer(c, v)
	var attente := c.evenements_en_attente
	if not attente.is_empty():
		attente.append_array(v.evenements)
		v.evenements = attente.slice(0, Arene.EVENEMENTS_MAX)
		c.evenements_en_attente = []
	return v


## Chaque joueur avec ses statistiques du moment. Lire les arènes vide leurs évènements : on les
## garde de côté pour la prochaine `vue_arene`, qui les rend.
func vue_globale() -> VueGlobale:
	var g := VueGlobale.new()
	for j: JoueurPartie in _ordre:
		if j.arene != null and not j.fige:
			_lire_statistiques(j)
		var entree := {
			"id": j.id,
			"nom": j.nom,
			"manche": j.manche,
			"eliminations": j.eliminations,
			"degats": j.degats,
			"revenu": j.revenu,
			"vivant": j.en_jeu(),
			"victorieux": j.victorieux,
		}
		g.joueurs.append(entree)
	g.temps_ecoule = temps_ecoule()
	g.en_cours = _demarree and not _terminee
	g.termine = _terminee
	g.classement = _classement.duplicate()
	g.dernier_rempart = _dernier_rempart
	return g


func _joueur(id: int) -> JoueurPartie:
	var v: Variant = _joueurs.get(id)
	return v as JoueurPartie


func _phase_vue(j: JoueurPartie) -> int:
	if j.sans_fin:
		return Types.Phase.MANCHE
	return Types.Phase.VICTOIRE if j.victorieux else _phase


func _temps_restant(j: JoueurPartie) -> float:
	if j.victorieux:
		return 0.0
	if j.sans_fin:
		return float(_pas_manche - j.pas_manche_sans_fin) * _pas_s
	var duree := 0
	match _phase:
		Types.Phase.PREPARATION:
			duree = _pas_preparation
		Types.Phase.MANCHE:
			duree = _pas_manche
		_:
			return 0.0
	return float(duree - _pas_phase) * _pas_s


func _famille_annoncee(j: JoueurPartie) -> int:
	if j.sans_fin:
		return j.famille_suivante_sans_fin
	if _phase == Types.Phase.PREPARATION or _phase == Types.Phase.MANCHE:
		return _famille_suivante
	return -1


## Met à jour les statistiques d'un joueur depuis une vue qu'on vient de lire.
func _enregistrer(j: JoueurPartie, v: VueArene) -> void:
	j.manche = v.manche_max
	j.eliminations = v.eliminations
	j.degats = v.degats_infliges
	j.revenu = v.revenu


func _lire_statistiques(j: JoueurPartie) -> void:
	var v := j.arene.vue(_phase_vue(j), _temps_restant(j), _famille_annoncee(j), j.sans_fin)
	_enregistrer(j, v)
	var place := Arene.EVENEMENTS_MAX - j.evenements_en_attente.size()
	if place > 0:
		j.evenements_en_attente.append_array(v.evenements.slice(0, place))
