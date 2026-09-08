extends GdUnitTestSuite
## The project settings are a contract the world code reads at runtime: the
## controller asks the InputMap for its actions by name and the bodies set
## layer bits by number. A rename here is a silent behaviour change
## everywhere, so it is asserted like any other interface.

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "interact", "guild_menu", "inspect_hero", "floor_map", "help"]
const LAYERS := {1: "world", 2: "player", 3: "interactable", 4: "ghost"}


func test_the_game_renders_with_forward_plus() -> void:
	assert_str(String(ProjectSettings.get_setting("rendering/renderer/rendering_method"))).is_equal("forward_plus")


func test_the_pixel_art_viewport_is_gone() -> void:
	# 640x360 with an integer viewport stretch was the pixel-art direction.
	# A 3D game renders at the window's real resolution.
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_width"))).is_greater(640)
	# HudRoot scales/reflows the UI independently of the native 3D viewport.
	assert_str(String(ProjectSettings.get_setting("display/window/stretch/mode"))).is_equal("disabled")
	# Nearest filtering was there to keep sprites crisp. On a PBR wall it is
	# the difference between stone and static. has_setting() is no use here --
	# the engine registers this one with a default whether the project sets it
	# or not -- so the value is what gets asserted.
	assert_int(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))).is_not_equal(0)


func test_every_movement_action_exists_and_is_bound() -> void:
	for action in ACTIONS:
		assert_bool(InputMap.has_action(action)).override_failure_message("missing action: " + action).is_true()
		assert_array(InputMap.action_get_events(action)).override_failure_message("unbound action: " + action).is_not_empty()


func test_the_physics_layers_are_named() -> void:
	for bit in LAYERS:
		var key := "layer_names/3d_physics/layer_%d" % bit
		assert_str(String(ProjectSettings.get_setting(key))).is_equal(String(LAYERS[bit]))


func test_the_game_boots_into_the_crawl() -> void:
	assert_str(String(ProjectSettings.get_setting("application/run/main_scene"))).is_equal("res://game/crawl.tscn")
