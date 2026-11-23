class_name WeaponController
extends Node

# Owns ONLY weapon state: inventory, magazines, reserves, reload.
# It does not move the player, does not spawn bullets, does not know
# about LAN. It emits signals; the Player asks it to fire and the Game
# turns a fired signal into a bullet. (Single Responsibility.)

signal fired(weapon: WeaponResource, direction: Vector2)
signal reloaded(weapon: WeaponResource)
signal weapon_changed(weapon: WeaponResource)
signal ammo_changed

var weapons: Array[WeaponResource] = []
var current_index: int = 0
var mag: Dictionary = {}
var reserve: Dictionary = {}
var grenades: int = 3
var reloading: bool = false
var _reload_t: float = 0.0
var _fire_cd: float = 0.0
var _tactical_reload: float = 0.0  # Ranger ability timer
var _rapid_fire: float = 0.0
var _double_damage: float = 0.0

func setup(character_id: String, mission_num: int) -> void:
	weapons.clear()
	for wid in GameData.unlocked_weapons(mission_num):
		var w: WeaponResource = WeaponResource.from_dict(GameData.weapon(wid))
		weapons.append(w)
		mag[w.wid] = w.magazine_size
		var res: int = w.reserve_ammo
		if character_id == "Ranger" and res > 0:
			res = int(res * 1.2)
		reserve[w.wid] = res
	if weapons.is_empty():
		weapons.append(WeaponResource.from_dict(GameData.weapon("Pistol")))
	current_index = 0

func current() -> WeaponResource:
	return weapons[current_index]

func mag_ammo(wid: String = "") -> int:
	if wid == "": wid = current().wid
	return int(mag.get(wid, 0))

func reserve_ammo(wid: String = "") -> int:
	if wid == "": wid = current().wid
	return int(reserve.get(wid, -1))

func damage_multiplier() -> float:
	return 2.0 if _double_damage > 0.0 else 1.0

func switch_weapon(delta_index: int) -> void:
	if weapons.size() < 2 or reloading:
		return
	current_index = (current_index + delta_index) % weapons.size()
	reloading = false
	weapon_changed.emit(current())
	ammo_changed.emit()

func give_weapon(wid: String) -> void:
	for w in weapons:
		if w.wid == wid:
			return
	var w2: WeaponResource = WeaponResource.from_dict(GameData.weapon(wid))
	weapons.append(w2)
	mag[w2.wid] = w2.magazine_size
	reserve[w2.wid] = w2.reserve_ammo
	ammo_changed.emit()

func add_reserve(ammo_type: String, amount: int) -> void:
	for w in weapons:
		if w.ammo_type == ammo_type and int(reserve.get(w.wid, -1)) >= 0:
			reserve[w.wid] = int(reserve[w.wid]) + amount
	ammo_changed.emit()

func start_reload() -> void:
	var w: WeaponResource = current()
	if reloading or mag[w.wid] >= w.magazine_size:
		return
	if int(reserve.get(w.wid, -1)) == 0:
		return
	reloading = true
	_reload_t = w.reload_time * (0.5 if _tactical_reload > 0.0 else 1.0)

func apply_tactical_reload(duration: float) -> void:
	_tactical_reload = duration

func apply_powerup(kind: String, duration: float) -> void:
	if kind == "rapid_fire": _rapid_fire = duration
	elif kind == "double_damage": _double_damage = duration

func try_fire(direction: Vector2, held: bool) -> bool:
	var w: WeaponResource = current()
	if reloading or _fire_cd > 0.0:
		return false
	if w.mode == "semi" and not held:
		return false
	if w.mode == "semi" and held and _fire_cd > -0.001:
		pass
	if mag[w.wid] <= 0:
		start_reload()
		return false
	mag[w.wid] = int(mag[w.wid]) - 1
	_fire_cd = w.fire_interval * (0.6 if _rapid_fire > 0.0 else 1.0)
	ammo_changed.emit()
	fired.emit(w, direction)
	return true

func _process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_tactical_reload = maxf(0.0, _tactical_reload - delta)
	_rapid_fire = maxf(0.0, _rapid_fire - delta)
	_double_damage = maxf(0.0, _double_damage - delta)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			var w: WeaponResource = current()
			var need: int = w.magazine_size - int(mag[w.wid])
			var res: int = int(reserve.get(w.wid, -1))
			if res < 0:
				mag[w.wid] = w.magazine_size
			else:
				var take: int = mini(need, res)
				mag[w.wid] = int(mag[w.wid]) + take
				reserve[w.wid] = res - take
			reloaded.emit(w)
			ammo_changed.emit()
