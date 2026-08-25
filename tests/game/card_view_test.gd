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
