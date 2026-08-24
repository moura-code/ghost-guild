class_name Icons
extends RefCounted
## The icon set (spec §9): flat white silhouettes from game-icons.net, CC BY
## 3.0, credited in ATTRIBUTION.md. Each was stripped of its opaque backing
## plate and re-filled with `currentColor`, so the game tints them.
##
## Every lookup is nullable on purpose. An icon that is missing -- content
## added before its art, or an install with the assets stripped -- must
## degrade to text, never to a crash.

const ROOT := "res://assets/icons"

static var _cache: Dictionary = {}


## `category` is one of enemies, status, relics, card, ui.
static func get_icon(category: String, ident: String) -> Texture2D:
	var key := "%s/%s" % [category, ident]
	if _cache.has(key):
		return _cache[key]
	var path := "%s/%s.svg" % [ROOT, key]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[key] = texture
	return texture


static func enemy(def_id: String) -> Texture2D:
	return get_icon("enemies", def_id)


static func status(name: String) -> Texture2D:
	return get_icon("status", name)


static func relic(relic_id: String) -> Texture2D:
	return get_icon("relics", relic_id)


## Cards are iconified by type rather than one icon per card: 30 cards would
## need 30 pieces of art, and the type is what the player reads at a glance.
static func card_type(type: String) -> Texture2D:
	return get_icon("card", type)


static func ui(ident: String) -> Texture2D:
	return get_icon("ui", ident)


## A TextureRect sized and tinted for inline use next to text.
static func make_rect(texture: Texture2D, px: float, tint: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
