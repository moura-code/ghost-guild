extends GdUnitTestSuite
## There was no way out of this game except Alt+F4, and no way to change a
## setting at all.


func _menu(in_run: bool = false) -> PauseMenu:
	var m: PauseMenu = auto_free(PauseMenu.new())
	add_child(m)
	m.build(TestFixtures.content(), in_run)
	return m


func test_it_offers_resume_options_and_quit() -> void:
	var m := _menu(false)
	assert_bool(m.buttons.has(PauseMenu.RESUME)).is_true()
	assert_bool(m.buttons.has(PauseMenu.OPTIONS)).is_true()
	assert_bool(m.buttons.has(PauseMenu.QUIT)).is_true()


func test_the_guild_has_no_run_to_give_up() -> void:
	# A dead button is worse than a missing one.
	assert_bool(_menu(false).buttons.has(PauseMenu.ABANDON)).is_false()


func test_underground_you_can_give_up() -> void:
	assert_bool(_menu(true).buttons.has(PauseMenu.ABANDON)).is_true()


func test_every_button_says_something_real() -> void:
	var m := _menu(true)
	for id in m.buttons:
		var label: String = (m.buttons[id] as Button).text
		assert_str(label).is_not_empty()
		assert_bool(label.begins_with("ui.")).override_failure_message(
			"unresolved string on button %s" % id).is_false()


func test_each_button_reports_what_it_is() -> void:
	var m := _menu(true)
	var heard: Array = []
	m.resumed.connect(func() -> void: heard.append("resume"))
	m.options_requested.connect(func() -> void: heard.append("options"))
	m.abandon_requested.connect(func() -> void: heard.append("abandon"))
	m.quit_requested.connect(func() -> void: heard.append("quit"))
	for id in [PauseMenu.RESUME, PauseMenu.OPTIONS, PauseMenu.ABANDON, PauseMenu.QUIT]:
		m.press(String(id))
	assert_array(heard).is_equal(["resume", "options", "abandon", "quit"])


func test_rebuilding_does_not_stack_two_menus() -> void:
	var m := _menu(true)
	var before := m.buttons.size()
	m.build(TestFixtures.content(), true)
	assert_int(m.buttons.size()).is_equal(before)
