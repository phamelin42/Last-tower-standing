class_name CatalogueSons
extends RefCounted
## Catalogue des sons du jeu : un identifiant par son, un fichier `.ogg` sous `assets/sons/`.
## Un fichier absent n'arrête pas le jeu : il devient un silence de substitution, signalé par
## `est_substitution`, pour que l'absence d'un son se voie au test et non à l'écoute.

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

## Dossier, extension, ids d'armes, suffixes et fréquence vivent dans `data/assets.json` (T10.4) :
## changer de pack de sons ne demande que les fichiers et ce JSON.
static var dossier: String = str(Assets.section("sons").get("dossier", ""))
static var extension: String = str(Assets.section("sons").get("extension", ""))
## Les armes qui ont leur son de tir (`tir_<id>`), dans l'ordre de `data/armes.json` : un test
## vérifie qu'elles suivent les données. Une arme ajoutée au catalogue reçoit sa ligne ici et son
## fichier ; sans eux, son tir retombe sur `TIR`.
static var liste_ids_armes: Array[String] = _textes("ids_armes")
## Suffixe du son d'impact de chaque type de dégâts, dans l'ordre de `Types.TypeDegats`.
static var liste_suffixes_impact: Array[String] = _textes("suffixes_impact")
## Fréquence du silence de substitution, en hertz. Il est généré en mémoire : rien de binaire
## n'entre dans le dépôt pour un son absent.
static var frequence_substitution: int = int(
	Assets.section("sons").get("frequence_substitution", 22050)
)


static func _textes(cle: String) -> Array[String]:
	var sortie: Array[String] = []
	var liste: Array = Assets.section("sons").get(cle, [])
	for t: Variant in liste:
		sortie.append(str(t))
	return sortie


static func tous() -> Array[String]:
	var liste: Array[String] = TOUS.duplicate()
	for id: String in liste_ids_armes:
		liste.append("tir_" + id)
	for suffixe: String in liste_suffixes_impact:
		liste.append("impact_" + suffixe)
	return liste


static func ids_armes() -> PackedStringArray:
	return PackedStringArray(liste_ids_armes)


## Le son de tir de l'arme `id_arme`, ou `TIR` si elle n'a pas le sien.
static func id_tir(id_arme: String) -> String:
	return "tir_" + id_arme if liste_ids_armes.has(id_arme) else TIR


## Le son d'impact du type de dégâts (`Types.TypeDegats`), ou `IMPACT` si le type est inconnu.
static func id_impact(type_degats: int) -> String:
	if type_degats < 0 or type_degats >= liste_suffixes_impact.size():
		return IMPACT
	return "impact_" + liste_suffixes_impact[type_degats]


static func chemin(identifiant: String) -> String:
	return dossier + identifiant + extension


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
	wav.mix_rate = frequence_substitution
	wav.stereo = false
	wav.data = PackedByteArray([0, 0])
	return wav
