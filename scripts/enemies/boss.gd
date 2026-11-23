class_name Boss
extends Enemy

# A Boss IS an Enemy (Liskov): it spawns, takes damage and dies through
# the exact same interface the Game uses for every enemy, and adds only
# phase behaviour on top. New bosses are new GameData entries + a phase
# list - the base class is never edited to add one (Open/Closed).

var boss_id: String = "JungleWalker"
var boss_def: Dictionary = {}
var phase: int = 1
var phase_count: int = 4
var _attack_t: float = 0.0
var _core_exposed: bool = false

func setup_boss(p_id: String, p_game: Node, p_home: Vector2, player_count: int) -> void:
	boss_id = p_id
	boss_def = GameData.boss(boss_id)
	phase_count = (boss_def["phases"] as Array).size()
	# Reuse the Enemy contract with a synthetic def so the base AI works.
	def = {"id": boss_id, "display": boss_def["display"], "hp": int(boss_def["hp"]),
		"speed": 1.2, "damage": 25, "interval": 1.8, "detect": 20.0,
		"sprite": boss_def["sprite"], "scale": 2.0, "flying": false, "stationary": false}
	enemy_id = boss_id
	game = p_game
	home_pos = p_home
	global_position = p_home
	patrol_min = p_home + Vector2(-200, 0)
	patrol_max = p_home + Vector2(200, 0)
	max_hp = int(boss_def["hp"]) + (player_count - 1) * 1200
	hp = max_hp
	speed = 1.2
	_sprite = $Sprite2D
	SpriteLoader.apply_to_sprite(_sprite, "Enemies", str(boss_def["sprite"]), Color.RED, Vector2(190, 220))
	# Bosses hover: a slow bob on the static mech sprite, plus an
	# attack pulse (see _boss_attack). No walk cycle - a boss does not
	# walk, it looms.
	_animator = CharacterAnimator.new()
	_animator.setup_static(_sprite)
	_animator.bob_amp = 10.0
	_animator.bob_speed = 1.2
	add_to_group("enemy")
	add_to_group("boss")
	if game != null and game.has_method("show_boss_bar"):
		game.show_boss_bar(str(boss_def["display"]), 1.0)

func _physics_process(delta: float) -> void:
	if game != null and game.paused:
		return
	if game != null and not game.started:
		return
	# Phase from remaining HP - never edits base-class state directly.
	var frac: float = float(hp) / float(maxi(1, max_hp))
	var new_phase: int = clampi(int((1.0 - frac) * float(phase_count)) + 1, 1, phase_count)
	if new_phase != phase:
		phase = new_phase
		_core_exposed = phase >= phase_count
		if game != null and game.has_method("show_message"):
			game.show_message(str(boss_def["display"]) + " - " + str((boss_def["phases"] as Array)[phase - 1]), 3.0)
	_attack_t -= delta
	if _attack_t <= 0.0:
		_attack_t = 2.2 - float(phase) * 0.2
		_boss_attack()
	if game != null and game.has_method("show_boss_bar"):
		game.show_boss_bar(str(boss_def["display"]), frac)
	# Slow drift toward the player (base movement, not a new system).
	if game != null:
		var p: Node2D = game.get_local_player()
		if p != null:
			_move_toward(p.global_position, delta)
	if _animator != null:
		_animator.update(false, delta)
		_animator.set_facing(_dir)
	velocity.y += GameData.GRAVITY * delta
	move_and_slide()

func _boss_attack() -> void:
	if _animator != null:
		_animator.pulse()
	if game == null or not game.has_method("spawn_bullet"):
		return
	var p: Node2D = game.get_local_player()
	if p == null:
		return
	var dir: Vector2 = (p.global_position - global_position).normalized()
	match phase:
		1:
			for i in range(3):
				game.spawn_bullet(global_position + Vector2(-40, -40 + i * 40), dir, 15, 20.0 * GameData.SCALE, 16.0 * GameData.SCALE, false, false, 0.0, 0)
		2:
			# Stomp: damage anyone close, plus a bullet sweep.
			if global_position.distance_to(p.global_position) < 200.0 and p.has_method("apply_damage"):
				p.apply_damage(30, global_position)
			game.spawn_bullet(global_position, dir, 15, 20.0 * GameData.SCALE, 16.0 * GameData.SCALE, false, false, 0.0, 0)
		3:
			game.spawn_bullet(global_position + Vector2(0, -60), dir, 40, 12.0 * GameData.SCALE, 18.0 * GameData.SCALE, false, true, 2.5, 0)
			if boss_id in ["FrostWarden", "AbyssalCore"] and game.has_method("spawn_enemy_at"):
				game.spawn_enemy_at("Drone", global_position + Vector2(120, -80))
		_:
			# Final phase: core exposed - the boss attacks harder but
			# takes double damage (see take_damage below).
			for i in range(5):
				var a: float = dir.angle() + deg_to_rad(-20.0 + i * 10.0)
				game.spawn_bullet(global_position, Vector2.from_angle(a), 20, 22.0 * GameData.SCALE, 16.0 * GameData.SCALE, false, false, 0.0, 0)

func take_damage(amount: int, from_pos: Vector2, owner_id: int = 0) -> void:
	# Same host-authoritative routing as Enemy.take_damage (Boss IS an
	# Enemy): a client reports the hit, the host applies it (including
	# the core-exposed double damage) and the snapshot carries it back.
	if not _is_damage_authority():
		if game != null and game.has_method("report_enemy_damage"):
			game.report_enemy_damage(home_pos, amount, from_pos)
		return
	if _core_exposed:
		amount *= 2
	hp -= amount
	if game != null and game.has_method("show_damage"):
		game.show_damage(global_position, amount)
	if hp <= 0:
		_die()

func _die() -> void:
	if game != null and game.has_method("hide_boss_bar"):
		game.hide_boss_bar()
	if game != null and game.has_method("on_boss_defeated"):
		game.on_boss_defeated(boss_id)
	died.emit(self)
	queue_free()
