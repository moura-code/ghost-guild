extends GdUnitTestSuite
## A card the player cannot read is a card they cannot play. The review that
## produced the visual overhaul found rules text cut off mid-sentence in the
## reward picker -- "Deal 12 damage. Holy: 50% more against the" -- so the
## fit is pinned here, driven over every card in the game rather than a
## sample, because it is always the longest one that breaks.


func _card(def_id: String, content: Content, upgraded: bool = false) -> CardView:
	var view: CardView = auto_free(CardView.new())
	add_child(view)
	view.size = CardView.CARD_SIZE
	view.bind(content, CardInstance.new(1, def_id, upgraded), 0, true)
	return view


func test_no_card_in_the_game_has_its_rules_text_cut_off() -> void:
	var content := TestFixtures.content()
	await await_idle_frame()
	var clipped: Array[String] = []
	for def_id in content.cards:
		var view := _card(String(def_id), content)
		await await_idle_frame()
		if view._text.get_visible_line_count() < view._text.get_line_count():
			clipped.append("%s (%d of %d lines)" % [def_id,
				view._text.get_visible_line_count(), view._text.get_line_count()])
	assert_array(clipped) \
		.override_failure_message("rules text is cut off on: %s" % ", ".join(clipped)) \
		.is_empty()


func test_no_card_in_the_game_has_its_name_cut_off() -> void:
	var content := TestFixtures.content()
	await await_idle_frame()
	var clipped: Array[String] = []
	for def_id in content.cards:
		var view := _card(String(def_id), content)
		await await_idle_frame()
		if view._name.get_visible_line_count() < view._name.get_line_count():
			clipped.append(String(def_id))
	assert_array(clipped) \
		.override_failure_message("names are cut off on: %s" % ", ".join(clipped)) \
		.is_empty()


func test_an_upgraded_card_still_fits() -> void:
	# The upgrade suffix makes every name longer and some texts longer too,
	# so the worst case is an upgraded card, not a plain one.
	var content := TestFixtures.content()
	await await_idle_frame()
	var clipped: Array[String] = []
	for def_id in content.cards:
		var view := _card(String(def_id), content, true)
		await await_idle_frame()
		if view._text.get_visible_line_count() < view._text.get_line_count() \
				or view._name.get_visible_line_count() < view._name.get_line_count():
			clipped.append(String(def_id))
	assert_array(clipped) \
		.override_failure_message("upgraded cards cut off: %s" % ", ".join(clipped)) \
		.is_empty()


## A placeholder glyph and a real illustration want opposite treatment: the
## glyph is a white silhouette the card tints and centres, the illustration
## arrives lit and coloured and fills the window.
func test_an_illustrated_card_is_not_tinted() -> void:
	var content := TestFixtures.content()
	var illustrated := ""
	for def_id in content.cards:
		if Icons.has_card_art(String(def_id)):
			illustrated = String(def_id)
			break
	if illustrated == "":
		return
	var view := _card(illustrated, content)
	await await_idle_frame()
	assert_that(view._art_image.modulate).is_equal(Color.WHITE)
	assert_int(view._art_image.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)


func test_the_art_slot_crops_rather_than_spilling_over_the_card() -> void:
	var content := TestFixtures.content()
	var view := _card(String(content.cards.keys()[0]), content)
	await await_idle_frame()
	assert_bool(view._art.clip_contents) \
		.override_failure_message("a full-bleed illustration would paint over the card name") \
		.is_true()


func test_the_headroom_a_hover_needs_counts_the_scale_too() -> void:
	# A card scales about its own centre as it lifts, so it reaches higher
	# than HOVER_LIFT. A layout that budgeted only the lift printed the
	# hovered reward card over the screen's title.
	assert_float(CardView.hover_headroom()).is_greater(CardView.HOVER_LIFT)
	assert_float(CardView.hover_headroom()).is_equal_approx(
		CardView.HOVER_LIFT + CardView.CARD_SIZE.y * (CardView.HOVER_SCALE - 1.0) * 0.5, 0.001)
