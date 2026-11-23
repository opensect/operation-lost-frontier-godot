class_name MainMenu
extends CanvasLayer

# Owns ONLY the main menu screen: title, character choice, mission
# choice, difficulty, HOST / FIND HOST / JOIN, and START. It emits
# signals; the Game decides what starting means. (Single Responsibility.)

signal start_pressed
signal character_selected(character_id: String)
signal mission_changed(mission_num: int)
signal difficulty_changed(difficulty: String)
signal host_pressed
signal find_host_pressed
signal join_pressed(ip: String)

var selected_character: String = "Ranger"
var selected_mission: int = 1
var selected_difficulty: String = "Normal"

func _ready() -> void:
	# Art: game icon emblem, atlas logo, mission-06 backdrop, mission thumb.
	var icon_tex: Texture2D = load("res://icon.png")
	if icon_tex != null:
		%IconImage.texture = icon_tex
	%LogoImage.texture = SheetSlicer.logo()
	%MenuBackdrop.texture = SheetSlicer.menu_backdrop()
	%StartButton.pressed.connect(func() -> void: start_pressed.emit())
	%MissionPrevButton.pressed.connect(func() -> void: _change_mission(-1))
	%MissionNextButton.pressed.connect(func() -> void: _change_mission(1))
	%DifficultyButton.pressed.connect(_cycle_difficulty)
	%HostButton.pressed.connect(func() -> void: host_pressed.emit())
	%FindHostButton.pressed.connect(func() -> void: find_host_pressed.emit())
	%JoinButton.pressed.connect(func() -> void: join_pressed.emit(%IpLineEdit.text))
	UiTheme.style_button(%StartButton, Color(0.55, 0.38, 0.05), 28)
	for b in [%MissionPrevButton, %MissionNextButton, %HostButton, %FindHostButton, %JoinButton, %DifficultyButton]:
		UiTheme.style_button(b, Color(0.10, 0.20, 0.42), 18)
	for i in range(4):
		var cid: String = GameData.CHARACTERS[i]["id"]
		var btn: Button = %CharButtons.get_child(i)
		btn.text = GameData.CHARACTERS[i]["display"]
		btn.icon = SpriteLoader.texture("Characters", str(GameData.CHARACTERS[i]["sprite"]))
		btn.expand_icon = true
		UiTheme.style_button(btn, Color(0.10, 0.20, 0.42), 20)
	_update_labels()

func _select_character(cid: String) -> void:
	selected_character = cid
	character_selected.emit(cid)
	_update_labels()

func _change_mission(delta: int) -> void:
	selected_mission = clampi(selected_mission + delta, 1, 20)
	mission_changed.emit(selected_mission)
	_update_labels()

func _cycle_difficulty() -> void:
	var order: Array[String] = ["Easy", "Normal", "Hard", "Extreme"]
	var idx: int = (order.find(selected_difficulty) + 1) % order.size()
	selected_difficulty = order[idx]
	difficulty_changed.emit(selected_difficulty)
	_update_labels()

func _update_labels() -> void:
	var m: Dictionary = GameData.mission(selected_mission)
	%MissionLabel.text = "Mission %d: %s  (Act %d - %s)" % [m["number"], m["title"], m["act"], m["environment"]]
	%MissionThumb.texture = SheetSlicer.mission_thumb(selected_mission)
	%DifficultyButton.text = "Difficulty: " + selected_difficulty
	%HintLabel.text = "Character: %s - %s" % [selected_character, GameData.character(selected_character)["ability"]]
	for i in range(4):
		var btn: Button = %CharButtons.get_child(i)
		var cid: String = GameData.CHARACTERS[i]["id"]
		btn.modulate = Color(1.0, 0.85, 0.4) if cid == selected_character else Color.WHITE
