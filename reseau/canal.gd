class_name Canal
extends Node
## Déclaration unique des RPC. `Serveur` et `Client` en sont des enfants, au même chemin des deux
## côtés (le nœud s'appelle `Canal` partout) : les RPC se résolvent par le chemin du nœud. Les
## corps n'émettent qu'un signal ; tout octet reçu reste une donnée non fiable, validée par
## `Protocole` chez le destinataire.

signal bonjour_recu(pair: int, octets: PackedByteArray)
signal intention_recue(pair: int, octets: PackedByteArray)
signal etat_arene_recu(octets: PackedByteArray)
signal etat_global_recu(octets: PackedByteArray)
signal salon_recu(octets: PackedByteArray)
signal refus_recu(octets: PackedByteArray)

@rpc("any_peer", "reliable")
func rpc_bonjour(octets: PackedByteArray) -> void:
	bonjour_recu.emit(multiplayer.get_remote_sender_id(), octets)


@rpc("any_peer", "reliable")
func rpc_intention(octets: PackedByteArray) -> void:
	intention_recue.emit(multiplayer.get_remote_sender_id(), octets)


@rpc("authority", "unreliable")
func rpc_etat_arene(octets: PackedByteArray) -> void:
	etat_arene_recu.emit(octets)


@rpc("authority", "reliable")
func rpc_etat_global(octets: PackedByteArray) -> void:
	etat_global_recu.emit(octets)


@rpc("authority", "reliable")
func rpc_salon(octets: PackedByteArray) -> void:
	salon_recu.emit(octets)


@rpc("authority", "reliable")
func rpc_refus(octets: PackedByteArray) -> void:
	refus_recu.emit(octets)
