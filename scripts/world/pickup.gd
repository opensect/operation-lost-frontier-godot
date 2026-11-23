class_name Pickup
extends Area2D

# Health / armor / ammo / grenade / intel / power-up pickup.
# First-claim-wins in LAN: the host validates the claim (see main.gd).

var kind: String = "health"
var game: Node = null
var spawn_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _base_y: float = 0.0

const SPRITES := {
	"health": ["Powerups", "health"], "armor": ["Powerups", "armor"],
	"ammo": ["Weapons", "ammo_supply_crate"], "grenade": ["Props", "grenade_bundle"],
	"intel": ["Powerups", "bonus_star"], "double_damage": ["Powerups", "double_damage"],
	"speed": ["Powerups", "speed"], "rapid_fire": ["Powerups", "energy_burst"],
	"medkit": ["Weapons", "medkit"],
}

func setup(p_kind: String, p_game: Node) -> void:
	kind = p_kind
	game = p_game
	add_to_group("pickup")
	# Stable identity: the spawn position. The pickup bobs (see
	# _process), so its live position drifts with time and must never
	# be used as the claim key - two peers would compute different
	# keys for the same pickup and the host would reject the claim.
	spawn_pos = position
	# Capture the bob anchor HERE, not in _ready: spawn_pickup sets
	# position after add_child, so _ready saw position (0,0) and the
	# bob dragged every pickup to y~0, below the ground, unreachable.
	_base_y = position.y
	var s: Array = SPRITES.get(kind, ["Powerups", "bonus_star"])
	SpriteLoader.apply_to_sprite($Sprite2D, s[0], s[1], Color.GREEN, Vector2(44, 44))

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 2.5) * 6.0

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if game != null and game.has_method("collect_pickup"):
		if game.collect_pickup(self, body):
			queue_free()
