class_name CryptView
extends Control
## A live, isolated 3D illustration embedded in the UI. Hidden screens stop
## rendering. Rebinding combat numbers never recreates the model or world.

var subject: String = ""
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _actors: Node3D
var _time: float = 0.0
var _rests: Array[Vector3] = []
var _room: bool = false
var _chamber: Node3D
var _floor_signature: String = ""
var _yaw: float = 0.0
var _target_yaw: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 240)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var illustration := TextureRect.new()
	illustration.set_anchors_preset(Control.PRESET_FULL_RECT)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.texture = _viewport.get_texture()
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(illustration)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10151f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("91a6c5")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	_world.add_child(environment)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 2.65
	_world.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_color = Color("ffe2b4")
	key.light_energy = 1.1
	key.shadow_enabled = true
	_world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 145, 0)
	rim.light_color = Color("88c8d2")
	rim.light_energy = 0.55
	_world.add_child(rim)
	_actors = Node3D.new()
	_world.add_child(_actors)
	visibility_changed.connect(_sync_visibility)
	resized.connect(_sync_resolution)


func _ready() -> void:
	_sync_visibility()
	_sync_resolution()


func _sync_resolution() -> void:
	# Supersample the illustration independently of the logical UI canvas.
	# A plain TextureRect avoids SubViewportContainer's forced low resolution.
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var density := 2.0
	var extent := size * density
	if extent.x > 1280:
		extent *= 1280.0 / extent.x
	_viewport.size = Vector2i(maxi(2, int(extent.x)), maxi(2, int(extent.y)))


func _sync_visibility() -> void:
	var active := is_visible_in_tree()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	set_process(active)


func set_subject(id: String) -> void:
	if subject == id:
		return
	subject = id
	_clear_actors()
	var model := CryptModels.actor(id)
	_actors.add_child(model)
	model.rotation.y = -0.25
	_rests.append(Vector3.ZERO)
	_camera.position = Vector3(3.2, 2.2, 6)
	_camera.look_at_from_position(_camera.position, Vector3(0, 0.92, 0))
	_camera.size = 2.55
	if id in ["bone_rat", "crypt_spider"]:
		_camera.size = 2.7
		_camera.look_at_from_position(Vector3(3.0, 3.5, 6), Vector3(0, 0.5, 0))
	if id == "mother_of_bones":
		_camera.size = 3.05


func show_floor(campaign: Campaign, floor: int) -> void:
	if not _room:
		_room = true
		_chamber = CryptModels.chamber()
		_world.add_child(_chamber)
		_camera.size = 6.1
		_camera.position = Vector3(7.8, 6.8, 10.0)
		_camera.look_at_from_position(_camera.position, Vector3(0, 0.65, 0))
		for at in [Vector3(-2.8, 1.8, 1.6), Vector3(2.2, 1.5, -1.0)]:
			var candlelight := OmniLight3D.new()
			candlelight.position = at
			candlelight.light_color = Color("ffc076")
			candlelight.light_energy = 1.3
			candlelight.omni_range = 4.0
			_world.add_child(candlelight)
	var residents := campaign.ladder.on_floor(floor)
	var signature := str(floor)
	for resident in residents:
		signature += "/%d:%s:%s:%s" % [resident.id, resident.kind, resident.prepared, resident.restless]
	if _floor_signature == signature:
		return
	_floor_signature = signature
	_clear_actors()
	var shown := mini(5, residents.size())
	for i in shown:
		var resident: Ghost = residents[i]
		var kind := "restless" if resident.restless else ("prepared" if resident.prepared else resident.kind)
		var model := CryptModels.ghost(kind)
		_actors.add_child(model)
		var at := Vector3(0.4, 0.13, 0.35)
		if shown > 1:
			var a := TAU * float(i) / float(shown) - PI * 0.5
			at += Vector3(cos(a) * 0.85, 0, sin(a) * 0.62)
		model.position = at
		model.scale = Vector3.ONE * (0.85 if shown > 2 else 1.10)
		model.rotation.y = 0.2 + float(i) * 0.12
		_rests.append(at)
	# An empty reachable chamber stays empty: the illustration reflects
	# actual residents, so it never implies earnings that do not exist.


func _clear_actors() -> void:
	for child in _actors.get_children():
		# Models have no external owners or callbacks. Free them immediately
		# so a synchronous floor change cannot leave detached nodes behind.
		child.free()
	_rests.clear()


func _process(delta: float) -> void:
	_time += delta
	for i in _actors.get_child_count():
		var model := _actors.get_child(i) as Node3D
		var phase := _time * 1.4 + float(i) * 1.8
		var floating := _room or subject in ["ghost", "grave_wisp", "echo", "prepared", "restless"]
		model.position.y = _rests[i].y + sin(phase) * (0.065 if floating else 0.012)
		model.rotation.z = sin(phase * 0.7) * 0.025
	if _room:
		var local := get_local_mouse_position()
		_target_yaw = clampf((local.x / maxf(size.x, 1.0) - 0.5) * 0.09, -0.045, 0.045)
		_yaw = lerpf(_yaw, _target_yaw, 1.0 - exp(-delta * 3.0))
		_chamber.rotation.y = _yaw
		_actors.rotation.y = _yaw
