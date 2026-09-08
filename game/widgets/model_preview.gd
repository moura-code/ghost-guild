class_name ModelPreview
extends TextureRect
## An isolated, disposable model. Never borrows or reparents a world actor.

var viewport: SubViewport
var stage: Node3D
var visual: Node3D
var identity: String = ""
var _clock: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(145, 130)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(360, 400)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	texture = viewport.get_texture()
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.02, 0.03, 0.05, 0.0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a3b5d5")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.15, -3.1)
	camera.rotation_degrees = Vector3(-5, 180, 0)
	camera.fov = 42
	stage.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -145, 0)
	key.light_color = Color("ffe1b2")
	key.light_energy = 1.4
	key.shadow_enabled = false
	stage.add_child(key)
	visibility_changed.connect(_sync_rendering)


func show_hero(hero: Hero) -> void:
	_replace(HeroFigure.create(hero), "hero:" + hero.name + ":" + hero.class_id)


func show_ghost(ghost: Ghost) -> void:
	_replace(GhostFigure.create(ghost, Vector3.ZERO), "ghost:" + str(ghost.id))


func _replace(next: Node3D, id: String) -> void:
	if visual != null:
		visual.free()
	visual = next
	identity = id
	stage.add_child(visual)
	_clock = 0.0
	_sync_rendering()


func _sync_rendering() -> void:
	if viewport == null:
		return
	var active := is_visible_in_tree()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	stage.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	set_process(active)


func _process(delta: float) -> void:
	if visual != null:
		_clock += delta
		visual.rotation.y = 0.18 if Settings.motion_reduced else 0.18 + sin(_clock * 0.35) * 0.13
