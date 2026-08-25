class_name EpitaphScreen
extends PanelContainer
## The death beat (spec §9): "name, floor, epitaph, the ghost sliding into
## its row, the number starting to tick. The emotional beat of the game —
## give it time and sound. The trailer opens here."
##
## So it is paced deliberately rather than dumped at once: the name, then
## the epitaph, then the ghost arriving, then what it earns you, then — on
## the first death only — the rite that unlocks Take the Watch. The dismiss
## button does not appear until the beat has played, because the whole point
## is that the player sits with it.

signal dismissed()

const STEP_SECONDS := 0.55
const SLIDE_PIXELS := 46.0

## Tests set this false: every stage lands immediately and no tween runs.
var paced: bool = true

var game: GameRoot
var result: Dictionary = {}
var stage: int = 0

var _name: Label
var _epitaph: Label
var _arrival: HBoxContainer
var _mark: GhostMark
var _floor: Label
var _soul: Label
var _banked_caption: Label
var _soul_target: float = 0.0
var _rite: Label
var _dismiss: Button
var _timer: SceneTreeTimer


func _init() -> void:
	_build()


func _build() -> void:
	# Centred and given room. Spec §9 calls this the emotional beat of the
	# game and the opening of the trailer; a left-aligned column of labels
	# would read as a results dialog.
	# Translucent: an opaque panel here meant this screen alone had none of
	# the crypt behind it, and it read as flat black next to every other
	# screen in the game -- on the one screen the spec calls the emotional
	# centre.
	var frame := UiTheme.panel_box(Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.62),
		Color(Palette.STONE_EDGE.r, Palette.STONE_EDGE.g, Palette.STONE_EDGE.b, 0.30))
	add_theme_stylebox_override("panel", frame)
	# Owns the screen rather than sitting in a band at the top: this is the
	# moment the game is about, and it should not share the frame.
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A vigil is held by candlelight, and this screen was 90% empty void with
	# a small column of labels in the middle of it. The candles and the bones
	# give the frame something to be, and the mourners' light comes from
	# somewhere.
	var vigil := HBoxContainer.new()
	vigil.set_anchors_preset(Control.PRESET_FULL_RECT)
	vigil.alignment = BoxContainer.ALIGNMENT_CENTER
	vigil.add_theme_constant_override("separation", 420)
	vigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var stand := VBoxContainer.new()
		stand.alignment = BoxContainer.ALIGNMENT_CENTER
		stand.add_theme_constant_override("separation", 8)
		stand.add_child(Prop.of(Prop.Kind.CANDLE, i * 6 + 2))
		stand.add_child(Prop.of(Prop.Kind.SKULL, i))
		stand.add_child(Prop.of(Prop.Kind.BONES, i * 3))
		vigil.add_child(stand)
	add_child(vigil)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	_name = UiTheme.title("")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)

	_epitaph = UiTheme.body("", Palette.BONE_DIM)
	_epitaph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epitaph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_epitaph)

	_arrival = HBoxContainer.new()
	_arrival.add_theme_constant_override("separation", 12)
	_arrival.alignment = BoxContainer.ALIGNMENT_CENTER
	_mark = GhostMark.new()
	_mark.custom_minimum_size = GhostMark.BASE_SIZE * 2.0
	_arrival.add_child(_mark)
	_floor = UiTheme.body("", Palette.GHOST)
	_floor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arrival.add_child(_floor)
	box.add_child(_arrival)

	# The number, then what it is -- the same shape every other reading in
	# the game uses. Running the caption and the value together on one line
	# made what they brought home read as a sentence rather than a result.
	var banked := VBoxContainer.new()
	banked.add_theme_constant_override("separation", 0)
	banked.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var amount := HBoxContainer.new()
	amount.add_theme_constant_override("separation", 8)
	amount.alignment = BoxContainer.ALIGNMENT_CENTER
	amount.add_child(Icons.make_rect(Icons.ui("soul"), 24.0, Palette.SOUL))
	_soul = UiTheme.number("", Palette.SOUL)
	amount.add_child(_soul)
	banked.add_child(amount)
	_banked_caption = ScreenLayout.centre(UiTheme.small(""))
	banked.add_child(_banked_caption)
	box.add_child(banked)

	_rite = UiTheme.body("", Palette.PREPARED)
	_rite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_rite)

	_dismiss = Button.new()
	_dismiss.custom_minimum_size = Vector2(104.0, 22.0)
	_dismiss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dismiss.pressed.connect(func() -> void: dismissed.emit())
	box.add_child(_dismiss)


## Whether a run ending this way deserves the beat at all. Retreating is not
## a death — nobody is left behind, so there is nothing to memorialise.
static func should_show(p_result: Dictionary) -> bool:
	if p_result.is_empty():
		return false
	return int(p_result.get("ghost_id", 0)) > 0


func bind(g: GameRoot, p_result: Dictionary) -> void:
	if g != null and g.sfx != null:
		# The one sound in the game allowed to take a whole second.
		g.sfx.play("epitaph")
	game = g
	result = p_result
	stage = 0

	var ghost := g.campaign.ladder.find(int(p_result.get("ghost_id", 0)))
	_name.text = ghost.name if ghost != null else ""
	_epitaph.text = String(p_result.get("epitaph", ""))
	if ghost != null:
		_mark.bind(ghost)
	_floor.text = g.text("ui.epitaph.stands").replace("{floor}", str(int(p_result.get("floor", 1))))
	_soul_target = float(p_result.get("soul", 0.0))
	_soul.text = Num.short(0.0)
	_banked_caption.text = g.text("ui.epitaph.banked")
	_rite.text = g.text("ui.epitaph.rite") if _has_rite(p_result) else ""
	_dismiss.text = g.text("ui.epitaph.dismiss")

	if paced:
		_show_up_to(0)
		_advance()
	else:
		_show_up_to(stage_count())


## first_death carries the rite that unlocks Take the Watch (spec §3.4).
## The dead hero, tight. Everything else on this screen is a mourner.
func focus_rect() -> Rect2:
	if _name == null or not _name.is_inside_tree():
		return Rect2()
	var box := _name.get_global_rect()
	return Rect2(box.position - global_position - Vector2(80.0, 30.0),
		box.size + Vector2(160.0, 150.0))


static func _has_rite(p_result: Dictionary) -> bool:
	for event in p_result.get("rite_events", []):
		if String(event.get("type", "")) == "first_death":
			return true
	return false


func stage_count() -> int:
	return 5 if _has_rite(result) else 4


## Each beat fades and rises rather than snapping on. Four of the five
## stages used to simply flip .visible, on the screen the spec calls the
## emotional centre of the game.
func _reveal(node: Control) -> void:
	if node == null or node.visible or not is_inside_tree():
		return
	node.visible = true
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)


## The number counts up from nothing when it arrives. The spec asks for
## exactly this and it was popping in fully formed.
func _tick_soul() -> void:
	if not is_inside_tree():
		_soul.text = Num.short(_soul_target)
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _soul.text = Num.short(v),
		0.0, _soul_target, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_up_to(n: int) -> void:
	var was := stage
	stage = n
	var banked := _soul.get_parent().get_parent() as Control
	if paced and n > was:
		# Arriving: fade each beat in as it lands.
		if n >= 1: _reveal(_name)
		if n >= 2: _reveal(_epitaph)
		if n >= 3: _reveal(_arrival)
		if n >= 4 and not banked.visible:
			_reveal(banked)
			_tick_soul()
		if n >= 5 and _has_rite(result): _reveal(_rite)
		if n >= stage_count(): _reveal(_dismiss)
		return
	_name.visible = n >= 1
	_epitaph.visible = n >= 2
	_arrival.visible = n >= 3
	banked.visible = n >= 4
	if n >= 4:
		_soul.text = Num.short(_soul_target)
	_rite.visible = n >= 5 and _has_rite(result)
	_dismiss.visible = n >= stage_count()


## One stage per beat. The ghost's row slides in rather than appearing,
## because arriving is the thing the player is meant to feel.
func _advance() -> void:
	if stage >= stage_count():
		return
	_show_up_to(stage + 1)
	if stage == 3 and is_inside_tree():
		var to := _arrival.position
		_arrival.position = to + Vector2(-SLIDE_PIXELS, 0.0)
		var tween := create_tween()
		tween.tween_property(_arrival, "position", to, STEP_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if stage < stage_count() and is_inside_tree():
		_timer = get_tree().create_timer(STEP_SECONDS)
		_timer.timeout.connect(_advance)


## Lets an impatient player skip straight to the end of the beat.
func reveal_all() -> void:
	_show_up_to(stage_count())
