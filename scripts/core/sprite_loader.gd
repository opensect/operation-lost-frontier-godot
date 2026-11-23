class_name SpriteLoader
extends RefCounted

# Loads uploaded PNG art as proper Texture2D sprites.
# In Godot, a PNG in res://assets is imported as a Texture2D by default -
# this was the Unity blank-screen bug (PNGs imported as Default textures,
# so Resources.Load<Sprite> returned null). Here load() always returns a
# real texture, or a generated coloured placeholder - never null.

const CAT_PATH := {
	"Characters": "res://assets/characters/",
	"Enemies": "res://assets/enemies/",
	"Environment": "res://assets/environment/",
	"Props": "res://assets/props/",
	"Powerups": "res://assets/powerups/",
	"Weapons": "res://assets/weapons/",
	"UI": "res://assets/ui/",
	"Hazards": "res://assets/hazards/",
}

static var _placeholder: Dictionary = {}

static func texture(category: String, sprite_name: String) -> Texture2D:
	# "atlas:<key>" resolves through SheetSlicer (batch 12 interactive
	# objects, batch 03/04/06 panels). The atlas art lives in core, so
	# this stays inside the core module, not a cross-module dependency.
	if sprite_name.begins_with("atlas:"):
		return SheetSlicer.atlas_sprite(sprite_name.trim_prefix("atlas:"))
	# A name containing "/" is a path under res://assets/ (e.g. the
	# batch-2 cutouts: "characters/Cutouts/asset_017").
	if "/" in sprite_name:
		var full: String = "res://assets/" + sprite_name + ".png"
		if ResourceLoader.exists(full):
			var ft: Texture2D = load(full)
			if ft != null:
				return ft
	var base: String = CAT_PATH.get(category, "res://assets/props/")
	var path: String = base + sprite_name + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		if t != null:
			return t
	# Fallback: search every category by bare name.
	for cat_path in CAT_PATH.values():
		var p2: String = cat_path + sprite_name + ".png"
		if ResourceLoader.exists(p2):
			var t2: Texture2D = load(p2)
			if t2 != null:
				return t2
	return placeholder(Color(0.8, 0.8, 0.8))

static func placeholder(col: Color) -> Texture2D:
	var key: String = str(col)
	if _placeholder.has(key):
		return _placeholder[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(col)
	var tex := ImageTexture.create_from_image(img)
	_placeholder[key] = tex
	return tex

static func apply_to_sprite(sprite: Sprite2D, category: String, sprite_name: String, fallback: Color, size_px: Vector2) -> void:
	var tex: Texture2D = texture(category, sprite_name)
	sprite.texture = tex
	if tex == null:
		return
	var s: Vector2 = tex.get_size()
	if s.x > 0.0 and s.y > 0.0:
		# Fit INSIDE the target box (was: scale by height only, so a
		# wide texture became a huge opaque rectangle - the screenshot-2
		# brown rectangle). Uniform scale, aspect preserved.
		var sc: float = minf(size_px.x / s.x, size_px.y / s.y)
		sprite.scale = Vector2(sc, sc)
	sprite.modulate = fallback if sprite_name == "" else Color.WHITE
