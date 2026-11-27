extends CasDeTest
## Phil (27/11) : le bouton « Acheter » de la boutique saute un peu au premier clic. Un bouton ne
## doit ni bouger ni changer de taille quand il prend le focus, est survolé ou enfoncé : on mesure
## chaque bouton de la boutique avant et après, par le chemin de la souris et du clavier.

const GRAINE := 2024


func _jeu() -> Jeu:
	var donnees := AidesPartie.donnees()
	var jeu := (load("res://scenes/jeu.tscn") as PackedScene).instantiate() as Jeu
	jeu.chemin_reglages = dossier_temporaire().path_join("reglages.cfg")
	jeu.nom_joueur = "Mina"
	arbre.root.add_child(jeu)
	verifier(jeu.demarrer_solo(donnees, GRAINE, 1.0))
	for i: int in 4:
		jeu.source._process(0.25)
	return jeu


static func _boutons(noeud: Node, sortie: Array[Button]) -> void:
	for enfant: Node in noeud.get_children():
		if enfant is Button and (enfant as Button).is_visible_in_tree():
			sortie.append(enfant as Button)
		_boutons(enfant, sortie)


func _rects(boutons: Array[Button]) -> Array[Rect2]:
	var r: Array[Rect2] = []
	for b: Button in boutons:
		r.append(b.get_global_rect())
	return r


func test_un_bouton_de_la_boutique_ne_bouge_pas_au_focus_au_survol_ni_a_l_appui() -> void:
	var jeu := _jeu()
	await attendre_images(3)
	var boutons: Array[Button] = []
	_boutons(jeu.boutique, boutons)
	verifier(boutons.size() >= 4, "boutons de la boutique : %d" % boutons.size())
	var avant := _rects(boutons)
	for k: int in boutons.size():
		var b := boutons[k]
		b.grab_focus()
		await attendre_images(2)
		verifier_egal(
			_rects(boutons), avant, "focus sur %s (%s)" % [b.text, b.theme_type_variation]
		)
		b.button_down.emit()
		b.set_pressed_no_signal(true)
		await attendre_images(2)
		verifier_egal(_rects(boutons), avant, "appui sur %s" % b.text)
		b.set_pressed_no_signal(false)
		b.release_focus()


## Où tombe l'encre d'un style de bouton dans un rectangle `taille` : le rectangle dessiné (avec
## ses marges d'extension), puis le rectangle d'encre de la texture mis à l'échelle (étirée en
## hauteur, tranches de 40 px en largeur sans étirement).
static func _encre(style: StyleBoxTexture, taille: Vector2) -> Rect2:
	var image := style.texture.get_image()
	var u := Rect2(image.get_used_rect())
	var haut_image := float(image.get_height())
	if style.region_rect.size != Vector2.ZERO:
		# Région rognée en haut : l'encre se lit dans la région, la région remplit le rectangle.
		u.position.y -= style.region_rect.position.y
		haut_image = style.region_rect.size.y
	var dessin := Rect2(
		Vector2(-style.expand_margin_left, -style.expand_margin_top),
		(
			taille
			+ Vector2(
				style.expand_margin_left + style.expand_margin_right,
				style.expand_margin_top + style.expand_margin_bottom
			)
		)
	)
	var echelle_v := dessin.size.y / haut_image
	var gauche := dessin.position.x + u.position.x
	var droite := dessin.end.x - (float(image.get_width()) - u.end.x)
	return Rect2(
		Vector2(gauche, dessin.position.y + u.position.y * echelle_v),
		Vector2(droite - gauche, u.size.y * echelle_v)
	)


## Le pack dessine le bouton enfoncé (et l'inactif) 4 px plus bas, sans l'ombre : sans correction
## le corps du bouton « saute » à l'appui et à chaque achat qui rend une offre trop chère.
func test_le_corps_du_bouton_ne_saute_pas_d_un_etat_a_l_autre() -> void:
	var theme := ThemeJeu.creer()
	var taille := Vector2(220.0, 40.0)
	for type: String in ["Button", ThemeJeu.TYPE_DANGER, ThemeJeu.TYPE_ACHAT]:
		var base := _encre(theme.get_stylebox("normal", type) as StyleBoxTexture, taille)
		for etat: String in ["hover", "pressed", "disabled"]:
			var e := _encre(theme.get_stylebox(etat, type) as StyleBoxTexture, taille)
			var lieu := "%s / %s" % [type, etat]
			verifier_proche(e.position.y, base.position.y, 1.0, lieu + " : haut du corps")
			verifier_proche(e.position.x, base.position.x, 1.0, lieu + " : bord gauche")
			verifier_proche(e.end.x, base.end.x, 1.0, lieu + " : bord droit")
