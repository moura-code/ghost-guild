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
const HOVER_LIFT := 10.0
const FLY_SECONDS := 0.28

var hand_index: int = -1
var playable: bool = true
var selected: bool = false

var _cost: Label
var _name: Label
var _text: Label
var _type_icon: TextureRect
var _rest_y: float = 0.0


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = CARD_SIZE * 0.5
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_build()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_cost = UiTheme.number("", Palette.SOUL)
	head.add_child(_cost)
	_type_icon = Icons.make_rect(null, 20.0, Palette.BONE_DIM)
	_type_icon.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	head.add_child(_type_icon)
	box.add_child(head)

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
	# The container owns layout; remember where it put us so hover can
	# return the card to exactly that spot.
	_rest_y = position.y
	rotation = 0.0
	modulate.a = 1.0
	var def: CardDef = content.cards[card.def_id]
	var cost := def.cost_for(card.upgraded)
	_cost.text = content.text("ui.card.cost_x") if cost == CardDef.COST_X else str(cost)
	_name.text = content.text(def.name_key)
	if card.upgraded:
		_name.text += content.text("ui.upgraded")
	_text.text = content.text(def.text_key)
	_type_icon.texture = Icons.card_type(def.type)
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
	_type_icon.modulate = edge if playable else Palette.BONE_FAINT
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


## A playable card lifts under the cursor; an unaffordable one does not,
## which is a second, wordless way of saying you cannot afford it.
func _on_hover(entered: bool) -> void:
	if not is_inside_tree():
		return
	var lift := -HOVER_LIFT if entered and playable else 0.0
	var tween := create_tween()
	tween.tween_property(self, "position:y", _rest_y + lift, 0.08) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Arcs away toward the discard pile. Purely cosmetic: the engine has
## already resolved the card by the time this plays.
func fly_out(to: Vector2) -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", to, FLY_SECONDS) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", 0.5, FLY_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FLY_SECONDS)


func press() -> void:
	pressed.emit(hand_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			press()
