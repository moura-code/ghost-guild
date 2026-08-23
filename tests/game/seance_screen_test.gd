extends GdUnitTestSuite

const TMP := "user://test_saves/seance_screen_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 4
	return g


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _screen(g: GameRoot) -> SeanceScreen:
	var s: SeanceScreen = auto_free(SeanceScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func test_the_founder_gets_a_line_that_can_be_echoed() -> void:
	var g := _game()
	g.campaign.soul = 500.0
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	assert_int(s.lines.size()).is_equal(1)
	var line: GhostLine = s.lines[founder.id]
	assert_str(line._name.text).is_equal(founder.name)
	assert_bool(line._echo.visible).is_true()
	assert_bool(line._echo.disabled).is_false()
	assert_bool(line._call.visible).is_false()


func test_the_echo_button_is_disabled_without_the_soul_for_it() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var line: GhostLine = s.lines[g.campaign.ladder.ghosts[0].id]
	assert_bool(line._echo.disabled).is_true()


func test_placing_an_echo_adds_a_line_that_can_be_called() -> void:
	var g := _game()
	g.campaign.soul = 500.0
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	(s.lines[founder.id] as GhostLine)._echo.emit_signal("pressed")
	await await_idle_frame()
	assert_int(g.campaign.ladder.ghosts.size()).is_equal(2)
	assert_int(s.lines.size()).is_equal(2)
	var echo := g.campaign.ladder.ghosts[1]
	var echo_line: GhostLine = s.lines[echo.id]
	assert_bool(echo_line._call.visible).is_true()
	assert_bool(echo_line._echo.visible).is_false()


func test_the_floor_picker_is_capped_at_the_waypoint() -> void:
	var g := _game()
	g.campaign.soul = 500.0
	var s := _screen(g)
	await await_idle_frame()
	var line: GhostLine = s.lines[g.campaign.ladder.ghosts[0].id]
	assert_float(line._floor.min_value).is_equal(1.0)
	assert_float(line._floor.max_value).is_equal(float(g.campaign.ladder.waypoint()))


func test_tend_only_appears_for_a_restless_ghost_and_the_first_one_is_free() -> void:
	var g := _game()
	var founder := g.campaign.ladder.ghosts[0]
	var s := _screen(g)
	await await_idle_frame()
	assert_bool((s.lines[founder.id] as GhostLine)._tend.visible).is_false()

	founder.restless = true
	s.refresh()
	await await_idle_frame()
	var line: GhostLine = s.lines[founder.id]
	assert_bool(line._tend.visible).is_true()
	assert_str(line._tend.text).is_equal(g.text("ui.free"))
	line._tend.emit_signal("pressed")
	await await_idle_frame()
	assert_bool(founder.restless).is_false()
	assert_bool(g.campaign.onboarding.free_tend_available).is_false()


func test_mend_is_offered_only_when_the_hero_is_hurt() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_bool(s._mend_button.disabled).is_true()

	g.campaign.hero.hp = 10
	g.campaign.soul = 500.0
	s.refresh()
	await await_idle_frame()
	assert_bool(s._mend_button.disabled).is_false()
	s._mend_button.emit_signal("pressed")
	await await_idle_frame()
	assert_int(g.campaign.hero.hp).is_equal(g.campaign.hero.max_hp)
	assert_bool(s._mend_button.disabled).is_true()


func test_an_echo_can_be_called_to_another_floor() -> void:
	var g := _game()
	g.campaign.soul = 5000.0
	# A true ghost on floor 3 raises the waypoint so there is somewhere to go.
	TestFixtures.end_at_exit(g.campaign, 3, "watch", 1000)
	g.campaign.soul = 5000.0
	var s := _screen(g)
	await await_idle_frame()
	var source := g.campaign.ladder.ghosts[1]
	(s.lines[source.id] as GhostLine)._echo.emit_signal("pressed")
	await await_idle_frame()
	var echo := g.campaign.ladder.ghosts[2]
	assert_str(echo.kind).is_equal("echo")
	var echo_line: GhostLine = s.lines[echo.id]
	echo_line._floor.value = 2.0
	echo_line._call.emit_signal("pressed")
	await await_idle_frame()
	assert_int(echo.floor).is_equal(2)


func test_the_header_prices_an_echo_and_a_call() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._echo_price.text).is_equal(Num.short(Seance.echo_cost(g.campaign)))
	assert_str(s._call_price.text).is_equal(Num.short(Seance.call_cost(g.campaign)))


func test_a_line_shows_the_floor_and_the_strength() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	assert_str((s.lines[founder.id] as GhostLine)._detail.text).contains(str(founder.floor))
	assert_str((s.lines[founder.id] as GhostLine)._detail.text).contains(Num.short(founder.strength))


func test_removing_a_ghost_from_the_ladder_drops_its_line() -> void:
	var g := _game()
	g.campaign.soul = 500.0
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	(s.lines[founder.id] as GhostLine)._echo.emit_signal("pressed")
	await await_idle_frame()
	assert_int(s.lines.size()).is_equal(2)
	var echo_id: int = g.campaign.ladder.ghosts[1].id
	g.campaign.ladder.remove(echo_id)
	s.refresh()
	await await_idle_frame()
	assert_int(s.lines.size()).is_equal(1)
	assert_bool(s.lines.has(echo_id)).is_false()


func test_binding_twice_does_not_connect_the_signals_twice() -> void:
	var g := _game()
	var s := _screen(g)
	s.bind(g)
	await await_idle_frame()
	assert_int(g.ladder_changed.get_connections().size()).is_equal(1)


func test_a_ghost_line_reuses_its_widget_across_refreshes() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	var line: GhostLine = s.lines[founder.id]
	s.refresh()
	s.refresh()
	await await_idle_frame()
	assert_object(s.lines[founder.id]).is_same(line)
