class_name TowerView
extends Control
## The tower in cross-section (spec §9) — the game's signature image.
##
## The previous version was a VBoxContainer of FloorRows, which is to say a
## table: ten identical horizontal bars with a number at the left. It never
## read as a place, and nothing about it said "down".
##
## This draws the whole shaft as one thing instead: chambers cut into rock,
## narrowing as they descend so the shaft has perspective, each with a floor
## slab the ghosts stand on and walls between them. Light falls from the top
## and dies with depth. The floor you may descend to is lit; everything
## below it is unexcavated rock.
##
## Ghosts are real child nodes rather than drawn, because they bob and need
## their own colours; everything else is one _draw call.

signal floor_clicked(floor: int)

const TOP_INSET := 0.10
const BOTTOM_INSET := 0.30
const WALL := 3.0
const SLAB := 3.0
const MAX_MARKS := 8
## Fixed gutters either side of the shaft for the floor number and the rate.
const NUMBER_COLUMN := 52.0
const RATE_COLUMN := 96.0

var floors: int = 10
var hovered: int = 0
var _time: float = 0.0

var _campaign: Campaign
var _rows: Array = []
var _marks: Dictionary = {}
var _numbers: Dictionary = {}
var _rates: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560.0, 380.0)


func bind(campaign: Campaign) -> void:
	_campaign = campaign
	floors = campaign.biome().last_floor
	_rebuild()
	# The container may not have sized this yet, in which case _layout has
	# nothing to work with; run it again once it has.
	_layout.call_deferred()
	queue_redraw()


## How tall one chamber is.
func chamber_height() -> float:
	return size.y / float(maxi(1, floors))


## The chamber for a floor, in local coordinates. Narrowing with depth is
## what makes it read as a shaft going away from the viewer rather than a
## list going down a page.
func chamber_rect(floor: int) -> Rect2:
	var h := chamber_height()
	var t := float(floor - 1) / float(maxi(1, floors - 1))
	# The shaft lives between the two gutters, and tapers inside that.
	var left := NUMBER_COLUMN
	var right := size.x - RATE_COLUMN
	var span := maxf(0.0, right - left)
	var inset := lerpf(span * TOP_INSET, span * BOTTOM_INSET, t) * 0.5
	return Rect2(Vector2(left + inset, float(floor - 1) * h),
		Vector2(maxf(0.0, span - inset * 2.0), h))


## Light from the surface, dying with depth.
func light_at(floor: int) -> float:
	var t := float(floor - 1) / float(maxi(1, floors - 1))
	return lerpf(1.0, 0.16, t * t)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_marks.clear()
	_numbers.clear()
	_rates.clear()
	if _campaign == null:
		return
	for floor in range(1, floors + 1):
		var number := UiTheme.number(str(floor), Palette.BONE_DIM)
		add_child(number)
		_numbers[floor] = number
		var rate := UiTheme.small("", Palette.SOUL)
		add_child(rate)
		_rates[floor] = rate
		var row: Array[GhostMark] = []
		for ghost in _campaign.ladder.on_floor(floor).slice(0, MAX_MARKS):
			var mark := GhostMark.new()
			mark.bind(ghost)
			add_child(mark)
			row.append(mark)
		_marks[floor] = row
	_layout()


## The shaft breathes. A floor earning 52/h looked exactly like a floor
## earning nothing except for the static height of a gradient -- the game's
## signature image, representing its core loop, did not visibly produce
## anything.
func _process(delta: float) -> void:
	if _campaign == null:
		return
	_time += delta
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()


## Ghosts stand on the slab at the bottom of their chamber, and the numbers
## sit outside the shaft so the chamber itself stays clear.
func _layout() -> void:
	if _campaign == null or size.x <= 0.0:
		return
	var bal := _campaign.balance()
	var mods := _campaign.modifiers()
	for floor in range(1, floors + 1):
		var rect := chamber_rect(floor)
		var light := light_at(floor)

		# The numbers hold a fixed column at the left. Letting them follow the
		# taper made them wander diagonally down the screen, which read as a
		# mistake rather than as perspective.
		var number: Label = _numbers[floor]
		number.size = Vector2(NUMBER_COLUMN - 12.0, 24.0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.position = Vector2(0.0, rect.position.y + rect.size.y * 0.5 - 15.0)
		number.add_theme_color_override("font_color",
			Color(Palette.BONE.r, Palette.BONE.g, Palette.BONE.b, 0.25 + light * 0.6))

		var output := _campaign.ladder.floor_output(floor, bal, mods)
		# And the rate holds a column at the right, for the same reason.
		var rate: Label = _rates[floor]
		rate.text = Num.rate(output) if output > 0.0 else ""
		rate.size = Vector2(RATE_COLUMN - 10.0, 18.0)
		rate.position = Vector2(size.x - RATE_COLUMN + 10.0, rect.position.y + rect.size.y * 0.5 - 9.0)

		var marks: Array = _marks[floor]
		var foot := rect.end.y - SLAB
		for i in marks.size():
			var mark: GhostMark = marks[i]
			var span := minf(rect.size.x - 40.0, float(marks.size()) * 30.0)
			var start := rect.position.x + (rect.size.x - span) * 0.5
			mark.size = GhostMark.BASE_SIZE
			mark.position = Vector2(start + float(i) * 30.0, foot - GhostMark.BASE_SIZE.y)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := hovered
		hovered = _floor_at((event as InputEventMouseMotion).position)
		if hovered != was:
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var floor := _floor_at(mb.position)
			if floor > 0:
				floor_clicked.emit(floor)


## Which floor a point falls in, or 0 for none. The negative case matters:
## int() truncates toward zero, so a point above the shaft would otherwise
## come back as floor 1.
func _floor_at(at: Vector2) -> int:
	if size.y <= 0.0 or at.y < 0.0 or at.y >= size.y:
		return 0
	var floor := int(at.y / chamber_height()) + 1
	return floor if floor >= 1 and floor <= floors else 0


func _draw() -> void:
	if _campaign == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var bal := _campaign.balance()
	var mods := _campaign.modifiers()
	var accent := Palette.biome_accent(_campaign.biome_id)
	var waypoint := CampaignEngine.reach(_campaign)

	for floor in range(1, floors + 1):
		var rect := chamber_rect(floor)
		var light := light_at(floor)
		var reachable := floor <= waypoint

		# The rock the chamber is cut into. Translucent, not opaque: the
		# crypt wall behind the whole screen should read through it, so the
		# shaft looks cut into that wall rather than pasted on top of it.
		draw_rect(Rect2(Vector2(NUMBER_COLUMN, rect.position.y),
			Vector2(size.x - NUMBER_COLUMN - RATE_COLUMN, rect.size.y)),
			Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.55))

		# The chamber itself: darker than the rock, lit from above.
		var air := Palette.STONE_RAISED
		var lit := 0.35 + light * 0.65
		draw_rect(rect, Color(air.r * lit, air.g * lit, air.b * lit, 0.92))

		# Its saturation, as light pooling in the chamber rather than a bar.
		var saturation := _campaign.ladder.saturation(floor, bal, mods)
		if saturation > 0.0:
			# Busier floors pulse faster and brighter: the light in the
			# chamber is the Soul being earned.
			var output := _campaign.ladder.floor_output(floor, bal, mods)
			var speed := 1.1 + clampf(output / 400.0, 0.0, 1.6)
			var breath := 0.82 + 0.18 * sin((_time + float(floor) * 0.7) * speed)
			var glow := clampf(saturation, 0.0, 1.0) * breath
			var pool := rect.size.y * 0.7
			for i in 12:
				var t := float(i) / 11.0
				draw_rect(Rect2(Vector2(rect.position.x + 2.0, rect.end.y - SLAB - pool * (1.0 - t)),
					Vector2(rect.size.x - 4.0, pool / 12.0 + 1.0)),
					Color(Palette.GHOST.r, Palette.GHOST.g, Palette.GHOST.b, 0.11 * glow * t))

		# The slab they stand on, and the shadow it throws into the chamber.
		var slab := accent if reachable else Palette.STONE_EDGE
		draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - SLAB), Vector2(rect.size.x, SLAB)),
			Color(slab.r, slab.g, slab.b, 0.20 + light * 0.55))

		# Walls, catching the light on their inner faces.
		var wall_light := Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g,
			Palette.EDGE_LIGHT.b, 0.10 + light * 0.35)
		draw_rect(Rect2(rect.position, Vector2(WALL, rect.size.y)), wall_light)
		draw_rect(Rect2(Vector2(rect.end.x - WALL, rect.position.y), Vector2(WALL, rect.size.y)),
			wall_light)

		# Unexcavated: below your reach the shaft has not been opened.
		if not reachable:
			draw_rect(rect, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.55))

		if floor == hovered:
			draw_rect(rect, Color(Palette.SOUL.r, Palette.SOUL.g, Palette.SOUL.b, 0.05))

		# The frontier: the deepest floor you may descend to.
		if floor == waypoint:
			draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - SLAB - 1.0),
				Vector2(rect.size.x, 1.0)), Palette.SOUL)
