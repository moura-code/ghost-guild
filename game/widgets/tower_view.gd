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

const TOP_INSET := 0.04
const BOTTOM_INSET := 0.26
const WALL := 2.0
const SLAB := 2.0
const MAX_MARKS := 8
## Fixed gutters either side of the shaft for the floor number and the rate.
const NUMBER_COLUMN := 14.0
const RATE_COLUMN := 34.0

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
	custom_minimum_size = Vector2(160.0, 200.0)


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
		# Nobody stands inside undug rock.
		var dug := floor <= CampaignEngine.reach(_campaign)
		var foot := rect.end.y - SLAB
		for i in marks.size():
			var mark: GhostMark = marks[i]
			var span := minf(rect.size.x - 40.0, float(marks.size()) * 30.0)
			var start := rect.position.x + (rect.size.x - span) * 0.5
			mark.visible = dug
			# Nearer floors are nearer the viewer. A ghost drawn the same size
			# on floor 1 and floor 10 fights the shaft's perspective and flattens
			# it back into a list.
			var near := 1.0 - float(floor - 1) / float(maxi(1, floors - 1))
			var wanted := GhostMark.BASE_SIZE * lerpf(1.0, 1.7, near)
			# ...but never taller than the room they are standing in. On a
			# 640x360 frame a chamber is about 24 pixels high, and a ghost
			# scaled for depth spilled up through the floor above it.
			var headroom := maxf(8.0, rect.size.y - SLAB - 1.0)
			if wanted.y > headroom:
				wanted *= headroom / wanted.y
			mark.size = wanted
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


## The stone filling an unexcavated floor. This is the tapered chamber, not
## the full gutter-to-gutter rock: filling the gutters made floors 2-10 one
## flat wall of constant width and erased the perspective that is the only
## thing telling the player the shaft goes *down*.
func solid_rect(floor: int) -> Rect2:
	return chamber_rect(floor)


## The colour of undug rock, and of an open chamber's air. Both are pulled
## out of _draw so the rule that matters can be asserted: the floors you
## cannot reach must never outshine the ones you can.
func undug_colour(floor: int) -> Color:
	var solid := 0.34 - float(floor) * 0.022
	return Color(Palette.STONE_HIGH.r * solid, Palette.STONE_HIGH.g * solid,
		Palette.STONE_HIGH.b * solid, 1.0)


func chamber_colour(floor: int) -> Color:
	var air := Palette.STONE_RAISED
	var lit := 0.35 + light_at(floor) * 0.65
	return Color(air.r * lit, air.g * lit, air.b * lit, 0.92)


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

		# The rock the shaft is cut through.
		var rock := Rect2(Vector2(NUMBER_COLUMN, rect.position.y),
			Vector2(size.x - NUMBER_COLUMN - RATE_COLUMN, rect.size.y))
		draw_rect(rock, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.55))

		if not reachable:
			rock = solid_rect(floor)
			# Below your reach the shaft has not been dug: this is the rock
			# it will one day be cut through.
			#
			# It used to be drawn LIGHTER than an open chamber, on the theory
			# that solid stone catches light while a room swallows it. True
			# of a real wall, wrong here: it made undug rock the brightest
			# thing on the game's capsule screen, so the eye went to the nine
			# floors you cannot reach instead of to the one ghost you have.
			# Unreached floors are a promise, not the subject. They recede.
			draw_rect(rock, undug_colour(floor))
			# How lit this rock is, reused to keep the courses in step with it.
			var solid := 0.34 - float(floor) * 0.022
			# Courses, faint. Enough texture that it reads as laid stone
			# rather than as a hole in the screen, not enough to compete.
			var courses := 3
			var course_h := rock.size.y / float(courses)
			for c in courses:
				var y := rock.position.y + course_h * float(c)
				draw_rect(Rect2(Vector2(rock.position.x, y), Vector2(rock.size.x, 1.0)),
					Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b,
						0.10 * solid * 3.0))
				draw_rect(Rect2(Vector2(rock.position.x, y + 1.0), Vector2(rock.size.x, 1.0)),
					Color(0.0, 0.0, 0.0, 0.30))
				var joints := 6
				for j in range(1, joints):
					var offset := 0.5 if c % 2 == 0 else 0.0
					var jx := rock.position.x + rock.size.x * (float(j) + offset) / float(joints)
					if jx >= rock.end.x:
						continue
					draw_rect(Rect2(Vector2(jx, y + 2.0), Vector2(1.0, course_h - 2.0)),
						Color(0.0, 0.0, 0.0, 0.22))
			continue

		# The chamber itself: darker than the rock, lit from above.
		draw_rect(rect, chamber_colour(floor))
		# Its back wall catches the light near the ceiling and falls away.
		for i in 6:
			var t := float(i) / 5.0
			draw_rect(Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y * t / 6.0 * 6.0),
				Vector2(rect.size.x, rect.size.y / 6.0 + 1.0)),
				Color(0.0, 0.0, 0.02, 0.05 + t * 0.16))

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

		# The floor of the room, in perspective.
		#
		# A flat bar across the bottom of a rectangle is a chart axis. A
		# trapezoid narrowing toward the back is a floor you are looking down
		# onto, and it is most of what turns ten stacked rectangles into ten
		# rooms one above another.
		var slab := accent if reachable else Palette.STONE_EDGE
		var back := rect.size.x * 0.14
		var deep_y := rect.end.y - rect.size.y * 0.26
		draw_colored_polygon(PackedVector2Array([
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.end.x, rect.end.y),
			Vector2(rect.end.x - back, deep_y),
			Vector2(rect.position.x + back, deep_y)]),
			Color(slab.r * 0.22, slab.g * 0.22, slab.b * 0.24, 0.55 + light * 0.35))
		# The lit front lip of it, which is what gives the floor an edge to
		# stand on rather than a fade into the wall.
		draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - SLAB), Vector2(rect.size.x, SLAB)),
			Color(slab.r, slab.g, slab.b, 0.20 + light * 0.55))

		# A lantern bracketed to the near wall of every floor you can reach.
		# The ghosts stand in what it throws, and it is the reason there is
		# any light down here at all.
		var flame := 0.82 + 0.18 * sin((_time + float(floor) * 1.9) * 3.3)
		var lamp := Vector2(rect.position.x + WALL + 5.0, rect.position.y + rect.size.y * 0.34)
		for i in 5:
			var t := float(i) / 4.0
			draw_circle(lamp, (4.0 + t * rect.size.y * 0.55) * flame,
				Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b,
					0.055 * (1.0 - t) * (0.35 + light * 0.65) * flame))
		draw_circle(lamp, 2.6 * flame,
			Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, 0.95 * flame))

		# Walls, catching the light on their inner faces.
		var wall_light := Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g,
			Palette.EDGE_LIGHT.b, 0.10 + light * 0.35)
		draw_rect(Rect2(rect.position, Vector2(WALL, rect.size.y)), wall_light)
		draw_rect(Rect2(Vector2(rect.end.x - WALL, rect.position.y), Vector2(WALL, rect.size.y)),
			wall_light)

		if floor == hovered:
			draw_rect(rect, Color(Palette.SOUL.r, Palette.SOUL.g, Palette.SOUL.b, 0.05))

		# The frontier: the deepest floor you may descend to.
		if floor == waypoint:
			draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - SLAB - 1.0),
				Vector2(rect.size.x, 1.0)), Palette.SOUL)
