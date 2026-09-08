extends SceneTree

var surface: SubViewport
## Native rendering measurements; gameplay and saves are synthetic.

func _init() -> void:
	await process_frame
	surface = SubViewport.new()
	surface.size = Vector2i(1920, 1080)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var game := GameRoot.new()
	game.save_path = "user://benchmark/campaign.json"
	game.clock = func() -> int: return 1000
	game.autosave_seconds = 0
	surface.add_child(game)
	var crawl := Crawl.new()
	crawl.game = game
	crawl.settings_path = "user://benchmark/settings.cfg"
	crawl.show_title = false
	surface.add_child(crawl)
	crawl.bind(game)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(surface.get_viewport_rid(), true)
	# Performance monitors update periodically; exclude startup samples.
	await create_timer(3.0).timeout
	await _measure("guild", crawl)
	crawl.open_guild(GuildRoom.DESK)
	# Performance monitors update periodically; exclude startup samples.
	await create_timer(3.0).timeout
	await _measure("hero_preview", crawl)
	crawl.close_panel()
	for _i in 5:
		crawl.open_guild(GuildRoom.DESK)
		crawl.inspect_ghost(game.campaign.ladder.ghosts[0].id)
		crawl.close_panel()
		crawl.close_panel()
		await process_frame
	var before := _counts(crawl)
	for _i in 50:
		crawl.open_guild(GuildRoom.DESK)
		crawl.inspect_ghost(game.campaign.ladder.ghosts[0].id)
		crawl.close_panel()
		crawl.close_panel()
		await process_frame
	for _i in 10:
		await process_frame
	print("cycles: ", JSON.stringify({"before": before, "after": _counts(crawl)}))
	game.start_run(1)
	var run := game.campaign.run
	run.floor = 31
	run.nodes = [{"kind": "fight", "enemies": ["bone_rat", "hollow_knight", "plague_bearer"]}]
	run.node_index = 0
	run.resolved = [false]
	run.phase = "node"
	crawl.build_floor()
	var at := Kit.cell_to_world(crawl.layout.room_center(crawl.layout.room_of_node(0)))
	crawl.player.place_at(at - Vector3(0, 0, Kit.CELL * 1.4), 0)
	crawl._on_marker_entered(0)
	await create_timer(3.0).timeout
	await _measure("floor31_fight", crawl)
	if game.sfx != null:
		game.sfx.release()
	crawl.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	quit()


func _measure(label: String, crawl: Crawl) -> void:
	var frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var cpu_ms: Array[float] = []
	var gpu_ms: Array[float] = []
	var preview_cpu: Array[float] = []
	var preview_gpu: Array[float] = []
	var previews: Array[SubViewport] = []
	_previews(crawl, previews)
	for preview in previews:
		RenderingServer.viewport_set_measure_render_time(preview.get_viewport_rid(), true)
	var last := Time.get_ticks_usec()
	for _i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(surface.get_viewport_rid()))
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(surface.get_viewport_rid()))
		var cpu := 0.0
		var gpu := 0.0
		for preview in previews:
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(preview.get_viewport_rid())
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(preview.get_viewport_rid())
		preview_cpu.append(cpu)
		preview_gpu.append(gpu)
	frame_ms.sort()
	print("benchmark: ", JSON.stringify({"mode": label, "resolution": str(surface.size),
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(),
		"frame_ms_median": frame_ms[90], "frame_ms_p95": frame_ms[171],
		"process_ms_mean": _mean(process_ms), "render_cpu_ms_mean": _mean(cpu_ms), "render_gpu_ms_mean": _mean(gpu_ms),
		"preview_cpu_ms_mean": _mean(preview_cpu), "preview_gpu_ms_mean": _mean(preview_gpu),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "counts": _counts(crawl)}))


func _previews(node: Node, out: Array[SubViewport]) -> void:
	if node is ModelPreview and node.is_visible_in_tree():
		out.append(node.viewport)
	for child in node.get_children():
		_previews(child, out)


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(1, values.size())


func _counts(crawl: Crawl) -> Dictionary:
	var counts := {"nodes": 0, "lights": 0, "viewports": 0, "active_previews": 0,
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}
	_count(crawl, counts)
	return counts


func _count(node: Node, counts: Dictionary) -> void:
	counts["nodes"] += 1
	if node is Light3D:
		counts["lights"] += 1
	if node is SubViewport:
		counts["viewports"] += 1
		if node.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			counts["active_previews"] += 1
	for child in node.get_children():
		_count(child, counts)
