extends GdUnitTestSuite
## The second prestige layer (spec §6.2). Ink has existed since Legends
## shipped and bought nothing.
##
## The property everything hangs off is the same one the layer below it has: a
## guild with no Chapters plays the game exactly as it was. Everything here is
## an identity at zero, and the demos prove it.


func _campaign(legends: int = 6, ink: int = 20) -> Campaign:
	var c := TestFixtures.campaign()
	for i in legends:
		var l := Legend.new()
		l.id = i + 1
		l.cycle = i + 1
		l.multiplier = 1.0
		c.legends.append(l)
	c.ink = ink
	return c


# ------------------------------------------------------------- the identity

func test_a_guild_with_no_chapters_plays_the_game_it_always_played() -> void:
	var c := TestFixtures.campaign()
	assert_int(Chronicle.founder_floor(c)).is_equal(1)
	assert_float(Chronicle.spawn(c)).is_equal(1.0)
	assert_float(Chronicle.soul_kept(c)).is_equal(0.0)
	assert_int(Chronicle.seals_available(c)).is_equal(0)


func test_an_unsealed_descent_is_the_descent_the_game_is_balanced_around() -> void:
	var c := TestFixtures.content()
	assert_float(Chronicle.seal_scaling(c, 0)).is_equal(1.0)
	assert_float(Chronicle.seal_yield(c, 0)).is_equal(1.0)
	assert_int(Scaling.enemy_hp(30, 5, c.balance, 1, 1.0)).is_equal(
		Scaling.enemy_hp(30, 5, c.balance, 1))


# --------------------------------------------------------------- the opening

func test_the_chronicle_is_shut_until_the_guild_has_run_the_loop() -> void:
	# A layer that only pays across cycles is noise until there have been
	# several of them.
	var early := _campaign(1)
	assert_bool(Chronicle.is_open(early)).is_false()
	var r := Chronicle.write(early, "breeding_dark", 1000)
	assert_bool(r["ok"]).is_false()
	assert_str(String(r["reason"])).is_equal("locked")


func test_it_opens_at_the_authored_threshold() -> void:
	var c := _campaign(Chronicle.threshold(TestFixtures.content()))
	assert_bool(Chronicle.is_open(c)).is_true()


# ---------------------------------------------------------------- the writing

func test_writing_a_chapter_spends_ink_and_sticks() -> void:
	var c := _campaign()
	var price := Chronicle.cost_of(c, "breeding_dark")
	assert_int(price).is_greater(0)
	var purse := c.ink
	assert_bool(Chronicle.write(c, "breeding_dark", 1000)["ok"]).is_true()
	assert_int(c.ink).is_equal(purse - price)
	assert_int(Chronicle.level_of(c, "breeding_dark")).is_equal(1)


func test_each_level_costs_more_than_the_last() -> void:
	# Ink arrives one per rite, so the curve has to be linear rather than
	# geometric or the fourth level of anything is unreachable.
	var c := _campaign()
	var first := Chronicle.cost_of(c, "breeding_dark")
	Chronicle.write(c, "breeding_dark", 1000)
	assert_int(Chronicle.cost_of(c, "breeding_dark")).is_greater(first)


func test_a_finished_chapter_cannot_be_written_again() -> void:
	var c := _campaign(6, 500)
	var def: ChapterDef = c.content.chapters["old_blood"]
	for i in def.max_level:
		assert_bool(Chronicle.write(c, "old_blood", 1000)["ok"]).is_true()
	assert_int(Chronicle.cost_of(c, "old_blood")).is_equal(-1)
	var r := Chronicle.write(c, "old_blood", 1000)
	assert_bool(r["ok"]).is_false()
	assert_str(String(r["reason"])).is_equal("finished")


func test_a_guild_with_no_ink_is_refused_rather_than_put_in_debt() -> void:
	var c := _campaign(6, 0)
	var r := Chronicle.write(c, "breeding_dark", 1000)
	assert_bool(r["ok"]).is_false()
	assert_str(String(r["reason"])).is_equal("ink")
	assert_int(c.ink).is_equal(0)


func test_a_chapter_nobody_wrote_is_not_a_chapter() -> void:
	var c := _campaign()
	assert_bool(Chronicle.write(c, "no_such_chapter", 1000)["ok"]).is_false()


func test_the_chronicle_survives_a_save() -> void:
	var c := _campaign()
	Chronicle.write(c, "breeding_dark", 1000)
	var back := Campaign.from_dict(c.content, c.to_dict())
	assert_int(Chronicle.level_of(back, "breeding_dark")).is_equal(1)
	assert_int(back.ink).is_equal(c.ink)


# ------------------------------------------------------------- what it buys

func test_the_breeding_dark_makes_every_floor_bigger() -> void:
	var c := _campaign()
	var before := float(c.modifiers()["global_spawn"])
	Chronicle.write(c, "breeding_dark", 1000)
	assert_float(float(c.modifiers()["global_spawn"])).override_failure_message(
		"the Chronicle bought a number nothing reads").is_greater(before)


func test_the_breeding_dark_multiplies_the_upgrade_rather_than_replacing_it() -> void:
	# A guild with both should get both.
	var c := _campaign()
	c.upgrades.levels = {"ghost_spawn": 2}
	var upgraded := float(c.modifiers()["global_spawn"])
	Chronicle.write(c, "breeding_dark", 1000)
	assert_float(float(c.modifiers()["global_spawn"])).is_greater(upgraded)


func test_deeper_roots_stands_the_next_founder_further_down() -> void:
	var c := _campaign()
	assert_int(Chronicle.founder_floor(c)).is_equal(1)
	Chronicle.write(c, "deeper_roots", 1000)
	assert_int(Chronicle.founder_floor(c)).is_greater(1)


func test_old_blood_keeps_some_of_the_soul_through_the_rite() -> void:
	var c := _campaign()
	Chronicle.write(c, "old_blood", 1000)
	assert_float(Chronicle.soul_kept(c)).is_greater(0.0)
	assert_float(Chronicle.soul_kept(c)).override_failure_message(
		"the rite stopped being a reset").is_less(1.0)


func test_the_rite_honours_the_chronicle() -> void:
	# The wiring, not the arithmetic. Prestige is the one place these two
	# chapters are read, and a prestige that forgot them would look exactly
	# like a Chronicle nobody had written.
	var c := TestFixtures.campaign()
	c.chapters = {"deeper_roots": 1, "old_blood": 1}
	c.soul = 1000.0
	c.record_depth = 60
	TestFixtures.end_at_exit(c, CampaignEngine.prestige_threshold(c), "watch", 3000)
	var r := CampaignEngine.prestige(c, 4000)
	if not bool(r["ok"]):
		return
	assert_float(c.soul).override_failure_message(
		"Old Blood kept nothing").is_greater(0.0)
	assert_int(c.ladder.ghosts[0].floor).override_failure_message(
		"the new Founder stood on floor 1 with Deeper Roots written").is_greater(1)


# ------------------------------------------------------------- the deep seals

func test_a_seal_cannot_be_set_before_it_is_written() -> void:
	var c := _campaign()
	assert_int(Chronicle.seals_available(c)).is_equal(0)
	assert_bool(CampaignEngine.set_seal(c, 1, 1000)).is_false()
	assert_int(c.seal).is_equal(0)


func test_a_written_seal_can_be_set_and_unset() -> void:
	var c := _campaign()
	Chronicle.write(c, "depth_seals", 1000)
	assert_int(Chronicle.seals_available(c)).is_equal(1)
	assert_bool(CampaignEngine.set_seal(c, 1, 1000)).is_true()
	assert_int(c.seal).is_equal(1)
	assert_bool(CampaignEngine.set_seal(c, 0, 1000)).is_true()
	assert_int(c.seal).is_equal(0)


func test_a_seal_makes_the_dungeon_harder() -> void:
	var c := TestFixtures.content()
	assert_int(Scaling.enemy_hp(30, 5, c.balance, 1, Chronicle.seal_scaling(c, 2))) \
		.is_greater(Scaling.enemy_hp(30, 5, c.balance, 1))


func test_a_seal_pays_better_than_it_costs() -> void:
	# An opt-in difficulty that pays less than not opting in is a feature
	# nobody has.
	var c := TestFixtures.content()
	for seal in [1, 2, 3]:
		assert_float(Chronicle.seal_yield(c, seal)).override_failure_message(
			"seal %d is harder than it is worth" % seal) \
			.is_greater(Chronicle.seal_scaling(c, seal))


func test_the_run_carries_the_seal_it_started_under() -> void:
	var run := RunEngine.start_run(TestFixtures.content(), TestFixtures.hero(), 1, 42,
		true, [], 1.0, 0, "", 2)
	assert_int(run.seal).is_equal(2)
	assert_float(run.seal_scaling()).is_greater(1.0)
	assert_int(RunState.from_dict(run.content, run.to_dict()).seal).is_equal(2)


func test_a_ghost_left_under_a_seal_is_worth_more_for_ever() -> void:
	# And keeps the seal, so a later tend re-prices it with the seal still on
	# rather than washing it off.
	var c := TestFixtures.campaign()
	var hero := Hero.create(c.content, Classes.starting(c.content), "Sealed", {}, 1)
	var plain := Ghost.from_expedition(hero, 4, 1000)
	plain.kind = "true"
	plain.fixed_strength = false
	var sealed := Ghost.from_expedition(hero, 4, 1000)
	sealed.kind = "true"
	sealed.fixed_strength = false
	sealed.seal = 2
	c.ladder.add(plain)
	c.ladder.add(sealed)
	assert_float(CampaignEngine.strength_for(c, sealed)).override_failure_message(
		"the Seal bought nothing").is_greater(CampaignEngine.strength_for(c, plain))
	assert_int(Ghost.from_dict(sealed.to_dict()).seal).is_equal(2)
