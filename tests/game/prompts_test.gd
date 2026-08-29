extends GdUnitTestSuite


func _prompts() -> Prompts:
	var p: Prompts = auto_free(Prompts.new())
	add_child(p)
	p.size = Vector2(640.0, 360.0)
	return p


func test_the_floor_banner_announces_and_then_gets_out_of_the_way() -> void:
	var p := _prompts()
	p.announce("Floor 3")
	assert_str(p.banner.text).is_equal("Floor 3")
	assert_bool(p.is_announcing()).is_true()


func test_a_prompt_shows_and_clears() -> void:
	var p := _prompts()
	assert_bool(p.has_prompt()).is_false()
	p.show_prompt("Descend")
	assert_bool(p.has_prompt()).is_true()
	p.clear_prompt()
	assert_bool(p.has_prompt()).is_false()


func test_announcing_twice_does_not_leave_two_banners_fading() -> void:
	var p := _prompts()
	p.announce("Floor 1")
	p.announce("Floor 2")
	assert_str(p.banner.text).is_equal("Floor 2")
	assert_float(p.banner.modulate.a).is_equal(1.0)


func test_it_never_swallows_a_click_meant_for_a_card() -> void:
	var p := _prompts()
	assert_int(p.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(p.banner.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(p.prompt.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
