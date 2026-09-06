class_name HandView
extends Control
## The hand of cards, fanned along the bottom of the screen over the live 3D
## room. Cards stay 2D on purpose: a card rendered in perspective is a card
## you cannot read (spec §3.2).
##
## `fan` is a pure function of a count and the rectangle the hand may live in.
## The 2D fight screen computed the same arc inline off node sizes mid-layout,
## which meant it could only ever be checked by looking at it.

signal card_pressed(hand_index: int)

const FAN_ARC := 0.048
## How far apart cards may sit, as a multiple of a card's width. Was 1.02,
## which capped the step at the card's own width and left a five-card hand
## touching edge to edge -- unreadable at rest, however good the hover is.
const FAN_SPREAD := 1.32
const FAN_LIFT := 6.0
## How far the bottom of the cards sits above the bottom of the area.
const BOTTOM := 6.0
## Cards were authored for a screen they owned. Over a live 3D room they have
## to leave the room visible: at full size a five-card hand hides the enemies
## completely, which is the fight covering up the fight. You read a card by
## pointing at it now, not by having all five permanently legible.
const CARD_SCALE := 0.78
const HOVER_SCALE := 1.22
const HOVER_LIFT := 26.0
const HOVER_SECONDS := 0.12

var content: Content
var views: Array[CardView] = []
var selected: int = -1
## The card under the pointer, or -1. A shrunk hand is a hand you read one
## card at a time.
var hovered: int = -1

var _seats: Array = []
var _hover_tweens: Dictionary = {}


## One seat per card: `{"position": Vector2, "angle": float}`, in the order the
## hand is held. Each card tilts a little further from vertical and hangs a
## little lower the further it is from the middle, which is what a hand of
## cards actually looks like.
## The size a card actually occupies on screen at rest.
static func card_size() -> Vector2:
	return CardView.CARD_SIZE * CARD_SCALE


static func fan(count: int, area: Rect2) -> Array:
	var out: Array = []
	if count <= 0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return out
	var card := card_size()
	var edge := float(count - 1) * 0.5
	var max_angle := minf(edge * FAN_ARC, 0.13)
	# Include the rotated corners when fitting the fan. Large hands may
	# overlap; every card must remain reachable inside the viewport.
	var pad_x := (sin(max_angle) * card.y + cos(max_angle) * card.x - card.x) * 0.5 + 2.0
	var pad_y := (sin(max_angle) * card.x + cos(max_angle) * card.y - card.y) * 0.5
	var step := minf(maxf(0.0, area.size.x - card.x - pad_x * 2.0) / maxf(1.0, float(count - 1)),
		card.x * FAN_SPREAD)
	var centre := area.position.x + area.size.x * 0.5
	var deepest := minf(edge * edge * FAN_LIFT * 0.5, 12.0)
	var base_y := area.end.y - card.y - BOTTOM - deepest - pad_y
	for i in count:
		var offset := float(i) - edge
		var fraction := offset / maxf(1.0, edge)
		out.append({
			"position": Vector2(centre + offset * step - card.x * 0.5, base_y + fraction * fraction * deepest),
			"angle": fraction * max_angle,
		})
	return out


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func bind(c: Content) -> void:
	content = c


func visible_count() -> int:
	var n := 0
	for v in views:
		if v.visible:
			n += 1
	return n


## `playable` is keyed by hand index, as the fight screen's map was, so an
## unplayable card is dimmed rather than missing -- you should be able to see
## what you cannot afford.
func show_hand(fight: FightState, playable: Dictionary) -> void:
	_cancel_hover_tweens()
	if hovered >= fight.hand.size():
		hovered = -1
	while views.size() < fight.hand.size():
		var view := CardView.new()
		view.managed_hover = true
		var slot := views.size()
		view.pressed.connect(_on_pressed)
		view.mouse_entered.connect(func() -> void: hover(slot))
		view.mouse_exited.connect(func() -> void: if hovered == slot: hover(-1))
		add_child(view)
		views.append(view)
	# Views are hidden, never destroyed. A hand's size changes every turn, and
	# churning card nodes each draw throws away the hover state and the fly-in
	# tween along with them.
	for i in views.size():
		var used := i < fight.hand.size()
		views[i].visible = used
		if not used:
			continue
		move_child(views[i], i)
		views[i].size = CardView.CARD_SIZE
		views[i].pivot_offset = CardView.CARD_SIZE * 0.5
		views[i].scale = Vector2.ONE * CARD_SCALE
		views[i].bind(content, fight.hand[i], i, playable.has(i))
		views[i].set_selected(i == selected)
	_seats = fan(fight.hand.size(), hand_area())
	for i in _seats.size():
		var seat: Dictionary = _seats[i]
		# The seat is where the card's top-left corner goes at rest. Scale is
		# applied about the centre, so the visual position has to be corrected
		# back by the half-size the scale removed.
		views[i].place(seat["position"] - CardView.CARD_SIZE * (1.0 - CARD_SCALE) * 0.5, float(seat["angle"]))
	_raise(hovered)


## The corridor the hand lives in: clear of the vitals bottom-left and the end
## turn button bottom-right. Computed rather than assumed, because a fan
## centred on the whole screen runs straight over both.
func hand_area() -> Rect2:
	return Rect2(Vector2(LEFT_GUTTER, 0.0), Vector2(maxf(CardView.CARD_SIZE.x, size.x - LEFT_GUTTER - RIGHT_GUTTER), size.y))


## Measured from the widgets that actually sit there, not guessed. A guessed
## 60 put the vitals plate straight over the first card.
const LEFT_GUTTER := HeroPanel.PANEL_SIZE.x + 24.0
const RIGHT_GUTTER := 84.0


## The hovered card grows and lifts clear of its neighbours, and it is drawn
## last so nothing overlaps it.
func hover(index: int) -> void:
	if index < 0 or index >= visible_count():
		index = -1
	if hovered == index:
		return
	hovered = index
	_raise(index)


func _raise(index: int) -> void:
	# Restore the fan order before lifting one card; the last hovered card
	# must not keep covering its neighbours after the pointer leaves it.
	for i in views.size():
		move_child(views[i], i)
	for i in views.size():
		if not views[i].visible or i >= _seats.size():
			continue
		var seat: Dictionary = _seats[i]
		var lifted := i == index
		var to_scale := Vector2.ONE * (CARD_SCALE * HOVER_SCALE if lifted else CARD_SCALE)
		var rest: Vector2 = seat["position"] - CardView.CARD_SIZE * (1.0 - CARD_SCALE) * 0.5
		var to_pos := rest - Vector2(0.0, HOVER_LIFT if lifted else 0.0)
		if lifted:
			move_child(views[i], get_child_count() - 1)
		if not is_inside_tree():
			views[i].scale = to_scale
			views[i].position = to_pos
			views[i].rotation = 0.0 if lifted else float(seat["angle"])
			continue
		var previous: Tween = _hover_tweens.get(i)
		if previous != null and previous.is_valid():
			previous.kill()
		var tween := create_tween()
		_hover_tweens[i] = tween
		tween.set_parallel(true)
		tween.tween_property(views[i], "scale", to_scale, HOVER_SECONDS)
		tween.tween_property(views[i], "position", to_pos, HOVER_SECONDS)
		tween.tween_property(views[i], "rotation", 0.0 if lifted else float(seat["angle"]), HOVER_SECONDS)


func select(index: int) -> void:
	selected = index
	for i in views.size():
		views[i].set_selected(i == index)


func clear() -> void:
	_cancel_hover_tweens()
	select(-1)
	hovered = -1
	for v in views:
		v.visible = false


func _cancel_hover_tweens() -> void:
	for tween: Tween in _hover_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_hover_tweens.clear()


func _on_pressed(hand_index: int) -> void:
	card_pressed.emit(hand_index)
