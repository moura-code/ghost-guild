extends GdUnitTestSuite


func test_focus_reads_the_next_authored_threshold_and_current_benefits() -> void:
	var c := Content.load_from("res://data")
	assert_str(MechanicsText.stat(c, "focus", 2)).contains("3")
	assert_str(MechanicsText.stat(c, "focus", 3)).contains("6")
	assert_str(MechanicsText.stat(c, "focus", 12)).contains(c.text("help.focus.capped"))
	c.balance["focus_draw_thresholds"] = [4, 10]
	assert_str(MechanicsText.stat(c, "focus", 2)).contains("4")


func test_scaling_only_explains_marked_effects_and_retains_full_rules() -> void:
	var c := TestFixtures.content()
	var brace := CardInstance.new(1, "brace")
	var text := MechanicsText.card_details(c, brace, {"wit": 2})
	assert_str(text).contains("5 + 2")
	assert_str(text).contains("7")
	assert_str(text).contains(CardText.of(c, c.cards["brace"], false))
	assert_str(MechanicsText.scaling(c, c.cards["strike"], false, {"wit": 9, "might": 1})).contains("6 + 1")


func test_cost_changing_upgrade_compares_cost_and_preserves_uid_and_scope() -> void:
	var c := Content.load_from("res://data")
	var hero := TestFixtures.hero()
	var def: CardDef = c.cards["strike"]
	def.upgrade_cost = 0
	var copy := hero.deck[0]
	var text := MechanicsText.comparison(c, hero, copy.uid)
	assert_str(text).contains("1 → 0")
	assert_str(text).contains(hero.name)
	assert_bool(copy.upgraded).is_false()


func test_event_preview_caps_healing_and_warns_about_lethal_sacrifices() -> void:
	var run := TestFixtures.new_run()
	var well: EventDef = run.content.events["whispering_well"]
	run.hero.hp = run.hero.max_hp - 2
	var before := run.to_dict()
	assert_str(MechanicsText.event_choice(run, well.choices[0])).contains("Heal 2")
	assert_dict(run.to_dict()).is_equal(before)
	run.hero.hp = 7
	assert_str(MechanicsText.event_choice(run, well.choices[1])).contains(run.content.text("help.event.lethal"))
