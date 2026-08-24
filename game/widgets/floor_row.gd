class_name FloorRow
extends Control
## One floor of the tower cross-section (spec §9): a biome colour band, the
## floor number, the saturation fill, the ghosts standing in it, and what the
## floor pays per hour. A widget -- it takes data through bind() and never
## touches Game.

const ROW_HEIGHT := 41.0
const BAND_WIDTH := 5.0
const NUMBER_WIDTH := 34.0
const RIGHT_WIDTH := 116.0
const GAP := 8.0
const MAX_MARKS := 12
## The tower recedes: deeper rows are indented and dimmer, so ten floors
## read as a descent rather than as a list.
const DEPTH_INDENT := 8.0
const DEPTH_DIM := 0.62

var floor_number: int = 1
var saturation: float = 0.0
var output_per_hour: float = 0.0
var is_waypoint: bool = false
var accent: Color = Palette.BONE_DIM

var _marks: HBoxContainer
var _number: Label
var _output: Label
var _farmed: Label
var _overflow: Label


func _init() -> void:
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	_number = UiTheme.body("1", Palette.BONE_DIM)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_number.custom_minimum_size = Vector2(NUMBER_WIDTH, 0.0)
	_number.position = Vector2(BAND_WIDTH + GAP, 10.0)
	add_child(_number)

	_marks = HBoxContainer.new()
	_marks.add_theme_constant_override("separation", 5)
	_marks.position = Vector2(BAND_WIDTH + GAP + NUMBER_WIDTH + GAP, 4.0)
	add_child(_marks)

	_overflow = UiTheme.small("", Palette.BONE_FAINT)
	add_child(_overflow)

	_output = UiTheme.body("", Palette.SOUL)
	_output.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_output.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	add_child(_output)

	_farmed = UiTheme.small("", Palette.BONE_FAINT)
	_farmed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_farmed.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	add_child(_farmed)


func bind(campaign: Campaign, p_floor: int) -> void:
	var bal := campaign.balance()
	var mods := campaign.modifiers()
	floor_number = p_floor
	saturation = campaign.ladder.saturation(p_floor, bal, mods)
	output_per_hour = campaign.ladder.floor_output(p_floor, bal, mods)
	is_waypoint = campaign.ladder.waypoint() == p_floor
	accent = Palette.biome_accent(campaign.biome_id)

	_number.text = str(p_floor)
	_number.add_theme_color_override("font_color", Palette.BONE if is_waypoint else Palette.BONE_DIM)
	_output.text = Num.rate(output_per_hour) if output_per_hour > 0.0 else ""
	var farmed_word := campaign.content.text("ui.farmed")
	_farmed.text = "%s %s" % [Num.percent(saturation), farmed_word] if saturation > 0.0 else ""

	_refresh_tooltip(campaign, p_floor, bal, mods)

	var ghosts := campaign.ladder.on_floor(p_floor)
	_rebuild_marks(ghosts)
	queue_redraw()


## Saturation is the least self-explanatory number on the screen, so the row
## spells it out: what the floor spawns, and what this player's dead take.
func _refresh_tooltip(campaign: Campaign, p_floor: int, bal: Dictionary, mods: Dictionary) -> void:
	var spawn := Ladder.spawn_rate(p_floor, bal) * float(mods.get("global_spawn", 1.0))
	var strength := campaign.ladder.floor_strength(p_floor, bal, mods)
	var key := "ui.tip.floor" if strength > 0.0 else "ui.tip.floor_empty"
	tooltip_text = campaign.content.text(key) 		.replace("{floor}", str(p_floor)) 		.replace("{spawn}", Num.short(spawn)) 		.replace("{taken}", Num.short(minf(strength, spawn)))


func _rebuild_marks(ghosts: Array[Ghost]) -> void:
	for child in _marks.get_children():
		_marks.remove_child(child)
		child.queue_free()
	var shown := mini(ghosts.size(), MAX_MARKS)
	for i in range(shown):
		var m := GhostMark.new()
		m.bind(ghosts[i])
		_marks.add_child(m)
	var hidden := ghosts.size() - shown
	_overflow.text = "+%d" % hidden if hidden > 0 else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if _output == null:
		return
	# Inset by the same margin the fill uses, or the numbers sit on the edge.
	var right_x := size.x - RIGHT_WIDTH - GAP * 2.0
	_output.position = Vector2(right_x, 5.0)
	_farmed.position = Vector2(right_x, 23.0)
	_overflow.position = Vector2(_marks.position.x + _marks.size.x + GAP, 11.0)


## A floor is a niche cut into rock, not a table row. Four things make that
## read without any art: a recessed dark interior, a lit lip along the top
## where light from above catches the cut, a shadow under it, and a
## saturation glow that fades rather than ending in a hard edge.
func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var recede := clampf(float(floor_number - 1) / 9.0, 0.0, 1.0)
	var inset := recede * DEPTH_INDENT
	# Deeper floors are darker: the shaft goes down into the dark.
	var dim := 1.0 - recede * DEPTH_DIM
	var w := size.x - inset * 2.0
	var interior := Palette.STONE_RAISED
	draw_rect(Rect2(Vector2(inset, 0.0), Vector2(w, size.y)),
		Color(interior.r * dim, interior.g * dim, interior.b * dim, 1.0))

	# The cut lip along the top, and the shadow it throws down the wall.
	draw_rect(Rect2(Vector2(inset, 0.0), Vector2(w, 1.0)),
		Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b, 0.5 * dim))
	draw_rect(Rect2(Vector2(inset, 1.0), Vector2(w, 3.0)), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(Vector2(inset, 4.0), Vector2(w, 3.0)), Color(0.0, 0.0, 0.0, 0.14))
	draw_rect(Rect2(Vector2(inset, size.y - 1.0), Vector2(w, 1.0)), Color(0.0, 0.0, 0.0, 0.55))

	# The biome marker down the left edge, brightest where a ghost stands.
	var band_alpha := 0.85 if output_per_hour > 0.0 else 0.30
	draw_rect(Rect2(Vector2(inset, 0.0), Vector2(BAND_WIDTH, size.y)),
		Color(accent.r, accent.g, accent.b, band_alpha * dim))

	if output_per_hour <= 0.0:
		_draw_unclaimed(inset, w)
	else:
		_draw_saturation(inset, w)

	# The waypoint is a boundary, not a marker: the deepest floor a hero may
	# descend to gets the full lit edge.
	if is_waypoint:
		draw_rect(Rect2(Vector2(inset, size.y - 2.0), Vector2(w, 2.0)), Palette.SOUL)


## Nothing of yours stands here. A row of dashes reads as an empty seam in
## the rock rather than as a row whose data failed to load.
func _draw_unclaimed(inset: float, w: float) -> void:
	var start := inset + BAND_WIDTH + GAP + NUMBER_WIDTH + GAP
	var span := maxf(0.0, size.x - start - RIGHT_WIDTH - GAP * 2.0)
	var y := size.y * 0.5
	var dash := 7.0
	var step := dash * 2.6
	var count := int(span / step)
	for i in count:
		draw_rect(Rect2(Vector2(start + float(i) * step, y), Vector2(dash, 1.0)),
			Color(Palette.BONE_FAINT.r, Palette.BONE_FAINT.g, Palette.BONE_FAINT.b, 0.16))


## The gauge behind the ghosts: how much of this floor's spawn the ladder is
## taking. Drawn with a real gradient texture rather than a run of
## translucent rectangles -- overlapping alpha compounds at every seam and
## the result came out visibly striped.
func _draw_saturation(inset: float, w: float) -> void:
	var fill_x := inset + BAND_WIDTH + GAP + NUMBER_WIDTH + GAP
	var fill_w := maxf(0.0, size.x - fill_x - RIGHT_WIDTH - GAP * 2.0)
	if fill_w <= 0.0 or saturation <= 0.0:
		return
	var lit := fill_w * clampf(saturation, 0.0, 1.0)
	draw_texture_rect(_gauge_texture(), Rect2(Vector2(fill_x, 3.0), Vector2(lit, size.y - 7.0)), false)
	if saturation > 1.0:
		# Past the soft cap the floor still pays, at a quarter rate.
		draw_rect(Rect2(Vector2(fill_x + fill_w - 2.0, 3.0), Vector2(2.0, size.y - 7.0)),
			Palette.PREPARED)


## Built once and shared: every row draws the same left-to-right falloff.
static var _gauge: GradientTexture2D = null


static func _gauge_texture() -> GradientTexture2D:
	if _gauge != null:
		return _gauge
	var ramp := Gradient.new()
	ramp.set_color(0, Color(Palette.GHOST.r, Palette.GHOST.g, Palette.GHOST.b, 0.26))
	ramp.set_color(1, Color(Palette.GHOST.r, Palette.GHOST.g, Palette.GHOST.b, 0.03))
	_gauge = GradientTexture2D.new()
	_gauge.gradient = ramp
	_gauge.width = 128
	_gauge.height = 1
	_gauge.fill_from = Vector2(0.0, 0.0)
	_gauge.fill_to = Vector2(1.0, 0.0)
	return _gauge
