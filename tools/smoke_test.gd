extends SceneTree

# Headless smoke test: load the REAL Main scene, step frames, and prove
# the world is visible - the exact thing the Unity build failed at.
# Also audits the menu/HUD layout at 1920x1080 and at 800x360, and
# proves the player/enemies spawn ON the ground (not below it).
# Run: godot --headless --path . -s res://tools/smoke_test.gd

var _frames: int = 0
var _ok: bool = true

func _fail(msg: String) -> void:
	printerr("SMOKE FAIL: " + msg)
	_ok = false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		_fail("Main.tscn did not load")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in range(30):
		await process_frame
		_frames += 1
	_dump(main, "BEFORE START")
	_audit_layout(main, "MENU 1920x1080")
	root.size = Vector2(800, 360)
	for i in range(5):
		await process_frame
		_frames += 1
	_audit_layout(main, "MENU 800x360")
	root.size = Vector2(1920, 1080)
	for i in range(5):
		await process_frame
		_frames += 1
	_audit_art(main)
	if main.has_method("start_game"):
		main.start_game()
	for i in range(60):
		await process_frame
		_frames += 1
	_dump(main, "AFTER START")
	var player: Node = main.get_node_or_null("Player")
	if player == null:
		_fail("no Player node in scene")
	else:
		var py: float = player.global_position.y
		print("SMOKE player pos=%s (ground top is -224, standing centre ~-260)" % str(player.global_position))
		if py < -330.0 or py > -180.0:
			_fail("player not standing on the ground, y=%f" % py)
	var sprites: Array = []
	_collect_sprites(main, sprites)
	var null_sprites: int = 0
	for s in sprites:
		if s.texture == null:
			null_sprites += 1
	print("SMOKE sprites total=%d null=%d" % [sprites.size(), null_sprites])
	if null_sprites > 0:
		_fail("%d Sprite2D nodes have no texture" % null_sprites)
	var enemies: Array = get_nodes_in_group("enemy")
	print("SMOKE enemies in scene: %d" % enemies.size())
	if enemies.size() < 4:
		_fail("expected at least 4 enemies from the layout spawn points, got %d" % enemies.size())
	for e in enemies:
		if e.global_position.y < -330.0 or e.global_position.y > 0.0:
			_fail("enemy %s below the ground, y=%f" % [str(e.name), e.global_position.y])
	for st in get_nodes_in_group("station"):
		if st.global_position.y < -330.0 or st.global_position.y > -120.0:
			_fail("station %s out of player reach, y=%f" % [str(st.name), st.global_position.y])
	_audit_layout(main, "HUD 1920x1080")
	# Small landscape phone: resize and re-audit the HUD.
	root.size = Vector2(800, 360)
	for i in range(5):
		await process_frame
		_frames += 1
	_audit_layout(main, "HUD 800x360")
	root.size = Vector2(1920, 1080)
	for i in range(5):
		await process_frame
		_frames += 1
	print("SMOKE RESULT: " + ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)

func _audit_art(main: Node) -> void:
	for n in ["MenuBackdrop", "LogoImage", "IconImage", "MissionThumb"]:
		var tr: TextureRect = main.get_node_or_null("%" + n) as TextureRect
		if tr == null:
			_fail("menu node missing: " + n)
		elif tr.texture == null:
			_fail("menu art missing texture: " + n)
		else:
			print("SMOKE art ok: %s %s" % [n, str(tr.texture.get_size())])
	if SheetSlicer.interactive_terminal() == null or SheetSlicer.interactive_portal() == null:
		_fail("batch-12 atlas art (terminal/portal) did not resolve")
	for hn in ["hazard_spikes", "hazard_lava", "hazard_toxic", "hazard_saw", "hazard_laser", "hazard_ice"]:
		if not ResourceLoader.exists("res://assets/hazards/" + hn + ".png"):
			_fail("batch-10 hazard art missing: " + hn)
	var hz_test: Area2D = load("res://scenes/Hazard.tscn").instantiate()
	hz_test.set_kind("spikes")
	if (hz_test.get_node_or_null("Sprite2D") as Sprite2D).texture == null:
		_fail("hazard set_kind did not set a texture")
	hz_test.queue_free()

func _audit_layout(main: Node, tag: String) -> void:
	var vp: Vector2 = root.get_visible_rect().size
	var rects: Array = []
	_collect_controls(main.get_node_or_null("MainMenu") if main.get_node_or_null("MainMenu").visible else main.get_node_or_null("HUD"), rects)
	var bad: int = 0
	for c in rects:
		var r: Rect2 = c.get_global_rect()
		if r.position.x < -2.0 or r.position.y < -2.0 or r.end.x > vp.x + 2.0 or r.end.y > vp.y + 2.0:
			_fail("%s: %s outside viewport %s rect=%s" % [tag, str(c.name), str(vp), str(r)])
			bad += 1
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i].get_global_rect()
			var b: Rect2 = rects[j].get_global_rect()
			if a.intersects(b):
				var inter: Rect2 = a.intersection(b)
				if inter.get_area() > 25.0 and rects[i] is Button and rects[j] is Button:
					_fail("%s: buttons overlap: %s vs %s area=%f" % [tag, str(rects[i].name), str(rects[j].name), inter.get_area()])
					bad += 1
	print("SMOKE layout %s viewport=%s controls=%d problems=%d" % [tag, str(vp), rects.size(), bad])

func _collect_controls(n: Node, out: Array) -> void:
	if n == null:
		return
	if n is Button or n is Label or n is LineEdit:
		if n.visible:
			out.append(n)
	for child in n.get_children():
		_collect_controls(child, out)

func _dump(main: Node, tag: String) -> void:
	var sprites: Array = []
	_collect_sprites(main, sprites)
	var menu: Node = main.get_node_or_null("MainMenu")
	var hud: Node = main.get_node_or_null("HUD")
	var touch: Node = main.get_node_or_null("TouchControls")
	print("SMOKE %s frames=%d nodes=%d sprites=%d menu_visible=%s hud=%s touch_visible=%s player_pos=%s camera_pos=%s" % [
		tag, _frames, _count(main), sprites.size(),
		str(menu.visible) if menu != null else "missing",
		"ok" if hud != null else "missing",
		str(touch.visible) if touch != null else "missing",
		str(main.get_node_or_null("Player").global_position) if main.get_node_or_null("Player") != null else "missing",
		str(main.get_node_or_null("Camera2D").position) if main.get_node_or_null("Camera2D") != null else "missing"])

func _count(n: Node) -> int:
	var c: int = 1
	for child in n.get_children():
		c += _count(child)
	return c

func _collect_sprites(n: Node, out: Array) -> void:
	if n is Sprite2D:
		out.append(n)
	for child in n.get_children():
		_collect_sprites(child, out)
