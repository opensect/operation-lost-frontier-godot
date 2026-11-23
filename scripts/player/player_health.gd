class_name PlayerHealth
extends Node

# Owns ONLY health / armor / downed state. Signals out, never touches
# movement, weapons or UI directly. (Single Responsibility.)

signal health_changed(hp: int, armor: int, lives: int)
signal downed_changed(downed: bool)
signal died

var max_hp: int = 100
var hp: int = 100
var armor: int = 0
var lives: int = 3
var is_downed: bool = false
var downed_timer: float = 12.0
var downed_duration: float = 12.0
var _invuln: float = 0.0

func full_reset() -> void:
	hp = max_hp
	armor = 0
	is_downed = false
	downed_timer = downed_duration
	health_changed.emit(hp, armor, lives)

func apply_damage(amount: int, difficulty: String) -> int:
	if _invuln > 0.0 or is_downed:
		return 0
	var scaled: int = int(amount * GameData.difficulty_damage(difficulty))
	var absorbed: int = mini(armor, scaled)
	armor -= absorbed
	var rest: int = scaled - absorbed
	hp -= rest
	_invuln = 0.4
	if hp <= 0:
		hp = 0
		is_downed = true
		downed_timer = downed_duration
		downed_changed.emit(true)
	health_changed.emit(hp, armor, lives)
	return rest

func heal(amount: int) -> void:
	if is_downed:
		return
	hp = mini(max_hp, hp + amount)
	health_changed.emit(hp, armor, lives)

func add_armor(amount: int) -> void:
	armor += amount
	health_changed.emit(hp, armor, lives)

func revive() -> void:
	is_downed = false
	hp = 50
	downed_changed.emit(false)
	health_changed.emit(hp, armor, lives)

func _process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	if is_downed:
		downed_timer -= delta
		if downed_timer <= 0.0:
			is_downed = false
			lives -= 1
			downed_changed.emit(false)
			if lives <= 0:
				died.emit()
			else:
				full_reset()
			health_changed.emit(hp, armor, lives)
