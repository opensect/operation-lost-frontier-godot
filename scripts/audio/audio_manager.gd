class_name AudioManager
extends Node

# Audio API, kept deliberately small. No audio files were uploaded with
# the game, so this is a silent placeholder with the full interface
# ready: when audio files are added, only this module changes.
# (Interface Segregation - gameplay never touches AudioStreamPlayers.)

func play_shot(_weapon_id: String) -> void:
	pass

func play_explosion() -> void:
	pass

func play_pickup() -> void:
	pass

func play_objective() -> void:
	pass

func play_boss_phase() -> void:
	pass
