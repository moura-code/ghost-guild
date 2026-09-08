extends GdUnitTestSuite
## The game used to drop you straight into whatever the save file said, with
## no title, no way to start over, and no moment before it began.


func _menu(has_save: bool) -> TitleMenu:
	var m: TitleMenu = auto_free(TitleMenu.new())
	add_child(m)
	m.build(TestFixtures.content(), has_save)
	return m


func test_a_fresh_install_is_not_offered_a_game_to_continue() -> void:
	# Offering Continue on a fresh install, and having it do the same thing as
	# New, is how a menu teaches the player that its buttons are decorative.
	var m := _menu(false)
	assert_bool(m.buttons.has(TitleMenu.CONTINUE)).is_false()
	assert_bool(m.buttons.has(TitleMenu.NEW)).is_true()


func test_a_saved_guild_can_be_continued() -> void:
	assert_bool(_menu(true).buttons.has(TitleMenu.CONTINUE)).is_true()


func test_options_and_quit_are_always_there() -> void:
	for has_save in [true, false]:
		var m := _menu(has_save)
		assert_bool(m.buttons.has(TitleMenu.OPTIONS)).is_true()
		assert_bool(m.buttons.has(TitleMenu.QUIT)).is_true()


func test_it_says_the_name_of_the_game() -> void:
	var m := _menu(true)
	var titles: Array = []
	for child in m.find_children("*", "Label", true, false):
		titles.append((child as Label).text)
	assert_array(titles).contains([TestFixtures.content().text("ui.menu.title")])


func test_every_button_says_something_real() -> void:
	var m := _menu(true)
	for id in m.buttons:
		var label: String = (m.buttons[id] as Button).text
		assert_str(label).is_not_empty()
		assert_bool(label.begins_with("ui.")).is_false()


func test_each_button_reports_what_it_is() -> void:
	var m := _menu(true)
	var heard: Array = []
	m.continued.connect(func() -> void: heard.append("continue"))
	m.started_new.connect(func() -> void: heard.append("new"))
	m.options_requested.connect(func() -> void: heard.append("options"))
	m.quit_requested.connect(func() -> void: heard.append("quit"))
	for id in [TitleMenu.CONTINUE, TitleMenu.NEW, TitleMenu.OPTIONS, TitleMenu.QUIT]:
		m.press(String(id))
	assert_array(heard).is_equal(["continue", "new", "options", "quit"])
