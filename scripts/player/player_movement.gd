class_name PlayerMovement
extends Node

# Owns ONLY 2D platforming physics: gravity, coyote time, jump
# buffering, variable jump height, acceleration / deceleration,
# one-way drop-through, dash and knockback. It operates on the body
# it is given - it does not own the body. (Single Responsibility,
# Dependency Inversion: the body is injected.)

var coyote: float = 0.0
var jump_buffer: float = 0.0
var dash_t: float = 0.0
var dash_dir: float = 1.0
var knockback_vel: Vector2 = Vector2.ZERO
# Knockback added to the body last frame. It must be SUBTRACTED before
# the next move_toward, or the same impulse is re-added every frame
# while it decays and the velocity snowballs (observed: -2858 px/s
# after a few bullet hits, flinging the player across the map).
var _prev_kb: Vector2 = Vector2.ZERO
var ice: bool = false

func physics_step(body: CharacterBody2D, input_dir: float, want_jump: bool, jump_held: bool, delta: float, speed_mul: float = 1.0) -> void:
	if want_jump:
		jump_buffer = GameData.JUMP_BUFFER
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	if body.is_on_floor():
		coyote = GameData.COYOTE_TIME
	else:
		coyote = maxf(0.0, coyote - delta)
		body.velocity.y += GameData.GRAVITY * delta
	# Variable jump height: releasing jump early cuts the rise once.
	if not jump_held and body.velocity.y < -300.0:
		body.velocity.y = -300.0
	if jump_buffer > 0.0 and coyote > 0.0:
		body.velocity.y = GameData.JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
	# Analog stick: full push runs, half push walks. Keyboard is +-1.0
	# so it runs, as before.
	var mag: float = absf(input_dir)
	var base_speed: float = GameData.WALK_SPEED
	if mag > 0.85:
		base_speed = GameData.RUN_SPEED
	elif mag > 0.15:
		base_speed = lerpf(GameData.WALK_SPEED, GameData.RUN_SPEED, (mag - 0.15) / 0.7)
	var target: float = input_dir * base_speed * speed_mul
	if dash_t > 0.0:
		dash_t -= delta
		target = dash_dir * 12.0 * GameData.SCALE * 0.5
	var accel: float = 2400.0 if body.is_on_floor() else 1600.0
	if ice:
		accel = 700.0
	# Remove last frame's knockback before steering, then add the
	# current (decaying) knockback once. Without the subtraction the
	# impulse was re-added every frame and velocity snowballed.
	body.velocity.x = move_toward(body.velocity.x - _prev_kb.x, target, accel * delta)
	body.velocity.y -= _prev_kb.y
	if knockback_vel.length() > 1.0:
		body.velocity += knockback_vel
		_prev_kb = knockback_vel
		knockback_vel = knockback_vel.move_toward(Vector2.ZERO, 1400.0 * delta)
	else:
		_prev_kb = Vector2.ZERO
	body.move_and_slide()

func start_dash(dir: float) -> void:
	dash_t = 0.2
	dash_dir = dir if dir != 0.0 else 1.0

func apply_knockback(v: Vector2) -> void:
	knockback_vel += v
	# Cap stacked knockback (multiple bullets / an explosion) so the
	# player can never be flung across the map in one burst.
	if knockback_vel.length() > 600.0:
		knockback_vel = knockback_vel.normalized() * 600.0

func drop_through(body: CharacterBody2D) -> void:
	# One-way platforms: briefly disable one-way collision by moving down.
	body.position.y += 4.0
