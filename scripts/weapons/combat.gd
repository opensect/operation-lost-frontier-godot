class_name Combat
extends RefCounted

# Small explosion / area-damage service. Pure function over the scene
# tree groups - no state, no concrete Game dependency.
# (Dependency Inversion: callers pass the tree root in.)

static func explode(root: Node, pos: Vector2, radius: float, damage: int, by_player: bool, owner_id: int, difficulty: String) -> void:
	for e in root.get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and e.global_position.distance_to(pos) <= radius:
			var falloff: float = lerpf(1.0, 0.4, e.global_position.distance_to(pos) / radius)
			if e.has_method("take_damage"):
				e.take_damage(int(damage * falloff), pos, owner_id)
	for p in root.get_tree().get_nodes_in_group("player"):
		if p is Node2D and p.global_position.distance_to(pos) <= radius:
			if p.has_method("apply_damage"):
				# Friendly fire: player-caused explosions hurt teammates
				# at 60% and never below 1 HP (see Player.apply_damage).
				p.apply_damage(int(damage * 0.6), pos)
