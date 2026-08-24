class_name EnemyView
extends PanelContainer
## One enemy across the top of the fight (spec §9): name, HP bar, block,
## and the telegraphed intent — the number the player is deciding against.
##
## A widget: bind() renders, press() reports. Headless tests call press()
## directly since Godot does not deliver synthetic InputEvents headless.

signal pressed(enemy_index: int)

const VIEW_SIZE := Vector2(148.0, 96.0)
const BAR_HEIGHT := 6.0

var enemy_index: int = -1
var hp: int = 0
var max_hp: int = 1
var alive: bool = true
var targetable: bool = false

var _name: Label
var _hp: Label
var _intent: Label
var _statuses: Label
var _bar: Control


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	_name = UiTheme.body("")
	box.add_child(_name)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)

	_hp = UiTheme.small("", Palette.BONE_DIM)
	box.add_child(_hp)

	_intent = UiTheme.body("", Palette.DANGER)
	box.add_child(_intent)

	_statuses = UiTheme.small("", Palette.BONE_FAINT)
	box.add_child(_statuses)


func bind(state: FightState, index: int, is_targetable: bool) -> void:
	enemy_index = index
	targetable = is_targetable
	var enemy := state.enemies[index]
	var def: EnemyDef = state.content.enemies[enemy.def_id]
	hp = enemy.hp
	max_hp = maxi(1, enemy.max_hp)
	alive = enemy.alive

	_name.text = state.content.text(def.name_key)
	_hp.text = "%d/%d" % [enemy.hp, enemy.max_hp]
	if enemy.block > 0:
		_hp.text += "  +%d" % enemy.block
	_intent.text = intent_text(state, index)
	_statuses.text = status_text(state.content, enemy.statuses)
	_name.add_theme_color_override("font_color", Palette.BONE if alive else Palette.BONE_FAINT)
	add_theme_stylebox_override("panel", UiTheme.panel_box(
		Palette.STONE_RAISED if alive else Palette.STONE,
		Palette.SOUL if targetable else Palette.STONE_EDGE))
	_bar.queue_redraw()


## The telegraph. §4.1 says intents are shown, and the exit decision is only
## honest if the player can see what is coming.
static func intent_text(state: FightState, index: int) -> String:
	var content := state.content
	if not state.enemies[index].alive:
		return ""
	var intent := EnemyAI.intent_of(state, index)
	match String(intent.get("kind", "")):
		"attack":
			var hits := int(intent.get("hits", 1))
			var damage := int(intent.get("damage", 0))
			if hits > 1:
				return content.text("ui.fight.intent.attack_multi") \
					.replace("{damage}", str(damage)).replace("{hits}", str(hits))
			return content.text("ui.fight.intent.attack").replace("{damage}", str(damage))
		"block":
			return content.text("ui.fight.intent.block").replace("{block}", str(int(intent.get("block", 0))))
		"buff":
			return content.text("ui.fight.intent.buff")
		"debuff":
			return content.text("ui.fight.intent.debuff")
		"summon":
			return content.text("ui.fight.intent.summon")
	return content.text("ui.fight.intent.unknown")


static func status_text(content: Content, statuses: Dictionary) -> String:
	var parts := PackedStringArray()
	for name in statuses:
		var stacks := int(statuses[name])
		if stacks <= 0:
			continue
		parts.append("%s %d" % [content.text("status.%s.name" % String(name)), stacks])
	return " · ".join(parts)


func _draw_bar() -> void:
	var w := _bar.size.x
	if w <= 0.0:
		return
	var h := _bar.size.y
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Palette.STONE)
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var colour := Palette.DANGER if frac <= 0.35 else Palette.BONE_DIM
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w * frac, h)), colour)


func press() -> void:
	pressed.emit(enemy_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			press()
