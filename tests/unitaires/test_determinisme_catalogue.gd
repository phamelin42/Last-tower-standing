extends CasDeTest
## Reproductibilité du catalogue complet (T9.22, Review Focus 3) : deux parties de même graine, avec
## un robot qui possède les 75 armes et les 87 améliorations (invocations, zones posées, bombes et
## tout le reste), montrent la même vue à chaque pas. Un seul pas qui diverge, sur un tirage ou un
## ordre d'itération, ferait diverger les clients d'une partie en ligne.

const GRAINE := 20261127
const PAS := 600
const PERIODE_BOT := 100

var _d: Donnees


func avant_chaque() -> void:
	# 75 armes et 87 améliorations coûtent plusieurs ms par pas : le test se donne plus de temps.
	delai_max = 60.0
	# Préparation de 3 s et manches de 6 s : les ennemis arrivent dès le pas 60, les armes tirent.
	_d = (
		AidesPartie
		. donnees(
			{
				"partie.json":
				[
					[["preparation_s"], 3.0],
					[["manche_s"], 6.0],
					[["rayon_spawn"], 600.0],
					[["spawn_intervalle_depart"], 0.3],
					[["tour", "pv"], 1.0e12],
				],
			}
		)
	)


## Rend l'empreinte de chaque pas et ce que la partie a montré (alliés, zones, bombes).
func _jouer(graine: int) -> Dictionary:
	var p := AidesPartie.partie(_d, graine, 1)
	var arene: Arene = p._joueur(1).arene
	for id: String in _d.ids_catalogue:
		arene.inventaire.ajouter(id)
	arene.synchroniser()
	var empreintes := PackedInt64Array()
	var vu: Dictionary = {"allies": false, "zones": false, "bombes": false, "evenements": false}
	for pas: int in PAS:
		if pas % PERIODE_BOT == 0:
			BotAchat.jouer(p, 1, 8)
		AidesPartie.pas(p, 1)
		var v := p.vue_arene(1, 1)
		vu["allies"] = vu["allies"] or not v.allies.is_empty()
		vu["zones"] = vu["zones"] or not v.zones.is_empty()
		vu["bombes"] = vu["bombes"] or not v.bombes.is_empty()
		vu["evenements"] = vu["evenements"] or not v.evenements.is_empty()
		empreintes.append(hash(str(v.to_dict())))
	return {"empreintes": empreintes, "vu": vu}


func test_deux_parties_de_meme_graine_et_robot_qui_achete_tout_ont_la_meme_empreinte_sur_600_pas(
) -> void:
	var a := _jouer(GRAINE)
	var b := _jouer(GRAINE)
	var vu: Dictionary = a["vu"]
	for mecanique: String in vu:
		verifier(bool(vu[mecanique]), "la partie a montré : %s" % mecanique)
	var ea: PackedInt64Array = a["empreintes"]
	var eb: PackedInt64Array = b["empreintes"]
	verifier_egal(ea.size(), PAS)
	var premier := -1
	for pas: int in ea.size():
		if ea[pas] != eb[pas]:
			premier = pas
			break
	verifier_egal(premier, -1, "première vue différente au pas %d" % premier)


func test_une_autre_graine_donne_d_autres_empreintes() -> void:
	var a: PackedInt64Array = _jouer(GRAINE)["empreintes"]
	var c: PackedInt64Array = _jouer(GRAINE + 1)["empreintes"]
	var differentes := 0
	for pas: int in a.size():
		if a[pas] != c[pas]:
			differentes += 1
	verifier(
		differentes > PAS / 2, "une autre graine change la plupart des vues (%d)" % differentes
	)
