extends SceneTree

# Headless animation probe: proves the walk cycles, player animator
# and explosion frames are actually active in-game (the smoke test
# only proves the game runs - a missing frame folder would silently
# fall back to the static sprite, so this checks explicitly).
#
#   godot --headless --path . -s res://tools/anim_probe.gd

var _ok: bool = true

func _fail(msg: String) -> void:
	printerr("ANIM FAIL: " + msg)
	_ok = false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# 1. Frame folders load with the expected counts (verified grid).
	var expect := {"grunt": 14, "scout": 8, "elite": 14, "heavy": 14}
	for folder in expect.keys():
		var sf: SpriteFrames = CharacterAnimator.build_frames(folder)
		if sf == null:
			_fail("no SpriteFrames for " + folder)
		elif sf.get_frame_count("walk") != expect[folder]:
			_fail(folder + " has %d frames, expected %d" % [sf.get_frame_count("walk"), expect[folder]])
		else:
			print("ANIM frames %s: %d ok" % [folder, expect[folder]])
	# 2. Explosion frames.
	var boom := SpriteFrames.new()
	boom.add_animation("boom")
	for i in range(4):
		var p: String = "res://assets/anim/explosion/frame_%02d.png" % i
		if ResourceLoader.exists(p):
			boom.add_frame("boom", load(p))
	if boom.get_frame_count("boom") != 4:
		_fail("explosion has %d frames, expected 4" % boom.get_frame_count("boom"))
	else:
		print("ANIM frames explosion: 4 ok")
	# 3. In-game: spawn mission 1, check a walking enemy has a live
	# AnimatedSprite2D and its static sprite is hidden.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	main.start_game()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var walked: int = 0
	var total: int = 0
	for e in get_nodes_in_group("enemy"):
		total += 1
		var ws: Node = e.get_node_or_null("WalkSprite")
		if ws != null and ws is AnimatedSprite2D:
			walked += 1
			var spr: Sprite2D = e.get_node_or_null("Sprite2D")
			if spr != null and spr.visible:
				_fail("enemy " + str(e.get("enemy_id")) + " has both WalkSprite and visible static sprite")
	print("ANIM enemies with walk cycle: %d of %d" % [walked, total])
	if walked == 0:
		_fail("no enemy is using a walk cycle (all fell back to static)")
	# 4. Player has a procedural animator and the boss hovers.
	var player: Node = main.get_node_or_null("Player")
	if player == null:
		_fail("no Player node")
	elif player.get("_animator") == null:
		_fail("player has no PlayerAnimator")
	else:
		print("ANIM player animator: ok")
	var boss_count: int = 0
	for e in get_nodes_in_group("boss"):
		boss_count += 1
		if e.get("_animator") == null:
			_fail("boss has no CharacterAnimator")
	print("ANIM bosses with animator: %d" % boss_count)
	# Mission 1 has no boss, so test the boss path directly: spawn a
	# Jungle Walker and check its hover animator is set up.
	var boss_packed: PackedScene = load("res://scenes/Boss.tscn")
	var boss: Node = boss_packed.instantiate()
	main.get_node("World").add_child(boss)
	boss.setup_boss("JungleWalker", main, Vector2(0, -256), 1)
	if boss.get("_animator") == null:
		_fail("boss setup did not create a CharacterAnimator")
	elif float(boss.get("_animator").get("bob_amp")) <= 0.0:
		_fail("boss hover bob is not configured")
	else:
		print("ANIM boss hover animator: ok")
	# 5. Explosion spawns and plays (rocket visual).
	Explosion.spawn(main.get_node("World"), Vector2(0, -256), 200.0)
	for i in range(10):
		await process_frame
	var booms: int = 0
	for n in main.get_node("World").get_children():
		if n is Explosion:
			booms += 1
	if booms == 0:
		_fail("Explosion.spawn produced no Explosion node")
	else:
		print("ANIM explosion spawns: ok")
	print("ANIM RESULT: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)