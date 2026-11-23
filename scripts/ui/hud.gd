class_name Hud
extends CanvasLayer

# Owns ONLY the in-game HUD: health/armour bars, weapon + ammo, score,
# objective, timer, LAN state, boss bar, messages, results panel.
# It displays state; the Game decides it. (Single Responsibility.)
# All styling comes from UiTheme - one palette for every screen.

signal pause_pressed

@onready var hp_bar: ProgressBar = %HpBar
@onready var armor_bar: ProgressBar = %ArmorBar
@onready var lives_label: Label = %LivesLabel
@onready var hp_label: Label = %HpLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var grenades_label: Label = %GrenadesLabel
@onready var score_label: Label = %ScoreLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var timer_label: Label = %TimerLabel
@onready var message_label: Label = %MessageLabel
@onready var boss_label: Label = %BossLabel
@onready var boss_bar: ProgressBar = %BossBar
@onready var lan_label: Label = %LanLabel
@onready var ability_label: Label = %AbilityLabel
@onready var results_panel: TextureRect = %ResultsPanel

var mission_time: float = 0.0
var _msg_t: float = 0.0

func _ready() -> void:
	%PauseButton.pressed.connect(func() -> void: pause_pressed.emit())
	UiTheme.style_button(%PauseButton, Color(0.10, 0.20, 0.42), 22)
	var hp_s: Dictionary = UiTheme.bar_styles(UiTheme.RED)
	hp_bar.add_theme_stylebox_override("background", hp_s["bg"])
	hp_bar.add_theme_stylebox_override("fill", hp_s["fill"])
	var ar_s: Dictionary = UiTheme.bar_styles(UiTheme.BLUE)
	armor_bar.add_theme_stylebox_override("background", ar_s["bg"])
	armor_bar.add_theme_stylebox_override("fill", ar_s["fill"])
	var bo_s: Dictionary = UiTheme.bar_styles(UiTheme.RED)
	boss_bar.add_theme_stylebox_override("background", bo_s["bg"])
	boss_bar.add_theme_stylebox_override("fill", bo_s["fill"])
	results_panel.texture = SheetSlicer.mission_complete_panel()
	boss_label.visible = false
	boss_bar.visible = false
	results_panel.visible = false

func set_health(hp: int, armor: int, lives: int) -> void:
	hp_bar.value = clampi(hp, 0, 100)
	armor_bar.value = clampi(armor, 0, 100)
	lives_label.text = "Lives: %d" % lives
	# HP as a number too, so health is readable even if a bar fill
	# ever fails to draw (screenshot 2: empty bar, Lives: 3).
	if hp_label != null:
		hp_label.text = "HP %d" % clampi(hp, 0, 100)

func set_weapon(text: String, grenades_text: String = "") -> void:
	weapon_label.text = text
	if grenades_label != null:
		grenades_label.text = grenades_text

func set_score(score: int) -> void:
	score_label.text = "Score: %d" % score

func set_objective(text: String) -> void:
	# Short form: the panel already says what it is, and the full
	# "Objective: Reach the signal tower (0/3)" was truncated at the
	# right edge on phones. Keep it under the panel width.
	objective_label.text = text

func set_lan(text: String) -> void:
	lan_label.text = text

func set_ability(text: String) -> void:
	ability_label.text = text

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	_msg_t = duration

func show_boss_bar(bar_name: String, frac: float) -> void:
	boss_label.visible = true
	boss_bar.visible = true
	boss_label.text = bar_name
	boss_bar.value = clampf(frac, 0.0, 1.0) * 100.0

func hide_boss_bar() -> void:
	boss_label.visible = false
	boss_bar.visible = false

func show_results() -> void:
	results_panel.visible = true

func hide_results() -> void:
	results_panel.visible = false

func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			message_label.text = ""
	var mins: int = int(mission_time) / 60
	var secs: int = int(mission_time) % 60
	timer_label.text = "TIME %02d:%02d" % [mins, secs]
