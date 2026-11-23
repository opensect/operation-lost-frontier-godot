class_name SheetSlicer
extends RefCounted

# Crops rectangular art out of the master atlases (batches 03-06).
# ONLY rectangular crops are used: the atlases have baked checkerboard
# / gradient backgrounds with no clean alpha, so single characters cut
# out of them would carry the background into the game. Rectangular
# panels, logos and full background cells have no transparency need.
# Gameplay sprites (characters, enemies, bosses, weapons, pickups)
# always come from the individual batch 1+2 PNGs via SpriteLoader.

const B03_SHEET2 := "res://assets/sheets/batch03_weapons_environments_bosses_HUD.png"
const B04_ATLAS2 := "res://assets/sheets/batch04_Character_Animation_UI_Background_Atlas.png"
const B06_ATLAS := "res://assets/sheets/batch06_Batch_06_20_Mission_Background_Atlas.png"
const B12_ATLAS := "res://assets/sheets/batch12_Batch_12_Interactive_Objects_Atlas.png"

static func _atlas(path: String, region: Rect2) -> AtlasTexture:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = region
	return a

# Logo: a clean text logo drawn on transparency (assets/ui/logo_clean.png).
# The batch-03 sheet logo crop carried the sheet's baked checkerboard
# background into the menu, so it rendered as a white/grey checker box.
static func logo() -> Texture2D:
	return load("res://assets/ui/logo_clean.png")

# Batch 04, atlas 2: the "MISSION COMPLETE!" panel with 3 stars.
static func mission_complete_panel() -> AtlasTexture:
	return _atlas(B04_ATLAS2, Rect2(1086, 794, 296, 94))

# Batch 06: 4x5 grid of 20 mission backgrounds, cell 418x188.
# Mission N uses cell N (1-20). Full cell keeps its baked title label
# (good for the mission-select thumbnail); the backdrop crop drops the
# top 44 px so the label is gone (good for the in-world vista).
# 26 px was NOT enough: the label pill is ~40 px tall, so its bottom
# half ("1. Jungle Forest") still showed, clipped at the top of the
# screen, in both the menu and the game. Verified by rendering the
# cropped texture to a PNG and reading it back.
static func _cell(n: int) -> Rect2:
	var i: int = clampi(n, 1, 20) - 1
	return Rect2(float((i % 4) * 418), float((i / 4) * 188), 418.0, 188.0)

static func mission_thumb(mission_num: int) -> AtlasTexture:
	return _atlas(B06_ATLAS, _cell(mission_num))

static func mission_backdrop(mission_num: int) -> AtlasTexture:
	var c: Rect2 = _cell(mission_num)
	return _atlas(B06_ATLAS, Rect2(c.position + Vector2(0, 44), Vector2(c.size.x, c.size.y - 44)))

static func menu_backdrop() -> AtlasTexture:
	return mission_backdrop(1)

# Batch 12 interactive objects. Same rule as the other atlases: only
# rectangular crops whose object fills the frame (the sheet's dark
# backing then reads as a panel, not a stray rectangle). Keys:
# terminal = blue console (objective stations), portal = blue energy
# portal (extraction beacon), switch_red / door_blue = available.
static func atlas_sprite(key: String) -> AtlasTexture:
	match key:
		"terminal":
			return _atlas(B12_ATLAS, Rect2(686, 370, 68, 98))
		"portal":
			return _atlas(B12_ATLAS, Rect2(122, 782, 116, 210))
		"switch_red":
			return _atlas(B12_ATLAS, Rect2(16, 372, 80, 84))
		"door_blue":
			return _atlas(B12_ATLAS, Rect2(172, 38, 150, 144))
	return null

static func interactive_terminal() -> AtlasTexture:
	return atlas_sprite("terminal")

static func interactive_portal() -> AtlasTexture:
	return atlas_sprite("portal")
