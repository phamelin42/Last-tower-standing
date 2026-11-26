class_name ElementsArmes
extends RefCounted
## L'élément visuel des armes dont Phil juge les attaques (D22) : feu, glace, bombe, poison, foudre,
## arcane, puis la famille acier (une arme par élément). Une arme absente de la table garde le
## rendu par signature d'aujourd'hui (`de()` rend `""`) : les autres armes ne changent pas tant que
## Phil n'a pas validé la proposition.

const FEU: String = "feu"
const GLACE: String = "glace"
const BOMBE: String = "bombe"
const POISON: String = "poison"
const FOUDRE: String = "foudre"
const ARCANE: String = "arcane"
## La famille acier (armes tranchantes) : un élément par arme, car chaque genre a son geste.
const LAME: String = "lame"
const FAUCILLE: String = "faucille"
const DISQUE: String = "disque"
const MOULINET: String = "moulinet"
const GUILLOTINE: String = "guillotine"
const TOURBILLON: String = "tourbillon"
## La famille du carreau (armes perçantes) : un élément par arme, comme l'acier.
const ARBALETE: String = "arbalete"
const CHAUSSE_TRAPE: String = "chausse_trape"
const RICOCHET: String = "ricochet"
const HERSE: String = "herse"
const BALISTE: String = "baliste"
const PLUIE: String = "pluie"
## Les armes magiques et de siège : un élément par arme, comme l'acier et le carreau.
const CERCLE_GIVRE: String = "cercle_givre"
const NOVA: String = "nova"
const TEMPETE: String = "tempete"
const PETARD: String = "petard"
const TREBUCHET: String = "trebuchet"
const MINE_FORGE: String = "mine_forge"
const GRANDE_BOMBE: String = "grande_bombe"

const ELEMENTS: Array[String] = [
	FEU,
	GLACE,
	BOMBE,
	POISON,
	FOUDRE,
	ARCANE,
	LAME,
	FAUCILLE,
	DISQUE,
	MOULINET,
	GUILLOTINE,
	TOURBILLON,
	ARBALETE,
	CHAUSSE_TRAPE,
	RICOCHET,
	HERSE,
	BALISTE,
	PLUIE,
	CERCLE_GIVRE,
	NOVA,
	TEMPETE,
	PETARD,
]

## id d'arme → élément.
const TABLE: Dictionary = {
	"canon_de_cloche": FEU,
	"orbe_de_brume": GLACE,
	"bombarde_de_poche": BOMBE,
	"cornue_instable": POISON,
	"chaine_d_arcanes": FOUDRE,
	"etincelle_runique": ARCANE,
	"lame_de_fil": LAME,
	"faucille_a_ressort": FAUCILLE,
	"disque_scie": DISQUE,
	"moulinet_de_cuivre": MOULINET,
	"guillotine_a_vapeur": GUILLOTINE,
	"tourbillon_d_acier": TOURBILLON,
	"arbalete_de_bureau": ARBALETE,
	"chausse_trape": CHAUSSE_TRAPE,
	"carreau_ricochet": RICOCHET,
	"herse_de_ressorts": HERSE,
	"baliste_de_guet": BALISTE,
	"pluie_d_aiguilles": PLUIE,
	"cercle_de_givre": CERCLE_GIVRE,
	"nova_d_ambre": NOVA,
	"tempete_astrale": TEMPETE,
	"petard_de_rempart": PETARD,
}


## L'élément de l'arme `id_arme`, `""` si elle garde son rendu d'aujourd'hui.
static func de(id_arme: String) -> String:
	return String(TABLE.get(id_arme, ""))


static func ids() -> PackedStringArray:
	var liste: PackedStringArray = []
	for id: Variant in TABLE:
		liste.append(String(id))
	return liste
