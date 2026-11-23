class_name CharacterAnimator
extends RefCounted

# Drives character motion from the sliced batch-04 walk frames
# (assets/anim/<name>/frame_XX.png) or from a static sprite.
# One responsibility: make a character LOOK alive - walk cycles, idle,
# hover bob, attack pulse. It never touches AI, health or physics;
# the owner calls update() each physics tick.

const FOLDER := "res://assets/anim/"
const FPS := 12.0

# Enemy type -> walk-row folder. Only the types whose art matches a
# batch-04 walk row get a cycle; the rest keep their static sprite
# (Drone hovers, Turret is stationary, Beast lunges - see below).
const WALK_FOR := {
	"Grunt": "grunt", "Engineer": "grunt",
	"Scout": "scout",
	"Sniper": "elite", "EliteGuard": "elite",
	"Heavy": "heavy", "RocketSoldier": "heavy", "ShieldTrooper": "heavy",
}

var anim_sprite: AnimatedSprite2D = null
var sprite: Sprite2D = null
var bob_amp: float = 0.0
var bob_speed: float = 2.0
var _t: float = 0.0
var _base_y: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _pulse_tween: Tween = null

static func walk_folder_for(enemy_id: String) -> String:
	return str(WALK_FOR.get(enemy_id, ""))

static func build_frames(folder: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("walk")
	sf.set_animation_speed("walk", FPS)
	sf.set_animation_loop("walk", true)
	var i := 0
	while true:
		var path: String = "%s%s/frame_%02d.png" % [FOLDER, folder, i]
		if not ResourceLoader.exists(path):
			break
		var tex: Texture2D = load(path)
		if tex == null:
			break
		sf.add_frame("walk", tex)
		i += 1
	if sf.get_frame_count("walk") == 0:
		return null
	return sf

# Walk-cycle mode: hides nothing itself - the owner hides its static
# Sprite2D after this returns true. Returns false if no frames exist.
func setup_walk(owner: Node2D, folder: String, target_height: float) -> bool:
	var sf: SpriteFrames = build_frames(folder)
	if sf == null:
		return false
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "WalkSprite"
	anim_sprite.sprite_frames = sf
	anim_sprite.animation = "walk"
	# Same uniform-height rule as SpriteLoader: height = target_height,
	# width follows the frame's aspect ratio.
	var h: float = float(sf.get_frame_texture("walk", 0).get_size().y)
	var sc: float = target_height / maxf(1.0, h)
	_base_scale = Vector2(sc, sc)
	anim_sprite.scale = _base_scale
	_base_y = anim_sprite.position.y
	anim_sprite.play("walk")
	owner.add_child(anim_sprite)
	return true

# Static mode: drives bob / pulse on an existing Sprite2D (bosses,
# the Beast's lunge). No frames are loaded.
func setup_static(p_sprite: Sprite2D) -> void:
	sprite = p_sprite
	_base_y = sprite.position.y
	_base_scale = sprite.scale

func _node() -> Node2D:
	return anim_sprite if anim_sprite != null else sprite

func update(moving: bool, delta: float) -> void:
	_t += delta
	if anim_sprite != null:
		if moving:
			if not anim_sprite.is_playing():
				anim_sprite.play("walk")
		else:
			# Idle: hold the first frame (standing pose), not a blur.
			anim_sprite.pause()
			anim_sprite.frame = 0
	var node: Node2D = _node()
	if node != null and bob_amp > 0.0:
		node.position.y = _base_y + sin(_t * bob_speed) * bob_amp

func set_facing(dir: float) -> void:
	var node: Node2D = _node()
	if node == null:
		return
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).flip_h = dir < 0.0
	elif node is Sprite2D:
		(node as Sprite2D).flip_h = dir < 0.0

# Quick attack pulse: grow 15% and settle back. Works on either mode.
func pulse() -> void:
	var node: Node2D = _node()
	if node == null:
		return
	var tree: SceneTree = node.get_tree()
	if tree == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	node.scale = _base_scale
	_pulse_tween = tree.create_tween()
	_pulse_tween.tween_property(node, "scale", _base_scale * 1.15, 0.08)
	_pulse_tween.tween_property(node, "scale", _base_scale, 0.15)
