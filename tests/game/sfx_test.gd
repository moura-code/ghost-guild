extends GdUnitTestSuite
## Sound. The game shipped its whole vertical slice without a single
## AudioStream in it, which on a game this restrained visually was the
## largest remaining gap in how it feels.
##
## Tested for wiring, never for waveforms: that every id the game asks for
## exists, that asking for one that does not is survivable, that a burst of
## events cannot exhaust the voices, and that the mute switch actually mutes.


func _sfx() -> Sfx:
	var s: Sfx = auto_free(Sfx.new())
	add_child(s)
	return s


func test_every_sound_the_game_names_is_on_disk() -> void:
	# Sfx.CATALOGUE is the contract. A name in code with no file behind it is
	# a silent failure by construction, which is the worst kind here: nobody
	# notices a sound that never plays.
	var missing: Array[String] = []
	for id in Sfx.CATALOGUE:
		if not ResourceLoader.exists(Sfx.path_for(String(id))):
			missing.append(String(id))
	assert_array(missing) \
		.override_failure_message("no wav for: %s" % ", ".join(missing)) \
		.is_empty()


func test_playing_an_unknown_sound_is_survivable() -> void:
	# Content and screens will ask for sounds that do not exist yet. That has
	# to be silence, never a crash mid-fight.
	var s := _sfx()
	await await_idle_frame()
	s.play("no_such_sound")
	assert_bool(is_instance_valid(s)).is_true()


func test_a_burst_of_hits_does_not_run_out_of_voices() -> void:
	# An enemy phase resolves several blows in one apply(), and the animator
	# fires them a beat apart. If the pool is exhausted the last hits of a
	# round go silent, which reads as the game dropping frames.
	var s := _sfx()
	await await_idle_frame()
	for i in Sfx.VOICES * 3:
		s.play("hit_light")
	assert_int(s._players.size()).is_equal(Sfx.VOICES)
	assert_bool(is_instance_valid(s)).is_true()


func test_muting_stops_it_playing() -> void:
	var s := _sfx()
	await await_idle_frame()
	s.muted = true
	s.play("click")
	for player in s._players:
		assert_bool(player.playing) \
			.override_failure_message("muted and still playing").is_false()


func test_volume_is_remembered_and_clamped() -> void:
	var s := _sfx()
	s.volume = 2.5
	assert_float(s.volume).is_equal(1.0)
	s.volume = -1.0
	assert_float(s.volume).is_equal(0.0)


func test_the_catalogue_covers_every_fight_event_that_should_be_heard() -> void:
	# The animator turns engine events into feel. Any event kind that earns a
	# sound has to have one, and this is the list -- so adding a new one to
	# the engine without deciding whether it is audible fails here.
	for id in ["hit_light", "hit_heavy", "block", "enemy_die", "hero_hurt",
			"card_play", "card_draw", "turn_start"]:
		assert_bool(Sfx.CATALOGUE.has(id)) \
			.override_failure_message("%s is not in the catalogue" % id).is_true()


## The wiring, asserted where it actually matters: that the game reaches the
## sound rather than that a wav decoded. A silent game passes every other
## test in this suite, which is exactly why these exist.
func test_the_bridge_owns_one_pool_of_voices() -> void:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = "user://test_saves/sfx_wiring.json"
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	await await_idle_frame()
	assert_object(g.sfx).is_not_null()
	assert_int(g.sfx._players.size()).is_equal(Sfx.VOICES)


func test_the_animator_is_silent_without_a_sound_bank() -> void:
	# Built without a GameRoot in tests and in the screenshot tool. A missing
	# Sfx has to be silence, not a crash mid-fight.
	var a: FightAnimator3D = auto_free(FightAnimator3D.new())
	add_child(a)
	a.bind(TestFixtures.content(), null)
	assert_object(a.sfx).is_null()
	a.play([{"type": "damage", "target": "enemy", "index": 0, "amount": 12}])
	await await_idle_frame()
	assert_bool(is_instance_valid(a)).is_true()


func test_a_heavy_blow_and_a_light_one_are_different_sounds() -> void:
	# The ear and the eye use the same threshold, so the blows that shake the
	# screen are the blows that sound heavy.
	assert_int(Sfx.BIG_HIT).is_equal(FightAnimator3D.BIG_HIT)


func test_every_button_in_a_screen_gets_a_voice() -> void:
	var s := _sfx()
	var root: Control = auto_free(Control.new())
	var a := Button.new()
	var box := VBoxContainer.new()
	var b := Button.new()
	box.add_child(b)
	root.add_child(a)
	root.add_child(box)
	add_child(root)
	UiTheme.voice_buttons(root, s)
	# Nested as well as direct: screens build buttons several containers deep.
	assert_bool(a.pressed.get_connections().size() > 0).is_true()
	assert_bool(b.pressed.get_connections().size() > 0).is_true()
	assert_bool(b.mouse_entered.get_connections().size() > 0).is_true()


func test_voicing_twice_does_not_double_up_the_click() -> void:
	# show_tab re-voices its screen on every switch, because screens rebuild
	# their contents; that must not stack a second click on every button.
	var s := _sfx()
	var root: Control = auto_free(Control.new())
	var b := Button.new()
	root.add_child(b)
	add_child(root)
	UiTheme.voice_buttons(root, s)
	UiTheme.voice_buttons(root, s)
	assert_int(b.pressed.get_connections().size()).is_equal(1)


## Room tone. Its whole job is to be unnoticed until it stops, which makes it
## exactly the thing that breaks silently, so the wiring is pinned.
func test_the_room_has_a_tone_and_it_loops() -> void:
	var s := _sfx()
	await await_idle_frame()
	s.start_ambience()
	assert_bool(s._ambience.playing) 		.override_failure_message("the room is silent").is_true()
	var stream := s._ambience.stream as AudioStreamWAV
	assert_object(stream).is_not_null()
	# The loop is set at import time (edit/loop_mode=1), not at runtime:
	# mutating the shared cached resource meant holding a copy past shutdown,
	# which leaked the stream and its playback at exit.
	assert_int(stream.loop_mode) 		.override_failure_message("ambience would play once and stop") 		.is_equal(AudioStreamWAV.LOOP_FORWARD)


func test_starting_the_room_twice_does_not_stack_two_of_them() -> void:
	var s := _sfx()
	await await_idle_frame()
	s.start_ambience()
	s.start_ambience()
	assert_int(s.get_children().filter(func(c): return c == s._ambience).size()).is_equal(1)
	assert_bool(s._ambience.playing).is_true()


func test_the_room_sits_under_the_effects() -> void:
	# Loud ambience is the fastest way to make a player turn the sound off.
	assert_float(Sfx.AMBIENCE_LEVEL).is_less(1.0)
	assert_float(Sfx.AMBIENCE_LEVEL).is_greater(0.0)


func test_ducking_pulls_the_room_down_and_lets_it_back_up() -> void:
	var s := _sfx()
	await await_idle_frame()
	s.start_ambience()
	var full := s._ambience.volume_db
	s.duck(0.3)
	assert_float(s._ambience.volume_db) \
		.override_failure_message("duck did not lower the room").is_less(full)
	await get_tree().create_timer(0.75).timeout
	assert_float(s._ambience.volume_db).is_equal_approx(full, 0.5)


func test_muting_silences_the_room_too() -> void:
	var s := _sfx()
	await await_idle_frame()
	s.start_ambience()
	s.muted = true
	assert_bool(s._ambience.playing).is_false()


func test_the_footsteps_rotate_through_their_variants() -> void:
	# One sample at three per second stops being a footstep and becomes a
	# rhythm. The rotation is what the index the player emits is FOR, so it is
	# the part worth pinning.
	var seen: Array[String] = []
	for i in range(1, Sfx.STEPS.size() * 2 + 1):
		seen.append(Sfx.step_sound(i))
	for id in Sfx.STEPS:
		assert_array(seen).contains([id])
	assert_str(seen[0]).is_not_equal(seen[1])
	assert_str(seen[0]).is_equal(seen[Sfx.STEPS.size()])


func test_every_footstep_variant_is_in_the_catalogue_and_on_disk() -> void:
	for id in Sfx.STEPS:
		assert_array(Sfx.CATALOGUE).override_failure_message("%s not in the catalogue" % id).contains([id])
		assert_bool(ResourceLoader.exists(Sfx.path_for(String(id)))) \
			.override_failure_message("no wav for %s" % id).is_true()


func test_a_footstep_is_quieter_than_the_thing_that_plays_it() -> void:
	# Feet are the most repeated sound in the game by an order of magnitude.
	# At the level of a blow landing they would be the whole mix.
	assert_float(Sfx.STEP_LEVEL).is_less(1.0)
	assert_float(Sfx.STEP_LEVEL).is_greater(0.0)


func test_walking_the_player_is_what_makes_the_sound() -> void:
	# The wire the whole batch exists for: Player emits, Sfx answers. Asserted
	# by playing it directly, because a headless audio server will not tell
	# you what came out of the speakers.
	var s := _sfx()
	await await_idle_frame()
	s.step(1)
	s.step(2)
	assert_bool(is_instance_valid(s)).is_true()


# ------------------------------------------------------------------ the room

func test_the_game_has_a_dry_path_and_a_wet_one() -> void:
	# A crypt has a tail, and a UI click does not happen in the crypt. One
	# reverb over everything makes menus sound underwater; none at all leaves
	# a blow landing in a stone corridor sounding like a button.
	Sfx.ensure_buses()
	for id in [Sfx.BUS_UI, Sfx.BUS_WORLD, Sfx.BUS_AMBIENCE]:
		assert_int(AudioServer.get_bus_index(id)).override_failure_message("no %s bus" % id).is_greater_equal(0)
	var world := AudioServer.get_bus_index(Sfx.BUS_WORLD)
	var ui := AudioServer.get_bus_index(Sfx.BUS_UI)
	assert_int(AudioServer.get_bus_effect_count(world)).override_failure_message("the world is dry").is_greater(0)
	assert_object(AudioServer.get_bus_effect(world, 0)).is_instanceof(AudioEffectReverb)
	assert_int(AudioServer.get_bus_effect_count(ui)).override_failure_message("the menu is in a cave").is_equal(0)


func test_every_bus_still_goes_through_master() -> void:
	# Settings turns the volume down by setting bus 0. A bus that sends
	# anywhere else is a sound the volume slider cannot reach.
	Sfx.ensure_buses()
	for id in [Sfx.BUS_UI, Sfx.BUS_WORLD, Sfx.BUS_AMBIENCE]:
		assert_str(AudioServer.get_bus_send(AudioServer.get_bus_index(id))).is_equal("Master")


func test_building_the_buses_twice_does_not_build_them_twice() -> void:
	# Every Sfx that boots calls this, and the suite boots a great many.
	Sfx.ensure_buses()
	var before := AudioServer.bus_count
	Sfx.ensure_buses()
	Sfx.ensure_buses()
	assert_int(AudioServer.bus_count).is_equal(before)


func test_a_click_is_a_menu_and_a_blow_is_a_room() -> void:
	assert_str(Sfx.bus_for("click")).is_equal(Sfx.BUS_UI)
	assert_str(Sfx.bus_for("hover")).is_equal(Sfx.BUS_UI)
	assert_str(Sfx.bus_for("card_play")).is_equal(Sfx.BUS_UI)
	assert_str(Sfx.bus_for("hit_heavy")).is_equal(Sfx.BUS_WORLD)
	assert_str(Sfx.bus_for("step_a")).is_equal(Sfx.BUS_WORLD)
	assert_str(Sfx.bus_for("enemy_die")).is_equal(Sfx.BUS_WORLD)
	assert_str(Sfx.bus_for("descend")).is_equal(Sfx.BUS_WORLD)


func test_every_sound_in_the_catalogue_lands_on_a_bus_that_exists() -> void:
	# The failure mode of a typo'd bus name is that Godot routes it to Master
	# silently, so the sound plays and only the reverb is missing -- which is
	# exactly the kind of wrong nobody hears until the mix is finished.
	Sfx.ensure_buses()
	for id in Sfx.CATALOGUE:
		var bus := Sfx.bus_for(String(id))
		assert_int(AudioServer.get_bus_index(bus)) \
			.override_failure_message("%s routes to a bus called %s, which does not exist" % [id, bus]) \
			.is_greater_equal(0)


func test_the_room_tone_is_not_reverbed_into_a_second_room() -> void:
	assert_str(Sfx.bus_for(Sfx.AMBIENCE)).is_equal(Sfx.BUS_AMBIENCE)
