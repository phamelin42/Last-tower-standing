extends SceneTree
## Compose la planche des signatures d'armes que Phil valide : une section par type de dégâts. Les
## armes déjà en jeu (celles qui ont un élément D22, `ElementsArmes`) sont en vignettes de rappel,
## avec leurs sprites ; chaque autre arme qui a une signature a une carte : son nom, son
## projectile, trois images de son impact, sa mécanique, son statut et sa marque (rayons d'un tir
## tournant, disque au sol d'une zone posée, bombe, allié, vulnérabilité). Rien n'est écrit en dur
## par arme : les listes viennent de `SignaturesArmes` et de `data/`, les sprites de
## `tools/dessin/fiches_planche.gd` (une arme sans fiche est montrée par les formes de sa
## signature). Rendu par `Image`, sans fenêtre ni hasard : la même exécution sort les mêmes octets.
##   godot --headless --path . --script res://tools/planche_signatures.gd [-- --sortie <fichier>]
## Avec `--fin-de-partie`, la planche ne montre que les 15 armes de fin de partie (T12.8) : la
## famille existante de chacune, teintée de la teinte de sa rareté (`data/assets.json`,
## `signatures.raretes_tardives`), avec l'insigne de sa rareté.

const Outils := preload("res://tools/dessin/planche_outils.gd")
const Fiches := preload("res://tools/dessin/fiches_planche.gd")
const Commun := preload("res://tools/dessin/dessin_commun.gd")

const SORTIE_DEFAUT := "res://docs/planche_signatures.png"
const SORTIE_FIN_DE_PARTIE := "res://docs/planche_armes_tardives.png"
const OPTION_FIN_DE_PARTIE := "--fin-de-partie"
## Insigne de rareté : plaque de la couleur de la rareté, avec son mot en encre sombre.
const INSIGNE := Vector2i(92, 18)
const ENCRE_INSIGNE := Color("161c2e")
const CARTE := Vector2i(374, 156)
const VIGNETTE := Vector2i(188, 90)
const MARGE: int = 10
const COLONNES_CARTES: int = 3
const COLONNES_VIGNETTES: int = 6
const FOND := Color("161c2e")
const CARTE_FOND := Color("232b45")
const CARTE_BORD := Color("3b4670")
const TEXTE := Color("f2f4ff")
const TEXTE_DISCRET := Color("9aa6d0")
const TEXTE_TITRE := Color("ffe27a")
const CASE := 64
const CASE_PROJECTILE := 56
const TYPES: Array[String] = ["tranchant", "perçant", "magique", "siège", "chaos"]
const NOMS_TYPES: Array[String] = ["Tranchant", "Perçant", "Magique", "Siège", "Chaos"]
const ENTETE: int = 74
const TITRE_TYPE: int = 34
const SOUS_TITRE: int = 22
const ECART_SECTION: int = 18
## Ce que dit la marque d'une mécanique propre, en clair.
const TEXTES_MARQUES: Dictionary = {
	"": "aucune",
	"rayon_tournant": "rayons qui tournent",
	"disque_au_sol": "disque au sol",
	"bombe": "bombe à mèche",
	"allie": "allié invoqué (teinte et anneau)",
	"vulnerabilite": "marqueur de vulnérabilité",
}
const TEXTES_EFFETS: Dictionary = {
	"cible_unique": "cible unique",
	"rebond": "rebond",
	"zone": "zone",
	"aura": "aura",
	"onde": "onde",
	"barrage": "barrage",
	"tournant": "tir tournant",
	"zone_posee": "zone posée",
	"mine": "mine",
	"piege": "piège",
	"bombe": "bombe",
	"invocation": "allié invoqué",
}
## Ce que compte chaque effet à nombre (clé de `data/armes.json` → mot au pluriel).
const NOMBRES_EFFETS: Dictionary = {
	"tournant": ["branches", "branches"],
	"barrage": ["projectiles", "projectiles"],
	"rebond": ["cibles", "cibles"],
}
const COULEUR_ARENE := Commun.VERT_ARENE
## La teinte de l'icône de chaque statut sur la planche.
const COULEURS_STATUTS: Dictionary = {
	"givre": Color(0.7, 0.9, 1.0),
	"poison": Color(0.5, 0.82, 0.35),
	"etourdissement": Color(1.0, 0.88, 0.35),
	"brulure": Color(1.0, 0.55, 0.2),
	"vulnerabilite": Color(1.0, 0.7, 0.3),
	"malediction_toucher": Color(0.75, 0.55, 1.0),
	"malediction_degats": Color(0.9, 0.5, 0.85),
	"repoussement": Color(0.85, 0.9, 1.0),
	"siphon": Color(0.8, 0.6, 1.0),
	"mana_au_coup": Color(0.45, 0.75, 1.0),
}
const COULEUR_STATUT_DEFAUT := Color(0.45, 0.9, 0.5)

var _texte: Outils.Texte = Outils.Texte.new()
var _fin_de_partie: bool = false


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	_fin_de_partie = args.has(OPTION_FIN_DE_PARTIE)
	var sortie: String = ProjectSettings.globalize_path(
		SORTIE_FIN_DE_PARTIE if _fin_de_partie else SORTIE_DEFAUT
	)
	var i: int = 0
	while i < args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
			i += 2
		elif args[i] == OPTION_FIN_DE_PARTIE:
			i += 1
		else:
			printerr("Argument inconnu : %s" % args[i])
			return 1
	if not _texte.charger(Outils.POLICE):
		printerr("Police illisible : %s" % Outils.POLICE)
		return 1
	var donnees: Donnees = Donnees.charger()
	var sections: Array[Dictionary] = _sections(donnees)
	if sections.is_empty():
		printerr("Aucune arme à montrer")
		return 1
	var planche: Image = Image.create(_largeur(), _hauteur(sections), false, Image.FORMAT_RGBA8)
	planche.fill(FOND)
	var titre: String = "Armes de fin de partie" if _fin_de_partie else "Signatures d’armes"
	var sous_titre: String = (
		"Proposition à valider : familles existantes teintées et insigne de rareté, hors jeu."
		if _fin_de_partie
		else "Proposition à valider : le style D22 des armes du lot 9, sans intégration en jeu."
	)
	_texte.ecrire(planche, titre, Vector2i(MARGE, 8), 22, TEXTE)
	_texte.ecrire(planche, sous_titre, Vector2i(MARGE, 40), 13, TEXTE_DISCRET)
	var y: int = ENTETE
	for section: Dictionary in sections:
		y = _dessiner_section(planche, y, section, donnees)
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	var erreur: int = planche.save_png(sortie)
	if erreur != OK:
		printerr("Écriture impossible : %s (%d)" % [sortie, erreur])
		return 1
	print("Planche écrite : %s" % sortie)
	return 0


## Une section par type qui a au moins une arme signée : `{type, rappel, nouvelles}` (ids).
func _sections(donnees: Donnees) -> Array[Dictionary]:
	var par_type: Array[Dictionary] = []
	for _t: String in TYPES:
		par_type.append({"rappel": [] as Array[String], "nouvelles": [] as Array[String]})
	for id: String in SignaturesArmes.ids():
		var rang: int = int((donnees.armes[id] as Dictionary)["type_degats"])
		if _tardive(donnees.armes[id]) != _fin_de_partie:
			continue
		if rang < 0 or rang >= TYPES.size():
			printerr("Type inconnu : %s" % id)
			return []
		var en_jeu: bool = ElementsArmes.de(id) != "" and not _fin_de_partie
		var cle: String = "rappel" if en_jeu else "nouvelles"
		(par_type[rang][cle] as Array[String]).append(id)
	var sections: Array[Dictionary] = []
	for rang: int in TYPES.size():
		var rappel: Array[String] = par_type[rang]["rappel"]
		var nouvelles: Array[String] = par_type[rang]["nouvelles"]
		if not rappel.is_empty() or not nouvelles.is_empty():
			sections.append({"type": rang, "rappel": rappel, "nouvelles": nouvelles})
	return sections


func _largeur() -> int:
	return (
		MARGE
		+ maxi(
			COLONNES_VIGNETTES * (VIGNETTE.x + 4),
			COLONNES_CARTES * (CARTE.x + MARGE),
		)
	)


func _hauteur(sections: Array[Dictionary]) -> int:
	var y: int = ENTETE
	for section: Dictionary in sections:
		y += _hauteur_section(section)
	return y + MARGE


func _hauteur_section(section: Dictionary) -> int:
	var h: int = TITRE_TYPE + ECART_SECTION
	var rappel: int = (section["rappel"] as Array).size()
	var nouvelles: int = (section["nouvelles"] as Array).size()
	if rappel > 0:
		var lignes: int = ceili(float(rappel) / COLONNES_VIGNETTES)
		h += SOUS_TITRE + lignes * (VIGNETTE.y + 4) + 6
	if nouvelles > 0:
		var lignes: int = ceili(float(nouvelles) / COLONNES_CARTES)
		h += SOUS_TITRE + lignes * (CARTE.y + MARGE)
	return h


func _dessiner_section(planche: Image, y0: int, section: Dictionary, donnees: Donnees) -> int:
	var y: int = y0
	_texte.ecrire(planche, NOMS_TYPES[section["type"]], Vector2i(MARGE, y), 20, TEXTE_TITRE)
	y += TITRE_TYPE
	var rappel: Array = section["rappel"]
	if not rappel.is_empty():
		_texte.ecrire(planche, "Déjà en jeu (lot 8, rappel)", Vector2i(MARGE, y), 13, TEXTE_DISCRET)
		y += SOUS_TITRE
		for k: int in rappel.size():
			var id: String = rappel[k]
			var x: int = MARGE + (k % COLONNES_VIGNETTES) * (VIGNETTE.x + 4)
			var haut: int = y + (k / COLONNES_VIGNETTES) * (VIGNETTE.y + 4)
			_vignette(planche, Vector2i(x, haut), id, donnees.armes[id])
		y += ceili(float(rappel.size()) / COLONNES_VIGNETTES) * (VIGNETTE.y + 4) + 6
	var nouvelles: Array = section["nouvelles"]
	if not nouvelles.is_empty():
		var legende: String = (
			"Fin de partie (T12.7)" if _fin_de_partie else "Nouvelles armes (lot 9)"
		)
		_texte.ecrire(planche, legende, Vector2i(MARGE, y), 13, TEXTE_DISCRET)
		y += SOUS_TITRE
		for k: int in nouvelles.size():
			var id: String = nouvelles[k]
			var x: int = MARGE + (k % COLONNES_CARTES) * (CARTE.x + MARGE)
			var haut: int = y + (k / COLONNES_CARTES) * (CARTE.y + MARGE)
			_carte(planche, Vector2i(x, haut), id, donnees.armes[id])
		y += ceili(float(nouvelles.size()) / COLONNES_CARTES) * (CARTE.y + MARGE)
	return y + ECART_SECTION


## Un cadre de carte : bord puis fond.
func _cadre(planche: Image, origine: Vector2i, taille: Vector2i) -> void:
	planche.fill_rect(Rect2i(origine, taille), CARTE_BORD)
	planche.fill_rect(Rect2i(origine + Vector2i(2, 2), taille - Vector2i(4, 4)), CARTE_FOND)


## Une case d'herbe où poser un sprite, comme dans l'arène.
func _case(planche: Image, rect: Rect2i) -> void:
	planche.fill_rect(rect, COULEUR_ARENE)


## Le rappel d'une arme du lot 8 : son nom, son projectile et deux images de son impact.
func _vignette(planche: Image, origine: Vector2i, id: String, arme: Dictionary) -> void:
	_cadre(planche, origine, VIGNETTE)
	_texte.ecrire(planche, String(arme["nom"]), origine + Vector2i(8, 4), 11, TEXTE)
	var s: Dictionary = SignaturesArmes.de(id)
	var fiche: Dictionary = Fiches.de(id)
	var y: int = origine.y + 22
	var projectile: Rect2i = Rect2i(Vector2i(origine.x + 4, y), Vector2i(CASE_PROJECTILE - 8, CASE))
	_case(planche, projectile)
	var image: Image = _image_projectile(fiche, s, projectile.size.x)
	if image != null:
		Outils.poser_centree(planche, image, projectile)
	var impacts: Array[Image] = _images_impact(fiche, s)
	var depart: int = origine.x + 4 + projectile.size.x + 4
	var reste: int = mini(2, impacts.size())
	for k: int in reste:
		var case: Rect2i = Rect2i(Vector2i(depart + k * (CASE + 4), y), Vector2i(CASE, CASE))
		_case(planche, case)
		Outils.poser_centree(planche, impacts[impacts.size() - reste + k], case)


## La carte d'une arme du lot 9.
func _carte(planche: Image, origine: Vector2i, id: String, arme: Dictionary) -> void:
	_cadre(planche, origine, CARTE)
	var s: Dictionary = SignaturesArmes.de(id)
	var fiche: Dictionary = Fiches.de(id)
	var teinte: Color = _teinte_rarete(arme)
	_texte.ecrire(planche, String(arme["nom"]), origine + Vector2i(10, 8), 14, TEXTE)
	_pastille_statut(planche, origine + Vector2i(CARTE.x - 26, 18), s)
	if _tardive(arme):
		_insigne(planche, origine + Vector2i(CARTE.x - INSIGNE.x - 40, 6), int(arme["rarete"]))
	var y: int = origine.y + 30
	var projectile: Rect2i = Rect2i(Vector2i(origine.x + 10, y), Vector2i(CASE, CASE))
	_case(planche, projectile)
	var image: Image = _image_projectile(fiche, s, CASE_PROJECTILE, teinte)
	if image != null:
		Outils.poser_centree(planche, image, projectile)
	var impacts: Array[Image] = _images_impact(fiche, s, teinte)
	for k: int in impacts.size():
		var case: Rect2i = Rect2i(
			Vector2i(origine.x + 10 + (CASE + 4) * (k + 1) + 6, y), Vector2i(CASE, CASE)
		)
		_case(planche, case)
		Outils.poser_centree(planche, impacts[k], case)
	var case_marque: Rect2i = Rect2i(
		Vector2i(origine.x + CARTE.x - 10 - CASE, y), Vector2i(CASE, CASE)
	)
	var marque: Image = _image_marque(s, fiche, arme)
	if marque != null:
		_case(planche, case_marque)
		Outils.poser_centree(planche, marque, case_marque)
	var bas: int = y + CASE + 6
	_texte.ecrire(
		planche, "mécanique : " + _mecanique(arme), Vector2i(origine.x + 10, bas), 12, TEXTE_DISCRET
	)
	_texte.ecrire(
		planche, "statut : " + _statuts(arme), Vector2i(origine.x + 10, bas + 16), 12, TEXTE_DISCRET
	)
	_texte.ecrire(
		planche,
		"marque : " + _texte_marque(s, arme),
		Vector2i(origine.x + 10, bas + 32),
		12,
		TEXTE_DISCRET
	)


## La marque en clair ; un tir tournant dit son sens.
func _texte_marque(s: Dictionary, arme: Dictionary) -> String:
	var marque: String = String(s["marque"])
	var texte: String = String(TEXTES_MARQUES.get(marque, ""))
	if marque == "rayon_tournant":
		var sens: String = String(_parametre(arme, "tournant", "sens", ""))
		if sens != "":
			texte += ", sens %s" % sens
	return texte


## Le projectile : l'image 1 de sa planche, teintée, ou la forme de la signature sans fiche ;
## `null` pour une arme sans projectile (aura, onde).
func _image_projectile(
	fiche: Dictionary, s: Dictionary, cote: int, teinte_rarete: Color = Fiches.SANS
) -> Image:
	if fiche.is_empty():
		var forme: Image = FormesSignatures.image(String(s["projectile"]))
		return Outils.teinter(forme, s["couleur"])
	var nom: String = String(fiche["projectile"])
	if nom == "":
		return null
	var image: Image = Outils.image_de(nom, 0)
	image = Outils.teinter(image, fiche.get("teinte", Fiches.SANS))
	image = Outils.teinter(image, teinte_rarete)
	return Outils.agrandir(image, Outils.echelle_pour(image, cote))


## Trois images de l'impact (le début, le milieu, la fin), ou la forme de la signature sans fiche.
func _images_impact(
	fiche: Dictionary, s: Dictionary, teinte_rarete: Color = Fiches.SANS
) -> Array[Image]:
	var images: Array[Image] = []
	if fiche.is_empty():
		images.append(Outils.teinter(FormesSignatures.image(String(s["impact"])), s["couleur"]))
		return images
	var nom: String = String(fiche["impact"])
	for rang: int in Fiches.images_impact(Outils.nombre_images(nom)):
		var image: Image = Outils.teinter(Outils.image_de(nom, rang), teinte_rarete)
		images.append(Outils.agrandir(image, Outils.echelle_pour(image, CASE)))
	return images


## La marque de la mécanique propre de l'arme, `null` sans marque.
func _image_marque(s: Dictionary, fiche: Dictionary, arme: Dictionary) -> Image:
	var teinte: Color = (s["couleur"] as Color).lerp(Color.WHITE, 0.3)
	match String(s["marque"]):
		"rayon_tournant":
			var branches: int = int(_parametre(arme, "tournant", "branches", 4))
			var rang: int = clampi(branches - 2, 0, Outils.nombre_images("rayons") - 1)
			return Outils.agrandir(Outils.teinter(Outils.image_de("rayons", rang), teinte), 2)
		"disque_au_sol":
			var nom: String = String(fiche.get("disque", "disque_rune"))
			var dernier: int = Outils.nombre_images(nom) - 1
			return Outils.agrandir(Outils.image_de(nom, dernier), 2)
		"vulnerabilite":
			return Outils.agrandir(Outils.image_de("vulnerable", 1), 4)
		"bombe":
			return Outils.agrandir(Outils.image_de("bombe_meche", 2), 3)
		"allie":
			return Outils.agrandir(Outils.teinter(Outils.image_de("allie", 0), teinte), 2)
	return null


## Le paramètre `cle` de l'effet `kind` de l'arme, `defaut` s'il manque.
func _parametre(arme: Dictionary, kind: String, cle: String, defaut: Variant) -> Variant:
	for effet: Variant in arme["effets"]:
		if String((effet as Dictionary)["kind"]) == kind:
			return (effet as Dictionary).get(cle, defaut)
	return defaut


## « tir tournant · 4 branches », « barrage · 6 projectiles »…
func _mecanique(arme: Dictionary) -> String:
	var parts: PackedStringArray = []
	for effet: Variant in arme["effets"]:
		var e: Dictionary = effet
		var kind: String = String(e["kind"])
		var texte: String = String(TEXTES_EFFETS.get(kind, kind))
		if NOMBRES_EFFETS.has(kind):
			var cle: String = String((NOMBRES_EFFETS[kind] as Array)[0])
			var nombre: int = int(e.get(_cle_nombre(kind), 0))
			if nombre > 0:
				texte += " (%d %s)" % [nombre, cle]
		parts.append(texte)
	return ", ".join(parts)


## La clé de `data/armes.json` qui porte le nombre de chaque effet à nombre.
func _cle_nombre(kind: String) -> String:
	match kind:
		"tournant":
			return "branches"
		"barrage":
			return "projectiles"
	return "cibles"


func _statuts(arme: Dictionary) -> String:
	var libelles: PackedStringArray = []
	for statut: Variant in arme["statuts"]:
		var libelle: String = SignaturesArmes.libelle_statut(String((statut as Dictionary)["kind"]))
		libelles.append(libelle if libelle != "" else String((statut as Dictionary)["kind"]))
	return "aucun" if libelles.is_empty() else ", ".join(libelles)


## L'icône du statut principal de la signature, dans un coin de la carte.
func _pastille_statut(planche: Image, centre: Vector2i, s: Dictionary) -> void:
	var statut: String = String(s["statut"])
	if statut == "":
		return
	var forme: Image = FormesSignatures.image(String(SignaturesArmes.STATUTS[statut]))
	forme = Outils.teinter(forme, COULEURS_STATUTS.get(statut, COULEUR_STATUT_DEFAUT))
	forme.resize(28, 28, Image.INTERPOLATE_BILINEAR)
	for y: int in forme.get_height():
		for x: int in forme.get_width():
			var p: Color = forme.get_pixel(x, y)
			if p.a > 0.0:
				Outils.melanger(planche, centre - forme.get_size() / 2 + Vector2i(x, y), p)


## Vrai pour une arme de fin de partie (rareté ancestrale ou souveraine).
func _tardive(arme: Dictionary) -> bool:
	return int(arme["rarete"]) >= Types.Rarete.ANCESTRALE


## La teinte de fin de partie de la rareté de l'arme (`data/assets.json`), blanche pour les autres.
func _teinte_rarete(arme: Dictionary) -> Color:
	if not _tardive(arme):
		return Fiches.SANS
	var table: Dictionary = Assets.typee("signatures").get("raretes_tardives", {})
	var nom: String = Types.NOMS_RARETES[int(arme["rarete"])]
	return (table.get(nom, {}) as Dictionary).get("teinte", Fiches.SANS)


## L'insigne de rareté : une plaque de la couleur de la rareté et son mot, en encre sombre.
func _insigne(planche: Image, origine: Vector2i, rarete: int) -> void:
	planche.fill_rect(Rect2i(origine, INSIGNE), Apparence.couleur_rarete(rarete))
	var mot: String = TranslationServer.translate(Apparence.cle_libelle_rarete(rarete))
	_texte.ecrire(planche, mot, origine + Vector2i(6, 2), 13, ENCRE_INSIGNE)
