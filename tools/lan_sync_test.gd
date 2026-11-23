extends SceneTree

# Headless LAN sync test (sequential phases, one Main at a time).
#
# WHY SEQUENTIAL: two Main instances in one SceneTree share one
# physics space, so the host's player would collect the client's
# pickups and vice versa. Instead the host runs alone, is then frozen
# (process disabled, all its physics bodies set to layer 0 / mask 0 so
# nothing interacts), and the client runs alone. The host snapshot is
# the bridge between the phases - exactly what the network carries in
# a real session.
#
# WHY NO REAL NETWORK: the sandbox blocks UDP sends at the syscall
# level (python sendto() -> PermissionError: Operation not permitted),
# so two Godot processes can never complete an ENet handshake here -
# create_server / create_client both return OK, but the client gets
# "connection_failed" and ENet logs "Sending failed!". That is a
# sandbox limit, not a game bug. The ENet transport is stock Godot
# (ENet on port 7777, discovery on UDP 8888); live two-device play
# still needs real hardware.
#
# What IS tested here, end to end: the snapshot protocol
# (LanSync build -> apply), host damage validation, pickup-claim
# validation and stable keys, remote-player state application and
# interpolation, stale-snapshot rejection. The RPCs in LanManager are
# thin wrappers around exactly these calls, so a pass here means the
# protocol is correct; only the UDP wire remains unproven in-sandbox.
#
#   godot --headless --path . -s res://tools/lan_sync_test.gd -- --dur=6 --out=/tmp/lan_sync.json

var _dur: int = 6
var _out: String = "/tmp/lan_sync.json"
var _ok: bool = true
var _snapshots: int = 0

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dur="):
			_dur = int(a.trim_prefix("--dur="))
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	_run.call_deferred()

func _fail(msg: String) -> void:
	printerr("LAN SYNC FAIL: " + msg)
	_ok = false

func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		_fail("Main.tscn did not load")
		quit(1)
		return
	# ---------- Phase 1: the host plays alone. ----------
	var host: Node = packed.instantiate()
	root.add_child(host)
	for i in range(5):
		await process_frame
	# Both peers start mission 1. The per-mission seed makes both
	# spawn the SAME enemy types at the same spawn points.
	host.start_game()
	# Pretend the session is up: the host is the authority. The
	# LanManager still gates every real RPC on the link being up, so
	# nothing is actually sent.
	host.lan.connected = true
	host.lan.is_host = true
	# Host player walks onto the double-damage pickup at (256, -224)
	# so a real claim (Area2D body_entered -> collect_pickup) happens.
	var hp_player: Node = host.get_node_or_null("Player")
	if hp_player != null:
		hp_player.global_position = Vector2(240, -260)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < _dur * 1000:
		await process_frame
	var host_state: Dictionary = hp_player.sync_state() if hp_player != null else {}
	var host_claims: Array = host.get_sync_claims()
	if host_claims.is_empty():
		_fail("host claimed no pickup (walk onto (256,-224) did not collect)")
	else:
		print("LAN SYNC host claims: %s" % str(host_claims))
	# Freeze the host in place (out of the client's way): stop its
	# simulation and make every one of its physics bodies
	# non-interacting (layer 0 / mask 0). The host stays in the tree
	# so its state (get_tree(), snapshots, damage) remains readable.
	# (Removing it from the tree instead would make get_tree() null
	# and every later read of the host fail.)
	_freeze(host)
	# ---------- Phase 2: the client plays alone. ----------
	var client: Node = packed.instantiate()
	root.add_child(client)
	for i in range(5):
		await process_frame
	client.start_game()
	client.lan.connected = true
	client.lan.is_host = false
	client.lan.snapshot_applied.connect(func(_seq: int) -> void: _snapshots += 1)
	var t1: int = Time.get_ticks_msec()
	var dmg_home: Vector2 = Vector2.ZERO
	var dmg_before: int = 0
	var dmg_done: bool = false
	while Time.get_ticks_msec() - t1 < _dur * 1000:
		await process_frame
		# Client-side damage test (once, mid-run): hit our first enemy
		# through the real take_damage() entry point. As a client this
		# must route to the host (no local apply); the host applies it
		# (next step) and the snapshot carries the new HP back to us.
		if not dmg_done and Time.get_ticks_msec() - t1 > _dur * 500:
			var enemies: Array = _sorted_enemies(client)
			if enemies.size() > 0:
				var e: Node = enemies[0]
				dmg_home = e.get("home_pos")
				dmg_before = int(e.get("hp"))
				dmg_done = true
				if e.has_method("take_damage"):
					e.take_damage(10, e.global_position, 1)
				if int(e.get("hp")) != dmg_before:
					_fail("client applied enemy damage locally instead of routing to host")
	# The host validates + applies the client's damage claim (exactly
	# what _rpc_damage does on the host), then sends a fresh snapshot.
	if dmg_done:
		host.apply_host_damage(dmg_home, 10)
	var snap: Dictionary = host.lan._sync.build_snapshot(host)
	var applied: bool = client.lan._sync.apply_snapshot(client, snap)
	if not applied:
		_fail("client refused the host snapshot")
	# ---------- Compare enemies / claims / objectives first (right
	# after the snapshot, before the client's enemies drift again). --
	_check_enemies(host, client, dmg_home, dmg_before)
	_check_claims(host, client)
	_check_objectives(host, client)
	# Remote-player state: feed the host's real state packet into the
	# client's RemotePlayer the way _rpc_state would, then let it
	# interpolate toward the host for half a second.
	client._on_peer_joined(2)
	client._on_remote_state(2, host_state.get("pos", Vector2.ZERO), int(host_state.get("hp", 100)), bool(host_state.get("downed", false)), int(host_state.get("facing", 1)), int(host_state.get("mag", 0)), int(host_state.get("reserve", 0)))
	for i in range(30):
		await process_frame
	_check_remote_player(client, host_state)
	# Stale snapshots must be dropped (out-of-order UDP): re-applying
	# the same snapshot is a no-op.
	if client.lan._sync.apply_snapshot(client, snap):
		_fail("stale snapshot (same seq) was applied twice")
	var report: Dictionary = {
		"host_claims": host.get_sync_claims(),
		"client_claims": client.get_sync_claims(),
		"host_enemies": _enemy_rows(host),
		"client_enemies": _enemy_rows(client),
		"host_objectives": host.get_sync_objectives(),
		"client_objectives": client.get_sync_objectives(),
		"pass": _ok,
	}
	var f: FileAccess = FileAccess.open(_out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report))
		f.close()
	print("LAN SYNC RESULT: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)

func _freeze(main: Node) -> void:
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject2D:
			(n as CollisionObject2D).collision_layer = 0
			(n as CollisionObject2D).collision_mask = 0
		for c in n.get_children():
			stack.append(c)

func _sorted_enemies(main: Node) -> Array:
	var arr: Array = []
	for e in main.get_tree().get_nodes_in_group("enemy"):
		if main.is_ancestor_of(e):
			arr.append(e)
	arr.sort_custom(func(a: Node, b: Node) -> bool: return a.get("home_pos").x < b.get("home_pos").x)
	return arr

func _enemy_rows(main: Node) -> Array:
	var rows: Array = []
	for e in _sorted_enemies(main):
		var home: Vector2 = e.get("home_pos")
		rows.append([int(home.x), int(home.y), int(e.global_position.x), int(e.global_position.y), int(e.get("hp"))])
	return rows

func _check_enemies(host: Node, client: Node, dmg_home: Vector2, dmg_before: int) -> void:
	var h_rows: Array = _enemy_rows(host)
	var c_map: Dictionary = {}
	for r in _enemy_rows(client):
		c_map[str(Vector2(r[0], r[1]))] = r
	if h_rows.size() != _enemy_rows(client).size():
		_fail("enemy count differs: host=%d client=%d" % [h_rows.size(), _enemy_rows(client).size()])
		return
	for r in h_rows:
		var key: String = str(Vector2(r[0], r[1]))
		if not c_map.has(key):
			_fail("enemy at home %s missing on client" % key)
			continue
		var c: Array = c_map[key]
		var d: float = Vector2(r[2], r[3]).distance_to(Vector2(c[2], c[3]))
		if d > 150.0:
			_fail("enemy %s positions differ by %.0f px after snapshot (tol 150)" % [key, d])
		if r[4] != c[4]:
			_fail("enemy %s HP differs: host=%d client=%d" % [key, r[4], c[4]])
		if key == str(dmg_home) and r[4] != dmg_before - 10:
			_fail("damaged enemy %s HP is %d, expected %d (host did not apply the claim)" % [key, r[4], dmg_before - 10])
	print("LAN SYNC enemies agree: %d enemies, positions + HP match" % h_rows.size())

func _check_claims(host: Node, client: Node) -> void:
	if host.get_sync_claims() != client.get_sync_claims():
		_fail("claimed pickups differ: host=%s client=%s" % [str(host.get_sync_claims()), str(client.get_sync_claims())])
	else:
		print("LAN SYNC claims agree: %s" % str(host.get_sync_claims()))

func _check_objectives(host: Node, client: Node) -> void:
	if host.get_sync_objectives() != client.get_sync_objectives():
		_fail("objectives differ: host=%s client=%s" % [str(host.get_sync_objectives()), str(client.get_sync_objectives())])
	else:
		print("LAN SYNC objectives agree: %s" % str(host.get_sync_objectives()))

func _check_remote_player(client: Node, host_state: Dictionary) -> void:
	var rps: Array = client.get_tree().get_nodes_in_group("remote_player")
	if rps.is_empty():
		_fail("client has no RemotePlayer for the host")
		return
	var rp: Node = rps[0]
	var want: Vector2 = host_state.get("pos", Vector2.ZERO)
	var d: float = rp.global_position.distance_to(want)
	if d > 150.0:
		_fail("RemotePlayer did not interpolate to host (off by %.0f px)" % d)
	elif int(rp.get("hp")) != int(host_state.get("hp", -1)):
		_fail("RemotePlayer HP %d != host HP %d" % [int(rp.get("hp")), int(host_state.get("hp", -1))])
	else:
		print("LAN SYNC remote player agrees: pos off by %.0f px, HP %d" % [d, int(rp.get("hp"))])
