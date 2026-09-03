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


func test_every_shipped_card_has_its_own_art() -> void:
	var content := TestFixtures.content()
	for card_id in content.cards:
		assert_object(Icons.get_icon("card_art", String(card_id))) \
			.override_failure_message("no art for card %s" % card_id).is_not_null()


func test_cards_that_do_different_things_look_different() -> void:
	# Strike and Last Rites shared a silhouette, so a player had to read the
	# text of every card in hand rather than recognising it.
	var content := TestFixtures.content()
	var seen := {}
	for card_id in content.cards:
		var art := Icons.get_icon("card_art", String(card_id))
		assert_bool(seen.has(art)) \
			.override_failure_message("%s reuses another card's icon" % card_id).is_false()
		seen[art] = card_id


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


## The art pipeline's delivery contract. ART_BRIEF.md tells an artist to drop
## `<id>.png` into assets/icons/card_art/ and see it in the game; before this
## the loader only ever looked for `.svg`, so a delivered PNG silently did
## nothing. Resolution takes a root so this can be proven against files the
## test makes itself rather than against shipped assets.
func _icon_root() -> String:
	var root := "user://icon_resolve_test"
	DirAccess.make_dir_recursive_absolute(root + "/card_art")
	return root


func _write(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("x")
	f.close()


func test_a_delivered_png_wins_over_the_placeholder_svg() -> void:
	var root := _icon_root()
	_write(root + "/card_art/both.png")
	_write(root + "/card_art/both.svg")
	assert_str(Icons.resolve("card_art", "both", root)).ends_with(".png")


func test_an_svg_still_resolves_when_no_png_was_delivered() -> void:
	var root := _icon_root()
	_write(root + "/card_art/svg_only.svg")
	assert_str(Icons.resolve("card_art", "svg_only", root)).ends_with(".svg")


func test_an_undelivered_id_resolves_to_nothing() -> void:
	assert_str(Icons.resolve("card_art", "no_such_card", _icon_root())).is_empty()


## Generated art ships under assets/ and the loader prefers it, so a missing
## or misnamed file has to be a red test rather than a silent fall back to
## the placeholder glyph -- the fallback is what makes a bad delivery
## invisible.
func test_every_shipped_card_resolves_to_a_file() -> void:
	var content := TestFixtures.content()
	var missing: Array[String] = []
	for def_id in content.cards:
		if Icons.resolve("card_art", String(def_id)) == "":
			missing.append(String(def_id))
	assert_array(missing) \
		.override_failure_message("no art at all for: %s" % ", ".join(missing)) \
		.is_empty()


func test_the_attribution_declares_the_generated_art() -> void:
	# Shipping generated art obliges a Steam AI disclosure. If the art is in
	# the build, the paperwork saying so has to be too.
	var f := FileAccess.open("res://ATTRIBUTION.md", FileAccess.READ)
	assert_object(f).is_not_null()
	var text := f.get_as_text()
	assert_str(text).contains("Stable Diffusion XL")
	assert_str(text).contains("disclos")


## Every upgrade needs a glyph. The Guild is a wall of tablets found by
## shape rather than by reading ten names, so one without an icon is not a
## missing detail -- it is a blank tablet that reads as a broken build.
func test_every_shipped_upgrade_has_an_icon() -> void:
	var content := TestFixtures.content()
	var missing: Array[String] = []
	for def_id in content.upgrades:
		if Icons.get_icon("upgrade", String(def_id)) == null:
			missing.append(String(def_id))
	assert_array(missing) \
		.override_failure_message("blank tablets on: %s" % ", ".join(missing)) \
		.is_empty()
