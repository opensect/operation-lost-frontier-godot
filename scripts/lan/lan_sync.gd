class_name LanSync
extends RefCounted

# Owns ONLY the LAN sync protocol: the host-authoritative snapshot
# payload (enemies, boss HP, claimed pickups, objectives, mission) and
# the rules for applying it on a client (sequence check, drift
# snap vs lerp, host-killed enemy removal, mission follow).
# It never touches the network itself - LanManager owns the RPCs and
# the timers; the Game owns the state. (Single Responsibility,
# Dependency Inversion: the Game is passed in and talked to through
# its small public sync interface.)

const STATE_INTERVAL: float = 0.05  # 20 Hz player state
const SNAPSHOT_INTERVAL: float = 0.1  # 10 Hz host snapshot
const SNAP_DIST: float = 96.0  # drift beyond this: snap, else lerp
const PICKUP_CLAIM_MAX_DIST: float = 500.0  # host claim validation

var _seq: int = 0
var _last_applied_seq: int = -1

func next_seq() -> int:
	_seq += 1
	return _seq

# ---- host side: build the snapshot from the Game's public state ----
func build_snapshot(game: Node) -> Dictionary:
	var snap: Dictionary = {
		"seq": next_seq(),
		"mission": int(game.get("current_mission")) if game.get("current_mission") != null else 1,
		"enemies": [],
		"boss": [-1, -1],
		"claims": [],
		"objectives": [],
	}
	if game.has_method("get_sync_enemies"):
		snap["enemies"] = game.get_sync_enemies()
	if game.has_method("get_sync_boss"):
		snap["boss"] = game.get_sync_boss()
	if game.has_method("get_sync_claims"):
		snap["claims"] = game.get_sync_claims()
	if game.has_method("get_sync_objectives"):
		snap["objectives"] = game.get_sync_objectives()
	return snap

# ---- client side: apply a snapshot, or return false if stale/bad ----
func apply_snapshot(game: Node, snap: Dictionary) -> bool:
	if not snap.has("seq") or not snap.has("enemies"):
		return false
	var seq: int = int(snap["seq"])
	if seq <= _last_applied_seq:
		return false  # stale or duplicate (out-of-order UDP): drop it
	_last_applied_seq = seq
	# Follow the host's mission: the host drives mission progression.
	if snap.has("mission") and game.has_method("load_mission_level"):
		var m: int = int(snap["mission"])
		if game.get("current_mission") != null and int(game.get("current_mission")) != m:
			game.load_mission_level(m)
	# Enemies: match by home (spawn) position - stable across peers.
	var seen_homes: Dictionary = {}
	for e in snap["enemies"]:
		var arr: Array = e as Array
		if arr.size() < 5:
			continue
		var home := Vector2(float(arr[0]), float(arr[1]))
		var pos := Vector2(float(arr[2]), float(arr[3]))
		var hp: int = int(arr[4])
		seen_homes[str(home)] = true
		if game.has_method("apply_sync_enemy"):
			game.apply_sync_enemy(home, pos, hp)
	# An enemy the host no longer lists died on the host: remove ours.
	# (Skipped while the host's list is empty - it is mid-load, not
	# a level with zero enemies, and deleting ours would strand us.)
	if snap["enemies"].size() > 0 and game.has_method("get_sync_enemies"):
		for local in game.get_sync_enemies():
			var larr: Array = local as Array
			if larr.size() < 2:
				continue
			var home := Vector2(float(larr[0]), float(larr[1]))
			if not seen_homes.has(str(home)) and game.has_method("remove_sync_enemy"):
				game.remove_sync_enemy(home)
	# Boss HP (for the HUD bar) and claimed pickups.
	if snap.has("boss") and game.has_method("apply_sync_boss"):
		var b: Array = snap["boss"] as Array
		if b.size() >= 2:
			game.apply_sync_boss(int(b[0]), int(b[1]))
	if snap.has("claims") and game.has_method("apply_sync_claim"):
		for key in snap["claims"]:
			game.apply_sync_claim(str(key))
	if snap.has("objectives") and game.has_method("apply_sync_objectives"):
		game.apply_sync_objectives(snap["objectives"])
	return true
