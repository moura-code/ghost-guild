extends GdUnitTestSuite
## Guards the third-party assets in assets/. These are the only files in the
## project that came from outside it, and a silently-missing font or icon
## degrades quietly rather than failing loudly — so it gets pinned here.


func test_both_fonts_are_present_and_load() -> void:
	assert_bool(ResourceLoader.exists(UiTheme.BODY_FONT_PATH)).is_true()
	assert_bool(ResourceLoader.exists(UiTheme.TITLE_FONT_PATH)).is_true()
	assert_object(UiTheme.body_font()).is_not_null()
	assert_object(UiTheme.title_font()).is_not_null()


func test_the_theme_actually_uses_the_body_font() -> void:
	var t := UiTheme.build()
	assert_object(t.default_font).is_not_null()
	assert_object(t.get_font("font", "Label")).is_same(UiTheme.body_font())
	assert_object(t.get_font("font", "Button")).is_same(UiTheme.body_font())


func test_titles_are_set_in_the_display_serif() -> void:
	var l: Label = auto_free(UiTheme.title("Ilse"))
	assert_object(l.get_theme_font("font")).is_same(UiTheme.title_font())
	assert_object(UiTheme.title_font()).is_not_same(UiTheme.body_font())


func test_every_shipped_enemy_has_an_icon() -> void:
	var content := TestFixtures.content()
	for def_id in content.enemies:
		assert_object(Icons.enemy(String(def_id))) \
			.override_failure_message("no icon for enemy %s" % def_id).is_not_null()


func test_every_shipped_relic_has_an_icon() -> void:
	var content := TestFixtures.content()
	for relic_id in content.relics:
		assert_object(Icons.relic(String(relic_id))) \
			.override_failure_message("no icon for relic %s" % relic_id).is_not_null()


func test_every_status_the_validator_allows_has_an_icon() -> void:
	for name in ContentValidator.STATUSES:
		assert_object(Icons.status(String(name))) \
			.override_failure_message("no icon for status %s" % name).is_not_null()


func test_every_card_type_has_an_icon() -> void:
	for type in ["attack", "skill", "power"]:
		assert_object(Icons.card_type(type)) \
			.override_failure_message("no icon for card type %s" % type).is_not_null()


func test_a_missing_icon_returns_null_rather_than_throwing() -> void:
	assert_object(Icons.get_icon("enemies", "no_such_enemy")).is_null()
	assert_object(Icons.get_icon("nonsense", "at_all")).is_null()


func test_icons_are_cached_so_a_redraw_does_not_hit_the_disk() -> void:
	var first := Icons.enemy("bone_rat")
	var second := Icons.enemy("bone_rat")
	assert_object(second).is_same(first)


func test_the_icon_rect_helper_sizes_and_tints() -> void:
	var rect: TextureRect = auto_free(Icons.make_rect(Icons.ui("soul"), 18.0, Palette.SOUL))
	assert_object(rect.texture).is_not_null()
	assert_that(rect.custom_minimum_size).is_equal(Vector2(18.0, 18.0))
	assert_that(rect.modulate).is_equal(Palette.SOUL)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_attribution_file_exists_and_names_the_licences() -> void:
	var f := FileAccess.open("res://ATTRIBUTION.md", FileAccess.READ)
	assert_object(f).is_not_null()
	var text := f.get_as_text()
	assert_str(text).contains("CC BY 3.0")
	assert_str(text).contains("game-icons.net")
	assert_str(text).contains("Open Font License")
