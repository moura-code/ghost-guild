class_name CardView
extends PanelContainer
## One card in the hand (spec §9): cost bubble, name, text, rarity edge.
## Typographic — there is no card art and there never will be.
##
## A widget: it renders what bind() gives it and reports the click. Headless
## tests call press() directly, because Godot does not deliver synthetic
## InputEvents in headless mode.

signal pressed(hand_index: int)

const CARD_SIZE := Vector2(132.0, 172.0)

var hand_index: int = -1
var playable: bool = true
var selected: bool = false

var _cost: Label
var _name: Label
var _text: Label


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_cost = UiTheme.number("", Palette.SOUL)
	box.add_child(_cost)

	_name = UiTheme.body("")
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_name)

	_text = UiTheme.small("", Palette.BONE_DIM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)


func bind(content: Content, card: CardInstance, index: int, is_playable: bool) -> void:
	hand_index = index
	playable = is_playable
	var def: CardDef = content.cards[card.def_id]
	var cost := def.cost_for(card.upgraded)
	_cost.text = content.text("ui.card.cost_x") if cost == CardDef.COST_X else str(cost)
	_name.text = content.text(def.name_key)
	if card.upgraded:
		_name.text += content.text("ui.upgraded")
	_text.text = content.text(def.text_key)
	_paint(def)


## An unaffordable card stays legible but visibly out of reach, rather than
## disappearing — the player needs to see what they could not afford.
func _paint(def: CardDef) -> void:
	var edge := rarity_colour(def.rarity)
	var body := Palette.STONE_RAISED if playable else Palette.STONE
	if selected:
		edge = Palette.SOUL
	add_theme_stylebox_override("panel", UiTheme.panel_box(body, edge))
	var ink := Palette.BONE if playable else Palette.BONE_FAINT
	_name.add_theme_color_override("font_color", ink)
	_cost.add_theme_color_override("font_color", Palette.SOUL if playable else Palette.BONE_FAINT)


static func rarity_colour(rarity: String) -> Color:
	match rarity:
		"rare":
			return Palette.PREPARED
		"uncommon":
			return Palette.SOUL
		_:
			return Palette.STONE_EDGE


func set_selected(on: bool) -> void:
	if selected == on:
		return
	selected = on
	queue_redraw()
	if _name != null:
		# Repaint through the same path bind() uses so the two cannot drift.
		var edge := Palette.SOUL if selected else Palette.STONE_EDGE
		add_theme_stylebox_override("panel", UiTheme.panel_box(
			Palette.STONE_RAISED if playable else Palette.STONE, edge))


func press() -> void:
	pressed.emit(hand_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			press()
