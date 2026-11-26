extends CasDeTest
## Skins de la tour (T11.6, B5 à B8) : chacun a son sprite dans les bornes, son défi, ses ancrages
## et sa zone de marque dans son cadre, sa licence ; aucun sprite de Tiny Swords n'est retouché.

const BORNES := Vector2i(256, 384)
const SUPERPOSITIONS: Array[String] = ["epines", "mana", "armure", "esquive", "regen", "vol_de_vie"]
const LICENCES: Array[String] = ["CC0 1.0", "CC-BY 3.0", "CC-BY 4.0"]
const PIXELS_TEINTABLES_MIN := 500
## Empreintes SHA-256 des images de Tiny Swords des skins : un fichier retouché change la sienne.
const EMPREINTES := {
	"res://assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Blue.png":
	"2d39450c366fc1ebc0e5a290a860dcf21ebd7d4a22d16eb5cca23e6d4de94ca9",
	"res://assets/tiny_swords/Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Blue.png":
	"c22c288b5bb4f43eeb3054389642dda0d5a7c7bde0f79f15b0ea94282b3818a8",
	"res://assets/tiny_swords/Factions/Goblins/Buildings/Wood_House/Goblin_House.png":
	"5e25c872df37f63e4432230e9c5d762b4de2f34956799d1127cce1963f60e1a9",
	"res://assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Construction.png":
	"e4975c74fcf9874b5298ced752f79dca4c116c4f8a2a22784e0b8985ee81c905",
	"res://assets/tiny_swords/Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_InConstruction.png":
	"349a2b5a33226d59c2408263f94e29bb341065ef916d972fc4ea314f4b6b1c15",
	"res://assets/tiny_swords/Factions/Knights/Buildings/Tower/Tower_Destroyed.png":
	"e92d9ac401698e22171fd054ddcd9ce2f2b41cb5ad171e2a18c92ab511245a70",
	"res://assets/tiny_swords/Factions/Knights/Buildings/House/House_Blue.png":
	"9020e35116ffde6d22a8c854d7117d94e99e19bd582c3c3855ece449d7d2af6d",
	"res://assets/tiny_swords/Resources/Gold Mine/GoldMine_Active.png":
	"c5205d8181d488adce612f8cf5b1546d4bd793d0ab1dd2956aa86d22c861d37f",
}

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


func _cadre(skin: Dictionary, image: Image) -> Rect2i:
	if skin.has("cadre"):
		var c: Dictionary = skin["cadre"]
		return Rect2i(int(c["x"]), int(c["y"]), int(c["largeur"]), int(c["hauteur"]))
	return Rect2i(0, 0, image.get_width(), image.get_height())


func _image(skin: Dictionary) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(String(skin["sprite"])))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Les pixels bleu-vert de Tiny Swords que la teinte du joueur recolore (même règle que
## `tools/composer_skins_tour.py`).
func _pixels_teintables(img: Image, zone: Rect2i) -> int:
	var n := 0
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			var c := img.get_pixel(x, y)
			if c.a >= 0.5 and c.h >= 0.43 and c.h <= 0.68 and c.s > 0.25 and c.v > 0.3:
				n += 1
	return n


func test_chaque_skin_a_son_sprite_dans_les_bornes_de_taille() -> void:
	for id: String in d.skins_tour:
		var skin: Dictionary = d.skins_tour[id]
		var img := _image(skin)
		verifier(img != null, "%s : sprite lisible" % id)
		if img == null:
			continue
		var cadre := _cadre(skin, img)
		verifier(
			Rect2i(Vector2i.ZERO, img.get_size()).encloses(cadre), "%s : cadre dans l'image" % id
		)
		verifier(
			cadre.size.x <= BORNES.x and cadre.size.y <= BORNES.y,
			"%s : %s tient dans %s" % [id, cadre.size, BORNES]
		)


func test_un_skin_par_defi_et_un_defi_par_skin() -> void:
	var skins_des_defis: Dictionary = {}
	for id_defi: String in d.defis:
		skins_des_defis[id_defi] = String((d.defis[id_defi] as Dictionary)["skin"])
	var pris: Dictionary = {}
	for id: String in d.skins_tour:
		if id == "defaut":
			verifier_egal(
				String((d.skins_tour[id] as Dictionary)["defi"]), "", "defaut n'a pas de défi"
			)
			continue
		var defi := String((d.skins_tour[id] as Dictionary)["defi"])
		verifier(skins_des_defis.has(defi), "%s : le défi « %s » existe" % [id, defi])
		verifier_egal(
			String(skins_des_defis.get(defi, "")), id, "%s : le défi débloque ce skin" % id
		)
		verifier(
			not pris.has(defi), "%s : défi %s déjà pris par %s" % [id, defi, pris.get(defi, "")]
		)
		pris[defi] = id


func test_chaque_skin_a_un_ancrage_pour_chacune_des_superpositions_dans_son_cadre() -> void:
	for id: String in d.skins_tour:
		var skin: Dictionary = d.skins_tour[id]
		var img := _image(skin)
		if img == null:
			continue
		var cadre := _cadre(skin, img)
		var ancrages: Dictionary = skin["ancrages"]
		for stat: String in SUPERPOSITIONS:
			var a: Dictionary = ancrages[stat]
			var p := Vector2i(int(a["x"]), int(a["y"]))
			verifier(
				Rect2i(Vector2i.ZERO, cadre.size).has_point(p),
				"%s : ancrage %s dans le cadre" % [id, stat]
			)


func test_chaque_skin_a_une_zone_de_marque_dans_son_cadre_avec_des_pixels_teintables() -> void:
	for id: String in d.skins_tour:
		var skin: Dictionary = d.skins_tour[id]
		var img := _image(skin)
		if img == null:
			continue
		var cadre := _cadre(skin, img)
		var m: Dictionary = skin["marque"]
		var zone := Rect2i(int(m["x"]), int(m["y"]), int(m["largeur"]), int(m["hauteur"]))
		verifier(Rect2i(Vector2i.ZERO, cadre.size).encloses(zone), "%s : marque dans le cadre" % id)
		if String(m["genre"]) == "origine":
			var decalee := Rect2i(zone.position + cadre.position, zone.size)
			verifier(
				_pixels_teintables(img, decalee) >= PIXELS_TEINTABLES_MIN,
				"%s : au moins %d pixels teintables dans la marque" % [id, PIXELS_TEINTABLES_MIN]
			)


func test_chaque_skin_a_une_licence_et_une_source_connues() -> void:
	for id: String in d.skins_tour:
		var skin: Dictionary = d.skins_tour[id]
		verifier(String(skin["licence"]) in LICENCES, "%s : licence CC0 ou CC-BY" % id)
		var sprite := String(skin["sprite"])
		if sprite.begins_with("res://assets/tours/"):
			var sources := FileAccess.get_file_as_string("res://assets/tours/SOURCES.md")
			verifier(
				sources.contains(sprite.get_file()),
				"%s : %s listé dans SOURCES.md" % [id, sprite.get_file()]
			)
		else:
			verifier(
				sprite.begins_with("res://assets/tiny_swords/"),
				"%s : sprite d'une source connue" % id
			)


func test_aucun_fichier_de_tiny_swords_n_a_ete_modifie() -> void:
	for id: String in d.skins_tour:
		var sprite := String((d.skins_tour[id] as Dictionary)["sprite"])
		if not sprite.begins_with("res://assets/tiny_swords/"):
			continue
		verifier(EMPREINTES.has(sprite), "%s : empreinte connue de %s" % [id, sprite])
		verifier_egal(
			FileAccess.get_sha256(sprite),
			String(EMPREINTES.get(sprite, "")),
			"%s : %s inchangé" % [id, sprite]
		)


func test_un_skin_mal_forme_est_refuse() -> void:
	var cas: Dictionary = {
		"sans défi": func(s: Dictionary) -> void: s.erase("defi"),
		"défaut avec un défi": func(s: Dictionary) -> void: s["defi"] = "premier_rempart",
		"sans marque": func(s: Dictionary) -> void: s.erase("marque"),
		"genre de marque inconnu":
		func(s: Dictionary) -> void: (s["marque"] as Dictionary)["genre"] = "tache",
		"marque de largeur nulle":
		func(s: Dictionary) -> void: (s["marque"] as Dictionary)["largeur"] = 0,
		"marque en position négative":
		func(s: Dictionary) -> void: (s["marque"] as Dictionary)["x"] = -1,
		"cadre non entier":
		func(s: Dictionary) -> void: s["cadre"] = {"x": 0.5, "y": 0, "largeur": 8, "hauteur": 8},
		"sans licence": func(s: Dictionary) -> void: s.erase("licence"),
		"sans source": func(s: Dictionary) -> void: s["source"] = "",
	}
	for nom: String in cas:
		var brut := AidesPartie.brut()
		var skins: Dictionary = brut["skins_tour.json"]
		(cas[nom] as Callable).call(skins["defaut"])
		verifier(not Donnees.valider(brut).is_empty(), "refusé : %s" % nom)
	var brut := AidesPartie.brut()
	var skins: Dictionary = brut["skins_tour.json"]
	var autre: Dictionary = (skins["defaut"] as Dictionary).duplicate(true)
	skins["tour_de_guet"] = autre
	verifier(not Donnees.valider(brut).is_empty(), "un skin autre que defaut sans défi est refusé")
