class_name PlayerAnimator
extends RefCounted

# Procedural animation for the player. The player's batch-1 art has no
# atlas walk frames (no batch-04 row matches the four player
# characters), so the motion is built from Tweens on the sprite the
# player already has: a run bob, squash-and-stretch on jump/land, and
# recoil on fire. No new art, no paid tools - just the existing sprite.
# One responsibility: make the player LOOK alive. It never touches
# input, physics or health; Player calls it from _physics_process.

var sprite: Sprite2D = null
var _bob_t: float = 0.0
var _base_y: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _stretch_tween: Tween = null

func setup(p_sprite: Sprite2D) -> void:
	sprite = p_sprite
	_base_y = sprite.position.y
	_base_scale = sprite.scale

func update(moving: bool, on_floor: bool, delta: float) -> void:
	if sprite == null:
		return
	if moving and on_floor:
		_bob_t += delta * 11.0
		sprite.position.y = _base_y + sin(_bob_t) * 2.5
	else:
		sprite.position.y = _base_y

func on_jump() -> void:
	_stretch(1.12, 0.9)

func on_land() -> void:
	_stretch(0.88, 1.12)

func on_fire() -> void:
	if sprite == null:
		return
	var tree: SceneTree = sprite.get_tree()
	if tree == null:
		return
	# Recoil: a quick kick back along the facing direction.
	var kick: float = 6.0 if sprite.flip_h else -6.0
	var tw: Tween = tree.create_tween()
	tw.tween_property(sprite, "position:x", sprite.position.x + kick, 0.05)
	tw.tween_property(sprite, "position:x", sprite.position.x, 0.12)

func _stretch(sy: float, sx: float) -> void:
	if sprite == null:
		return
	var tree: SceneTree = sprite.get_tree()
	if tree == null:
		return
	if _stretch_tween != null and _stretch_tween.is_valid():
		_stretch_tween.kill()
	sprite.scale = _base_scale
	_stretch_tween = tree.create_tween()
	_stretch_tween.tween_property(sprite, "scale", Vector2(_base_scale.x * sx, _base_scale.y * sy), 0.08)
	_stretch_tween.tween_property(sprite, "scale", _base_scale, 0.18)
