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
var _rite: Label
var _dismiss: Button
var _timer: SceneTreeTimer


func _init() -> void:
	_build()


func _build() -> void:
	# Centred and given room. Spec §9 calls this the emotional beat of the
	# game and the opening of the trailer; a left-aligned column of labels
	# would read as a results dialog.
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE, Palette.STONE_EDGE))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
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

	_soul = UiTheme.number("", Palette.SOUL)
	box.add_child(_soul)

	_rite = UiTheme.body("", Palette.PREPARED)
	_rite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_rite)

	_dismiss = Button.new()
	_dismiss.custom_minimum_size = Vector2(220.0, 44.0)
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
	game = g
	result = p_result
	stage = 0

	var ghost := g.campaign.ladder.find(int(p_result.get("ghost_id", 0)))
	_name.text = ghost.name if ghost != null else ""
	_epitaph.text = String(p_result.get("epitaph", ""))
	if ghost != null:
		_mark.bind(ghost)
	_floor.text = g.text("ui.epitaph.stands").replace("{floor}", str(int(p_result.get("floor", 1))))
	_soul.text = "%s %s" % [g.text("ui.epitaph.banked"), Num.short(float(p_result.get("soul", 0.0)))]
	_rite.text = g.text("ui.epitaph.rite") if _has_rite(p_result) else ""
	_dismiss.text = g.text("ui.epitaph.dismiss")

	if paced:
		_show_up_to(0)
		_advance()
	else:
		_show_up_to(stage_count())


## first_death carries the rite that unlocks Take the Watch (spec §3.4).
static func _has_rite(p_result: Dictionary) -> bool:
	for event in p_result.get("rite_events", []):
		if String(event.get("type", "")) == "first_death":
			return true
	return false


func stage_count() -> int:
	return 5 if _has_rite(result) else 4


func _show_up_to(n: int) -> void:
	stage = n
	_name.visible = n >= 1
	_epitaph.visible = n >= 2
	_arrival.visible = n >= 3
	_soul.get_parent().visible = n >= 4
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
