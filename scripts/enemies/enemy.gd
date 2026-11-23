class_name Enemy
extends CharacterBody2D

# Base enemy. One class, data-driven: type comes from a GameData
# dictionary, so a new enemy type is a new data entry, not a new class
# (Open/Closed). Subclasses (Boss) must honour this contract - same
# take_damage / die / group membership - wherever an Enemy is used
# (Liskov Substitution).

signal died(enemy: Enemy)

enum State { PATROL, DETECT, APPROACH, ATTACK, REPOSITION, SEARCH, RETURN }

var enemy_id: String = "Grunt"
var def: Dictionary = {}
var hp: int = 100
var max_hp: int = 100
var speed: float = 2.5
var state: int = State.PATROL
var game: Node = null
var player: Node2D = null
var home_pos: Vector2 = Vector2.ZERO
var patrol_min: Vector2 = Vector2.ZERO
var patrol_max: Vector2 = Vector2.ZERO
var _dir: float = 1.0
var _attack_cd: float = 0.0
var _state_t: float = 0.0
var _sprite: Sprite2D
var _animator: CharacterAnimator = null

func setup(p_id: String, p_game: Node, p_home: Vector2, p_min: Vector2, p_max: Vector2) -> void:
	enemy_id = p_id
	game = p_game
	def = GameData.enemy(enemy_id)
	home_pos = p_home
	global_position = p_home
	patrol_min = p_min
	patrol_max = p_max
	max_hp = int(def["hp"])
	var mult: float = 1.0
	if game != null:
		mult = GameData.enemy_count_multiplier(game.player_count)
	hp = int(max_hp * mult)
	speed = float(def["speed"])
	_sprite = $Sprite2D
	SpriteLoader.apply_to_sprite(_sprite, "Enemies", str(def["sprite"]), Color.RED, Vector2(58, 88) * float(def["scale"]))
	# Animation (see ANIMATION.md): types with a batch-04 walk row get
	# a real walk cycle and the static sprite is hidden; the Beast
	# keeps its static sprite and lunges (pulse on attack). Drones
	# hover via their velocity bob; Turrets are stationary.
	var folder: String = CharacterAnimator.walk_folder_for(enemy_id)
	if folder != "":
		_animator = CharacterAnimator.new()
		if _animator.setup_walk(self, folder, 88.0 * float(def["scale"])):
			_sprite.visible = false
		else:
			_animator = null
	elif enemy_id == "Beast":
		_animator = CharacterAnimator.new()
		_animator.setup_static(_sprite)
	# Small red HP bar above the head, so damage / enemy health is
	# visible and enemies are readable at a glance.
	var hpbar := ProgressBar.new()
	hpbar.name = "HpBar"
	hpbar.position = Vector2(-20, -62)
	hpbar.custom_minimum_size = Vector2(40, 6)
	hpbar.max_value = 100.0
	hpbar.value = 100.0
	hpbar.show_percentage = false
	add_child(hpbar)
	add_to_group("enemy")
	if bool(def.get("flying", false)):
		add_to_group("flying")

func _physics_process(delta: float) -> void:
	if game != null and game.paused:
		return
	if game != null and not game.started:
		return
	if game != null:
		player = game.get_local_player()
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_state_t += delta
	var target: Node2D = player
	if target == null:
		return
	var dist: float = global_position.distance_to(target.global_position)
	var detect: float = float(def["detect"]) * GameData.SCALE
	match state:
		State.PATROL:
			_patrol(delta)
			if dist < detect:
				state = State.DETECT
				_state_t = 0.0
		State.DETECT:
			velocity.x = 0.0
			if _state_t > 0.4:
				state = State.APPROACH
		State.APPROACH:
			_move_toward(target.global_position, delta)
			if dist < 260.0:
				state = State.ATTACK
		State.ATTACK:
			velocity.x = 0.0
			if dist > 420.0:
				state = State.APPROACH
			elif _attack_cd <= 0.0:
				_attack(target)
		State.REPOSITION:
			_move_toward(home_pos, delta)
			if global_position.distance_to(home_pos) < 40.0:
				state = State.PATROL
		State.SEARCH:
			_patrol(delta)
			if dist < detect:
				state = State.DETECT
		State.RETURN:
			_move_toward(home_pos, delta)
			if global_position.distance_to(home_pos) < 40.0:
				state = State.PATROL
	if not bool(def.get("flying", false)) and not bool(def.get("stationary", false)):
		velocity.y += GameData.GRAVITY * delta
		move_and_slide()
	elif bool(def.get("flying", false)):
		# Drones hover: gentle bob, no gravity.
		velocity.y = sin(_state_t * 2.0) * 20.0
		global_position += velocity * delta
	var _hpbar: ProgressBar = get_node_or_null("HpBar") as ProgressBar
	if _hpbar != null:
		_hpbar.value = clampf(float(hp) / maxf(1.0, float(max_hp)) * 100.0, 0.0, 100.0)
	if _animator != null:
		_animator.update(absf(velocity.x) > 10.0, delta)
		_animator.set_facing(_dir)
	if global_position.y > 1200.0:
		queue_free()

func _patrol(delta: float) -> void:
	if bool(def.get("stationary", false)):
		return
	velocity.x = _dir * speed * GameData.SCALE * 0.35
	if global_position.x < patrol_min.x:
		_dir = 1.0
	elif global_position.x > patrol_max.x:
		_dir = -1.0

func _move_toward(pos: Vector2, delta: float) -> void:
	if bool(def.get("stationary", false)):
		return
	var d: float = pos.x - global_position.x
	_dir = 1.0 if d > 0.0 else -1.0
	velocity.x = _dir * speed * GameData.SCALE
	if _sprite != null:
		_sprite.flip_h = _dir < 0.0

func _attack(target: Node2D) -> void:
	_attack_cd = float(def["interval"])
	if game == null or not game.has_method("spawn_bullet"):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	# Shield Trooper blocks frontal attacks - handled in take_damage.
	# Melee types (Beast / Scout) lunge instead of shooting.
	if enemy_id in ["Beast", "Scout"]:
		velocity.x = _dir * speed * GameData.SCALE * 2.0
		if _animator != null:
			_animator.pulse()
		if global_position.distance_to(target.global_position) < 70.0 and target.has_method("apply_damage"):
			target.apply_damage(int(def["damage"]), global_position)
		return
	if enemy_id == "RocketSoldier":
		game.spawn_bullet(global_position + Vector2(_dir * 30.0, -10.0), dir, int(def["damage"]), 12.0 * GameData.SCALE, 18.0 * GameData.SCALE, false, true, 2.0, 0)
		return
	game.spawn_bullet(global_position + Vector2(_dir * 30.0, -10.0), dir, int(def["damage"]), 22.0 * GameData.SCALE, 14.0 * GameData.SCALE, false, false, 0.0, 0)

func take_damage(amount: int, from_pos: Vector2, owner_id: int = 0) -> void:
	# Host-authoritative damage: on a client this peer does NOT own
	# enemy HP, so the hit is reported to the host instead of applied
	# here. The host applies it (validating it) and the next snapshot
	# carries the new HP back. Solo / host: apply locally as before.
	if not _is_damage_authority():
		if game != null and game.has_method("report_enemy_damage"):
			game.report_enemy_damage(home_pos, amount, from_pos)
		return
	# Shield Trooper: frontal attacks are blocked (flank or explosives).
	# (Was: `from_pos.x < global_position.x == (_dir > 0.0)` - a boolean
	#  comparison that almost never blocked, and was unreadable.)
	if enemy_id == "ShieldTrooper":
		var frontal: bool = (from_pos.x < global_position.x and _dir > 0.0) or (from_pos.x > global_position.x and _dir < 0.0)
		if frontal:
			amount = int(amount * 0.2)
	hp -= amount
	if game != null and game.has_method("show_damage"):
		game.show_damage(global_position, amount)
	if hp <= 0:
		_die()

# True when this peer owns enemy HP: solo, or the LAN host.
func _is_damage_authority() -> bool:
	if game == null or not game.has_method("is_host"):
		return true
	return game.is_host()

func _die() -> void:
	died.emit(self)
	if game != null and game.has_method("on_enemy_killed"):
		game.on_enemy_killed(self)
	queue_free()
