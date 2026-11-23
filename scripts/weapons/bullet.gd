class_name Bullet
extends Area2D

# Player or enemy projectile. Pooled by the Game (main.gd) - freed on
# range expiry, impact, or leaving the level.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 10
var max_range: float = 600.0
var from_player: bool = true
var explosive: bool = false
var radius: float = 0.0
var travelled: float = 0.0
var owner_id: int = 0
var game: Node = null
var _sprite: Sprite2D

func _ready() -> void:
	_sprite = $Sprite2D
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	monitoring = true
	monitorable = true

func init_bullet(pos: Vector2, dir: Vector2, dmg: int, speed: float, rng: float, p_from_player: bool, p_explosive: bool, p_radius: float, p_owner: int, p_game: Node) -> void:
	global_position = pos
	velocity = dir.normalized() * speed
	damage = dmg
	max_range = rng
	from_player = p_from_player
	explosive = p_explosive
	radius = p_radius
	owner_id = p_owner
	game = p_game
	rotation = dir.angle()
	if explosive:
		_sprite.modulate = Color(1, 0.5, 0.2)
	elif from_player:
		_sprite.modulate = Color(1, 0.9, 0.3)
	else:
		_sprite.modulate = Color(1, 0.3, 0.8)
	if from_player:
		collision_layer = 8  # bullet_player
		collision_mask = 1 | 4  # world + enemy
	else:
		collision_layer = 16  # bullet_enemy
		collision_mask = 1 | 2  # world + player

func _physics_process(delta: float) -> void:
	var step: Vector2 = velocity * delta
	global_position += step
	travelled += step.length()
	if travelled >= max_range:
		_detonate()
		queue_free()

func _detonate() -> void:
	if explosive and game != null and game.has_method("explode"):
		game.explode(global_position, radius * GameData.SCALE, damage, from_player, owner_id)

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		_detonate()
		queue_free()
		return
	if from_player and body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position, owner_id)
		_detonate()
		queue_free()
	elif not from_player and body.is_in_group("player"):
		if body.has_method("apply_damage"):
			body.apply_damage(damage, global_position)
		_detonate()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if from_player and area.is_in_group("enemy"):
		if area.has_method("take_damage"):
			area.take_damage(damage, global_position, owner_id)
		_detonate()
		queue_free()
	elif not from_player and area.is_in_group("player"):
		if area.has_method("apply_damage"):
			area.apply_damage(damage, global_position)
		_detonate()
		queue_free()
