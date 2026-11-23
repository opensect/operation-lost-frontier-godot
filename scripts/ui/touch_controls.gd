class_name TouchControls
extends CanvasLayer

# Owns ONLY the Android touch controls. It writes to the small public
# state the Game reads each frame (touch_move / touch_fire / ...).
# It never moves the player itself. Visible only after START.
# Movement is a VirtualJoystick (bottom-left, analog); JUMP / FIRE /
# E / ABILITY stay as buttons on the bottom-right.

var move: float = 0.0
var fire: bool = false
var interact: bool = false
var jump_pressed: bool = false
var ability_pressed: bool = false
var joystick: VirtualJoystick = null

func _ready() -> void:
	for b in [$JumpButton, $FireButton, $InteractButton, $AbilityButton]:
		UiTheme.style_touch_button(b)
	_bind($JumpButton, func() -> void: jump_pressed = true, func() -> void: pass)
	_bind($FireButton, func() -> void: fire = true, func() -> void: fire = false)
	_bind($InteractButton, func() -> void: interact = true, func() -> void: interact = false)
	_bind($AbilityButton, func() -> void: ability_pressed = true, func() -> void: pass)
	# Virtual joystick, bottom-left, clear of every HUD panel.
	joystick = VirtualJoystick.new()
	joystick.name = "Joystick"
	joystick.position = Vector2(30, 1080 - 250)
	joystick.size = Vector2(230, 230)
	add_child(joystick)

func _process(_delta: float) -> void:
	if joystick != null:
		move = joystick.value

func _bind(btn: BaseButton, on_down: Callable, on_up: Callable) -> void:
	btn.button_down.connect(on_down)
	btn.button_up.connect(on_up)
