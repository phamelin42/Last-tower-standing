extends CasDeTest
## Le coût d'un pas se juge sur ses mesures les plus rapides : une machine chargée ne fait pas
## échouer un budget respecté, une vraie régression le fait échouer.


func test_une_charge_qui_ralentit_la_plupart_des_mesures_ne_change_pas_le_resultat() -> void:
	var durees := PackedInt32Array()
	for k: int in 100:
		# 3 000 µs au repos ; la charge ajoute de 500 à 4 000 µs à 85 mesures sur 100.
		durees.append(3000 + (500 + (k * 37) % 3500 if k % 20 < 17 else 0))
	verifier_proche(MesurePas.centile_bas_ms(durees), 3.0, 0.0001, "le coût du code, pas la charge")


func test_une_regression_qui_double_le_cout_double_le_resultat() -> void:
	var avant := PackedInt32Array()
	var apres := PackedInt32Array()
	for k: int in 100:
		var charge := (k * 37) % 1500
		avant.append(3000 + charge)
		apres.append(6000 + charge)
	var rapport := MesurePas.centile_bas_ms(apres) / MesurePas.centile_bas_ms(avant)
	verifier(rapport > 1.7, "la régression se voit (×%.2f)" % rapport)


func test_une_mesure_de_plusieurs_pas_se_ramene_au_pas() -> void:
	var durees := PackedInt32Array([8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000])
	verifier_proche(MesurePas.centile_bas_ms(durees, 4), 2.0, 0.0001, "8 ms pour 4 pas : 2 ms")


func test_sans_mesure_le_resultat_est_nul() -> void:
	verifier_egal(MesurePas.centile_bas_ms(PackedInt32Array()), 0.0, "aucune mesure")
	verifier_egal(
		MesurePas.centile_bas_ms(PackedInt32Array([5]), 0), 0.0, "pas par mesure invalide"
	)
