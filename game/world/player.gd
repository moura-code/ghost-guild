class_name Player
extends CharacterBody3D
## The hero's body in the crypt: walk, look, and carry the light.
##
## It reports where it is and nothing else. Nothing here writes to RunState;
## the only channel from the world to the simulation is Crawl calling
## GameRoot.run_action (spec §4).
##
## The movement maths are static so they can be tested without a window --
## the suite runs headless and cannot press a key, so the parts worth
## asserting are pulled out of the frame loop.

const LAYER_PLAYER := 2
const SPEED := 3.6
const SPRINT := 6.0
## High acceleration on purpose. A crawler wants a body that answers
## instantly; momentum is for vehicles.
const ACCEL := 14.0
const GRAVITY := 20.0
const EYE := 1.62
const RADIUS := 0.35
const HEIGHT := 1.75
const SENSITIVITY := 0.0022
## Just short of straight up, so the horizon never flips.
const PITCH_LIMIT := 1.45

var head: Node3D
var camera: Camera3D
var torch: OmniLight3D
## Off while a fight or a menu owns the mouse.
var look_enabled: bool = true
## Frozen in place while a fight is staged or a panel is open. Gravity still
## applies -- a frozen body should stand on the floor, not hang in the air --
## so this zeroes the wish vector rather than the whole physics step.
var frozen: bool = false
## Set from Settings. Multiplies the authored SENSITIVITY.
var sensitivity_scale: float = 1.0
var invert_y: bool = false

var _pitch: float = 0.0


static func wish_direction(input: Vector2, yaw: float) -> Vector3:
	var v := Vector3(input.x, 0.0, input.y)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v.rotated(Vector3.UP, yaw)


static func clamp_pitch(pitch: float) -> float:
	return clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = DungeonBuilder.LAYER_WORLD

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, EYE, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 72.0
	camera.current = true
	head.add_child(camera)

	# The reach of your own torch is the difficulty made physical (spec §2.3),
	# so the hero carries one and it is deliberately short.
	torch = OmniLight3D.new()
	torch.name = "Torch"
	torch.light_color = Color(1.0, 0.70, 0.38)
	# Strong enough that the ground at your feet is warm. With the cold fill
	# raised, a weak hero torch left everything within arm's reach blue -- the
	# one place the player's own light should be winning.
	torch.light_energy = 4.4
	torch.omni_range = Kit.CELL * 3.4
	torch.omni_attenuation = 1.5
	torch.position = Vector3(0.25, -0.15, 0.0)
	head.add_child(torch)

	capture_mouse(true)


func capture_mouse(on: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func place_at(at: Vector3, yaw: float) -> void:
	position = at
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch = 0.0
	if head != null:
		head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func read_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))


func _physics_process(delta: float) -> void:
	var speed := SPRINT if Input.is_action_pressed("sprint") else SPEED
	var wish := Vector3.ZERO if frozen else wish_direction(read_input(), rotation.y) * speed
	velocity.x = move_toward(velocity.x, wish.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, wish.z, ACCEL * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and look_enabled and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var speed := SENSITIVITY * sensitivity_scale
		rotate_y(-motion.relative.x * speed)
		var dy := motion.relative.y * speed
		_pitch = clamp_pitch(_pitch + (dy if invert_y else -dy))
		head.rotation.x = _pitch
		return
	# Escape gives the mouse back rather than quitting: a captured cursor with
	# no way out is the fastest way to make a build feel broken.
	#
	# Not while frozen, though. _unhandled_input reaches children before
	# parents, so a body that grabbed Escape here would recapture the cursor
	# before Crawl ever saw the key -- and a panel you cannot click is worse
	# than a cursor you cannot free.
	if event.is_action_pressed("ui_cancel") and not frozen:
		capture_mouse(Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED)
