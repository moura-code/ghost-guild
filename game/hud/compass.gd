class_name Compass
extends Control
## A strip across the top with a mark for every room that still wants
## something from you, placed by bearing.
##
## This is the fix for the single worst thing about playing the game: a 24x24
## grid, three rooms, and no way to know where any of them were. You wandered
## near-identical corridors hoping to bump into a glow. A crawler is allowed to
## make you walk; it is not allowed to make you guess.
##
## The optional minimap complements bearings with the floor schematic.

const HEIGHT := 16.0
const TOP := 8.0
## How much of the world the strip spans, in degrees. Wider than the camera's
## FOV so a room just off-screen still shows near the edge rather than popping.
const SPAN_DEGREES := 150.0
const MARK_WIDTH := 9.0
## Marks further than this are drawn at their faintest.
const FAR := 40.0

## `{"at": Vector3, "kind": String, "done": bool}` -- kind is "encounter",
## "stairs" or "ghost".
var marks: Array = []

var _origin: Vector3 = Vector3.ZERO
var _yaw: float = 0.0


## Where a target sits on the strip: 0 is dead ahead, -1 and +1 are the edges,
## and anything beyond is pinned to the edge so a room behind you still tells
## you which way to turn. Pure, because "which way is that room" is the one
## piece of maths in this file that can actually be wrong.
static func bearing_offset(from: Vector3, yaw: float, to: Vector3) -> float:
	var delta := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if delta.length_squared() < 0.0001:
		return 0.0
	# Godot yaw: 0 looks down -Z, and turning left is positive.
	var facing := -yaw
	var target := atan2(delta.x, -delta.z)
	var relative := wrapf(target - facing, -PI, PI)
	return clampf(relative / deg_to_rad(SPAN_DEGREES * 0.5), -1.0, 1.0)


## True when the target is outside the strip's span and its mark is therefore
## pinned to an edge rather than sitting where it really is.
static func is_pinned(from: Vector3, yaw: float, to: Vector3) -> bool:
	return absf(bearing_offset(from, yaw, to)) >= 0.999


static func colour_for(kind: String) -> Color:
	match kind:
		"marker":
			return Palette.LANTERN
		"stairs":
			return Palette.SOUL
		"ghost":
			return Color(0.55, 0.78, 0.95)
		_:
			return RoomPresentation.accent(kind)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = TOP
	offset_bottom = TOP + HEIGHT


## Called every frame with where the player is and which way they are looking.
func look(from: Vector3, yaw: float) -> void:
	_origin = from
	_yaw = yaw
	queue_redraw()


func set_marks(next: Array) -> void:
	marks = next
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0:
		return
	var middle := size.y * 0.5
	# The rule itself: faint, so it reads as an instrument rather than as a
	# banner across the top of the screen.
	var rule := Palette.BONE_DIM
	rule.a = 0.18
	draw_line(Vector2(size.x * 0.16, middle), Vector2(size.x * 0.84, middle), rule, 1.0)

	for raw in marks:
		var mark: Dictionary = raw
		var at: Vector3 = mark.get("at", Vector3.ZERO)
		var offset := bearing_offset(_origin, _yaw, at)
		var x := size.x * 0.5 + offset * size.x * 0.34
		var far := clampf(_origin.distance_to(at) / FAR, 0.0, 1.0)
		var tint := colour_for(String(mark.get("kind", "encounter")))
		# Near rooms are solid, far ones ghost out. Distance is the other half
		# of "where do I go" and a flat mark throws it away.
		tint.a = lerpf(0.95, 0.35, far)
		if is_pinned(_origin, _yaw, at):
			# Behind you: a chevron at the edge pointing the way round.
			var dir := signf(offset)
			var tip := Vector2(x + dir * MARK_WIDTH * 0.5, middle)
			draw_colored_polygon(PackedVector2Array([
				tip,
				Vector2(x - dir * MARK_WIDTH * 0.5, middle - MARK_WIDTH * 0.45),
				Vector2(x - dir * MARK_WIDTH * 0.5, middle + MARK_WIDTH * 0.45),
			]), tint)
			continue
		var texture := RoomPresentation.icon(String(mark.get("kind", "fight"))) if RoomPresentation.KINDS.has(mark.get("kind")) else null
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2(x - 6, middle - 6), Vector2(12, 12)), false, tint)
			continue
		var half := MARK_WIDTH * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, middle + half),
			Vector2(x - half, middle - half),
			Vector2(x + half, middle - half),
		]), tint)
