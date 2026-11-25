extends CasDeTest
## Classement : manche atteinte, puis dégâts, puis identifiant ; mention « Dernier rempart ».

const D := Classement.Cause.DEFAITE
const X := Classement.Cause.DECONNEXION
const V := Classement.Cause.VICTOIRE


func _e(id: int, manche: int, degats: float, pas: int, cause: int) -> Dictionary:
	return {"id": id, "manche": manche, "degats": degats, "pas_fin": pas, "cause": cause}


func test_classement_par_manche_puis_degats_puis_id() -> void:
	var entrees: Array[Dictionary] = [
		_e(4, 5, 100.0, 10, D),
		_e(2, 7, 10.0, 20, D),
		_e(9, 5, 300.0, 11, D),
		_e(3, 5, 100.0, 12, D),
		_e(1, 5, 100.0, 13, D),
	]
	verifier_egal(Classement.ordonner(entrees), [2, 9, 1, 3, 4])


func test_le_classement_ne_depend_pas_de_l_ordre_des_entrees() -> void:
	var entrees: Array[Dictionary] = [_e(1, 3, 5.0, 1, D), _e(2, 3, 5.0, 1, D), _e(3, 4, 0.0, 2, D)]
	var attendu := Classement.ordonner(entrees)
	entrees.reverse()
	verifier_egal(Classement.ordonner(entrees), attendu)
	verifier_egal(attendu, [3, 1, 2])


func test_classement_vide() -> void:
	verifier_egal(Classement.ordonner([]), [])
	verifier_egal(Classement.dernier_rempart([]), -1)


func test_dernier_rempart_est_le_dernier_a_tomber_apres_d_autres() -> void:
	var entrees: Array[Dictionary] = [
		_e(1, 3, 0.0, 100, D), _e(2, 6, 0.0, 300, D), _e(3, 4, 0.0, 200, D)
	]
	verifier_egal(Classement.dernier_rempart(entrees), 2)


func test_pas_de_dernier_rempart_en_solo() -> void:
	var entrees: Array[Dictionary] = [_e(1, 9, 0.0, 100, D)]
	verifier_egal(Classement.dernier_rempart(entrees), -1)


func test_pas_de_dernier_rempart_si_les_deux_derniers_tombent_au_meme_pas() -> void:
	var entrees: Array[Dictionary] = [
		_e(1, 3, 0.0, 100, D), _e(2, 6, 0.0, 300, D), _e(3, 6, 0.0, 300, D)
	]
	verifier_egal(Classement.dernier_rempart(entrees), -1)


func test_pas_de_dernier_rempart_si_le_dernier_est_parti() -> void:
	var entrees: Array[Dictionary] = [_e(1, 3, 0.0, 100, D), _e(2, 6, 0.0, 300, X)]
	verifier_egal(Classement.dernier_rempart(entrees), -1)


func test_pas_de_dernier_rempart_si_quelqu_un_a_vaincu_le_boss() -> void:
	var entrees: Array[Dictionary] = [
		_e(1, 31, 0.0, 100, V), _e(2, 20, 0.0, 300, D), _e(3, 5, 0.0, 50, D)
	]
	verifier_egal(Classement.dernier_rempart(entrees), -1)
