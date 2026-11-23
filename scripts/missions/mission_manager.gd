class_name MissionManager
extends Node

# Owns ONLY mission state: objectives, kills, secrets, revives, time,
# checkpoints and the result. It never builds levels, never spawns
# enemies, never draws UI - it emits signals and the Game reacts.
# (Single Responsibility.)

signal objective_completed(objective: String)
signal mission_completed(rank: String, stats: Dictionary)
signal mission_failed

var mission: Dictionary = {}
var layout: Dictionary = {}
var kills: int = 0
var secrets: int = 0
var revives: int = 0
var mission_time: float = 0.0
var done_objectives: Array[String] = []
var mission_complete: bool = false
var is_failed: bool = false
var _checkpoints: Array = []
var _checkpoint_index: int = 0

func load_mission(num: int) -> void:
	mission = GameData.mission(num)
	layout = GameData.layout(num)
	kills = 0
	secrets = 0
	revives = 0
	mission_time = 0.0
	done_objectives.clear()
	mission_complete = false
	is_failed = false
	_checkpoints = layout["checkpoints"]
	_checkpoint_index = 0

func _process(delta: float) -> void:
	if not mission_complete and not is_failed:
		mission_time += delta

func objectives() -> Array:
	return mission.get("primary", [])

func is_objective_done(objective: String) -> bool:
	return objective in done_objectives

func complete_objective(objective: String) -> void:
	if objective in done_objectives or mission_complete:
		return
	done_objectives.append(objective)
	objective_completed.emit(objective)
	_check_completion()

func complete_objective_progress(objective: String) -> void:
	# Count-based objectives (e.g. "Find 3 missing soldiers"): each
	# station completion counts once; the mission completes when the
	# station count for that objective is reached - handled by the
	# Game, which calls complete_objective() when the count is met.
	complete_objective(objective)

func on_kill() -> void:
	kills += 1
	var target: int = int(layout.get("kill_target", 0))
	if target > 0 and kills >= target and str(layout.get("kill_objective", "")) != "":
		complete_objective(str(layout["kill_objective"]))

func on_boss_defeated() -> void:
	var boss_id: String = str(mission.get("boss", ""))
	if boss_id == "":
		return
	for obj in objectives():
		if "Defeat" in obj:
			complete_objective(obj)

func on_revive() -> void:
	revives += 1

func on_secret() -> void:
	secrets += 1

func reach_checkpoint_at(pos: Vector2) -> void:
	for i in range(_checkpoints.size()):
		var cp: Array = _checkpoints[i]
		if Vector2(float(cp[0]), float(cp[1])).distance_to(pos) < 2.0:
			_checkpoint_index = maxi(_checkpoint_index, i)

func checkpoint_pos() -> Vector2:
	if _checkpoints.is_empty():
		return Vector2(-8, -2) * GameData.SCALE
	var cp: Array = _checkpoints[_checkpoint_index]
	return Vector2(float(cp[0]), float(cp[1])) * GameData.SCALE

func _check_completion() -> void:
	if mission_complete:
		return
	for obj in objectives():
		if obj not in done_objectives:
			return
	complete_mission()

func complete_mission() -> void:
	mission_complete = true
	var rank: String = rank_for()
	mission_completed.emit(rank, stats())

func fail_mission() -> void:
	is_failed = true
	mission_failed.emit()

func stats() -> Dictionary:
	return {"time": mission_time, "kills": kills, "revives": revives,
		"secrets": secrets, "objectives": done_objectives.size(),
		"total_objectives": objectives().size()}

func rank_for() -> String:
	# Bronze: complete. Silver: +1 optional (intel). Gold: all intel
	# + fast. Elite: Gold + no downs is tracked by the Game.
	if secrets >= 2 and mission_time < 300.0:
		return "Gold"
	if secrets >= 1:
		return "Silver"
	return "Bronze"
