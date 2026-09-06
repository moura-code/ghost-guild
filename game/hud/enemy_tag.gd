class_name EnemyTag
extends Control
## Name, health and intent for one enemy, drawn in 2D at the point on screen
## where that enemy's head is.
##
## It has to be 2D. The numbers a player reads every turn -- how much health
## is left, how hard the next blow lands -- cannot be a texture on a mesh in a
## dark corridor at whatever angle the fight left them. Same argument the spec
## makes for cards (§3.2), applied to the only other thing you read mid-fight.
##
## The projection is done by whoever owns the camera and handed in through
## `place`, so this node knows nothing about 3D.

## Narrow on purpose. A bar as wide as the creature is tall stops reading as
## "that thing's health" and starts reading as a stripe across the room.
const WIDTH := 82.0
const BAR_HEIGHT := 4.0
const GAP := 2.0
## Two enemies at similar depth project to nearly the same point, and their
## tags stack until neither is readable. This is the smallest vertical
## distance two tags may end up apart.
const STACK_GAP := 44.0

var index: int = -1

var _name: Label
var _intent: Label
var _health: Label
var _intent_icon: TextureRect
var _hp: int = 1
var _max_hp: int = 1
var _block: int = 0
var _plate: StyleBox = UiTheme.panel_box(
	Color(Palette.ABYSS.r, Palette.ABYSS.g, Palette.ABYSS.b, 0.82), Palette.STONE_EDGE)


static func create(enemy_index: int) -> EnemyTag:
	var t := EnemyTag.new()
	t.name = "Tag%d" % enemy_index
	t.index = enemy_index
	return t


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 38.0)
	size = custom_minimum_size

	_name = UiTheme.body("", Palette.BONE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(WIDTH, 12.0)
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	_health = UiTheme.small("", Palette.BONE_DIM)
	_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health.position = Vector2(0, 12)
	_health.size = Vector2(WIDTH, 9)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health)
	_intent_icon = Icons.make_rect(null, 9, Palette.DANGER)
	_intent_icon.position = Vector2(18, 28)
	add_child(_intent_icon)

	# Bright, not blood-red: the intent sits on a dark plate over dark stone,
	# and a dark warm red on that is a number you have to lean in to read.
	_intent = UiTheme.body("", Palette.BONE)
	_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent.position = Vector2(11.0, 27.0)
	_intent.size = Vector2(WIDTH - 15, 11.0)
	_intent.clip_text = true
	_intent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intent)


func bind(content: Content, fight: FightState, enemy_index: int) -> void:
	index = enemy_index
	var e: EnemyState = fight.enemies[enemy_index]
	var def: EnemyDef = content.enemies[e.def_id]
	_name.text = content.text(def.name_key)
	_hp = e.hp
	_max_hp = maxi(1, e.max_hp)
	_block = e.block
	_health.text = "%d / %d" % [_hp, _max_hp]
	if _block > 0:
		_health.text += "  +%d" % _block
	var kind := String(EnemyAI.intent_of(fight, enemy_index).get("kind", "unknown"))
	_intent_icon.texture = Icons.get_icon("intent", kind)
	_intent_icon.modulate = Palette.DANGER if kind == "attack" else Palette.EDGE_LIGHT
	_intent.add_theme_color_override("font_color", Palette.DANGER if kind == "attack" else Palette.BONE)
	_intent_icon.visible = kind in ["attack", "block"]
	_intent.position.x = 11 if _intent_icon.visible else 0
	_intent.size.x = WIDTH - _intent.position.x
	_intent.text = intent_text(content, fight, enemy_index)
	visible = e.alive
	queue_redraw()


## What the enemy is about to do, in the fewest characters that say it. Ported
## from the 2D enemy panel unchanged: the engine is the authority and this only
## reads it.
static func intent_text(content: Content, fight: FightState, enemy_index: int) -> String:
	var intent := EnemyAI.intent_of(fight, enemy_index)
	match String(intent.get("kind", "")):
		"attack":
			var hits := int(intent.get("hits", 1))
			var damage := int(intent.get("damage", 0))
			return "%d x%d" % [damage, hits] if hits > 1 else str(damage)
		"block":
			return str(int(intent.get("block", 0)))
		"buff":
			return content.text("ui.fight.intent.buff")
		"debuff":
			return content.text("ui.fight.intent.debuff")
		"summon":
			return content.text("ui.fight.intent.summon")
	return content.text("ui.fight.intent.unknown")


## Centred on the projected head point and lifted clear of it, so the tag
## floats above the creature rather than across its face.
func place(at: Vector2) -> void:
	position = at - Vector2(WIDTH * 0.5, size.y + 6.0)


func _draw() -> void:
	# A backing plate under the whole tag. Without it the text and the bar sit
	# straight on lit stone, and a red bar with nothing behind it reads as a
	# stripe painted on the wall rather than as that creature's health.
	#
	# Carved, like everything else the player reads. It was a flat translucent
	# rectangle with a flat red bar in it, which was fine while the rest of the
	# HUD was stock Godot controls and became the one unstyled object on screen
	# the day the theme was actually applied.
	draw_style_box(_plate, Rect2(-4.0, -2.0, WIDTH + 8.0, size.y + 4.0))

	var top := 22.0
	# The same bar the hero's own health uses: banded, lit along the top, with
	# block sitting in front of the health rather than beside it -- it is the
	# part you have to get through first.
	UiTheme.draw_health(self, Rect2(0.0, top, WIDTH, BAR_HEIGHT + 1.0),
		float(_hp) / float(_max_hp), Palette.DANGER,
		clampf(float(_block) / float(_max_hp), 0.0, 1.0))


## Pushes tags apart that would otherwise land on top of each other. Takes the
## projected points in draw order and returns the points to actually use.
##
## Pure, because this is a geometry bug that a screenshot found and a test
## should keep found: three enemies in a line project to three points a few
## pixels apart, and stacked tags are worse than no tags.
static func spread(points: Array) -> Array:
	var order: Array = []
	for i in points.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return float(points[a].y) < float(points[b].y))
	var out: Array = points.duplicate()
	var placed: Array[Vector2] = []
	for i in order:
		var at: Vector2 = out[i]
		for previous in placed:
			if absf(at.x - previous.x) < WIDTH + 8.0 and at.y - previous.y < STACK_GAP:
				at.y = previous.y + STACK_GAP
		out[i] = at
		placed.append(at)
	return out
