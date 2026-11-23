class_name VirtualJoystick
extends Control

# Virtual joystick for Android movement. Owns ONLY the stick: a circular
# base with a draggable knob. Analog output -1..1 (x), dead zone in the
# centre, knob returns to centre on release. Touch only in the game;
# mouse drag works too so it can be playtested on desktop.
# (Single Responsibility: it never moves the player itself.)

const BASE_RADIUS := 95.0
const KNOB_RADIUS := 42.0
const MAX_DRAG := 68.0
const DEAD_ZONE := 0.12

var value: float = 0.0
var _dragging: bool = false
var _drag_id: int = -1
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(BASE_RADIUS * 2.0 + 20.0, BASE_RADIUS * 2.0 + 20.0)
	mouse_filter = MOUSE_FILTER_STOP

func _draw() -> void:
	var c: Vector2 = size * 0.5
	# Base: dark navy circle, gold rim.
	draw_circle(c, BASE_RADIUS, Color(0.04, 0.07, 0.14, 0.55))
	draw_arc(c, BASE_RADIUS, 0.0, TAU, 48, Color(1.0, 0.8, 0.2, 0.9), 3.0)
	# Direction ticks.
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (BASE_RADIUS - 14.0), c + d * (BASE_RADIUS - 4.0), Color(1, 1, 1, 0.5), 3.0)
	# Knob.
	draw_circle(c + _knob_offset, KNOB_RADIUS, Color(0.10, 0.20, 0.42, 0.85))
	draw_arc(c + _knob_offset, KNOB_RADIUS, 0.0, TAU, 32, Color(1.0, 0.8, 0.2, 0.95), 3.0)

func _update_from_point(p: Vector2) -> void:
	var c: Vector2 = size * 0.5
	var d: Vector2 = p - c
	if d.length() > MAX_DRAG:
		d = d.normalized() * MAX_DRAG
	_knob_offset = d
	var v: float = clampf(d.x / MAX_DRAG, -1.0, 1.0)
	value = 0.0 if absf(v) < DEAD_ZONE else v
	queue_redraw()

func _release() -> void:
	_dragging = false
	_drag_id = -1
	_knob_offset = Vector2.ZERO
	value = 0.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed and not _dragging:
			_dragging = true
			_drag_id = st.index
			_update_from_point(st.position)
			accept_event()
		elif not st.pressed and st.index == _drag_id:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if _dragging and sd.index == _drag_id:
			_update_from_point(sd.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _dragging:
				_dragging = true
				_drag_id = -1
				_update_from_point(mb.position)
				accept_event()
			elif not mb.pressed and _drag_id == -1:
				_release()
				accept_event()
	elif event is InputEventMouseMotion:
		if _dragging and _drag_id == -1:
			_update_from_point((event as InputEventMouseMotion).position)
			accept_event()
