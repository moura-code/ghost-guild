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

const WIDTH := 92.0
const BAR_HEIGHT := 5.0
const GAP := 2.0

var index: int = -1

var _name: Label
var _intent: Label
var _hp: int = 1
var _max_hp: int = 1
var _block: int = 0


static func create(enemy_index: int) -> EnemyTag:
	var t := EnemyTag.new()
	t.name = "Tag%d" % enemy_index
	t.index = enemy_index
	return t


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 34.0)
	size = custom_minimum_size

	_name = UiTheme.small("", Palette.BONE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(WIDTH, 10.0)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	_intent = UiTheme.small("", Palette.DANGER)
	_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent.position = Vector2(0.0, 22.0)
	_intent.size = Vector2(WIDTH, 10.0)
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
	var top := 12.0
	var bar := Rect2(0.0, top, WIDTH, BAR_HEIGHT)
	draw_rect(bar, Palette.ABYSS)
	var fraction := clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	draw_rect(Rect2(0.0, top, WIDTH * fraction, BAR_HEIGHT), Palette.DANGER)
	if _block > 0:
		# Block sits on top of the health rather than beside it: it is the
		# part of the bar you have to get through first.
		var width := WIDTH * clampf(float(_block) / float(_max_hp), 0.0, 1.0)
		draw_rect(Rect2(0.0, top - GAP - BAR_HEIGHT, width, BAR_HEIGHT), Palette.SOUL)
