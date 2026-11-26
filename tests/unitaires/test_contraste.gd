extends CasDeTest
## Tout texte de l'interface se lit : au moins 4,5:1 sur son fond (WCAG AA). Les couleurs de
## rareté et d'armure se mesurent sur le fond des cartes et des panneaux, la couleur de base du
## texte sur chaque fond où elle se pose. La rareté et l'armure gardent en plus leur symbole et
## leur libellé : la couleur ne porte jamais l'information seule.

const SEUIL := 4.5
const NB_RARETES := 4
const NB_ARMURES := 6


## Fonds sur lesquels un texte de rareté ou d'armure peut se poser.
func _fonds_de_texte_colore() -> Dictionary:
	return {"carte": ThemeJeu.ENCRE_CARTE, "panneau": ThemeJeu.ENCRE}


func test_chaque_rarete_se_lit_sur_chaque_fond_de_carte_et_de_panneau() -> void:
	var fonds := _fonds_de_texte_colore()
	for r: int in range(NB_RARETES):
		for nom: String in fonds:
			var fond: Color = fonds[nom]
			var c := ThemeJeu.contraste(Apparence.couleur_rarete(r), fond)
			verifier(c >= SEUIL, "rareté %d sur %s : %.2f:1 sous %.1f:1" % [r, nom, c, SEUIL])


func test_chaque_armure_se_lit_sur_chaque_fond_de_carte_et_de_panneau() -> void:
	var fonds := _fonds_de_texte_colore()
	for a: int in range(NB_ARMURES):
		for nom: String in fonds:
			var fond: Color = fonds[nom]
			var c := ThemeJeu.contraste(Apparence.couleur_texte_armure(a), fond)
			verifier(c >= SEUIL, "armure %d sur %s : %.2f:1 sous %.1f:1" % [a, nom, c, SEUIL])


func test_le_fond_de_reference_des_raretes_est_celui_des_cartes() -> void:
	verifier_egal(Apparence.FOND_INTERFACE, ThemeJeu.ENCRE_CARTE)


func test_le_texte_de_base_se_lit_sur_chaque_fond_ou_il_se_pose() -> void:
	var fonds: Array[Color] = [
		ThemeJeu.ENCRE,
		ThemeJeu.ENCRE_CARTE,
		ThemeJeu.ENCRE_BOUTON,
		ThemeJeu.ENCRE_SURVOL,
		ThemeJeu.ENCRE_APPUI,
		ThemeJeu.JAUGE_FOND,
		ThemeJeu.JAUGE_PLEINE,
		ThemeJeu.JAUGE_BASSE,
	]
	for i: int in fonds.size():
		var c := ThemeJeu.contraste(ThemeJeu.PARCHEMIN, fonds[i])
		verifier(c >= SEUIL, "parchemin sur le fond %d : %.2f:1" % [i, c])


func test_les_textes_secondaires_et_les_titres_se_lisent_sur_les_panneaux() -> void:
	var textes: Dictionary = {
		"attenue": ThemeJeu.PARCHEMIN_ATTENU,
		"titre": ThemeJeu.LAITON_CLAIR,
	}
	for nom: String in textes:
		var couleur: Color = textes[nom]
		for fond: Color in [ThemeJeu.ENCRE, ThemeJeu.ENCRE_CARTE, ThemeJeu.JAUGE_FOND]:
			var c := ThemeJeu.contraste(couleur, fond)
			verifier(c >= SEUIL, "texte %s : %.2f:1" % [nom, c])


func test_un_bouton_inactif_reste_lisible() -> void:
	var c := ThemeJeu.contraste(ThemeJeu.TEXTE_INACTIF, ThemeJeu.ENCRE_INACTIF)
	verifier(c >= SEUIL, "bouton inactif : %.2f:1" % c)


## Contrôle négatif : la mesure sait dire qu'un texte est illisible (l'ancienne couleur de la
## rareté commune sur le fond sombre des cartes).
func test_la_mesure_refuse_un_texte_illisible() -> void:
	verifier(ThemeJeu.contraste(Color("#4a4458"), ThemeJeu.ENCRE_CARTE) < SEUIL)
	verifier_proche(ThemeJeu.contraste(Color.WHITE, Color.BLACK), 21.0, 0.01, "blanc sur noir")


func test_rarete_et_armure_gardent_leur_symbole_et_leur_libelle() -> void:
	for r: int in range(NB_RARETES):
		verifier(not Apparence.symbole_rarete(r).is_empty(), "rareté %d : symbole" % r)
		verifier(not Apparence.cle_libelle_rarete(r).is_empty(), "rareté %d : libellé" % r)
	for a: int in range(NB_ARMURES):
		verifier(not Apparence.symbole_armure(a).is_empty(), "armure %d : symbole" % a)
		verifier(not Apparence.cle_libelle_armure(a).is_empty(), "armure %d : libellé" % a)


## T8.18 : les valeurs de la barre du haut (texte de base) et les chiffres du tableau des scores
## (panneau) gardent le contraste AA ; les en-têtes du tableau sont des titres de panneau.
func test_les_textes_de_la_barre_et_du_tableau_gardent_un_contraste_aa() -> void:
	var textes: Dictionary = {
		"valeur de la barre": ThemeJeu.PARCHEMIN,
		"chiffre du tableau": ThemeJeu.PARCHEMIN,
		"en-tête secondaire": ThemeJeu.PARCHEMIN_ATTENU,
	}
	var fonds: Dictionary = {"barre": ThemeJeu.ENCRE, "panneau": ThemeJeu.ENCRE}
	for nom: String in textes:
		for fond: String in fonds:
			var c := ThemeJeu.contraste(textes[nom], fonds[fond])
			verifier(c >= SEUIL, "%s sur le fond de la %s : %.2f:1" % [nom, fond, c])
