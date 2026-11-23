class_name WeaponResource
extends Resource

# One weapon, as data. Adding a weapon = adding one entry in
# GameData.WEAPONS (or one .tres made from it) - no gameplay code changes.
# (Open/Closed principle.)

@export var wid: String = "Pistol"
@export var display_name: String = "Pistol"
@export var mode: String = "semi"
@export var damage: int = 20
@export var fire_interval: float = 0.30
@export var magazine_size: int = 12
@export var reserve_ammo: int = -1  # -1 = infinite
@export var ammo_type: String = "Pistol"
@export var reload_time: float = 1.0
@export var projectile_speed: float = 30.0
@export var range_units: float = 10.0
@export var spread_deg: float = 1.0
@export var pellets: int = 1
@export var explosive: bool = false
@export var explosion_radius: float = 0.0
@export var sprite_name: String = "pistol"
@export var unlock_mission: int = 1

static func from_dict(d: Dictionary) -> WeaponResource:
	var w := WeaponResource.new()
	w.wid = str(d["id"]); w.display_name = str(d["display"]); w.mode = str(d["mode"])
	w.damage = int(d["damage"]); w.fire_interval = float(d["interval"])
	w.magazine_size = int(d["mag"]); w.reserve_ammo = int(d["reserve"])
	w.ammo_type = str(d["ammo"]); w.reload_time = float(d["reload"])
	w.projectile_speed = float(d["speed"]); w.range_units = float(d["range"])
	w.spread_deg = float(d["spread"]); w.pellets = int(d["pellets"])
	w.explosive = bool(d["explosive"]); w.explosion_radius = float(d["radius"])
	w.sprite_name = str(d["sprite"]); w.unlock_mission = int(d["unlock"])
	return w
