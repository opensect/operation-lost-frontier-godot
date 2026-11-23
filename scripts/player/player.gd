class_name Player
extends CharacterBody2D

# The local (or host-owned) player. Thin coordinator: input -> the
# Movement / Health / WeaponController components, which own their own
# state. It does not implement physics, health or weapon math itself.
# Dependencies (game, character, peer id) are injected via setup().

signal ability_used(ability_name: String, cooldown: float)

const SIZE := Vector2(58, 92)

var character_id: String = "Ranger"
var peer_id: int = 1
var is_local: bool = true
var game: Node = null
var movement: PlayerMovement
var health: PlayerHealth
var weapons: WeaponController
var facing: int = 1
var aim_up: bool = false
var aim_down: bool = false
var _ability_cd: float = 0.0
var _shield_pool: float = 0.0
var _speed_t: float = 0.0
var _fire_held: bool = false
var _fire_pressed: bool = false
var _sprite: Sprite2D
var _animator: PlayerAnimator = null
var _was_on_floor: bool = true

# The LAN sync DTO: the real local state (position, HP, downed, facing,
# ammo) the LanManager sends at 20 Hz. One small dictionary, no
# references - cheap to send, and the host never has to guess.
func sync_state() -> Dictionary:
	return {
		"pos": global_position,
		"hp": health.hp if health != null else 100,
		"downed": health.is_downed if health != null else false,
		"facing": facing,
		"mag": weapons.mag_ammo() if weapons != null else 0,
		"reserve": weapons.reserve_ammo() if weapons != null else 0,
	}

func setup(p_character: String, p_peer: int, p_local: bool, p_game: Node, mission_num: int) -> void:
	character_id = p_character
	peer_id = p_peer
	is_local = p_local
	game = p_game
	var def: Dictionary = GameData.character(character_id)
	_sprite = $Sprite2D
	SpriteLoader.apply_to_sprite(_sprite, "Characters", def["sprite"], Color.WHITE, Vector2(58, 92))
	_sprite.modulate = Color(def["tint"][0], def["tint"][1], def["tint"][2])
	# Procedural animation (see ANIMATION.md): the player's batch-1
	# art has no atlas walk frames, so the motion is Tween-based.
	_animator = PlayerAnimator.new()
	_animator.setup(_sprite)
	# Reuse components if they already exist: setup() is called again
	# on every character change, and the old code added a NEW Movement /
	# Health / WeaponController each time - duplicate _process nodes,
	# and Main's health_changed / died connections pointed at the OLD
	# (orphaned) Health node, so the HUD stopped updating after the
	# first character change (screenshot 2: empty HP bar, Lives stuck).
	if movement == null:
		movement = PlayerMovement.new()
		movement.name = "Movement"
		add_child(movement)
	if health == null:
		health = PlayerHealth.new()
		health.name = "Health"
		add_child(health)
	if weapons == null:
		weapons = WeaponController.new()
		weapons.name = "WeaponController"
		add_child(weapons)
	weapons.setup(character_id, mission_num)
	_add_player_marker()
	weapons.fired.connect(_on_weapon_fired)
	health.died.connect(func() -> void: if game != null and game.has_method("on_player_died"): game.on_player_died(self))
	add_to_group("player")

func _add_player_marker() -> void:
	# The player must be unmistakable vs enemies: a green ring under
	# the feet and a "YOU" label above the head. Both are created once.
	if get_node_or_null("PlayerMarker") != null:
		return
	var ring_img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for yy in range(64):
		for xx in range(64):
			var dx: float = float(xx - 32)
			var dy: float = float(yy - 32)
			var r: float = sqrt(dx * dx + dy * dy)
			if r >= 26.0 and r <= 32.0:
				ring_img.set_pixel(xx, yy, Color(0.3, 1.0, 0.4, 0.95))
	var ring := Sprite2D.new()
	ring.name = "PlayerMarker"
	ring.texture = ImageTexture.create_from_image(ring_img)
	ring.position = Vector2(0, 40)
	ring.z_index = -1
	add_child(ring)
	var lbl := Label.new()
	lbl.name = "YouLabel"
	lbl.text = "YOU"
	lbl.position = Vector2(-22, -118)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	add_child(lbl)

func is_engineer() -> bool:
	return character_id == "Engineer"

func _physics_process(delta: float) -> void:
	if game != null and game.paused:
		return
	_ability_cd = maxf(0.0, _ability_cd - delta)
	_speed_t = maxf(0.0, _speed_t - delta)
	if not is_local:
		return
	if health.is_downed:
		velocity = Vector2.ZERO
		move_and_slide()
		_try_revive()
		return
	var input_dir: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		input_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		input_dir += 1.0
	if game != null:
		input_dir += game.touch_move
		input_dir = clampf(input_dir, -1.0, 1.0)
	aim_up = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	aim_down = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var want_jump: bool = Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE) or (game != null and game.touch_jump_pressed)
	if game != null:
		game.touch_jump_pressed = false
	var jump_held: bool = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept")
	if want_jump and aim_down and is_on_floor():
		movement.drop_through(self)
	var speed_mul: float = 1.3 if _speed_t > 0.0 else 1.0
	var was_on_floor: bool = is_on_floor()
	movement.physics_step(self, input_dir, want_jump, jump_held, delta, speed_mul)
	var now_on_floor: bool = is_on_floor()
	if _animator != null:
		if was_on_floor and not now_on_floor and velocity.y < 0.0:
			_animator.on_jump()
		elif not was_on_floor and now_on_floor:
			_animator.on_land()
		_animator.update(input_dir != 0.0, now_on_floor, delta)
	_was_on_floor = now_on_floor
	if input_dir != 0.0:
		facing = 1 if input_dir > 0.0 else -1
		_sprite.flip_h = facing < 0
	if global_position.y > 600.0:
		# Fall-through safety net: respawn at the checkpoint, never a void.
		if game != null and game.has_method("respawn_player"):
			game.respawn_player(self)
	# Firing
	var fire_now: bool = Input.is_physical_key_pressed(KEY_J) or (game != null and game.touch_fire)
	_fire_pressed = fire_now and not _fire_held
	_fire_held = fire_now
	if fire_now:
		var dir := Vector2(float(facing), 0.0)
		if aim_up: dir = Vector2(float(facing) * 0.5, -1.0).normalized()
		elif aim_down and not is_on_floor(): dir = Vector2(float(facing) * 0.5, 1.0).normalized()
		weapons.try_fire(dir, _fire_pressed)
	if Input.is_physical_key_pressed(KEY_K):
		weapons.start_reload()
	if Input.is_physical_key_pressed(KEY_Q):
		weapons.switch_weapon(1)
	if Input.is_physical_key_pressed(KEY_L):
		_throw_grenade()
	if Input.is_physical_key_pressed(KEY_F) or (game != null and game.touch_ability_pressed):
		if game != null:
			game.touch_ability_pressed = false
		use_ability()
	if Input.is_physical_key_pressed(KEY_E):
		_try_revive()
	# Camera follow is the Game's job (it owns the Camera2D).

func _on_weapon_fired(w: WeaponResource, direction: Vector2) -> void:
	if _animator != null:
		_animator.on_fire()
	if game == null or not game.has_method("spawn_bullet"):
		return
	var muzzle: Vector2 = global_position + Vector2(facing * 34.0, -8.0)
	var dmg: int = int(w.damage * weapons.damage_multiplier())
	for i in range(w.pellets):
		var spread: float = deg_to_rad(randf_range(-w.spread_deg, w.spread_deg))
		game.spawn_bullet(muzzle, direction.rotated(spread), dmg, w.projectile_speed * GameData.SCALE, w.range_units * GameData.SCALE, true, w.explosive, w.explosion_radius, peer_id)
	if game != null and game.has_method("lan_shoot"):
		game.lan_shoot(muzzle, direction, w.wid)

func _throw_grenade() -> void:
	if weapons.grenades <= 0 or game == null or not game.has_method("spawn_grenade"):
		return
	weapons.grenades -= 1
	game.spawn_grenade(global_position + Vector2(facing * 30.0, -20.0), Vector2(facing * 320.0, -420.0), peer_id)

func use_ability() -> void:
	if _ability_cd > 0.0:
		return
	var def: Dictionary = GameData.character(character_id)
	_ability_cd = float(def["cooldown"])
	match character_id:
		"Ranger":
			weapons.apply_tactical_reload(6.0)
		"Scout":
			movement.start_dash(float(facing))
		"Engineer":
			_shield_pool = 150.0
			if game != null and game.has_method("spawn_shield"):
				game.spawn_shield(global_position, 6.0)
		"Medic":
			if game != null and game.has_method("heal_nearby"):
				game.heal_nearby(global_position, 3.0 * GameData.SCALE, 25)
	ability_used.emit(def["ability"], float(def["cooldown"]))
	if game != null and game.has_method("show_message"):
		game.show_message(def["ability"] + " used", 2.0)

func apply_damage(amount: int, from_pos: Vector2) -> void:
	if _shield_pool > 0.0:
		var absorbed: int = mini(int(_shield_pool), amount)
		_shield_pool -= absorbed
		amount -= absorbed
		if amount <= 0:
			return
	var diff: String = "Normal"
	if game != null:
		diff = game.difficulty
	health.apply_damage(amount, diff)
	# Friendly-fire rule: damage from a teammate never drops below 1 HP
	# when the source is a teammate explosion - handled by Combat.
	if health.hp > 0:
		movement.apply_knockback((global_position - from_pos).normalized() * 180.0)

func knockback(v: Vector2) -> void:
	movement.apply_knockback(v)

func heal(amount: int) -> void:
	health.heal(amount)

func add_armor(amount: int) -> void:
	health.add_armor(amount)

func apply_powerup(kind: String, duration: float) -> void:
	if kind == "speed":
		_speed_t = duration
	else:
		weapons.apply_powerup(kind, duration)

func _try_revive() -> void:
	if game != null and game.has_method("try_revive"):
		game.try_revive(self)
