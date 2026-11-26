class_name CatalogueSons
extends RefCounted
## Catalogue des sons du jeu : un identifiant par son, un fichier `.ogg` sous `assets/sons/`.
## Un fichier absent n'arrête pas le jeu : il devient un silence de substitution, signalé par
## `est_substitution`, pour que l'absence d'un son se voie au test et non à l'écoute.

const DOSSIER := "res://assets/sons/"
const EXTENSION := ".ogg"

const TIR := "tir"
const IMPACT := "impact"
const MORT := "mort"
const ACHAT := "achat"
const RELANCE := "relance"
const PV_BAS := "pv_bas"
const DEBUT_MANCHE := "debut_manche"
const BOSS := "boss"
const VICTOIRE := "victoire"
const DEFAITE := "defaite"
const AMBIANCE := "ambiance"

## Les armes qui ont leur son de tir (`tir_<id>`), dans l'ordre de `data/armes.json` : un test
## vérifie qu'elles suivent les données. Une arme ajoutée au catalogue reçoit sa ligne ici et son
## fichier ; sans eux, son tir retombe sur `TIR`.
const IDS_ARMES: Array[String] = [
	"lame_de_fil",
	"faucille_a_ressort",
	"disque_scie",
	"moulinet_de_cuivre",
	"guillotine_a_vapeur",
	"tourbillon_d_acier",
	"arbalete_de_bureau",
	"chausse_trape",
	"carreau_ricochet",
	"herse_de_ressorts",
	"baliste_de_guet",
	"pluie_d_aiguilles",
	"etincelle_runique",
	"orbe_de_brume",
	"chaine_d_arcanes",
	"cercle_de_givre",
	"nova_d_ambre",
	"tempete_astrale",
	"bombarde_de_poche",
	"petard_de_rempart",
	"trebuchet_de_chambre",
	"mine_de_forge",
	"canon_de_cloche",
	"grande_bombarde",
	"de_pipe",
	"sablier_fele",
	"cornue_instable",
	"miroir_brise",
	"vortex_de_verre",
	"horloge_folle",
]
## Suffixe du son d'impact de chaque type de dégâts, dans l'ordre de `Types.TypeDegats`.
const SUFFIXES_IMPACT: Array[String] = ["tranchant", "percant", "magique", "siege", "chaos"]

const TOUS: Array[String] = [
	TIR,
	IMPACT,
	MORT,
	ACHAT,
	RELANCE,
	PV_BAS,
	DEBUT_MANCHE,
	BOSS,
	VICTOIRE,
	DEFAITE,
	AMBIANCE,
]

## Fréquence du silence de substitution, en hertz. Il est généré en mémoire : rien de binaire
## n'entre dans le dépôt pour un son absent.
const FREQUENCE_SUBSTITUTION := 22050


static func tous() -> Array[String]:
	var liste: Array[String] = TOUS.duplicate()
	for id: String in IDS_ARMES:
		liste.append("tir_" + id)
	for suffixe: String in SUFFIXES_IMPACT:
		liste.append("impact_" + suffixe)
	return liste


static func ids_armes() -> PackedStringArray:
	return PackedStringArray(IDS_ARMES)


## Le son de tir de l'arme `id_arme`, ou `TIR` si elle n'a pas le sien.
static func id_tir(id_arme: String) -> String:
	return "tir_" + id_arme if IDS_ARMES.has(id_arme) else TIR


## Le son d'impact du type de dégâts (`Types.TypeDegats`), ou `IMPACT` si le type est inconnu.
static func id_impact(type_degats: int) -> String:
	if type_degats < 0 or type_degats >= SUFFIXES_IMPACT.size():
		return IMPACT
	return "impact_" + SUFFIXES_IMPACT[type_degats]


static func chemin(identifiant: String) -> String:
	return DOSSIER + identifiant + EXTENSION


## Le flux du son : le fichier s'il existe, sinon un silence de substitution.
static func flux(identifiant: String) -> AudioStream:
	if not est_substitution(identifiant):
		return load(chemin(identifiant)) as AudioStream
	return _silence()


## Vrai pour un identifiant inconnu ou dont le fichier n'est pas versionné.
static func est_substitution(identifiant: String) -> bool:
	return not tous().has(identifiant) or not ResourceLoader.exists(chemin(identifiant))


static func _silence() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FREQUENCE_SUBSTITUTION
	wav.stereo = false
	wav.data = PackedByteArray([0, 0])
	return wav
