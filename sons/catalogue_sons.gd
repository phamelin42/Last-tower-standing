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
	return TOUS.duplicate()


static func chemin(identifiant: String) -> String:
	return DOSSIER + identifiant + EXTENSION


## Le flux du son : le fichier s'il existe, sinon un silence de substitution.
static func flux(identifiant: String) -> AudioStream:
	if not est_substitution(identifiant):
		return load(chemin(identifiant)) as AudioStream
	return _silence()


## Vrai pour un identifiant inconnu ou dont le fichier n'est pas versionné.
static func est_substitution(identifiant: String) -> bool:
	return not TOUS.has(identifiant) or not ResourceLoader.exists(chemin(identifiant))


static func _silence() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FREQUENCE_SUBSTITUTION
	wav.stereo = false
	wav.data = PackedByteArray([0, 0])
	return wav
