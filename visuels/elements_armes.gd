class_name ElementsArmes
extends RefCounted
## L'élément visuel des armes dont Phil juge les attaques (D22) : feu, glace, bombe, poison, foudre
## ou arcane. Une arme absente de la table garde le rendu par signature d'aujourd'hui (`de()` rend
## `""`) : les autres armes ne changent pas tant que Phil n'a pas validé la proposition.

const FEU: String = "feu"
const GLACE: String = "glace"
const BOMBE: String = "bombe"
const POISON: String = "poison"
const FOUDRE: String = "foudre"
const ARCANE: String = "arcane"

const ELEMENTS: Array[String] = [FEU, GLACE, BOMBE, POISON, FOUDRE, ARCANE]

## id d'arme → élément.
const TABLE: Dictionary = {
	"canon_de_cloche": FEU,
	"orbe_de_brume": GLACE,
	"bombarde_de_poche": BOMBE,
	"cornue_instable": POISON,
	"chaine_d_arcanes": FOUDRE,
	"etincelle_runique": ARCANE,
}


## L'élément de l'arme `id_arme`, `""` si elle garde son rendu d'aujourd'hui.
static func de(id_arme: String) -> String:
	return String(TABLE.get(id_arme, ""))


static func ids() -> PackedStringArray:
	var liste: PackedStringArray = []
	for id: Variant in TABLE:
		liste.append(String(id))
	return liste
