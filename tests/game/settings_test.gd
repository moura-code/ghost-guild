extends GdUnitTestSuite
## Settings live beside the save, not in it: they belong to the machine, and
## copying a campaign to another PC should not bring somebody else's mouse
## sensitivity with it.

const TMP := "user://test_saves/settings_test.cfg"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_a_fresh_install_gets_playable_defaults() -> void:
	var s := Settings.defaults()
	assert_float(s.sensitivity).is_equal(1.0)
	assert_bool(s.invert_y).is_false()
	assert_float(s.fov).is_between(Settings.FOV_MIN, Settings.FOV_MAX)
	assert_float(s.master_volume).is_greater(0.0)


func test_what_you_choose_survives_a_restart() -> void:
	var s := Settings.defaults()
	s.sensitivity = 1.9
	s.invert_y = true
	s.fov = 95.0
	s.master_volume = 0.3
	s.fullscreen = true
	assert_int(s.save(TMP)).is_equal(OK)
	var back := Settings.load_from(TMP)
	assert_float(back.sensitivity).is_equal_approx(1.9, 0.001)
	assert_bool(back.invert_y).is_true()
	assert_float(back.fov).is_equal_approx(95.0, 0.001)
	assert_float(back.master_volume).is_equal_approx(0.3, 0.001)
	assert_bool(back.fullscreen).is_true()


func test_a_missing_file_is_defaults_and_not_a_crash() -> void:
	var s := Settings.load_from("user://test_saves/_nothing_here.cfg")
	assert_float(s.sensitivity).is_equal(1.0)


func test_a_hand_edited_config_still_gives_a_playable_game() -> void:
	var s := Settings.defaults()
	s.from_dict({"sensitivity": 900.0, "fov": 4.0, "master_volume": -3.0})
	assert_float(s.sensitivity).is_equal(Settings.SENSITIVITY_MAX)
	assert_float(s.fov).is_equal(Settings.FOV_MIN)
	assert_float(s.master_volume).is_equal(0.0)


func test_applying_reaches_the_body_that_has_to_obey_it() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var s := Settings.defaults()
	s.sensitivity = 2.0
	s.invert_y = true
	s.fov = 88.0
	s.apply(p)
	assert_float(p.sensitivity_scale).is_equal_approx(2.0, 0.001)
	assert_bool(p.invert_y).is_true()
	assert_float(p.camera.fov).is_equal_approx(88.0, 0.001)


func test_applying_with_no_player_does_not_crash() -> void:
	Settings.defaults().apply(null)
	assert_bool(true).is_true()
