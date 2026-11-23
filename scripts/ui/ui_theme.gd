class_name UiTheme
extends RefCounted

# The one visual theme for every screen (menu, HUD, pause, results,
# touch controls). One palette, one font, one button style - so no
# screen clashes with another. Colours match the uploaded UI art:
# dark navy panels, gold titles, red health, blue armour, orange ammo.

const NAVY := Color(0.05, 0.08, 0.16)
const PANEL := Color(0.04, 0.07, 0.14, 0.94)
const PANEL_BORDER := Color(1.0, 0.8, 0.2)
const GOLD := Color(1.0, 0.8, 0.2)
const BLUE := Color(0.35, 0.65, 1.0)
const RED := Color(0.95, 0.25, 0.25)
const GREEN := Color(0.35, 0.85, 0.4)
const ORANGE := Color(1.0, 0.6, 0.15)
const CREAM := Color(0.95, 0.93, 0.85)
const MUTED := Color(0.7, 0.8, 0.95)
const FONT_PATH := "res://assets/fonts/DejaVuSans-Bold.ttf"

static func font() -> Font:
	return load(FONT_PATH)

static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = PANEL_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16.0
	s.content_margin_right = 16.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s

static func button_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s

static func style_button(btn: Button, bg: Color = Color(0.10, 0.20, 0.42), font_size: int = 20) -> void:
	btn.add_theme_stylebox_override("normal", button_style(bg))
	var hov: StyleBoxFlat = button_style(bg.lightened(0.25))
	btn.add_theme_stylebox_override("hover", hov)
	var pr: StyleBoxFlat = button_style(bg.darkened(0.2))
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_font_override("font", font())

static func style_touch_button(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.07, 0.14, 0.55)
	s.border_color = Color(1.0, 0.8, 0.2, 0.8)
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", s)
	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(1.0, 0.8, 0.2, 0.55)
	pr.border_color = GOLD
	pr.set_border_width_all(2)
	pr.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_font_override("font", font())

static func bar_styles(fill: Color) -> Dictionary:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_corner_radius_all(6)
	var fl := StyleBoxFlat.new()
	fl.bg_color = fill
	fl.set_corner_radius_all(6)
	return {"bg": bg, "fill": fl}
