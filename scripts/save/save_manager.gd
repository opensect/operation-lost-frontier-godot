class_name SaveManager
extends RefCounted

# Campaign progress, unlocks and settings. Stored in user://save.cfg.
# No personal info is ever written here - only mission numbers and ranks.

const PATH := "user://save.cfg"

var unlocked_mission: int = 1
var ranks: Dictionary = {}
var difficulty: String = "Normal"
var character_id: String = "Ranger"

func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	unlocked_mission = int(cfg.get_value("campaign", "unlocked_mission", 1))
	difficulty = str(cfg.get_value("campaign", "difficulty", "Normal"))
	character_id = str(cfg.get_value("campaign", "character_id", "Ranger"))
	var r: Dictionary = cfg.get_value("campaign", "ranks", {})
	if r is Dictionary:
		ranks = r

func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked_mission", unlocked_mission)
	cfg.set_value("campaign", "difficulty", difficulty)
	cfg.set_value("campaign", "character_id", character_id)
	cfg.set_value("campaign", "ranks", ranks)
	cfg.save(PATH)

func unlock_mission(n: int) -> void:
	unlocked_mission = maxi(unlocked_mission, n)
	save_all()

func set_rank(mission_num: int, rank: String) -> void:
	ranks[str(mission_num)] = rank
	save_all()
