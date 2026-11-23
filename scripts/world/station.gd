class_name Station
extends Area2D

# Objective station: stand near it and hold Interact (E / touch E) to
# complete it. Engineer repairs 40% faster.

var objective: String = ""
var hold_seconds: float = 2.0
var count: int = 1
var game: Node = null
var progress: float = 0.0
var done: bool = false
var _player_near: Node2D = null

func setup(p_objective: String, p_hold: float, p_count: int, p_sprite: String, p_game: Node) -> void:
	# Group membership was missing: get_nodes_in_group("station") was
	# always empty, so the old smoke test's station check was vacuous.
	add_to_group("station")
	objective = p_objective
	hold_seconds = p_hold
	count = p_count
	game = p_game
	var cat: String = "Props"
	if p_sprite in ["jungle_watchtower", "cave_entrance", "fortress_gate", "ruined_stone_wall", "waterfall_cliff", "rope_bridge"]:
		cat = "Environment"
	SpriteLoader.apply_to_sprite($Sprite2D, cat, p_sprite, Color.YELLOW, Vector2(96, 128))

func _ready() -> void:
	body_entered.connect(func(b: Node2D) -> void: if b.is_in_group("player"): _player_near = b)
	body_exited.connect(func(b: Node2D) -> void: if b == _player_near: _player_near = null)

func _process(delta: float) -> void:
	# Proximity by distance, not only body_entered: teleporting the
	# player in, an enemy shove, or a physics edge could fire
	# body_exited for a frame and wipe all progress. Distance is
	# re-checked every frame, so a 1-frame exit cannot reset it.
	if game != null and game.has_method("get_local_player"):
		var pl: Node2D = game.get_local_player()
		if pl != null and pl.global_position.distance_to(global_position) < 150.0:
			_player_near = pl
		elif _player_near != null and _player_near.global_position.distance_to(global_position) > 170.0:
			_player_near = null
	if done or _player_near == null:
		# Progress persists when the player steps away to fight:
		# wiping it on every exit made stations near-impossible
		# while enemies attack. It only resets on mission restart.
		return
	var interacting: bool = Input.is_physical_key_pressed(KEY_E) or (game != null and game.touch_interact)
	if not interacting:
		# Same: hold progress, don't wipe it.
		return
	var rate: float = 1.0
	if _player_near.has_method("is_engineer") and _player_near.is_engineer():
		rate = 1.4
	progress += delta * rate
	if game != null and game.has_method("show_message"):
		game.show_message(objective + "  " + str(int(progress / hold_seconds * 100.0)) + "%", 0.2)
	if progress >= hold_seconds:
		done = true
		if game != null and game.has_method("complete_objective"):
			game.complete_objective(objective)
		queue_free()
