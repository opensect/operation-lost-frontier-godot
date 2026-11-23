class_name Hazard
extends Area2D

var damage: int = 10
var kind: String = "spikes"
var _cooldown: float = 0.0
var _pulse_t: float = 0.0

# Hazard visuals are the cleaned batch-10 art (assets/hazards/,
# cropped + checkerboard removed in the generator); kind selects
# which one. The pulse is the clear visual warning.
func set_kind(p_kind: String) -> void:
	kind = p_kind
	var spr: Sprite2D = get_node_or_null("Sprite2D")
	if spr != null:
		SpriteLoader.apply_to_sprite(spr, "Hazards", "hazard_" + kind, Color.WHITE, Vector2(120, 48))

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_pulse_t += delta
	var spr: Sprite2D = get_node_or_null("Sprite2D")
	if spr != null:
		var pp: float = 0.5 + 0.5 * sin(_pulse_t * 5.0)
		spr.modulate = Color(1.0, 0.55 + 0.45 * pp, 0.55 + 0.45 * pp)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _cooldown <= 0.0:
		_cooldown = 1.0
		if body.has_method("apply_damage"):
			body.apply_damage(damage, global_position)
			if body.has_method("knockback"):
				body.knockback((body.global_position - global_position).normalized() * 260.0)
