class_name EnemyView
extends Control
## One enemy in the fight (spec §9). Deliberately NOT a panel.
##
## The earlier version put every enemy inside a bordered box with a small
## icon in it, and that is the single thing that made the fight read as an
## application rather than a game: a card game's enemies are figures
## standing on a floor, not rows in a list. So this draws a large
## silhouette with its shadow on the ground, its name and health beneath
## it, and its telegraphed intent floating above its head. Being a legal
## target is a pool of light, not a border.
##
## A widget: bind() renders, press() reports. Headless tests call press()
## directly since Godot does not deliver synthetic InputEvents headless.

signal pressed(enemy_index: int)

const VIEW_SIZE := Vector2(230.0, 236.0)
const FIGURE := 52.0
## The plate is the figure plus its margins on both sides, so it is half
## again as wide. The slot has to be sized to the plate, not to the figure,
## or the name below it is drawn over the bottom of the disc.
const PLATE := FIGURE * 1.44
const BAR_WIDTH := 132.0
const BAR_HEIGHT := 8.0

const FLASH_SECONDS := 0.09
const SQUASH := 0.12
const DEATH_SECONDS := 0.45
const BREATH_SECONDS := 3.4
const BREATH_DEPTH := 0.02

var enemy_index: int = -1
var hp: int = 0
var max_hp: int = 1
var block: int = 0
var alive: bool = true
var targetable: bool = false
var idling: bool = true

var _figure: TextureRect
var _illustrated: bool = false
var _plate_slot: Control
var _plate: PanelContainer
var _name: Label
var _hp: Label
var _intent: Label
var _intent_icon: TextureRect
var _intent_chip: PanelContainer
var _status_row: HBoxContainer
var _bar: Control
var _reaction: Tween
var _breath: float = 0.0


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Scales from the feet: a figure that grows should grow upward rather
	# than sink into the floor it is standing on.
	pivot_offset = Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y)
	draw.connect(_draw_ground)
	_build()


func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# The intent floats above the figure's head: it is the thing the player
	# is deciding against, so it sits where they are already looking.
	_intent_chip = PanelContainer.new()
	_intent_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_intent_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 5)
	_intent_icon = Icons.make_rect(null, 20.0, Palette.DANGER)
	chip_row.add_child(_intent_icon)
	_intent = UiTheme.number("", Palette.DANGER)
	chip_row.add_child(_intent)
	_intent_chip.add_child(chip_row)
	column.add_child(_intent_chip)

	# The figure sits on a plate so it reads as a designed piece rather
	# than a stock glyph floating on the background.
	# A slot of constant height holds it, with the plate standing on the
	# slot's floor. Letting the column size to the plate meant a smaller
	# enemy's whole widget rode up, so two enemies of different size no
	# longer shared a ground line and the row looked misaligned.
	_plate_slot = Control.new()
	_plate_slot.custom_minimum_size = Vector2(0.0, PLATE)
	_plate_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_slot.resized.connect(_resize_plate)
	column.add_child(_plate_slot)

	_plate = Icons.make_plate(null, FIGURE, Palette.BONE, Palette.PLATE_ENEMY,
		Palette.STONE_EDGE)
	_figure = _plate.get_child(0)
	_plate_slot.add_child(_plate)

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_status_row)

	_name = UiTheme.body("")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.draw.connect(_draw_bar)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bar)

	_hp = UiTheme.small("", Palette.BONE_DIM)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hp)


func bind(state: FightState, index: int, is_targetable: bool) -> void:
	if enemy_index != index:
		_breath = float(index) * 1.3
	enemy_index = index
	targetable = is_targetable
	var enemy := state.enemies[index]
	var def: EnemyDef = state.content.enemies[enemy.def_id]
	hp = enemy.hp
	max_hp = maxi(1, enemy.max_hp)
	block = enemy.block
	alive = enemy.alive

	_figure.texture = Icons.enemy(enemy.def_id)
	_illustrated = Icons.is_illustrated("enemies", enemy.def_id)
	_figure.modulate = _figure_colour()
	_resize_plate()
	_repaint_plate()
	_name.text = state.content.text(def.name_key)
	_name.add_theme_color_override("font_color", Palette.BONE if alive else Palette.BONE_FAINT)
	_hp.text = "%d/%d" % [enemy.hp, enemy.max_hp]
	if enemy.block > 0:
		_hp.text += "   +%d" % enemy.block

	_intent.text = intent_text(state, index)
	_intent_icon.texture = Icons.get_icon("intent", intent_kind(state, index))
	_intent_chip.visible = alive
	_intent_chip.add_theme_stylebox_override("panel",
		UiTheme.pip_box(Palette.VOID, Palette.DANGER))

	if alive and _reaction == null:
		modulate = Color.WHITE
		scale = Vector2.ONE
		idling = true
	_refresh_status_icons(enemy.statuses)
	_bar.queue_redraw()
	queue_redraw()


## The plate carries the state a border used to: lit when this enemy can be
## struck, drained when it is dead.
## How big this thing is, from how much punishment it takes. A 14 HP rat and
## a 24 HP shambler were drawn at exactly the same size, which is most of why
## they read as one object with two stickers.
func _figure_scale() -> float:
	return clampf(sqrt(float(max_hp) / 24.0), 0.70, 1.32)


func _resize_plate() -> void:
	if _plate_slot == null:
		return
	var scale := _figure_scale()
	var px := FIGURE * scale
	var disc := PLATE * scale
	_figure.custom_minimum_size = Vector2(px, px)
	_plate.custom_minimum_size = Vector2(disc, disc)
	_plate.size = Vector2(disc, disc)
	# Centred in the slot, standing on its floor, so enemies of different
	# size share a ground line.
	_plate.position = Vector2((_plate_slot.size.x - disc) * 0.5, PLATE - disc)
	queue_redraw()


## The plate holds the figure's margins and nothing else; _draw_niche paints
## it, because a flat disc of colour behind a white glyph is the flattest
## thing the game can put on screen and a StyleBox cannot be shaded.
func _repaint_plate() -> void:
	var px := FIGURE * _figure_scale()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_corner_radius_all(int(px))
	box.set_content_margin_all(px * 0.22)
	box.content_margin_bottom = px * 0.22
	_plate.add_theme_stylebox_override("panel", box)
	queue_redraw()


## The colour of the stone the thing stands in.
func _plate_colour() -> Color:
	if not alive:
		return Palette.VOID
	return Palette.PLATE_ENEMY.lerp(Palette.SOUL, 0.22) if targetable else Palette.PLATE_ENEMY


## The lit edge of the opening.
func _ring_colour() -> Color:
	if not alive:
		return Palette.STONE_RAISED
	return Palette.SOUL if targetable else Palette.EDGE_LIGHT


## The niche the enemy stands in: recessed, lit from above by the same
## lantern as the room, with a shadow pooling at its foot.
func _draw_niche() -> void:
	if _plate == null or _plate.size.x <= 4.0:
		return
	var c := _plate_slot.position + _plate.position + _plate.size * 0.5
	var r := _plate.size.x * 0.5
	var base := _plate_colour()
	var ring := _ring_colour()

	# The shadow the cut throws onto the wall around it.
	draw_circle(c + Vector2(0.0, 3.0), r + 5.0, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(c, r, Color(base.r * 0.55, base.g * 0.55, base.b * 0.62, 1.0))

	# Light from above: discs that shrink and climb, each barely visible on
	# its own. draw_circle has no gradient, and this is what one costs.
	for i in 8:
		var t := float(i) / 7.0
		var lift := 1.0 + t * 0.85
		draw_circle(c - Vector2(0.0, r * 0.26 * t), r * (1.0 - t * 0.40),
			Color(minf(base.r * lift, 1.0), minf(base.g * lift, 1.0),
				minf(base.b * lift, 1.0), 0.10))
	# Shadow pooling at the foot, so the figure has something to stand on.
	for i in 5:
		var t := float(i) / 4.0
		draw_circle(c + Vector2(0.0, r * 0.34 + r * 0.20 * t), r * (0.72 - t * 0.22),
			Color(0.0, 0.0, 0.0, 0.11))

	# The rim: lit along the crown, dark along the sill.
	draw_arc(c, r - 1.0, PI * 1.06, PI * 1.94, 34,
		Color(ring.r, ring.g, ring.b, 0.85 if alive else 0.35), 2.0, true)
	draw_arc(c, r - 1.0, PI * 0.06, PI * 0.94, 34, Color(0.0, 0.0, 0.02, 0.50), 2.0, true)


## Lit when it can be struck, bone while it lives, faded once it is dead.
## A silhouette glyph is tinted to say what it is doing; an illustration
## arrives already lit and coloured, so it only ever gets dimmed or lifted.
## Multiplying a full-colour piece by bone-white makes it look faded, and by
## SOUL makes it look like it is underwater.
func _figure_colour() -> Color:
	if _illustrated:
		if not alive:
			return Color(0.40, 0.40, 0.46, 1.0)
		return Color(1.18, 1.18, 1.12, 1.0) if targetable else Color.WHITE
	if not alive:
		return Palette.BONE_FAINT
	return Palette.SOUL if targetable else Palette.BONE


## Which icon the telegraph wears. Separate from the text so a glance reads
## "sword, 7" while the number stays exact.
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
				return "%d ×%d" % [damage, hits]
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


## Takes a hit: a fast white flash and a squash that springs back.
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
	_reaction.tween_property(self, "scale", Vector2.ONE, FLASH_SECONDS * 3.0) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Dies: sags, fades and drains of colour rather than blinking out.
func react_death() -> void:
	if not is_inside_tree():
		return
	_kill_reaction()
	# The dead do not breathe. Without this the idle swell reclaims the
	# scale the moment the death tween ends and the corpse sits back up.
	idling = false
	_reaction = create_tween()
	_reaction.set_parallel(true)
	_reaction.tween_property(self, "modulate:a", 0.25, DEATH_SECONDS).set_ease(Tween.EASE_IN)
	_reaction.tween_property(self, "scale", Vector2(1.06, 0.8), DEATH_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _kill_reaction() -> void:
	if _reaction != null and _reaction.is_valid():
		_reaction.kill()


## A slow swell, seeded per enemy so a row of them does not pulse in
## lockstep. Suppressed while a reaction owns the scale.
func _process(delta: float) -> void:
	if not idling or not alive or (_reaction != null and _reaction.is_valid()):
		return
	_breath += delta
	var swell := 1.0 + sin(_breath * TAU / BREATH_SECONDS) * BREATH_DEPTH
	scale = Vector2(swell, swell)


## Status icons read faster than a comma-separated list mid-fight.
func _refresh_status_icons(statuses: Dictionary) -> void:
	var wanted: Array[String] = []
	for name in statuses:
		if int(statuses[name]) > 0:
			wanted.append(String(name))
	while _status_row.get_child_count() < wanted.size():
		_status_row.add_child(Icons.make_rect(null, 16.0, Palette.PREPARED))
	for i in _status_row.get_child_count():
		var rect: TextureRect = _status_row.get_child(i)
		var used := i < wanted.size()
		rect.visible = used
		if used:
			rect.texture = Icons.status(wanted[i])


## The shadow the figure casts, and the light that marks it as a target.
## Drawn rather than styled, because the whole point of this widget is that
## there is no panel behind it.
func _draw_ground() -> void:
	if size.x <= 0.0:
		return
	_draw_niche()
	if not alive:
		return
	var centre := Vector2(size.x * 0.5, size.y - 44.0)
	var wide := 46.0 * _figure_scale()
	if targetable:
		# A pool of light under a legal target: selection without a border.
		for i in 9:
			var t := float(i) / 8.0
			draw_circle(centre, 30.0 + t * 52.0,
				Color(Palette.SOUL.r, Palette.SOUL.g, Palette.SOUL.b, 0.055 * (1.0 - t)))
	# The shadow it puts on the floor. Three flattened ellipses tightening
	# toward the middle: a blurred contact shadow for the price of three
	# polygons, and without one the thing is floating.
	_ellipse(centre, wide * 1.5, 11.0, Color(0.0, 0.0, 0.0, 0.15))
	_ellipse(centre, wide * 1.15, 8.0, Color(0.0, 0.0, 0.0, 0.20))
	_ellipse(centre, wide * 0.85, 5.5, Color(0.0, 0.0, 0.0, 0.26))


## A flattened disc. draw_circle only draws round ones, and a round shadow
## on a floor seen from the front reads as a ball, not as contact.
func _ellipse(centre: Vector2, rx: float, ry: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, colour)


func _draw_bar() -> void:
	var w := minf(_bar.size.x, BAR_WIDTH)
	if w <= 0.0:
		return
	var frac := float(hp) / float(max_hp)
	var colour := Palette.DANGER if frac <= 0.35 else Palette.BONE_DIM.lerp(Palette.BONE, 0.4)
	UiTheme.draw_health(_bar, Rect2(Vector2((_bar.size.x - w) * 0.5, 0.0), Vector2(w, _bar.size.y)),
		frac, colour, float(block) / float(max_hp))


func press() -> void:
	pressed.emit(enemy_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			press()
