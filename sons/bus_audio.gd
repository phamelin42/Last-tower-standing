class_name BusAudio
extends RefCounted
## Bus audio du jeu : le bus principal reçoit le volume général des réglages, et deux bus enfants
## séparent la musique des effets. Le bus est créé au démarrage s'il n'existe pas, une seule fois.

const BUS_PRINCIPAL := "Master"
const BUS_MUSIQUE := "Musique"
const BUS_EFFETS := "Effets"


## Crée les bus musique et effets, rattachés au bus principal, s'ils manquent.
static func assurer_bus() -> void:
	for nom: String in [BUS_MUSIQUE, BUS_EFFETS]:
		if AudioServer.get_bus_index(nom) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, nom)
		AudioServer.set_bus_send(index, BUS_PRINCIPAL)


## Règle le bus principal sur le volume général (0 à 1). Zéro coupe le son ; une valeur hors
## bornes est ramenée dans ses bornes, comme dans `Reglages`.
static func appliquer_volume(volume: float) -> void:
	var borne := clampf(volume, 0.0, 1.0)
	var index := AudioServer.get_bus_index(BUS_PRINCIPAL)
	AudioServer.set_bus_mute(index, borne <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(borne) if borne > 0.0 else 0.0)
