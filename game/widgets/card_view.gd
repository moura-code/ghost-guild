class_name CardView
extends PanelContainer
## One card in the hand (spec §9): cost bubble, art slot, name, text, rarity
## edge.
##
## The art slot holds the card-type icon today and is sized to the aspect a
## real illustration would use, so the frame already shows an artist exactly
## where art goes and how much room it has. Drop a texture in and the icon
## steps aside.
##
## A widget: it renders what bind() gives it and reports the click. Headless
## tests call press() directly, because Godot does not deliver synthetic
## InputEvents in headless mode.

signal pressed(hand_index: int)

const CARD_SIZE := Vector2(146.0, 208.0)
const ART_SIZE := Vector2(122.0, 74.0)
const HOVER_LIFT := 14.0
const HOVER_SCALE := 1.06
const FLY_SECONDS := 0.28

var hand_index: int = -1
var playable: bool = true
var selected: bool = false

var _cost: Label
var _name: Label
var _text: Label
var _type_icon: TextureRect
var _art: PanelContainer
var _art_image: TextureRect
var _rest_y: float = 0.0
var _rest_position: Vector2 = Vector2.ZERO
var _rest_rotation: float = 0.0
var _hover_tween: Tween


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

	# The art slot. Empty by design until there is art -- it is the brief.
	_art = PanelContainer.new()
	_art.custom_minimum_size = ART_SIZE
	_art.add_theme_stylebox_override("panel", UiTheme.fill_box(Palette.STONE))
	_art_image = TextureRect.new()
	_art_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_image.modulate = Palette.BONE_FAINT
	_art_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_art_image)
	box.add_child(_art)

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
	rotation = 0.0
	modulate.a = 1.0
	scale = Vector2.ONE
	z_index = 0
	var def: CardDef = content.cards[card.def_id]
	var cost := def.cost_for(card.upgraded)
	_cost.text = content.text("ui.card.cost_x") if cost == CardDef.COST_X else str(cost)
	_name.text = content.text(def.name_key)
	if card.upgraded:
		_name.text += content.text("ui.upgraded")
	_text.text = content.text(def.text_key)
	_type_icon.texture = Icons.card_type(def.type)
	# Real card art would load here; until then the type icon stands in it,
	# at the size and aspect the illustration will occupy.
	_art_image.texture = Icons.card_art(card.def_id, def.type)
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
	var raise := entered and playable
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "position:y", _rest_y - (HOVER_LIFT if raise else 0.0), 0.10) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale",
		Vector2.ONE * (HOVER_SCALE if raise else 1.0), 0.10) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# A raised card must draw over its neighbours, or the fan clips it.
	z_index = 10 if raise else 0


## Flies in from the draw pile to the place the fan gave it. Cosmetic: the
## card is already in hand as far as the engine is concerned.
func fly_in(from: Vector2, delay: float) -> void:
	if not is_inside_tree():
		return
	var to := _rest_position
	position = from
	rotation = -0.5
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(self, "position", to, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", _rest_rotation, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


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


## Where the fan put this card. Hover returns here, so the two cannot fight
## over the same property.
func place(at: Vector2, angle: float) -> void:
	_rest_position = at
	_rest_rotation = angle
	_rest_y = at.y
	position = at
	rotation = angle


func press() -> void:
	pressed.emit(hand_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			press()
