extends CasDeTest
## Phil n'entend plus rien (27/11) : en solo, une partie qui avance doit jouer des sons, par le
## chemin complet du jeu (source → vue → `LecteurSons` → bus), et le bus principal doit les
## laisser passer.

const GRAINE := 2024
const PAS := 0.25
const PAS_MAX := 400


func test_une_partie_solo_joue_des_sons_audibles() -> void:
	var donnees := AidesPartie.donnees({"economie.json": [[["or_depart"], 1000000]]})
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	verifier(jeu.demarrer_solo(donnees, GRAINE, 1.0))
	var sons := {}
	jeu.source.acheter(0)
	for i: int in PAS_MAX:
		jeu.source._process(PAS)
		var lecteur := jeu.get_node("Sons") as LecteurSons
		for s: String in lecteur.derniers_sons:
			sons[s] = true
	verifier(sons.keys().any(func(x: String) -> bool: return x.begins_with("tir")), "aucun tir")
	verifier(sons.size() > 0, "aucun son joué en %d pas" % PAS_MAX)
	for s: String in sons:
		verifier_faux(CatalogueSons.est_substitution(s), s + " : substitution")
	verifier_faux(AudioServer.is_bus_mute(0), "bus principal muet")
