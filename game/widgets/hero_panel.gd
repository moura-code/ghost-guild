class_name HeroPanel
extends PanelContainer
## The hero's vitals during a fight (spec §9): HP as a bar, energy as orbs,
## block as a shield with a number on it.
##
## This replaces a line of text. The difference matters for play, not just
## looks: mid-fight the player is deciding whether they can afford a card
## and whether the incoming hit kills them, and both answers should be
## readable at a glance rather than parsed out of a sentence.

const PANEL_SIZE := Vector2(124.0, 82.0)
const BAR_HEIGHT := 5.0
const ORB_RADIUS := 4.0
const ORB_GAP := 4.0

var hp: int = 0
var max_hp: int = 1
var block: int = 0
var energy: int = 0
var max_energy: int = 3
var turn: int = 0

var _bar: Control
var _hp_text: Label
var _orbs: Control
var _shield: Control
var _shield_text: Label
var _turn: Label
var _piles: Label
var _energy_text: Label
var _status_row: HBoxContainer
var _flash: float = 0.0
var _figure: TextureRect
var _plate: PanelContainer
var _reaction: Tween


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	# The hero had no body in the fight: every hit they took registered only
	# as a bar flash, while enemies flash, squash and spring back. Now they
	# have a figure that reacts the same way.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	_plate = Icons.make_plate(Icons.ui("hero"), 17.0, Palette.BONE,
		Palette.PLATE_SKILL, Palette.STONE_EDGE)
	_figure = _plate.get_child(0)
	top.add_child(_plate)
	_hp_text = UiTheme.body("")
	_hp_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_hp_text)

	# The shield only appears when there is block to show; an empty shield
	# outline would read as "you have protection" when you have none.
	_shield = Control.new()
	_shield.custom_minimum_size = Vector2(15.0, 17.0)
	_shield.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shield.draw.connect(_draw_shield)
	_shield.visible = false
	top.add_child(_shield)
	# Sits on the shield rather than beside it, so block reads as one thing.
	_shield_text = UiTheme.small("", Palette.STONE)
	_shield_text.visible = false
	_shield_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shield.add_child(_shield_text)

	_turn = UiTheme.small("", Palette.BONE_DIM)
	_turn.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	top.add_child(_turn)
	box.add_child(top)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)

	_orbs = Control.new()
	_orbs.custom_minimum_size = Vector2(0.0, ORB_RADIUS * 2.0 + 4.0)
	_orbs.draw.connect(_draw_orbs)
	_energy_text = UiTheme.small("", Palette.SOUL)
	_energy_text.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_energy_text.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_orbs.add_child(_energy_text)
	box.add_child(_orbs)

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 4)
	box.add_child(_status_row)

	_piles = UiTheme.small("", Palette.BONE_DIM)
	box.add_child(_piles)


func bind(content: Content, fight: FightState) -> void:
	var was_hp := hp
	hp = fight.hero_hp
	max_hp = maxi(1, fight.hero_max_hp)
	block = fight.hero_block
	energy = fight.energy
	max_energy = maxi(1, fight.max_energy)
	turn = fight.turn
	_energy_text.text = "%d / %d %s" % [energy, max_energy, content.text("ui.fight.energy")]

	_hp_text.text = "%d/%d" % [hp, max_hp]
	_hp_text.add_theme_color_override("font_color", _hp_colour())
	_shield.visible = block > 0
	_shield_text.visible = block > 0
	_shield_text.text = str(block)
	_turn.text = content.text("ui.fight.turn").replace("{turn}", str(turn))
	_piles.text = "%s %d   %s %d" % [
		content.text("ui.fight.draw"), fight.draw_pile.size(),
		content.text("ui.fight.discard"), fight.discard_pile.size(),
	]
	_refresh_statuses(fight.statuses)

	# A drop in HP tints the bar for a moment, so losing health registers
	# even when the player is looking at the enemy that caused it.
	if was_hp > 0 and hp < was_hp:
		_flash = 1.0
		var tween := create_tween()
		tween.tween_method(_set_flash, 1.0, 0.0, 0.5)

	_bar.queue_redraw()
	_orbs.queue_redraw()
	_shield.queue_redraw()


## Bone while healthy, amber under half, danger under a quarter — so the
## colour alone tells the player how much trouble they are in.
## The same flash-and-squash the enemies get, so a hit on the hero reads as
## a hit rather than as a number quietly changing.
func react_hit(amount: int) -> void:
	if not is_inside_tree():
		return
	if _reaction != null and _reaction.is_valid():
		_reaction.kill()
	var depth := clampf(float(amount) / 12.0, 0.4, 1.0)
	_plate.pivot_offset = _plate.size * 0.5
	_plate.modulate = Palette.DANGER
	_plate.scale = Vector2(1.0 + 0.14 * depth, 1.0 - 0.14 * depth)
	_reaction = create_tween()
	_reaction.set_parallel(true)
	_reaction.tween_property(_plate, "modulate", Color.WHITE, 0.22)
	_reaction.tween_property(_plate, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _hp_colour() -> Color:
	var frac := float(hp) / float(max_hp)
	if frac <= 0.25:
		return Palette.DANGER
	if frac <= 0.5:
		return Palette.PREPARED
	return Palette.BONE


func _set_flash(value: float) -> void:
	_flash = value
	_bar.queue_redraw()


func _refresh_statuses(statuses: Dictionary) -> void:
	var wanted: Array[String] = []
	for name in statuses:
		if int(statuses[name]) > 0:
			wanted.append(String(name))
	while _status_row.get_child_count() < wanted.size():
		_status_row.add_child(Icons.make_rect(null, 8.0, Palette.PREPARED))
	for i in _status_row.get_child_count():
		var rect: TextureRect = _status_row.get_child(i)
		var used := i < wanted.size()
		rect.visible = used
		if used:
			rect.texture = Icons.status(wanted[i])


## Block is drawn over the health it is protecting, so a big shield visibly
## covers the damage it is about to absorb.
func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var frac := float(hp) / float(max_hp)
	UiTheme.draw_health(_bar, Rect2(Vector2.ZERO, Vector2(w, h)), frac, _hp_colour(),
		float(block) / float(max_hp))
	if _flash > 0.0:
		_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(1.0, 1.0, 1.0, 0.5 * _flash))


## One orb per point of energy: spent ones hollow out rather than vanish,
## so the player can see both what they have and what they started with.
func _draw_orbs() -> void:
	for i in max_energy:
		var centre := Vector2(ORB_RADIUS + float(i) * (ORB_RADIUS * 2.0 + ORB_GAP), ORB_RADIUS + 2.0)
		if i < energy:
			_orbs.draw_circle(centre, ORB_RADIUS, Palette.SOUL)
			_orbs.draw_circle(centre, ORB_RADIUS * 0.45, Palette.STONE)
		else:
			_orbs.draw_arc(centre, ORB_RADIUS, 0.0, TAU, 20, Palette.BONE_FAINT, 1.5)


func _draw_shield() -> void:
	var w := _shield.size.x
	var h := _shield.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var points := PackedVector2Array([
		Vector2(w * 0.5, 0.0), Vector2(w, h * 0.22), Vector2(w * 0.86, h * 0.78),
		Vector2(w * 0.5, h), Vector2(w * 0.14, h * 0.78), Vector2(0.0, h * 0.22),
	])
	_shield.draw_colored_polygon(points, Palette.SOUL)
