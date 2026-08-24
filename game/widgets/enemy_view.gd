class_name EnemyView
extends PanelContainer
## One enemy across the top of the fight (spec §9): name, HP bar, block,
## and the telegraphed intent — the number the player is deciding against.
##
## A widget: bind() renders, press() reports. Headless tests call press()
## directly since Godot does not deliver synthetic InputEvents headless.

signal pressed(enemy_index: int)

const VIEW_SIZE := Vector2(186.0, 132.0)
const BAR_HEIGHT := 9.0
const FLASH_SECONDS := 0.09
const SQUASH := 0.12
const DEATH_SECONDS := 0.45
const BREATH_SECONDS := 3.4
const BREATH_DEPTH := 0.018

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
var _icon: TextureRect
var _status_row: HBoxContainer
var _reaction: Tween
var _intent_icon: TextureRect
var _breath: float = 0.0
var idling: bool = true


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = VIEW_SIZE * 0.5
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_icon = Icons.make_rect(null, 40.0, Palette.BONE)
	head.add_child(_icon)
	_name = UiTheme.body("")
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	box.add_child(head)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)

	_hp = UiTheme.small("", Palette.BONE_DIM)
	box.add_child(_hp)

	var intent_row := HBoxContainer.new()
	intent_row.add_theme_constant_override("separation", 4)
	_intent_icon = Icons.make_rect(null, 22.0, Palette.DANGER)
	intent_row.add_child(_intent_icon)
	_intent = UiTheme.number("", Palette.DANGER)
	intent_row.add_child(_intent)
	box.add_child(intent_row)

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 4)
	box.add_child(_status_row)

	_statuses = UiTheme.small("", Palette.BONE_FAINT)
	box.add_child(_statuses)


func bind(state: FightState, index: int, is_targetable: bool) -> void:
	if enemy_index != index:
		_breath = float(index) * 1.3
	enemy_index = index
	targetable = is_targetable
	var enemy := state.enemies[index]
	var def: EnemyDef = state.content.enemies[enemy.def_id]
	hp = enemy.hp
	max_hp = maxi(1, enemy.max_hp)
	alive = enemy.alive

	_name.text = state.content.text(def.name_key)
	_icon.texture = Icons.enemy(enemy.def_id)
	if alive and _reaction == null:
		modulate = Color.WHITE
		scale = Vector2.ONE
		idling = true
	_icon.modulate = Palette.BONE if alive else Palette.BONE_FAINT
	_refresh_status_icons(enemy.statuses)
	_hp.text = "%d/%d" % [enemy.hp, enemy.max_hp]
	if enemy.block > 0:
		_hp.text += "  +%d" % enemy.block
	_intent.text = intent_text(state, index)
	_intent_icon.texture = Icons.get_icon("intent", intent_kind(state, index))
	_intent_icon.visible = alive
	_statuses.text = status_text(state.content, enemy.statuses)
	_name.add_theme_color_override("font_color", Palette.BONE if alive else Palette.BONE_FAINT)
	add_theme_stylebox_override("panel", UiTheme.panel_box(
		Palette.STONE_RAISED if alive else Palette.STONE,
		Palette.SOUL if targetable else Palette.STONE_EDGE))
	_bar.queue_redraw()


## Which icon the telegraph wears. Separate from the text so a glance reads
## "sword, 7" while the sentence underneath stays unambiguous.
static func intent_kind(state: FightState, index: int) -> String:
	if not state.enemies[index].alive:
		return ""
	var kind := String(EnemyAI.intent_of(state, index).get("kind", ""))
	return kind if kind != "" else "unknown"


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
				return "%d x%d" % [damage, hits]
			return str(damage)
		"block":
			return str(int(intent.get("block", 0)))
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


## Takes a hit: a fast white flash and a squash that springs back. Both are
## short on purpose -- long enough to see, not long enough to wait for.
func react_hit(amount: int) -> void:
	if not is_inside_tree():
		return
	_kill_reaction()
	var depth := clampf(float(amount) / 12.0, 0.35, 1.0)
	modulate = Palette.BONE
	scale = Vector2(1.0 + SQUASH * depth, 1.0 - SQUASH * depth)
	_reaction = create_tween()
	_reaction.set_parallel(true)
	_reaction.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS * 2.0)
	_reaction.tween_property(self, "scale", Vector2.ONE, FLASH_SECONDS * 3.0) 		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Dies: sags, fades and drains of colour rather than blinking out.
func react_death() -> void:
	if not is_inside_tree():
		return
	_kill_reaction()
	# The dead do not breathe. Without this the idle swell reclaims the
	# scale the moment the death tween finishes and the corpse sits up.
	idling = false
	_reaction = create_tween()
	_reaction.set_parallel(true)
	_reaction.tween_property(self, "modulate:a", 0.25, DEATH_SECONDS).set_ease(Tween.EASE_IN)
	_reaction.tween_property(self, "scale", Vector2(1.0, 0.82), DEATH_SECONDS) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _kill_reaction() -> void:
	if _reaction != null and _reaction.is_valid():
		_reaction.kill()


## A slow swell, seeded per enemy so a row of them does not pulse in
## lockstep. Suppressed while a hit reaction or a death is playing, since
## those own the scale.
func _process(delta: float) -> void:
	if not idling or not alive or (_reaction != null and _reaction.is_valid()):
		return
	_breath += delta
	var swell := 1.0 + sin(_breath * TAU / BREATH_SECONDS) * BREATH_DEPTH
	scale = Vector2(swell, swell)


## Status icons read faster than a comma-separated list mid-fight; the text
## line stays underneath as the unambiguous version.
func _refresh_status_icons(statuses: Dictionary) -> void:
	var wanted: Array[String] = []
	for name in statuses:
		if int(statuses[name]) > 0:
			wanted.append(String(name))
	while _status_row.get_child_count() < wanted.size():
		_status_row.add_child(Icons.make_rect(null, 14.0, Palette.PREPARED))
	for i in _status_row.get_child_count():
		var rect: TextureRect = _status_row.get_child(i)
		var used := i < wanted.size()
		rect.visible = used
		if used:
			rect.texture = Icons.status(wanted[i])


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
