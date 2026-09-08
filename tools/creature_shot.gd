extends SceneTree
## Render the shipped enemy rigs or ghost states under neutral light.
## godot --path . -s tools/creature_shot.gd -- <out.png> <enemy_id ...>
## Use `ghosts` in place of enemy IDs to inspect the four spectral states.
## No campaign or save file is created.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "user://creatures.png"
	var cast: Array[String] = []
	for i in range(1, args.size()):
		cast.append(args[i])
	if cast.is_empty():
		cast = ["bone_rat", "crypt_spider", "bone_archer", "hollow_knight", "plague_bearer"]
	var ghosts := cast[0] == "ghosts"
	if ghosts:
		cast = ["true", "echo", "prepared", "restless"]
	var content := Content.load_from("res://data")
	for id in cast:
		if not ghosts and not content.enemies.has(id):
			push_error("Unknown enemy: %s" % id)
			quit(1)
			return
	await process_frame
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1440, 900)
	var world := Node3D.new()
	win.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b121b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b1c3d7")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.glow_enabled = true
	var grade := WorldEnvironment.new()
	grade.environment = environment
	world.add_child(grade)
	_light(world, Vector3(-35, -30, 0), Color("d7e6ff"), 2.0, true)
	_light(world, Vector3(-20, 145, 0), Color("a1bbd8"), 1.1, false)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color("192330")
	slate.roughness = 0.9
	ground.material_override = slate
	world.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(4.3, float(cast.size()) * 1.20)
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 3.0, -10), Vector3(0, 1.12, 0))
	camera.current = true
	var overlay := Control.new()
	win.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(overlay, "GHOST GUILD  /  " + ("SPIRITS OF THE GUILD" if ghosts else "CREATURE STUDY"),
		Vector2(48, 35), Vector2(1300, 36), 26, Palette.BONE)
	_label(overlay, "PROCEDURAL MODELS  ·  LIVE GAME RIGS", Vector2(48, 79), Vector2(1300, 26), 14, Palette.EDGE_LIGHT)
	for i in cast.size():
		var at := Vector3((float(i) - float(cast.size() - 1) * 0.5) * 1.65, 0.03, 0)
		if ghosts:
			var ghost := Ghost.founder(content, 1000)
			ghost.id = i
			ghost.kind = "echo" if cast[i] == "echo" else "true"
			ghost.prepared = cast[i] == "prepared"
			ghost.restless = cast[i] == "restless"
			var figure := GhostFigure.create(ghost, at)
			world.add_child(figure)
			figure.set_process(false)
		else:
			var body := EnemyBody.create(content.enemies[cast[i]], i)
			world.add_child(body)
			body.position = at
			body.rotation.y = -0.17
			body.set_process(false)
		var pedestal := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.64
		cylinder.bottom_radius = 0.67
		cylinder.height = 0.04
		pedestal.mesh = cylinder
		pedestal.material_override = slate
		pedestal.position = Vector3(at.x, 0.01, 0)
		world.add_child(pedestal)
		var point := camera.unproject_position(at + Vector3(0, -0.16, -0.1))
		var caption := cast[i].capitalize() if ghosts else content.text((content.enemies[cast[i]] as EnemyDef).name_key)
		var label := _label(overlay, caption, point - Vector2(120, 0), Vector2(240, 30), 18, Palette.BONE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for frame in 32:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := win.get_texture().get_image().save_png(out)
	print("creature_shot -> %s err=%d" % [out, result])
	world.queue_free()
	overlay.queue_free()
	await process_frame
	await process_frame
	quit(0 if result == OK else 1)


func _light(world: Node3D, angle: Vector3, colour: Color, energy: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angle
	light.light_color = colour
	light.light_energy = energy
	light.shadow_enabled = shadows
	world.add_child(light)


func _label(parent: Control, text: String, at: Vector2, extent: Vector2, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = extent
	label.add_theme_font_override("font", UiTheme.body_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label
