class_name RemotePlayer
extends Node2D

# A remote (LAN) teammate. It never runs local input or physics - it
# only interpolates toward the positions the LanManager receives.
# (Single Responsibility.)

var peer_id: int = 0
var character_id: String = "Ranger"
var hp: int = 100
var mag: int = 0
var reserve: int = 0
var is_downed: bool = false
var _target: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _label: Label

func setup(p_peer: int, p_character: String, start_pos: Vector2) -> void:
	peer_id = p_peer
	character_id = p_character
	global_position = start_pos
	_target = start_pos
	var def: Dictionary = GameData.character(character_id)
	_sprite = Sprite2D.new()
	SpriteLoader.apply_to_sprite(_sprite, "Characters", def["sprite"], Color.WHITE, Vector2(58, 92))
	_sprite.modulate = Color(def["tint"][0], def["tint"][1], def["tint"][2])
	add_child(_sprite)
	_label = Label.new()
	_label.text = "P" + str(peer_id)
	_label.position = Vector2(-16, -64)
	add_child(_label)
	add_to_group("player")
	add_to_group("remote_player")

func apply_state(pos: Vector2, p_hp: int, p_downed: bool, p_facing: int, p_mag: int = 0, p_reserve: int = 0) -> void:
	_target = pos
	hp = p_hp
	mag = p_mag
	reserve = p_reserve
	is_downed = p_downed
	_sprite.flip_h = p_facing < 0
	_sprite.modulate.a = 0.5 if is_downed else 1.0
	_label.text = "P%d  %d HP" % [peer_id, hp]

func apply_damage(_amount: int, _from_pos: Vector2) -> void:
	# Damage is validated on the host; remote visuals only.
	pass

func _process(delta: float) -> void:
	global_position = global_position.lerp(_target, clampf(delta * 12.0, 0.0, 1.0))
