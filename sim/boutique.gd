class_name Boutique
extends RefCounted
## La boutique d'une arène : quatre offres tirées selon les poids de rareté de la manche,
## achat, relance au coût croissant, vente à moitié prix et marché noir.

## Entrées `{id, genre, rarete, prix, vendu}`.
var offres: Array[Dictionary] = []
## Prix de la prochaine relance payante.
var cout_relance: int = 0

var _donnees: Donnees
var _rng: RandomNumberGenerator
var _manche: int = 1
var _relances_payees: int = 0
var _nb_offres: int
var _cout_depart: int
var _increment: int
## Rareté → ids du catalogue (armes puis améliorations, dans l'ordre des fichiers).
var _candidats: Array[PackedStringArray] = []


func _init(donnees: Donnees, rng: RandomNumberGenerator) -> void:
	_donnees = donnees
	_rng = rng
	_nb_offres = int(donnees.partie["nb_offres"])
	var relance: Dictionary = donnees.boutique["relance"]
	_cout_depart = int(relance["cout_depart"])
	_increment = int(relance["increment"])
	cout_relance = _cout_depart
	for _r: int in Types.NOMS_RARETES.size():
		_candidats.append(PackedStringArray())
	for id: String in donnees.armes:
		_candidats[_rarete_de(donnees.armes[id])].append(id)
	for id: String in donnees.ameliorations:
		_candidats[_rarete_de(donnees.ameliorations[id])].append(id)


## Les relances gratuites sont passées à `relancer` à chaque appel : la boutique ne les mémorise
## pas.
func nouvelle_manche(manche: int, _relances_gratuites: int) -> void:
	_relances_payees = 0
	cout_relance = _cout_depart
	tirer(manche)


func tirer(manche: int) -> void:
	_manche = manche
	offres.clear()
	var pris: Dictionary = {}
	for _i: int in _nb_offres:
		var id := _tirer_un(manche, pris)
		if id == "":
			break
		pris[id] = true
		offres.append(_offre(id))


func acheter(index: int, economie: Economie, inventaire: Inventaire) -> int:
	if index < 0 or index >= offres.size():
		return Types.Resultat.INDICE_INVALIDE
	var offre := offres[index]
	if bool(offre["vendu"]):
		return Types.Resultat.DEJA_ACHETE
	var est_arme := int(offre["genre"]) == Types.Genre.ARME
	# Tout est vérifié avant de payer : un refus ne débite jamais.
	if est_arme and inventaire.armes.size() >= Inventaire.ARMES_MAX:
		return Types.Resultat.ARMES_AU_MAXIMUM
	if not economie.peut_payer(int(offre["prix"])):
		return Types.Resultat.OR_INSUFFISANT
	# La charge de copie se lit avant l'achat : l'objet acheté ne se double pas lui-même.
	var copie := inventaire.copie_disponible(int(offre["rarete"]))
	var resultat := inventaire.ajouter(str(offre["id"]))
	if resultat != Types.Resultat.OK:
		return resultat
	economie.payer(int(offre["prix"]))
	offre["vendu"] = true
	# Le second exemplaire est gratuit ; une arme sans place pour lui n'en consomme pas la charge.
	if copie and inventaire.ajouter(str(offre["id"])) == Types.Resultat.OK:
		inventaire.copies_utilisees += 1
	return Types.Resultat.OK


## Une relance gratuite passe avant l'or et ne fait pas monter le coût.
func relancer(economie: Economie, relances_gratuites: int) -> Array:
	if relances_gratuites > 0:
		tirer(_manche)
		return [Types.Resultat.OK, relances_gratuites - 1]
	if not economie.payer(cout_relance):
		return [Types.Resultat.OR_INSUFFISANT, relances_gratuites]
	_relances_payees += 1
	cout_relance = _cout_depart + _relances_payees * _increment
	tirer(_manche)
	return [Types.Resultat.OK, relances_gratuites]


func vendre(index_arme: int, economie: Economie, inventaire: Inventaire) -> int:
	if index_arme < 0 or index_arme >= inventaire.armes.size():
		return Types.Resultat.INDICE_INVALIDE
	var prix := inventaire.prix_vente(index_arme)
	inventaire.retirer_arme(index_arme)
	economie.gagner(prix)
	return Types.Resultat.OK


## Ids des améliorations de rareté ≤ `marche_noir.raretes_max`, triés.
func choix_marche_noir(donnees: Donnees) -> PackedStringArray:
	var noir: Dictionary = donnees.boutique["marche_noir"]
	var max_rarete := Types.rarete_depuis_nom(str(noir["raretes_max"]))
	var choix := PackedStringArray()
	for id: String in donnees.ameliorations:
		if _rarete_de(donnees.ameliorations[id]) <= max_rarete:
			choix.append(id)
	choix.sort()
	return choix


## Gratuit : le jeton, payé à l'achat de l'objet qui le donne, tient lieu de prix.
func acheter_marche_noir(id: String, _economie: Economie, inventaire: Inventaire) -> int:
	var disponibles := inventaire.stats().marche_noir - inventaire.jetons_marche_noir_utilises
	if disponibles <= 0:
		return Types.Resultat.NON_DISPONIBLE
	if not choix_marche_noir(_donnees).has(id):
		return Types.Resultat.OFFRE_INVALIDE
	var resultat := inventaire.ajouter(id)
	if resultat == Types.Resultat.OK:
		inventaire.jetons_marche_noir_utilises += 1
	return resultat


func _offre(id: String) -> Dictionary:
	var est_arme := _donnees.armes.has(id)
	var fiche: Dictionary = _donnees.armes[id] if est_arme else _donnees.ameliorations[id]
	return {
		"id": id,
		"genre": Types.Genre.ARME if est_arme else Types.Genre.AMELIORATION,
		"rarete": _rarete_de(fiche),
		"prix": int(fiche["prix"]),
		"vendu": false,
	}


## Rareté selon les poids de la manche, puis objet uniforme parmi ceux pas encore pris.
## Une rareté sans objet disponible est retirée du tirage. Vide si plus rien n'est tirable.
func _tirer_un(manche: int, pris: Dictionary) -> String:
	var table: Array = _donnees.boutique["poids"]
	var poids: Array[float] = []
	var reste: Array[PackedStringArray] = []
	var total := 0.0
	var tout_reste := 0
	for r: int in Types.NOMS_RARETES.size():
		var libres := PackedStringArray()
		for id: String in _candidats[r]:
			if not pris.has(id):
				libres.append(id)
		reste.append(libres)
		tout_reste += libres.size()
		var p := 0.0
		if not libres.is_empty():
			p = maxf(0.0, _donnees.palier(table, manche, Types.NOMS_RARETES[r]))
		poids.append(p)
		total += p
	if tout_reste == 0:
		return ""
	if total <= 0.0:
		# Les raretés encore disponibles ont toutes un poids nul : la boutique ne reste pas vide.
		for r: int in poids.size():
			if not reste[r].is_empty():
				poids[r] = 1.0
				total += 1.0
	var tirage := _rng.randf() * total
	var choisie := -1
	for r: int in poids.size():
		if poids[r] <= 0.0:
			continue
		choisie = r
		tirage -= poids[r]
		if tirage < 0.0:
			break
	return _choisir_selon_genre(reste[choisie], manche)


## Objet de la rareté tirée, pondéré par le poids de genre de la manche (arme ou amélioration) ;
## sans table `poids_genre`, tirage uniforme. Un poids nul n'exclut un genre que s'il reste
## un objet de l'autre.
func _choisir_selon_genre(libres: PackedStringArray, manche: int) -> String:
	if not _donnees.boutique.has("poids_genre"):
		return libres[_rng.randi_range(0, libres.size() - 1)]
	var table: Array = _donnees.boutique["poids_genre"]
	var poids_arme := maxf(0.0, _donnees.palier(table, manche, "arme"))
	var poids_amelioration := maxf(0.0, _donnees.palier(table, manche, "amelioration"))
	var poids: Array[float] = []
	var total := 0.0
	for id: String in libres:
		var p := poids_arme if _donnees.armes.has(id) else poids_amelioration
		poids.append(p)
		total += p
	if total <= 0.0:
		return libres[_rng.randi_range(0, libres.size() - 1)]
	var tirage := _rng.randf() * total
	for i: int in libres.size():
		tirage -= poids[i]
		if tirage < 0.0 and poids[i] > 0.0:
			return libres[i]
	for i: int in range(libres.size() - 1, -1, -1):
		if poids[i] > 0.0:
			return libres[i]
	return libres[0]


static func _rarete_de(fiche: Dictionary) -> int:
	return int(fiche["rarete"])
