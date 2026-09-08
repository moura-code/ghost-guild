extends SceneTree
## THROWAWAY -- Stage 0 of the 3D pivot. Not shipped, not tested, deleted when
## the pipeline question is answered. Its only job is to put the CC0 PBR
## materials on a real generated FloorLayout under torchlight and take a
## picture, so the "does this read as a commercial game" question gets an
## answer in days instead of months.
##
##   godot --path . --rendering-method forward_plus --resolution 1280x720 \
##         -s tools/spike_crypt.gd -- <out.png> [seed] [frames]

const CELL := 3.0
const WALL_H := 3.2
const MAT_ROOT := "res://assets/materials/"

## Set by the `diag` argument: floods the scene with flat light and kills the
## fog, so a black frame can be told apart from a broken build.
static var diag := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://spike.png"
	var seed_value := int(args[1]) if args.size() > 1 and String(args[1]).is_valid_int() else 3
	var frames := int(args[2]) if args.size() > 2 and String(args[2]).is_valid_int() else 20
	diag = args.has("diag")

	# SceneTree._init runs before the tree is up, so nothing may be added or
	# transformed until a frame has passed.
	await process_frame
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1280, 720)

	var layout := LayoutGenerator.generate(3, Rng.new(seed_value))
	var world := Node3D.new()
	win.add_child(world)
	_build(world, layout)
	_light(world, layout)
	var cam := _camera(world, layout)
	var actor := ""
	for a in args:
		if String(a).ends_with(".glb") or String(a).ends_with(".fbx"):
			actor = String(a)
	if actor != "":
		_actor(world, cam, actor)
	print("spike: %d rooms, entry=%d stairs=%d torches=%d camera=%s" % [
		layout.rooms.size(), layout.entry_room, layout.stairs_room,
		layout.torch_anchors.size(), cam.global_position])

	for i in frames:
		await process_frame
	await process_frame
	var img := win.get_texture().get_image()
	var err := img.save_png(out)
	print("spike -> %s err=%d" % [out, err])
	quit()


func _mat(name: String, tile: float, rough_boost: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(MAT_ROOT + name + "/color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(MAT_ROOT + name + "/normal.jpg")
	m.roughness_texture = load(MAT_ROOT + name + "/roughness.jpg")
	m.roughness = rough_boost
	m.ao_enabled = true
	m.ao_texture = load(MAT_ROOT + name + "/ao.jpg")
	m.ao_light_affect = 0.7
	# One texel density for the whole kit: every material repeats once per
	# `tile` metres, so a wall and the floor it meets never disagree about
	# how big a stone is. This is the single discipline that stops mixed
	# sources reading as an asset flip.
	m.uv1_scale = Vector3(CELL / tile, CELL / tile, 1.0)
	return m


func _build(world: Node3D, layout: FloorLayout) -> void:
	var floor_mat := _mat("pavingstones119", 2.0)
	var wall_mat := _mat("bricks100", 2.0)
	var ceil_mat := _mat("rock051", 3.0)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(CELL, CELL)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(CELL, WALL_H, CELL)

	for y in layout.height:
		for x in layout.width:
			var kind := layout.cell(x, y)
			var at := Vector3(x * CELL, 0.0, y * CELL)
			if kind == FloorLayout.Cell.FLOOR:
				var f := MeshInstance3D.new()
				f.mesh = floor_mesh
				f.material_override = floor_mat
				f.position = at
				world.add_child(f)
				var c := MeshInstance3D.new()
				c.mesh = floor_mesh
				c.material_override = ceil_mat
				c.position = at + Vector3(0, WALL_H, 0)
				c.rotation_degrees = Vector3(180, 0, 0)
				world.add_child(c)
			elif kind == FloorLayout.Cell.WALL:
				var w := MeshInstance3D.new()
				w.mesh = wall_mesh
				w.material_override = wall_mat
				w.position = at + Vector3(0, WALL_H / 2.0, 0)
				world.add_child(w)


func _light(world: Node3D, layout: FloorLayout) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.48)
	env.ambient_light_energy = 1.2 if diag else 0.06
	env.fog_enabled = not diag
	env.fog_light_color = Color(0.14, 0.15, 0.20)
	env.fog_density = 0.035
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for raw in layout.torch_anchors:
		var at: Vector2i = raw
		# The anchor is the wall cell the bracket is bolted to, so the flame has
		# to hang in the open cell in front of it. A light left at the anchor sits
		# inside the wall and lights it from within, which reads as a glowing
		# window floating in the stone.
		var out_dir := Vector2i.ZERO
		for side in sides:
			if layout.is_walkable(at.x + side.x, at.y + side.y):
				out_dir = side
				break
		if out_dir == Vector2i.ZERO:
			continue
		var l := OmniLight3D.new()
		l.position = Vector3((at.x + out_dir.x * 0.62) * CELL, WALL_H * 0.62, (at.y + out_dir.y * 0.62) * CELL)
		l.light_color = Color(1.0, 0.66, 0.32)
		l.light_energy = 5.0
		l.omni_range = CELL * 4.5
		l.omni_attenuation = 1.4
		l.shadow_enabled = true
		world.add_child(l)


func _camera(world: Node3D, layout: FloorLayout) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 70.0
	# The classic dungeon shot looks ALONG a corridor, not across a room: it is
	# the one framing where depth, the torch falloff and the vanishing point
	# all do their work. So find the longest straight walkable run and stand at
	# one end of it. Deterministic, so a seed always frames the same way.
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var best_len := 0
	var best_from := Vector2i.ZERO
	var best_dir := Vector2i(1, 0)
	for dir in dirs:
		for y in layout.height:
			for x in layout.width:
				if not layout.is_walkable(x, y):
					continue
				var back := Vector2i(x, y) - dir
				if layout.is_walkable(back.x, back.y):
					continue
				var n := 0
				var at := Vector2i(x, y)
				while layout.is_walkable(at.x, at.y):
					n += 1
					at += dir
				if n > best_len:
					best_len = n
					best_from = Vector2i(x, y)
					best_dir = dir
	var from := Vector3(best_from.x * CELL, 1.7, best_from.y * CELL)
	var to := from + Vector3(best_dir.x, 0.0, best_dir.y) * float(best_len - 1) * CELL
	to.y = 1.55
	cam.position = from
	world.add_child(cam)
	cam.look_at_from_position(from, to, Vector3.UP)
	cam.current = true
	if diag:
		var lamp := OmniLight3D.new()
		lamp.light_energy = 8.0
		lamp.omni_range = 40.0
		cam.add_child(lamp)
	print("spike: corridor run %d cells from %s dir %s" % [best_len, best_from, best_dir])
	return cam


## Drops a rigged, animated model into the corridor ahead of the camera to
## prove the part of the pipeline that cannot be reasoned about: that a
## skinned mesh imports, animates, takes torchlight and casts a shadow under
## Forward+. The model is a stand-in -- the art question is separate and is
## answered by swapping the file, not by changing this code.
func _actor(world: Node3D, cam: Camera3D, path: String) -> void:
	var packed: Resource = load(path)
	if packed == null:
		print("spike: no actor at " + path)
		return
	var inst: Node3D = (packed as PackedScene).instantiate()
	world.add_child(inst)
	var ahead := -cam.global_transform.basis.z
	ahead.y = 0.0
	inst.global_position = cam.global_position + ahead.normalized() * (CELL * 1.9) - Vector3(0, 1.7, 0)
	inst.look_at_from_position(inst.global_position, cam.global_position - Vector3(0, 1.7, 0), Vector3.UP)
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	var clips: Array = []
	for p in players:
		var ap: AnimationPlayer = p
		clips = ap.get_animation_list()
		if clips.is_empty():
			continue
		ap.play(String(clips[0]))
		ap.advance(0.55)
		break
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	print("spike: actor %s -- %d anim players, clips %s, %d meshes, at %s" % [
		path.get_file(), players.size(), clips, meshes.size(), inst.global_position])
