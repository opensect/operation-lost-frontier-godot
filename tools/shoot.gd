extends SceneTree

# Real rendered screenshots under xvfb (NOT headless dummy renderer).
# Run: xvfb-run -a godot --path . -s res://tools/shoot.gd
# Saves /tmp/shot_menu.png, /tmp/shot_game.png, /tmp/shot_moved.png
# and prints the same visibility dump as the smoke test.

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(path: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("SHOT saved %s %s" % [path, str(img.get_size())])

func _dump(main: Node, tag: String) -> void:
	var sprites: Array = []
	_collect(main, sprites)
	var nulls: int = 0
	var vis: int = 0
	for s in sprites:
		var tex: Texture2D = s.texture if s is Sprite2D else null
		if s is Sprite2D and tex == null:
			nulls += 1
		if s.visible and (s is AnimatedSprite2D or tex != null):
			vis += 1
	var p: Node = main.get_node_or_null("Player")
	var cam: Node = main.get_node_or_null("Camera2D")
	print("SHOT %s player=%s camera=%s enemies=%d sprites=%d visible_textured=%d null=%d" % [
		tag, str(p.global_position) if p != null else "?",
		str(cam.position) if cam != null else "?",
		get_nodes_in_group("enemy").size(), sprites.size(), vis, nulls])

func _collect(n: Node, out: Array) -> void:
	if n is Sprite2D or n is AnimatedSprite2D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)

func _run() -> void:
	root.size = Vector2(1920, 1080)
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	# Force Mission 1 (a save file can leave the unlocked mission at 5).
	main.load_mission_level(1)
	await _frames(40)
	_dump(main, "MENU")
	await _shot("/tmp/shot_menu.png")
	main.start_game()
	await _frames(60)
	_dump(main, "GAME")
	await _shot("/tmp/shot_game.png")
	# Move right with the joystick, jump, fire.
	var joy: Node = main.get_node_or_null("TouchControls/Joystick")
	if joy != null:
		joy.value = 1.0
		joy._knob_offset = Vector2(68, 0)
		joy.queue_redraw()
	main.touch.fire = true
	await _frames(90)
	main.touch.fire = false
	joy.value = 0.0
	_dump(main, "MOVED")
	await _shot("/tmp/shot_moved.png")
	# Small phone size.
	root.size = Vector2(800, 360)
	await _frames(10)
	_dump(main, "SMALL")
	await _shot("/tmp/shot_small.png")
	print("SHOT DONE")
	quit(0)
