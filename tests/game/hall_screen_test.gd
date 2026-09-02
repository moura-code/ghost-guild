extends GdUnitTestSuite
## The Hall of Legends (spec §6.1), and the rite you perform at it.
##
## The one thing a prestige button must never do is surprise someone. So the
## screen says what will be kept and what will be taken *before* it is pressed,
## and the Hall keeps every merged epitaph afterwards -- "the Legend is a
## memorial, not a deletion".

const TMP := "user://test_saves/hall_screen_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 2
	return g


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _screen(g: GameRoot) -> HallScreen:
	var s: HallScreen = auto_free(HallScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func _plant(g: GameRoot, floor: int) -> Ghost:
	var hero := Hero.create(g.content, "sexton", "Deepwalker", {}, 1)
	var ghost := g.campaign.ladder.add(Ghost.from_expedition(hero, floor, 0))
	ghost.strength = 150.0
	ghost.fixed_strength = true
	return ghost


# ---------------------------------------------------------------- the notice

func test_it_says_how_far_off_the_rite_is() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_bool(s._rite.disabled).is_true()
	assert_str(s._standing.text).contains(str(CampaignEngine.prestige_threshold(g.campaign)))


func test_the_rite_opens_when_someone_stands_deep_enough() -> void:
	var g := _game()
	var s := _screen(g)
	_plant(g, 15)
	s.refresh()
	await await_idle_frame()
	assert_bool(s._rite.disabled).is_false()


func test_it_says_what_will_be_taken_before_it_is_pressed() -> void:
	# A prestige button that surprises someone is the worst button in a game.
	var g := _game()
	var s := _screen(g)
	_plant(g, 15)
	g.campaign.soul = 4000.0
	s.refresh()
	await await_idle_frame()
	var warning := s._cost.text
	assert_bool(s._cost.visible).is_true()
	# It has to name the two things it takes, in numbers, not in general terms.
	assert_str(warning).contains(str(g.campaign.ladder.ghosts.size()))
	assert_str(warning).contains(Num.short(g.displayed_soul()))


# ----------------------------------------------------------------- the rite

func test_performing_it_goes_through_the_one_channel() -> void:
	var g := _game()
	var s := _screen(g)
	_plant(g, 15)
	s.refresh()
	s._rite.pressed.emit()
	await await_idle_frame()
	assert_array(g.campaign.legends).has_size(1)
	assert_int(g.campaign.ink).is_equal(1)
	var back := SaveGame.load_campaign(g.content, TMP)
	assert_array(back.legends).override_failure_message(
		"the rite was not saved").has_size(1)


func test_the_hall_keeps_everyone_it_merged() -> void:
	var g := _game()
	var s := _screen(g)
	_plant(g, 15)
	_plant(g, 6)
	s.refresh()
	s._rite.pressed.emit()
	await await_idle_frame()
	assert_array(s.rows).has_size(1)
	var legend: Legend = g.campaign.legends[0]
	assert_int(legend.epitaphs.size()).override_failure_message(
		"the Legend forgot somebody").is_greater_equal(3)
	assert_str(s.rows[0].text).contains(legend.name)


func test_the_blessing_is_shown_because_it_is_the_reward() -> void:
	var g := _game()
	var s := _screen(g)
	_plant(g, 15)
	s.refresh()
	s._rite.pressed.emit()
	await await_idle_frame()
	assert_str(s._blessing.text).contains(Num.percent(CampaignEngine.blessing(g.campaign) - 1.0))


func test_pressing_it_while_shallow_does_nothing_at_all() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	s._rite.pressed.emit()
	assert_array(g.campaign.legends).is_empty()
	assert_int(g.campaign.ladder.ghosts.size()).is_greater(0)
