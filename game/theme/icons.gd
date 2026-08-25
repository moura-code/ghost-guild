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
## Tried in order. PNG first so a delivered piece of real art replaces the
## CC BY placeholder glyph of the same id without a code change -- which is
## the contract ART_BRIEF.md makes to whoever is drawing, and which this
## loader quietly broke for as long as it only looked for `.svg`.
const EXTENSIONS := [".png", ".svg"]

static var _cache: Dictionary = {}


## The file backing an icon, or "" if nothing was delivered for it. Takes the
## root so it can be tested against files a test wrote rather than against
## the shipped asset tree.
static func resolve(category: String, ident: String, root: String = ROOT) -> String:
	for extension in EXTENSIONS:
		var path := "%s/%s/%s%s" % [root, category, ident, extension]
		# ResourceLoader knows about res:// imports; FileAccess covers a
		# plain directory, which is what a test hands us.
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


## `category` is one of enemies, status, relics, card, card_art, ui.
static func get_icon(category: String, ident: String) -> Texture2D:
	var key := "%s/%s" % [category, ident]
	if _cache.has(key):
		return _cache[key]
	var path := resolve(category, ident)
	var texture: Texture2D = null
	if path != "":
		texture = load(path) as Texture2D
	_cache[key] = texture
	return texture


static func enemy(def_id: String) -> Texture2D:
	return get_icon("enemies", def_id)


## Whether this id is backed by a raster illustration rather than a
## silhouette glyph. Callers tint a glyph and leave an illustration alone --
## a full-colour piece multiplied by bone-white just looks faded.
static func is_illustrated(category: String, ident: String) -> bool:
	return resolve(category, ident).ends_with(".png")


static func status(name: String) -> Texture2D:
	return get_icon("status", name)


static func relic(relic_id: String) -> Texture2D:
	return get_icon("relics", relic_id)


## Cards are iconified by type rather than one icon per card: 30 cards would
## need 30 pieces of art, and the type is what the player reads at a glance.
static func card_type(type: String) -> Texture2D:
	return get_icon("card", type)


## What sits in a card's art slot. Real per-card art would live under
## assets/icons/card_art/<id>; until it exists the type icon stands in, at
## the size and aspect the illustration will occupy.
static func card_art(def_id: String, type: String) -> Texture2D:
	var art := get_icon("card_art", def_id)
	return art if art != null else card_type(type)


## Whether this card has real illustration rather than a silhouette standing
## in for it. The two want opposite treatment: a glyph is a white shape the
## card tints and centres, while an illustration is already lit and coloured
## and tinting it just washes it out.
static func has_card_art(def_id: String) -> bool:
	return is_illustrated("card_art", def_id)


static func ui(ident: String) -> Texture2D:
	return get_icon("ui", ident)


## An icon on a coloured plate. A flat glyph alone reads as clip art
## dropped onto a slide; the same glyph on a filled disc reads as part of a
## system, which is what Slay the Spire, Monster Train and Balatro all do
## with flat iconography. Costs a StyleBox rather than an artist.
static func make_plate(texture: Texture2D, px: float, tint: Color, plate: Color,
		ring: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = plate
	box.set_corner_radius_all(int(px))
	box.set_content_margin_all(maxf(4.0, px * 0.22))
	if ring.a > 0.0:
		box.border_color = ring
		box.set_border_width_all(1)
	holder.add_theme_stylebox_override("panel", box)
	holder.add_child(make_rect(texture, px, tint))
	return holder


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
