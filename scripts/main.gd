class_name Main
extends Node2D

# Thin coordinator for Operation: Lost Frontier (Godot).
# It wires the modules together and owns ONLY: the current mission /
# score / pause state, the camera, and the small public API the other
# modules call (spawn_bullet, explode, collect_pickup, complete_objective,
# show_message, ...). Level building lives in LevelBuilder, mission
# state in MissionManager, LAN in LanManager, UI in Hud/MainMenu/
# TouchControls, save in SaveManager. No god class.

const BulletScene := preload("res://scenes/Bullet.tscn")
const GrenadeScene := preload("res://scenes/Grenade.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const BossScene := preload("res://scenes/Boss.tscn")
const PickupScene := preload("res://scenes/Pickup.tscn")

var save: SaveManager
var mission_mgr: MissionManager
var level_builder: LevelBuilder
var lan: LanManager
var audio: AudioManager
var player: Player
var camera: Camera2D
var world: Node2D
var hud: Hud
var menu: MainMenu
var touch: TouchControls

var current_mission: int = 1
var difficulty: String = "Normal"
var character_id: String = "Ranger"
var score: int = 0
var player_count: int = 1
var paused: bool = false
var started: bool = false
var _checkpoint: Vector2 = Vector2(-128, -256)
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _claimed_pickups: Dictionary = {}
var _spawned_pickups: Dictionary = {}
var _remote_players: Dictionary = {}
var _enemy_spawn_t: float = 0.0
var _background: TextureRect = null
var _station_counts: Dictionary = {}
var _kills_for_objective: int = 0

# Touch state, read by the Player each frame.
var touch_move: float = 0.0
var touch_fire: bool = false
var touch_interact: bool = false
var touch_jump_pressed: bool = false
var touch_ability_pressed: bool = false

# Group lookup scoped to THIS Main instance only. A Main must never
# reach into another Main's objects: in production there is one Main
# (so this is identical to the global group), but headless tests and
# scene reloads can hold two - the global group would then merge
# both instances' enemies/pickups/players, and a mission reload would
# free the OTHER instance's enemies (found by the LAN sync test).
func _own(group: String) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(group):
		if is_ancestor_of(node) or node == self:
			out.append(node)
	return out

func _ready() -> void:
	save = SaveManager.new()
	save.load_all()
	current_mission = save.unlocked_mission
	difficulty = save.difficulty
	character_id = save.character_id
	mission_mgr = MissionManager.new()
	mission_mgr.name = "MissionManager"
	add_child(mission_mgr)
	mission_mgr.objective_completed.connect(_on_objective_completed)
	mission_mgr.mission_completed.connect(_on_mission_completed)
	mission_mgr.mission_failed.connect(_on_mission_failed)
	level_builder = LevelBuilder.new()
	level_builder.name = "LevelBuilder"
	add_child(level_builder)
	lan = $LanManager
	lan.setup(self)
	lan.peer_joined.connect(_on_peer_joined)
	lan.peer_left.connect(_on_peer_left)
	lan.status_changed.connect(func(t: String) -> void: hud.set_lan(t))
	lan.remote_state.connect(_on_remote_state)
	lan.remote_shot.connect(_on_remote_shot)
	lan.remote_pickup.connect(_on_remote_pickup)
	lan.remote_mission_complete.connect(func(_pid: int, _rank: String) -> void: pass)
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	world = $World
	camera = $Camera2D
	_background = $BackgroundLayer/BackgroundRect
	hud = $HUD
	menu = $MainMenu
	touch = $TouchControls
	player = $Player
	player.setup(character_id, 1, true, self, current_mission)
	player.health.health_changed.connect(func(hp: int, armor: int, lives: int) -> void: hud.set_health(hp, armor, lives))
	player.health.died.connect(func() -> void: mission_mgr.fail_mission())
	hud.set_health(player.health.hp, player.health.armor, player.health.lives)
	hud.pause_pressed.connect(toggle_pause)
	menu.start_pressed.connect(start_game)
	menu.character_selected.connect(func(cid: String) -> void: character_id = cid; save.character_id = cid; save.save_all(); _respawn_player_with_character())
	menu.mission_changed.connect(func(n: int) -> void: current_mission = n)
	menu.difficulty_changed.connect(func(d: String) -> void: difficulty = d; save.difficulty = d; save.save_all())
	menu.host_pressed.connect(func() -> void: lan.start_host())
	menu.find_host_pressed.connect(func() -> void: lan.find_and_join_host())
	menu.join_pressed.connect(func(ip: String) -> void: lan.join_by_ip(ip))
	menu.selected_mission = current_mission
	menu.selected_difficulty = difficulty
	menu.selected_character = character_id
	menu._update_labels()
	touch.visible = false
	# Build mission 1 behind the menu so the world is visible from the
	# first frame - the Unity bug was an empty scene; this scene is real.
	_set_background(current_mission)
	load_mission_level(current_mission)
	_update_hud()
	show_message("OPERATION: LOST FRONTIER - pick a character and press START", 5.0)

func _set_background(mission_num: int) -> void:
	# Camera-following backdrop: a full-screen TextureRect on a
	# CanvasLayer behind the world. It always fills the screen, so the
	# camera can never show the bare clear colour (screenshot 1: blank
	# dark-green world) and there are no tiled seams or panel gaps.
	if _background != null:
		_background.texture = SheetSlicer.mission_backdrop(mission_num)

func load_mission_level(mission_num: int) -> void:
	current_mission = clampi(mission_num, 1, 20)
	_set_background(current_mission)
	# A mission start is a fresh run: full lives again.
	if player != null and player.health != null:
		player.health.lives = 3
	# Clear the previous load's runtime entities. LevelBuilder already
	# clears its own LevelRoot; enemies and pickups are added straight
	# to $World, so without this a mission restart doubles them.
	for _e in _own("enemy"):
		_e.queue_free()
	for _pk in _own("pickup"):
		_pk.queue_free()
	mission_mgr.load_mission(current_mission)
	var layout: Dictionary = mission_mgr.layout.duplicate(true)
	layout["mission_num"] = current_mission
	var sky: Array = layout["sky_col"]
	RenderingServer.set_default_clear_color(Color(float(sky[0]), float(sky[1]), float(sky[2])))
	level_builder.build(world, layout, self)
	_checkpoint = Vector2(-2, -4.0) * GameData.SCALE
	_boss_spawned = false
	_boss_defeated = false
	_claimed_pickups.clear()
	_spawned_pickups.clear()
	_station_counts.clear()
	# Enemies from the layout spawn points. Seeded per mission so every
	# peer picks the SAME enemy types at the same spawn points - without
	# this the host and a client simulate different enemies and no
	# snapshot can ever make them agree.
	seed(current_mission * 7919 + 13)
	for sp in layout["spawn_points"]:
		spawn_enemy_at(_pick_enemy(), Vector2(float(sp[0]), GameData.godot_y(float(sp[1]))) * GameData.SCALE)
	if str(layout.get("mini_boss", "")) != "":
		spawn_enemy_at(str(layout["mini_boss"]), Vector2(float(layout["mini_boss_pos"][0]), GameData.godot_y(float(layout["mini_boss_pos"][1]))) * GameData.SCALE)
	# Power-ups: double damage near the start, speed near extraction.
	spawn_pickup("double_damage", Vector2(4, -3.5) * GameData.SCALE)
	spawn_pickup("speed", Vector2(float(layout["level_length"]) - 10.0, -3.5) * GameData.SCALE)
	for pk in layout["pickups"]:
		spawn_pickup(str(pk["kind"]), Vector2(float(pk["pos"][0]), GameData.godot_y(float(pk["pos"][1]))) * GameData.SCALE)
	# Player back to the spawn point, fully reset.
	if player != null:
		player.global_position = Vector2(-2, -4.0) * GameData.SCALE
		player.velocity = Vector2.ZERO
		player.health.full_reset()
		# Snap the camera, don't lerp across the whole level: after a
		# respawn / reload the old lerp left the camera over empty
		# space for a second (blank world).
		camera.position = player.global_position + Vector2(120, -40)
		camera.reset_smoothing()
	_update_hud()
	_update_objective_label()

func start_game() -> void:
	hud.hide_results()
	menu.visible = false
	touch.visible = true
	started = true
	load_mission_level(current_mission)
	var m: Dictionary = GameData.mission(current_mission)
	show_message("Mission %d: %s - %s" % [m["number"], m["title"], (m["primary"] as Array)[0]], 4.0)

func _respawn_player_with_character() -> void:
	if player == null:
		return
	player.setup(character_id, 1, true, self, current_mission)
	player.global_position = Vector2(-2, -4.0) * GameData.SCALE

func respawn_player(p: Player) -> void:
	p.global_position = _checkpoint
	p.velocity = Vector2.ZERO
	p.health.full_reset()

func set_checkpoint(pos: Vector2) -> void:
	_checkpoint = pos
	mission_mgr.reach_checkpoint_at(pos / GameData.SCALE)
	show_message("Checkpoint reached", 2.0)

func get_local_player() -> Node2D:
	return player

# ---- combat (delegates to the Combat service) ----
func spawn_bullet(pos: Vector2, dir: Vector2, damage: int, speed: float, rng: float, from_player: bool, explosive: bool, radius: float, owner_id: int) -> void:
	var b: Area2D = BulletScene.instantiate()
	$World.add_child(b)
	b.init_bullet(pos, dir, damage, speed, rng, from_player, explosive, radius, owner_id, self)
	audio.play_shot("")

func spawn_grenade(pos: Vector2, vel: Vector2, owner_id: int) -> void:
	var g: CharacterBody2D = GrenadeScene.instantiate()
	$World.add_child(g)
	g.init_grenade(pos, vel, 80, owner_id, self)

func explode(pos: Vector2, radius: float, damage: int, by_player: bool, owner_id: int) -> void:
	Combat.explode(self, pos, radius, damage, by_player, owner_id, difficulty)
	audio.play_explosion()
	# The visual: a 4-frame explosion from the batch-04 frames.
	Explosion.spawn($World, pos, radius * 1.6)

func spawn_shield(pos: Vector2, duration: float) -> void:
	var s := Sprite2D.new()
	SpriteLoader.apply_to_sprite(s, "Powerups", "energy_shield_effect", Color(0.4, 0.8, 1.0, 0.5), Vector2(190, 190))
	s.global_position = pos
	$World.add_child(s)
	get_tree().create_timer(duration).timeout.connect(s.queue_free)

func heal_nearby(pos: Vector2, radius: float, amount: int) -> void:
	for p in _own("player"):
		if p is Node2D and p.global_position.distance_to(pos) <= radius and p.has_method("heal"):
			p.heal(amount)

func spawn_enemy_at(enemy_id: String, pos: Vector2) -> Node:
	var e: CharacterBody2D = EnemyScene.instantiate()
	$World.add_child(e)
	var layout: Dictionary = mission_mgr.layout
	e.setup(enemy_id, self, pos, pos + Vector2(-192, 0), pos + Vector2(192, 0))
	e.died.connect(func(_en: Enemy) -> void: pass)
	return e

func spawn_boss(boss_id: String) -> void:
	var b: CharacterBody2D = BossScene.instantiate()
	$World.add_child(b)
	b.setup_boss(boss_id, self, Vector2(player.global_position.x + 9.0 * GameData.SCALE, -64), player_count)
	_boss_spawned = true
	show_message("BOSS: " + GameData.boss(boss_id)["display"], 3.0)
	audio.play_boss_phase()

func spawn_pickup(kind: String, pos: Vector2) -> void:
	var pk: Area2D = PickupScene.instantiate()
	$World.add_child(pk)
	pk.position = pos
	pk.setup(kind, self)
	_spawned_pickups[str(pos)] = true

func collect_pickup(pickup: Pickup, body: Node2D) -> bool:
	# Keyed by the pickup's SPAWN position (stable), never its live
	# bobbed position - see Pickup.spawn_pos.
	var key: String = str(pickup.spawn_pos)
	if _claimed_pickups.has(key):
		return false
	apply_sync_claim(key)
	lan.send_pickup(pickup.kind, pickup.spawn_pos)
	_apply_pickup(pickup.kind, body)
	audio.play_pickup()
	return true

func _apply_pickup(kind: String, body: Node2D) -> void:
	match kind:
		"health", "medkit":
			if body.has_method("heal"): body.heal(30)
		"armor":
			if body.has_method("add_armor"): body.add_armor(25)
		"ammo":
			if body.get("weapons") != null: body.weapons.add_reserve("Rifle", 60)
		"grenade":
			if body.get("weapons") != null: body.weapons.grenades += 2
		"intel":
			mission_mgr.on_secret()
			score += 100
		"double_damage", "speed", "rapid_fire":
			if body.has_method("apply_powerup"): body.apply_powerup(kind, 10.0)
	_update_hud()

func complete_objective(objective: String) -> void:
	# Count-based objectives: complete only when every station for
	# that objective has been activated.
	var layout: Dictionary = mission_mgr.layout
	var total: int = 0
	for st in layout["stations"]:
		if str(st["objective"]) == objective:
			total += 1
	_station_counts[objective] = int(_station_counts.get(objective, 0)) + 1
	if total > 1 and int(_station_counts[objective]) < total:
		show_message(objective + "  " + str(_station_counts[objective]) + "/" + str(total), 2.0)
		return
	mission_mgr.complete_objective(objective)
	_update_objective_label()
	audio.play_objective()

func on_enemy_killed(_enemy: Node) -> void:
	score += 50
	mission_mgr.on_kill()
	_update_hud()
	_update_objective_label()

func on_boss_defeated(boss_id: String) -> void:
	_boss_defeated = true
	score += 1000
	mission_mgr.on_boss_defeated()
	show_message("Boss defeated: " + GameData.boss(boss_id)["display"], 4.0)
	_update_hud()
	_update_objective_label()

func on_extraction_reached() -> void:
	# Extraction only counts once every primary objective is done.
	if mission_mgr.mission_complete:
		return
	# Extraction-based objectives ("Escort survivors to extraction",
	# "Escape", "Escape lockdown") have no station or kill trigger:
	# reaching extraction IS their completion. Mission 2 was
	# unwinnable without this - "Escort survivors to extraction"
	# could never complete, so the mission could never finish.
	for obj in mission_mgr.objectives():
		if not mission_mgr.is_objective_done(obj) and ("Escort" in obj or "Escape" in obj):
			mission_mgr.complete_objective(obj)
	var all_done: bool = true
	for obj in mission_mgr.objectives():
		if not mission_mgr.is_objective_done(obj):
			all_done = false
	if all_done:
		mission_mgr.complete_mission()
	else:
		show_message("Extraction reached - finish the objectives first", 2.0)

func on_player_died(_p: Player) -> void:
	pass  # PlayerHealth already handles downed / lives / mission fail.

func try_revive(reviver: Player) -> void:
	for p in _own("player"):
		if p == reviver or not (p is Player):
			continue
		if p.health.is_downed and p.global_position.distance_to(reviver.global_position) < 96.0:
			var need: float = 1.8 if reviver.character_id == "Medic" else 3.0
			# Hold E near a downed teammate; progress is frame-based here.
			p.health.revive()
			mission_mgr.on_revive()
			show_message("Teammate revived", 2.0)
			return

func show_damage(_pos: Vector2, _amount: int) -> void:
	pass

func show_message(text: String, duration: float = 3.0) -> void:
	hud.show_message(text, duration)

func show_boss_bar(boss_name: String, frac: float) -> void:
	hud.show_boss_bar(boss_name, frac)

func hide_boss_bar() -> void:
	hud.hide_boss_bar()

# ---- LAN ----
func lan_shoot(pos: Vector2, dir: Vector2, weapon_id: String) -> void:
	lan.send_shoot(pos, dir, weapon_id)

func on_lan_connected(pid: int) -> void:
	player.peer_id = pid

func _on_peer_joined(pid: int) -> void:
	player_count = multiplayer.get_peers().size() + 1
	var rp := RemotePlayer.new()
	rp.setup(pid, "Scout", Vector2(-6, -2) * GameData.SCALE)
	$World.add_child(rp)
	_remote_players[pid] = rp
	show_message("Player " + str(pid) + " joined", 2.0)

func _on_peer_left(pid: int) -> void:
	player_count = maxi(1, multiplayer.get_peers().size() + 1)
	if _remote_players.has(pid):
		(_remote_players[pid] as Node).queue_free()
		_remote_players.erase(pid)

func _on_remote_state(pid: int, pos: Vector2, hp: int, downed: bool, facing: int, mag: int = 0, reserve: int = 0) -> void:
	if _remote_players.has(pid):
		(_remote_players[pid] as RemotePlayer).apply_state(pos, hp, downed, facing, mag, reserve)

func _on_remote_shot(pid: int, pos: Vector2, dir: Vector2, weapon_id: String) -> void:
	var w: Dictionary = GameData.weapon(weapon_id)
	spawn_bullet(pos, dir, int(w["damage"]), float(w["speed"]) * GameData.SCALE, float(w["range"]) * GameData.SCALE, false, bool(w["explosive"]), float(w["radius"]), pid)

func _on_remote_pickup(pid: int, kind: String, pos: Vector2) -> void:
	# Host-side validation: the pickup must be a real spawn, unclaimed,
	# and the claimant must be near it. A bad claim is ignored, never
	# applied - the host owns pickup state.
	if not is_valid_pickup_claim(pid, pos):
		return
	apply_sync_claim(str(pos))

# ---- LAN sync interface (used by LanSync; see LAN_SYNC.md) ----
# Authority split: each peer owns its own player's HP/ammo (sent in the
# 20 Hz state packet); the HOST owns enemy/boss HP, pickups and
# objectives (sent in the 10 Hz snapshot). Clients reconcile to it.

func is_host() -> bool:
	return lan == null or not lan.connected or lan.is_host

func report_enemy_damage(home: Vector2, amount: int, _from_pos: Vector2) -> void:
	# Called by Enemy.take_damage on a client: forward the hit to the
	# host instead of applying it locally.
	lan.send_damage(home, amount)

func apply_host_damage(home: Vector2, amount: int) -> void:
	# Host only: validate the enemy exists and the amount is sane,
	# then apply it. The result reaches everyone in the next snapshot.
	if amount < 1 or amount > 500:
		return
	for e in _own("enemy"):
		if e is Enemy and (e as Enemy).home_pos.distance_to(home) < 1.0:
			(e as Enemy).take_damage(amount, (e as Enemy).global_position, 0)
			return

func get_sync_enemies() -> Array:
	var out: Array = []
	for e in _own("enemy"):
		if e is Enemy:
			var en: Enemy = e as Enemy
			out.append([int(en.home_pos.x), int(en.home_pos.y), int(en.global_position.x), int(en.global_position.y), int(en.hp)])
	return out

func get_sync_boss() -> Array:
	for b in _own("boss"):
		if b is Enemy:
			return [int((b as Enemy).hp), int((b as Enemy).max_hp)]
	return [-1, -1]

func get_sync_claims() -> Array:
	return _claimed_pickups.keys()

func get_sync_objectives() -> Array:
	return mission_mgr.done_objectives.duplicate()

func apply_sync_enemy(home: Vector2, pos: Vector2, hp: int) -> void:
	for e in _own("enemy"):
		if e is Enemy and (e as Enemy).home_pos.distance_to(home) < 1.0:
			var en: Enemy = e as Enemy
			en.hp = hp
			# Reconciliation: snap on big drift (lag spike / bad packet),
			# otherwise ease toward the host's position so it never pops.
			if en.global_position.distance_to(pos) > LanSync.SNAP_DIST:
				en.global_position = pos
			else:
				en.global_position = en.global_position.lerp(pos, 0.5)
			return

func remove_sync_enemy(home: Vector2) -> void:
	for e in _own("enemy"):
		if e is Enemy and (e as Enemy).home_pos.distance_to(home) < 1.0:
			(e as Enemy).queue_free()
			return

func apply_sync_boss(hp: int, max_hp: int) -> void:
	if hp < 0:
		return
	for b in _own("boss"):
		if b is Enemy:
			(b as Enemy).hp = hp
			var def: Dictionary = GameData.boss((b as Boss).boss_id) if b is Boss else {}
			var bar_name: String = str(def.get("display", "BOSS"))
			hud.show_boss_bar(bar_name, float(hp) / maxf(1.0, float(max_hp)))
			return

func apply_sync_claim(key: String) -> void:
	if _claimed_pickups.has(key):
		return
	_claimed_pickups[key] = true
	for pk in _own("pickup"):
		if str((pk as Node).get("spawn_pos")) == key:
			(pk as Node).queue_free()
			return

func apply_sync_objectives(done: Array) -> void:
	mission_mgr.done_objectives.clear()
	for obj in done:
		mission_mgr.done_objectives.append(str(obj))
	_update_objective_label()

func is_valid_pickup_claim(pid: int, pos: Vector2) -> bool:
	var key: String = str(pos)
	if not _spawned_pickups.has(key):
		return false
	if _claimed_pickups.has(key):
		return false
	# The claimant must be near the pickup (or not tracked yet, e.g.
	# just joined - then the spawn check above is the validation).
	if _remote_players.has(pid):
		var rp: Node2D = _remote_players[pid] as Node2D
		if rp != null and rp.global_position.distance_to(pos) > LanSync.PICKUP_CLAIM_MAX_DIST:
			return false
	return true

# ---- HUD / flow ----
func _update_hud() -> void:
	# Health every frame, not only on the health_changed signal: the
	# signal connection was lost whenever the player was re-setup.
	if player != null and player.health != null:
		hud.set_health(player.health.hp, player.health.armor, player.health.lives)
	if player != null and player.weapons != null:
		var w: WeaponResource = player.weapons.current()
		var res: String = "∞" if player.weapons.reserve_ammo() < 0 else str(player.weapons.reserve_ammo())
		# Two lines, no truncation: "Pistol 12 / ∞" then "Grenades: 3".
		hud.set_weapon("%s  %d / %s" % [w.display_name, player.weapons.mag_ammo(), res], "Grenades: %d" % player.weapons.grenades)
	hud.set_score(score)
	hud.set_lan(lan.status_text)

func _update_objective_label() -> void:
	var done: int = mission_mgr.done_objectives.size()
	var total: int = mission_mgr.objectives().size()
	var next: String = ""
	for obj in mission_mgr.objectives():
		if not mission_mgr.is_objective_done(obj):
			next = obj
			break
	hud.set_objective("%s  (%d/%d)" % [next, done, total])

func _on_objective_completed(objective: String) -> void:
	show_message("Objective complete: " + objective, 3.0)
	_update_objective_label()
	_update_hud()

func _on_mission_completed(rank: String, stats: Dictionary) -> void:
	save.unlock_mission(current_mission + 1)
	save.set_rank(current_mission, rank)
	lan.send_mission_complete(rank)
	hud.show_results()
	var msg: String = "MISSION COMPLETE: %s - Rank %s  Time %ds  Kills %d  Revives %d  Secrets %d - press N for next mission" % [GameData.mission(current_mission)["title"], rank, int(stats["time"]), int(stats["kills"]), int(stats["revives"]), int(stats["secrets"])]
	show_message(msg, 8.0)
	hud.set_objective("MISSION COMPLETE - Rank " + rank)
	started = false

func _on_mission_failed() -> void:
	show_message("MISSION FAILED - press R to retry", 5.0)
	started = false

func toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	show_message("PAUSED - Esc to resume" if paused else "", 1.0)

func _pick_enemy() -> String:
	var pool: Array[String] = ["Grunt", "Grunt", "Grunt", "Scout", "Heavy", "Drone", "Sniper", "ShieldTrooper", "RocketSoldier", "Engineer", "Beast", "EliteGuard"]
	var idx: int = randi() % pool.size()
	# Later missions unlock tougher types.
	if current_mission < 4 and pool[idx] in ["EliteGuard", "Beast"]:
		return "Grunt"
	return pool[idx]

func _process(delta: float) -> void:
	# Touch state is read from the TouchControls node each frame.
	if touch != null:
		touch_move = touch.move
		touch_fire = touch.fire
		touch_interact = touch.interact
		if touch.jump_pressed:
			touch_jump_pressed = true
			touch.jump_pressed = false
		if touch.ability_pressed:
			touch_ability_pressed = true
			touch.ability_pressed = false
	if hud != null:
		hud.mission_time = mission_mgr.mission_time
	if player != null:
		var target: Vector2 = player.global_position + Vector2(120, -40)
		# Snap if the camera is far away (respawn / reload), otherwise
		# smooth-follow - and clamp to the level so it never shows
		# empty space past the level ends.
		if camera.position.distance_to(target) > 900.0:
			camera.position = target
		else:
			camera.position = camera.position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
		var lvl_len: float = float(mission_mgr.layout.get("level_length", 52.0)) * GameData.SCALE
		camera.position.x = clampf(camera.position.x, -600.0, lvl_len + 200.0)
		camera.position.y = clampf(camera.position.y, -600.0, 200.0)
		# Boss trigger: crossing the boss x spawns the mission boss.
		var layout: Dictionary = mission_mgr.layout
		var boss_id: String = str(GameData.mission(current_mission).get("boss", ""))
		if boss_id != "" and not _boss_spawned and started:
			var need_stations: bool = bool(layout.get("boss_after_stations", false))
			var stations_done: bool = mission_mgr.done_objectives.size() >= (layout["stations"] as Array).size()
			if player.global_position.x > float(layout["boss_spawn_x"]) * GameData.SCALE and (not need_stations or stations_done):
				spawn_boss(boss_id)
	# Trickle-spawn enemies near the player so missions stay populated.
	if started and not mission_mgr.mission_complete:
		_enemy_spawn_t -= delta
		if _enemy_spawn_t <= 0.0:
			_enemy_spawn_t = 6.0
			var enemies: Array = _own("enemy")
			if enemies.size() < 6:
				spawn_enemy_at(_pick_enemy(), player.global_position + Vector2(randf_range(500.0, 800.0), -128.0))
	if player != null and player.weapons != null:
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.keycode == KEY_R and mission_mgr.is_failed:
			load_mission_level(current_mission)
			started = true
			menu.visible = false
			touch.visible = true
		elif k.keycode == KEY_N and mission_mgr.mission_complete:
			if current_mission < 20:
				load_mission_level(current_mission + 1)
				started = true
				menu.visible = false
				touch.visible = true
			else:
				show_message("CAMPAIGN COMPLETE - all 20 missions done!", 5.0)
		elif k.keycode == KEY_ESCAPE:
			toggle_pause()
		elif k.keycode == KEY_TAB:
			show_message("Mission: " + str(GameData.mission(current_mission)["title"]), 3.0)
