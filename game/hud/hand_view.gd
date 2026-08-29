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
const FAN_SPREAD := 1.02
const FAN_LIFT := 6.0
## How far the bottom of the cards sits above the bottom of the area.
const BOTTOM := 34.0

var content: Content
var views: Array[CardView] = []
var selected: int = -1


## One seat per card: `{"position": Vector2, "angle": float}`, in the order the
## hand is held. Each card tilts a little further from vertical and hangs a
## little lower the further it is from the middle, which is what a hand of
## cards actually looks like.
static func fan(count: int, area: Rect2) -> Array:
	var out: Array = []
	if count <= 0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return out
	var card := CardView.CARD_SIZE
	# Never closer than the card's own text allows. A tighter floor lets the
	# card in front eat the rules text of the one behind it, so a five-card
	# hand cannot be read without hovering each card in turn.
	var step := clampf((area.size.x - card.x) / maxf(1.0, float(count - 1)),
		CardView.text_safe_step(), card.x * FAN_SPREAD)
	var half_span := float(count - 1) * 0.5 * step
	# The minimum step can make the hand wider than the area at small window
	# sizes. Push the centre right until the leftmost card clears the edge:
	# readable cards matter more than a hand that is exactly centred.
	var centre := maxf(area.position.x + area.size.x * 0.5, area.position.x + half_span + card.x * 0.5)
	var base_y := area.end.y - card.y - BOTTOM
	for i in count:
		var offset := float(i) - float(count - 1) * 0.5
		var lift := absf(offset) * absf(offset) * FAN_LIFT * 0.5
		out.append({
			"position": Vector2(centre + offset * step - card.x * 0.5, base_y + lift),
			"angle": offset * FAN_ARC,
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
	while views.size() < fight.hand.size():
		var view := CardView.new()
		view.pressed.connect(_on_pressed)
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
		views[i].size = CardView.CARD_SIZE
		views[i].bind(content, fight.hand[i], i, playable.has(i))
		views[i].set_selected(i == selected)
	var seats := fan(fight.hand.size(), hand_area())
	for i in seats.size():
		var seat: Dictionary = seats[i]
		views[i].place(seat["position"], float(seat["angle"]))


## The corridor the hand lives in: clear of the vitals bottom-left and the end
## turn button bottom-right. Computed rather than assumed, because a fan
## centred on the whole screen runs straight over both.
func hand_area() -> Rect2:
	return Rect2(Vector2(LEFT_GUTTER, 0.0), Vector2(maxf(CardView.CARD_SIZE.x, size.x - LEFT_GUTTER - RIGHT_GUTTER), size.y))


const LEFT_GUTTER := 60.0
const RIGHT_GUTTER := 74.0


func select(index: int) -> void:
	selected = index
	for i in views.size():
		views[i].set_selected(i == index)


func clear() -> void:
	select(-1)
	for v in views:
		v.visible = false


func _on_pressed(hand_index: int) -> void:
	card_pressed.emit(hand_index)
