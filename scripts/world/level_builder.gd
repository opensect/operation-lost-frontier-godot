class_name LevelBuilder
extends Node

# Owns ONLY level construction from a layout dictionary: ground,
# platforms, props, hazards, stations, checkpoints, pickups, spawn
# points, and the per-mission backdrop vista. It never runs gameplay -
# it returns the built nodes and the Game wires them up.
# (Single Responsibility.)

# Y_OFF: layout Y values are Unity feet positions (ground top -2.5
# units). In Godot the walkable ground top is -3.5 units, so every
# layout Y is shifted up 1.5 units - otherwise stations, checkpoints,
# pickups and extraction sit below the ground surface where the
# player can never reach them.
const Y_OFF: float = -1.5

signal level_built(info: Dictionary)

func build(world: Node2D, layout: Dictionary, game: Node) -> Dictionary:
	# Clear the previous mission's level nodes (kept under "LevelRoot").
	var old: Node = world.get_node_or_null("LevelRoot")
	if old != null:
		# Remove immediately, not just queue_free: a queued node keeps
		# its name until the frame ends, so the new root was renamed
		# "LevelRoot@2" and get_node("World/LevelRoot") could never
		# find the live level again.
		world.remove_child(old)
		old.queue_free()
	var root := Node2D.new()
	root.name = "LevelRoot"
	world.add_child(root)
	var s: float = GameData.SCALE
	var length: float = float(layout["level_length"])
	var info: Dictionary = {"spawn_points": [], "boss_spawn_x": float(layout["boss_spawn_x"])}
	# Backdrop is now camera-following (Main sets it on a CanvasLayer),
	# NOT two fixed panels in the world: fixed panels tiled with seams,
	# overlapped, and left blank space past x=3400 - screenshot 2.
	# Ground visuals: clean generated tile (256x64, transparent, seamless
	# horizontally), uniform scale, step = exact displayed tile width
	# (256 px = 4 units) so tiles abut with no gap and no overlap.
	# The old code stretched a 205x179 opaque scene painting to 448x64
	# per tile - that was the broken / duplicated ground in screenshot 2.
	var ground_tex: Texture2D = SpriteLoader.texture("Environment", str(layout["ground_sprite"]))
	var x: float = -14.0
	while x < length + 4.0:
		var g := Sprite2D.new()
		g.name = "GroundTile"
		g.texture = ground_tex
		# Uniform scale: tile height 64 px = 1 unit, width follows.
		var gs: Vector2 = ground_tex.get_size() if ground_tex != null else Vector2(256, 64)
		var gsc: float = (1.0 * s) / maxf(1.0, gs.y)
		g.scale = Vector2(gsc, gsc)
		var tile_w_units: float = gs.x * gsc / s
		g.position = Vector2((x + tile_w_units * 0.5) * s, -3.0 * s)
		root.add_child(g)
		x += tile_w_units
	# One continuous ground collider - no seams to catch on.
	var ground_body := StaticBody2D.new()
	ground_body.name = "GroundCollider"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2((length + 14.0) * s, 1.0 * s)
	shape.shape = rect
	shape.position = Vector2((length - 14.0) / 2.0 * s, -3.0 * s)
	ground_body.add_child(shape)
	root.add_child(ground_body)
	# Invisible end walls: the player / enemies can never walk off the
	# end of the level and fall into the void (the blank-world shot).
	for wx in [-14.0, length]:
		var wall := StaticBody2D.new()
		wall.name = "EndWall"
		wall.collision_layer = 1
		wall.collision_mask = 0
		var wshape := CollisionShape2D.new()
		var wrect := RectangleShape2D.new()
		wrect.size = Vector2(1.0 * s, 20.0 * s)
		wshape.shape = wrect
		wshape.position = Vector2(wx * s, -10.0 * s)
		wall.add_child(wshape)
		root.add_child(wall)
	# One-way platforms.
	for plat in layout["platforms"]:
		var p := StaticBody2D.new()
		var ps := CollisionShape2D.new()
		var pr := RectangleShape2D.new()
		pr.size = Vector2(5.0 * s, 0.6 * s)
		ps.shape = pr
		ps.one_way_collision = true
		p.add_child(ps)
		var spr := Sprite2D.new()
		# Slab art is a flat stone slab: stretch it to the full collider
		# size (320x38) - fit-inside would leave it 202 px wide with
		# empty collider sticking out on both sides.
		var ptex: Texture2D = SpriteLoader.texture("Environment", "stone_platform_tiles")
		spr.texture = ptex
		if ptex != null:
			var pts: Vector2 = ptex.get_size()
			spr.scale = Vector2((5.0 * s) / maxf(1.0, pts.x), (0.6 * s) / maxf(1.0, pts.y))
		p.add_child(spr)
		p.position = Vector2(float(plat[0]) * s, GameData.godot_y(float(plat[1])) * s)
		root.add_child(p)
	# Props (watchtowers, crates, barrels, traps).
	for prop in layout["props"]:
		var go := Sprite2D.new()
		go.name = str(prop["sprite"])
		var cat: String = str(prop["cat"])
		SpriteLoader.apply_to_sprite(go, cat, str(prop["sprite"]), Color.WHITE, Vector2(float(prop["size"][0]) * s, float(prop["size"][1]) * s))
		# Ground hazards sit ON the ground: their layout Y (-3.0) put
		# them 64 px in the air (floating spikes). Pin them to the
		# ground top (-3.7 units, same as the hardcoded hazard spots).
		var py: float = GameData.godot_y(float(prop["pos"][1]))
		if str(prop["sprite"]) in ["spike_trap", "proximity_mine"]:
			py = -3.7
		go.position = Vector2(float(prop["pos"][0]) * s, py * s)
		root.add_child(go)
		if str(prop["sprite"]) in ["spike_trap", "proximity_mine", "laser_barrier"]:
			var hz: Area2D = load("res://scenes/Hazard.tscn").instantiate()
			hz.position = go.position
			hz.damage = 15 if str(prop["sprite"]) == "laser_barrier" else 10
			hz.set_kind({"spike_trap": "spikes", "laser_barrier": "laser", "proximity_mine": "toxic"}[str(prop["sprite"])])
			root.add_child(hz)
	# Environment hazards from the mission's own flags (batch-10 art):
	# ice missions get ice spikes, the crusher factory gets a saw,
	# the unstable reactor gets a laser surge zone. Damage on touch,
	# pulsing red warning - see Hazard.
	var _hz_spots: Array = []
	if bool(layout.get("ice", false)):
		_hz_spots.append(["ice", float(length) * 0.5])
	if "crusher" in str(layout.get("mechanic", "")):
		_hz_spots.append(["saw", float(length) * 0.6])
	if "reactor" in str(layout.get("mechanic", "")) or "surge" in str(layout.get("mechanic", "")):
		_hz_spots.append(["laser", float(length) * 0.45])
	for _hk in _hz_spots:
		var _hz: Area2D = load("res://scenes/Hazard.tscn").instantiate()
		_hz.position = Vector2(float(_hk[1]) * s, (-2.2 + Y_OFF) * s)
		_hz.damage = 15
		_hz.set_kind(str(_hk[0]))
		root.add_child(_hz)
	# Objective stations.
	for st in layout["stations"]:
		var station: Area2D = load("res://scenes/Station.tscn").instantiate()
		station.position = Vector2(float(st["pos"][0]) * s, GameData.godot_y(float(st["pos"][1])) * s)
		root.add_child(station)
		# Generic supply stations become the batch-12 console terminal;
		# named stations (gates, turrets, barriers) keep their batch-1 art.
		var st_sprite: String = str(st["sprite"])
		if st_sprite == "metal_supply_box":
			st_sprite = "atlas:terminal"
		station.setup(str(st["objective"]), float(st["hold"]), int(st["count"]), st_sprite, game)
	# Checkpoints (after the spawn).
	var cps: Array = layout["checkpoints"]
	for i in range(1, cps.size()):
		var cp := Area2D.new()
		# Areas must detect the player (layer 2): the default mask 1
		# only sees layer-1 bodies, so checkpoints never fired and
		# respawns always went back to the start. Same convention as
		# Pickup/Station/Hazard (layer 32, mask 2).
		cp.collision_layer = 32
		cp.collision_mask = 2
		cp.name = "Checkpoint"
		var cs := CollisionShape2D.new()
		var cr := RectangleShape2D.new()
		cr.size = Vector2(64, 96)
		cs.shape = cr
		cp.add_child(cs)
		var spr2 := Sprite2D.new()
		SpriteLoader.apply_to_sprite(spr2, "Props", "metal_supply_box", Color.CYAN, Vector2(64, 96))
		cp.add_child(spr2)
		cp.position = Vector2(float(cps[i][0]) * s, GameData.godot_y(float(cps[i][1])) * s)
		cp.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group("player") and game != null and game.has_method("set_checkpoint"):
				game.set_checkpoint(cp.position))
		root.add_child(cp)
	# Extraction beacon at the far end.
	var ex := Sprite2D.new()
	ex.name = "ExtractionBeacon"
	SpriteLoader.apply_to_sprite(ex, "Props", "atlas:portal", Color.CYAN, Vector2(96, 128))
	ex.position = Vector2((length - 4.0) * s, (-2.2 + Y_OFF) * s)
	root.add_child(ex)
	var ex_area := Area2D.new()
	# Same mask bug as the checkpoints: default mask 1 never sees
	# the player (layer 2), so the extraction beacon never fired
	# and Mission 2's escort objective could never complete.
	ex_area.collision_layer = 32
	ex_area.collision_mask = 2
	ex_area.name = "ExtractionArea"
	var ex_shape := CollisionShape2D.new()
	var ex_rect := RectangleShape2D.new()
	ex_rect.size = Vector2(120, 160)
	ex_shape.shape = ex_rect
	ex_area.add_child(ex_shape)
	ex_area.position = ex.position
	ex_area.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and game != null and game.has_method("on_extraction_reached"):
			game.on_extraction_reached())
	root.add_child(ex_area)
	info["spawn_points"] = layout["spawn_points"]
	info["extraction_pos"] = ex.position
	level_built.emit(info)
	return info
