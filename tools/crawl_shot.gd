extends SceneTree
## Takes a picture of a real generated floor with the real kit, builder and
## grade -- no GameRoot, no save file, no run. The headless suite cannot see,
## so this is the only thing that can answer "does it look right", and it is
## also where the Steam capsule shot comes from.
##
##   godot --path . --rendering-method forward_plus --resolution 1280x720 \
##         -s tools/crawl_shot.gd -- <out.png> [seed] [frames] [depth] [diag]
##
## Note the missing --headless: there is no framebuffer to read without a
## renderer, so this runs windowed and reads the viewport texture.

## Floods the scene with flat light and kills the fog. A black frame has two
## causes -- the build is broken, or the room really is that dark -- and this
## is what tells them apart.
static var diag := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://crawl.png"
	var seed_value := int(args[1]) if args.size() > 1 and String(args[1]).is_valid_int() else 3
	var frames := int(args[2]) if args.size() > 2 and String(args[2]).is_valid_int() else 24
	var depth := float(args[3]) if args.size() > 3 and String(args[3]).is_valid_float() else 0.35
	diag = args.has("diag")

	# SceneTree._init runs before the tree is up: nothing may be added or
	# transformed until a frame has passed.
	await process_frame
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1280, 720)

	var layout := LayoutGenerator.generate(3, Rng.new(seed_value))
	var world := Node3D.new()
	win.add_child(world)
	var counts := DungeonBuilder.build(layout, world)

	var env := Grade.environment(depth)
	if diag:
		env.fog_enabled = false
		env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var shot := _corridor_shot(layout)
	var cam := Camera3D.new()
	cam.fov = 72.0
	world.add_child(cam)
	cam.look_at_from_position(shot[0], shot[1], Vector3.UP)
	cam.current = true

	# The hero's torch is most of the near light, so the shot is wrong without
	# it: stand at the camera and carry the same lamp Player carries.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 8.0 if diag else 2.6
	lamp.omni_range = Kit.CELL * (12.0 if diag else 3.0)
	lamp.omni_attenuation = 1.6
	cam.add_child(lamp)

	print("crawl_shot: floors=%d walls=%d torches=%d boxes=%d" % [
		counts["floors"], counts["walls"], counts["torches"], counts["boxes"]])

	for _i in frames:
		await process_frame
	await process_frame
	var err := win.get_texture().get_image().save_png(out)
	print("crawl_shot -> %s err=%d" % [out, err])
	quit()


## The classic dungeon shot looks ALONG a corridor, not across a room: it is
## the one framing where depth, torch falloff and the vanishing point all do
## their work at once. Deterministic, so a seed always frames the same way.
func _corridor_shot(layout: FloorLayout) -> Array:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var best_len := 0
	var best_from := Vector2i.ZERO
	var best_dir := Vector2i(1, 0)
	for dir in dirs:
		for y in layout.height:
			for x in layout.width:
				if not layout.is_walkable(x, y) or layout.is_walkable(x - dir.x, y - dir.y):
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
	var from := Kit.cell_to_world(best_from) + Vector3(0.0, Player.EYE, 0.0)
	var to := from + Vector3(best_dir.x, 0.0, best_dir.y) * float(best_len - 1) * Kit.CELL
	to.y = Player.EYE - 0.15
	print("crawl_shot: corridor %d cells from %s dir %s" % [best_len, best_from, best_dir])
	return [from, to]
