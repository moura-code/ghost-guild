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

## A foot hit the ground. Numbered from one, for the life of the body.
##
## A signal rather than a call into `Sfx`, because the body has no business
## knowing what a footstep sounds like -- and because it makes "does walking
## actually produce footfalls" answerable in a headless suite with no audio
## server worth speaking of.
signal footfall(index: int)

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
## Below this, in metres per physics frame, you are not walking -- you are
## being nudged by a slide along a wall, and feet that answer that tick while
## you stand still with your face in the stone.
const MOVING := 0.0005
## What the hero's torch burns at with nothing driving it. Strong enough that
## the ground at your feet is warm: with the cold fill raised, a weak hero
## torch left everything within arm's reach blue, which is the one place the
## player's own light should be winning.
const TORCH_ENERGY := 4.4
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
var reduced_motion: bool = false

var _pitch: float = 0.0
## Where in the walk cycle the body is, in footfalls. See `Stride`.
var _stride_phase: float = 0.0
## The bob's weight, eased so that stopping settles the head rather than
## freezing it wherever the last frame left it.
var _bob_amount: float = 0.0
## Counts up for the life of the body. The sound picker rotates variants by
## it, which is what stops thirty footfalls down one corridor reading as one
## sample on a loop.
var _step_index: int = 0
var _torch_t: float = 0.0


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
	torch.light_energy = TORCH_ENERGY
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
	_stride_phase = 0.0
	_bob_amount = 0.0
	if head != null:
		head.rotation = Vector3.ZERO
		# Every descent and every retreat comes through here. A head left
		# mid-dip would put the camera below eye level for a whole floor.
		head.position = Vector3(0.0, EYE, 0.0)
	if camera != null:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func read_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))


## Share the pitch with combat framing so mouse look resumes without a snap.
func set_pitch(value: float) -> void:
	_pitch = clamp_pitch(value)
	if head != null:
		head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var speed := SPRINT if Input.is_action_pressed("sprint") else SPEED
	var wish := Vector3.ZERO if frozen else wish_direction(read_input(), rotation.y) * speed
	velocity.x = 0.0 if frozen else move_toward(velocity.x, wish.x, ACCEL * delta)
	velocity.z = 0.0 if frozen else move_toward(velocity.z, wish.z, ACCEL * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var was := position
	move_and_slide()
	_walk(delta, speed, Vector2(position.x - was.x, position.z - was.z).length())


## The walk cycle, driven by ground actually covered rather than by the clock.
## A body that is accelerating, sliding along a wall or walking into one gets
## less far than its speed says, and a cadence read off the clock keeps
## marching while you stand still with your face in the stone.
func _walk(delta: float, speed: float, travelled: float) -> void:
	var moving := travelled > MOVING and is_on_floor()
	_bob_amount = Stride.ease_amount(_bob_amount, 1.0 if moving else 0.0, delta)
	if moving:
		var next := Stride.advance(_stride_phase, travelled, speed)
		for i in Stride.footfalls(_stride_phase, next):
			_step_index += 1
			footfall.emit(_step_index)
		_stride_phase = next
	if head != null:
		head.position = Vector3(0.0, EYE, 0.0) + (Vector3.ZERO if reduced_motion else Stride.bob_offset(_stride_phase, _bob_amount))


## The torch you are carrying. Driven here rather than by the floor's `Torches`
## rig because it is a hand's length from the camera: on the wall rate it would
## read as the whole room strobing rather than as the thing in your hand.
func _process(delta: float) -> void:
	_torch_t += delta
	if torch != null:
		torch.light_energy = TORCH_ENERGY * Flame.energy(_torch_t * Flame.HERO_RATE, Flame.HERO_PHASE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and look_enabled and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var speed := SENSITIVITY * sensitivity_scale
		rotate_y(-motion.relative.x * speed)
		var dy := motion.relative.y * speed
		set_pitch(_pitch + (dy if invert_y else -dy))
		return
