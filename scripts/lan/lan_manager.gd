class_name LanManager
extends Node

# Owns ONLY the LAN session: ENet host/client, peer join/leave, and the
# unreliable position + reliable event RPCs. Gameplay (damage, pickups,
# mission completion) is validated by the Game on the host - this class
# only transports messages. (Single Responsibility, Dependency
# Inversion: the Game is injected and notified through signals.)

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal status_changed(text: String)
signal remote_state(peer_id: int, pos: Vector2, hp: int, downed: bool, facing: int, mag: int, reserve: int)
signal remote_shot(peer_id: int, pos: Vector2, dir: Vector2, weapon_id: String)
signal remote_pickup(peer_id: int, kind: String, pos: Vector2)
signal remote_mission_complete(peer_id: int, rank: String)
signal snapshot_applied(seq: int)

const GAME_PORT := 7777
const MAX_PLAYERS := 4

var game: Node = null
var discovery: LanDiscovery
var is_host: bool = false
var connected: bool = false
var status_text: String = "Solo"
var _peer: ENetMultiplayerPeer = null
var _sync: LanSync = LanSync.new()
var _send_t: float = 0.0
var _snap_t: float = 0.0

func setup(p_game: Node) -> void:
	game = p_game
	discovery = LanDiscovery.new()
	discovery.name = "Discovery"
	add_child(discovery)
	discovery.host_found.connect(_on_host_found)

func start_host() -> void:
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_server(GAME_PORT, MAX_PLAYERS) != OK:
		status_text = "Host failed"
		status_changed.emit(status_text)
		return
	multiplayer.multiplayer_peer = _peer
	is_host = true
	connected = true
	status_text = "Hosting on " + get_local_ip() + ":" + str(GAME_PORT)
	discovery.start_broadcast(GAME_PORT)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status_changed.emit(status_text)

func join_by_ip(ip: String) -> void:
	if ip.strip_edges() == "":
		return
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_client(ip.strip_edges(), GAME_PORT) != OK:
		status_text = "Join failed"
		status_changed.emit(status_text)
		return
	multiplayer.multiplayer_peer = _peer
	is_host = false
	connected = true
	status_text = "Connecting to " + ip + "..."
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	status_changed.emit(status_text)

func _on_connection_failed() -> void:
	connected = false
	status_text = "Connection failed"
	status_changed.emit(status_text)

# True only when the ENet link is actually up. `connected` is set
# optimistically when hosting/joining, so RPCs must be gated on this
# or they spam "peer which is not connected" errors while the client
# is still handshaking (or after a failed connect).
func _is_link_up() -> bool:
	return _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func find_and_join_host() -> void:
	status_text = "Searching LAN for a host..."
	status_changed.emit(status_text)
	discovery.start_listening()

func _on_host_found(ip: String, _port: int) -> void:
	discovery.stop()
	join_by_ip(ip)

func _on_connected_to_server() -> void:
	status_text = "Connected - lobby"
	status_changed.emit(status_text)
	if game != null and game.has_method("on_lan_connected"):
		game.on_lan_connected(multiplayer.get_unique_id())

func _on_peer_connected(pid: int) -> void:
	peer_joined.emit(pid)
	status_text = "Players: " + str(multiplayer.get_peers().size() + 1)
	status_changed.emit(status_text)
	if is_host:
		# Send a snapshot at once so the new peer syncs immediately.
		_snap_t = 0.0

func _on_peer_disconnected(pid: int) -> void:
	peer_left.emit(pid)
	status_text = "Player " + str(pid) + " left"
	status_changed.emit(status_text)

func _process(delta: float) -> void:
	if not connected or game == null or not _is_link_up():
		return
	# Player state, 20 Hz, unreliable: a lost packet is superseded by
	# the next one, so a single drop never desyncs anyone for long.
	# Values are the REAL local state (hp / downed / facing / ammo),
	# read through the player's sync_state() DTO.
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = LanSync.STATE_INTERVAL
		var p: Node = game.get_local_player()
		if p != null and p.has_method("sync_state"):
			var st: Dictionary = p.sync_state()
			_rpc_state.rpc(st["pos"], int(st["hp"]), bool(st["downed"]), int(st["facing"]), int(st["mag"]), int(st["reserve"]))
	# Host snapshot, 10 Hz, unreliable: enemies, boss HP, claimed
	# pickups, objectives, mission. Clients reconcile to it (see
	# LanSync); the host never applies its own snapshot.
	if is_host:
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = LanSync.SNAPSHOT_INTERVAL
			_rpc_snapshot.rpc(_sync.build_snapshot(game))

func send_shoot(pos: Vector2, dir: Vector2, weapon_id: String) -> void:
	if connected and _is_link_up():
		_rpc_shoot.rpc(pos, dir, weapon_id)

func send_pickup(kind: String, pos: Vector2) -> void:
	if connected and _is_link_up():
		_rpc_pickup.rpc(kind, pos)

func send_mission_complete(rank: String) -> void:
	if connected and _is_link_up():
		_rpc_mission.rpc(rank)

# Client -> host damage claim (reliable). The host validates it and
# applies it; the result comes back in the next snapshot. Never apply
# enemy damage locally on a client - the host owns enemy HP.
func send_damage(home: Vector2, amount: int) -> void:
	if connected and not is_host and _is_link_up():
		_rpc_damage.rpc(home, amount)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_state(pos: Vector2, hp: int, downed: bool, facing: int, mag: int, reserve: int) -> void:
	remote_state.emit(multiplayer.get_remote_sender_id(), pos, hp, downed, facing, mag, reserve)

# Host-authoritative snapshot (host -> all, unreliable, sequenced).
@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(snap: Dictionary) -> void:
	if _sync.apply_snapshot(game, snap):
		snapshot_applied.emit(int(snap.get("seq", 0)))

# Damage claim from a client: only the host applies it, after the
# Game validates the enemy exists and the amount is sane.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_damage(home: Vector2, amount: int) -> void:
	if not is_host:
		return
	if game != null and game.has_method("apply_host_damage"):
		game.apply_host_damage(home, amount)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_shoot(pos: Vector2, dir: Vector2, weapon_id: String) -> void:
	remote_shot.emit(multiplayer.get_remote_sender_id(), pos, dir, weapon_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_pickup(kind: String, pos: Vector2) -> void:
	remote_pickup.emit(multiplayer.get_remote_sender_id(), kind, pos)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_mission(rank: String) -> void:
	remote_mission_complete.emit(multiplayer.get_remote_sender_id(), rank)

static func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	return "127.0.0.1"
