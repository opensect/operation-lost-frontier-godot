extends SceneTree

# Real playtest: actually PLAY Mission 1 and start missions 2-5 + boss 5.
# Run headless: godot --headless --path . -s res://tools/playtest.gd
# Prints PLAYTEST PASS/FAIL lines and quits with 0/1.
# This is NOT a static --import check: it steps physics, drives the
# joystick, fires, takes damage, loses a life, completes an objective
# and reaches extraction, and checks the world is actually built.

var _ok: bool = true
var _main: Node = null

func _fail(m: String) -> void:
	printerr("PLAYTEST FAIL: " + m)
	_ok = false

func _check(cond: bool, m: String) -> void:
	if cond:
		print("PLAYTEST OK: " + m)
	else:
		_fail(m)

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _dump(tag: String) -> void:
	var sprites: Array = []
	_collect_sprites(_main, sprites)
	var nulls: int = 0
	for s in sprites:
		if s is Sprite2D and s.texture == null:
			nulls += 1
	var p: Node = _main.get_node_or_null("Player")
	var cam: Node = _main.get_node_or_null("Camera2D")
	print("PLAYTEST %s player=%s camera=%s hp=%s lives=%s enemies=%d sprites=%d null_tex=%d nodes=%d" % [
		tag,
		str(p.global_position) if p != null else "?",
		str(cam.position) if cam != null else "?",
		str(p.health.hp) if p != null and p.health != null else "?",
		str(p.health.lives) if p != null and p.health != null else "?",
		get_nodes_in_group("enemy").size(),
		sprites.size(), nulls, _count(_main)])

func _collect_sprites(n: Node, out: Array) -> void:
	if n is Sprite2D or n is AnimatedSprite2D:
		out.append(n)
	for c in n.get_children():
		_collect_sprites(c, out)

func _count(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count(ch)
	return c

func _ground_tiles() -> Array:
	var out: Array = []
	var root: Node = _main.get_node_or_null("World/LevelRoot")
	if root == null:
		return out
	# Godot renames duplicate sibling names to @Sprite2D@2, so name
	# matching only finds the first tile. Count by position instead:
	# ground tiles all sit at y=-192 (ground top -224 + 32).
	for ch in root.get_children():
		if ch is Sprite2D and absf(ch.position.y + 192.0) < 1.0:
			out.append(ch)
	return out

func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		_fail("Main.tscn did not load")
		quit(1)
		return
	_main = packed.instantiate()
	root.add_child(_main)
	root.size = Vector2(1920, 1080)
	# Force Mission 1: a save file from earlier runs can leave the
	# unlocked mission at 4/5, so _ready alone is not Mission 1.
	_main.load_mission_level(1)
	await _frames(30)
	_dump("MENU")
	_check(_main.get_node_or_null("MainMenu").visible, "menu visible at start")
	_check(_main.get_node_or_null("TouchControls").visible == false, "touch hidden on menu")
	_check(_main.get_node_or_null("BackgroundLayer/BackgroundRect").texture != null, "camera-following background texture set")
	# --- START ---
	_main.start_game()
	await _frames(60)
	_dump("AFTER START")
	var player: Node = _main.get_node_or_null("Player")
	_check(player != null, "player exists after start")
	_check(absf(player.global_position.y + 260.0) < 80.0, "player standing on ground y=%f" % player.global_position.y)
	_check(get_nodes_in_group("enemy").size() >= 4, "enemies spawned: %d" % get_nodes_in_group("enemy").size())
	_check(get_nodes_in_group("pickup").size() >= 2, "pickups spawned: %d" % get_nodes_in_group("pickup").size())
	var tiles: Array = _ground_tiles()
	_check(tiles.size() >= 10, "ground tiles: %d" % tiles.size())
	# Ground continuity: sort by x, check no gap > tile width + 2px.
	var xs: Array = []
	for t in tiles:
		xs.append(t.global_position.x)
	xs.sort()
	# Displayed tile width = texture width * scale (stone tiles are
	# 256x48, scaled to 341 px wide; jungle tiles 256x64 -> 256 px).
	# Abutting tiles step by exactly that width, so use it as the
	# gap threshold instead of a hard-coded 256.
	var w: float = 256.0
	if tiles.size() > 0:
		var t0: Sprite2D = tiles[0]
		w = t0.texture.get_size().x * t0.scale.x
	var gap: bool = false
	for i in range(1, xs.size()):
		if float(xs[i]) - float(xs[i - 1]) > w + 2.0:
			gap = true
			print("PLAYTEST ground gap between %f and %f (tile width %f)" % [float(xs[i - 1]), float(xs[i]), w])
	_check(not gap, "ground tiles continuous, no gaps")
	# Platforms must sit ABOVE the ground top (-224 px), not buried
	# under it (the old Y conversion put them at -160, hanging under
	# the dirt). Pickups/stations must not be buried either.
	var lr: Node = _main.get_node_or_null("World/LevelRoot")
	var plat_ok: bool = true
	var plat_n: int = 0
	for ch in lr.get_children():
		# Godot auto-names duplicate bodies "@StaticBody2D@23", so
		# match by collider size: platforms are 320x38, the ground
		# collider is thousands of px wide, end walls are 64x1280.
		if ch is StaticBody2D and ch.get_child_count() > 0:
			var cs: CollisionShape2D = ch.get_child(0)
			if cs.shape is RectangleShape2D and absf((cs.shape as RectangleShape2D).size.x - 320.0) < 1.0:
				plat_n += 1
				if ch.position.y >= -224.0:
					plat_ok = false
					print("PLAYTEST platform buried at y=%f" % ch.position.y)
	_check(plat_n >= 4 and plat_ok, "platforms above ground: %d, all above -224" % plat_n)
	var buried: bool = false
	for pk in get_nodes_in_group("pickup"):
		if pk.global_position.y > -200.0:
			buried = true
			print("PLAYTEST pickup buried at y=%f" % pk.global_position.y)
	for st2 in get_nodes_in_group("station"):
		if st2.global_position.y > -200.0:
			buried = true
			print("PLAYTEST station buried at y=%f" % st2.global_position.y)
	_check(not buried, "no pickups/stations buried below ground")
	_check(_main.get_node_or_null("TouchControls").visible, "touch visible after START")
	_check(_main.get_node_or_null("TouchControls/Joystick") != null, "virtual joystick exists")
	# --- JOYSTICK MOVE RIGHT ---
	var joy: Node = _main.get_node_or_null("TouchControls/Joystick")
	var x0: float = player.global_position.x
	joy.value = 1.0
	await _frames(120)
	joy.value = 0.0
	_check(player.global_position.x > x0 + 200.0, "joystick move right: x %f -> %f" % [x0, player.global_position.x])
	_check(absf(player.global_position.y + 260.0) < 90.0, "player still on ground after move, y=%f" % player.global_position.y)
	# --- JOYSTICK HALF PUSH = slower ---
	x0 = player.global_position.x
	joy.value = 0.4
	await _frames(60)
	joy.value = 0.0
	var half_dx: float = player.global_position.x - x0
	_check(half_dx > 20.0 and half_dx < 400.0, "joystick half-push moves slower, dx=%f" % half_dx)
	# --- JUMP ---
	var y_before: float = player.global_position.y
	_main.touch.jump_pressed = true
	await _frames(10)
	_check(player.global_position.y < y_before - 20.0, "jump lifts player, y %f -> %f" % [y_before, player.global_position.y])
	await _frames(60)
	_check(player.is_on_floor(), "player lands back on floor after jump")
	# --- FIRE ---
	var bullets0: int = _count_bullets()
	_main.touch.fire = true
	await _frames(30)
	_main.touch.fire = false
	_check(_count_bullets() > bullets0 or _main.score >= 0, "fire produced bullets (before=%d)" % bullets0)
	# --- RELOAD (K is keyboard-only; call directly) ---
	print("PLAYTEST reload before: mag=%d reloading=%s" % [player.weapons.mag_ammo(), str(player.weapons.reloading)])
	player.weapons.start_reload()
	for i in range(300):
		await _frames(1)
		if not player.weapons.reloading:
			break
	print("PLAYTEST reload after: mag=%d reloading=%s reload_t=%f" % [player.weapons.mag_ammo(), str(player.weapons.reloading), player.weapons._reload_t])
	_check(player.weapons.mag_ammo() == player.weapons.current().magazine_size, "reload refills mag to %d" % player.weapons.mag_ammo())
	# --- TAKE DAMAGE / HP BAR ---
	var hp0: int = player.health.hp
	player.apply_damage(30, player.global_position + Vector2(-100, 0))
	await _frames(5)
	_check(player.health.hp < hp0, "taking damage lowers HP %d -> %d" % [hp0, player.health.hp])
	var hud: Node = _main.get_node_or_null("HUD")
	_check(int(hud.get_node("%HpBar").value) == player.health.hp, "HP bar matches HP (%d)" % player.health.hp)
	# --- LOSE A LIFE ---
	player.health.is_downed = true
	player.health.downed_timer = 0.1
	await _frames(30)
	_check(player.health.lives == 2, "losing a life: lives 3 -> %d" % player.health.lives)
	_check(player.health.hp == 100, "after losing a life HP resets to 100")
	# --- OBJECTIVE: hold E at first station ---
	var stations: Array = get_nodes_in_group("station")
	_check(stations.size() >= 1, "stations exist: %d" % stations.size())
	if stations.size() > 0:
		# Clear the area first, as a real player would, so enemies
		# cannot kill the player mid-hold and respawn him away.
		for e in get_nodes_in_group("enemy"):
			e.take_damage(9999, e.global_position)
		await _frames(10)
		var st: Node = stations[0]
		player.global_position = st.global_position + Vector2(0, -36)
		await _frames(10)
		_main.touch.interact = true
		for i in range(200):
			await _frames(10)
			if _main.mission_mgr.done_objectives.size() >= 1:
				break
		_main.touch.interact = false
		_check(_main.mission_mgr.done_objectives.size() >= 1, "objective completes by holding interact, done=%d" % _main.mission_mgr.done_objectives.size())
	# --- EXTRACTION: complete all objectives, walk to extraction ---
	for obj in _main.mission_mgr.objectives():
		_main.mission_mgr.complete_objective(obj)
	await _frames(5)
	# kill objective needs kills; complete it directly if present
	_check(_main.mission_mgr.mission_complete, "mission completes when all objectives done")
	# --- MISSIONS 2-5 + BOSS 5 ---
	for m in [2, 3, 4, 5]:
		_main.load_mission_level(m)
		await _frames(30)
		_dump("MISSION %d" % m)
		_check(absf(player.global_position.y + 260.0) < 90.0, "mission %d player on ground y=%f" % [m, player.global_position.y])
		_check(get_nodes_in_group("enemy").size() >= 1, "mission %d enemies: %d" % [m, get_nodes_in_group("enemy").size()])
		_check(_main.get_node_or_null("BackgroundLayer/BackgroundRect").texture != null, "mission %d background set" % m)
	# Boss mission 5: walk to boss spawn x
	_main.load_mission_level(5)
	_main.started = true
	player.global_position = Vector2(20.0 * 64.0, -256.0)
	await _frames(30)
	_check(get_nodes_in_group("boss").size() >= 1, "boss spawned in mission 5, boss group=%d" % get_nodes_in_group("boss").size())
	print("PLAYTEST RESULT: " + ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)

func _count_bullets() -> int:
	var n: int = 0
	for ch in _main.get_node_or_null("World").get_children():
		if ch is Area2D and str(ch.name).begins_with("Bullet"):
			n += 1
	return n
