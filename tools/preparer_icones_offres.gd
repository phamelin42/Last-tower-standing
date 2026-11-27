extends SceneTree
## Rastérise les icônes de game-icons.net (CC BY 3.0, Lorc et Delapouite) listées par
## `tools/icones_offres.json` : blanc sur fond transparent, `TAILLE` px, sous
## `assets/icones/game_icons/`.
## Usage : godot --headless --path . --script res://tools/preparer_icones_offres.gd -- <dossier du
## dépôt game-icons/icons>. Le blanc se teinte dans l'interface par `modulate`.

const TAILLE := 32
const SORTIE := "res://assets/icones/game_icons/"
## Le fond noir que chaque fichier source dessine en premier.
const FOND := '<path d="M0 0h512v512H0z"/>'


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("dossier source manquant")
		quit(1)
		return
	var liste: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/icones_offres.json")
	)
	var n := 0
	for groupe: String in liste:
		for id: String in liste[groupe]:
			var source := String((liste[groupe] as Dictionary)[id])
			var svg := FileAccess.get_file_as_string("%s/%s.svg" % [args[0], source])
			svg = svg.replace(FOND, "").replace("<path ", '<path fill="#fff" ')
			var image := Image.new()
			var erreur := image.load_svg_from_string(svg, float(TAILLE) / 512.0)
			if erreur != OK:
				push_error("%s : svg illisible" % source)
				continue
			image.save_png(ProjectSettings.globalize_path(SORTIE + source.get_file() + ".png"))
			n += 1
	print("%d icônes écrites" % n)
	quit(0)
