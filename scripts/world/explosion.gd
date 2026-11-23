class_name Explosion
extends Node2D

# One-shot explosion visual from the batch-04 explosion frames
# (assets/anim/explosion/frame_00..03.png). Plays once at 12 fps,
# then frees itself. The DAMAGE is done by Combat.explode - this is
# only the visual. Spawned by Main.explode().

static func spawn(parent: Node, pos: Vector2, size_px: float) -> void:
	var ex := Explosion.new()
	ex.position = pos
	parent.add_child(ex)
	ex._play(size_px)

var _anim: AnimatedSprite2D = null

func _play(size_px: float) -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("boom")
	sf.set_animation_speed("boom", 12.0)
	sf.set_animation_loop("boom", false)
	for i in range(4):
		var path: String = "res://assets/anim/explosion/frame_%02d.png" % i
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				sf.add_frame("boom", tex)
	if sf.get_frame_count("boom") == 0:
		queue_free()
		return
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = sf
	_anim.animation = "boom"
	var h: float = float(sf.get_frame_texture("boom", 0).get_size().y)
	var sc: float = size_px / maxf(1.0, h)
	_anim.scale = Vector2(sc, sc)
	add_child(_anim)
	_anim.play("boom")
	_anim.animation_finished.connect(queue_free)
