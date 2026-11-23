class_name Grenade
extends CharacterBody2D

# Arcing grenade with real gravity and a fuse. Bounces off the ground.

var damage: int = 80
var fuse: float = 2.0
var owner_id: int = 0
var game: Node = null

func init_grenade(pos: Vector2, vel: Vector2, dmg: int, p_owner: int, p_game: Node) -> void:
	global_position = pos
	velocity = vel
	damage = dmg
	owner_id = p_owner
	game = p_game

func _physics_process(delta: float) -> void:
	velocity.y += GameData.GRAVITY * 0.7 * delta
	fuse -= delta
	if fuse <= 0.0:
		_blow()
		return
	move_and_slide()
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = -velocity.y * 0.35
		velocity.x *= 0.7
	if is_on_wall():
		velocity.x = -velocity.x * 0.5

func _blow() -> void:
	if game != null and game.has_method("explode"):
		game.explode(global_position, 2.5 * GameData.SCALE, damage, true, owner_id)
	queue_free()
