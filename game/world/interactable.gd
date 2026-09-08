class_name Interactable
extends Area3D
## Something you walk up to and press E on. One type for the whole game: the
## guild's table, circle, desk and ladder are all this, and so is anything
## added later.
##
## It reports focus and use. It never acts -- whoever built it decides what
## pressing E means, exactly as EncounterMarker only ever reports an index.

signal focused(id: String)
signal blurred(id: String)
signal used(id: String)

## Layer 3 of the project's physics layers, as a bit value. Same layer the
## encounter markers use: both are "things in the world you can reach".
const LAYER_INTERACTABLE := 4
const REACH := 1.9

var id: String = ""
## The string key of the line shown while you are standing in it.
var label_key: String = ""
var focus: bool = false


static func create(p_id: String, at: Vector3, p_label_key: String, reach: float = REACH) -> Interactable:
	var it := Interactable.new()
	it.name = "Use_" + p_id
	it.id = p_id
	it.label_key = p_label_key
	it.position = at
	it.collision_layer = LAYER_INTERACTABLE
	it.collision_mask = Player.LAYER_PLAYER

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = reach
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.9, 0.0)
	it.add_child(shape)

	it.body_entered.connect(it.enter)
	it.body_exited.connect(it.leave)
	return it


## Split from the signal handlers so the suite can exercise them without a
## physics step: an Area3D reports overlaps on its own schedule, and a test
## that waits for one is a test that fails on a slow machine.
func enter(_body: Node3D) -> void:
	if focus:
		return
	focus = true
	focused.emit(id)


func leave(_body: Node3D) -> void:
	if not focus:
		return
	focus = false
	blurred.emit(id)


## Pressing E anywhere else in the world does nothing. You have to be standing
## in it, which is what makes the guild a place you walk around rather than a
## menu with a 3D background.
func use() -> void:
	if focus:
		used.emit(id)
