extends GdUnitTestSuite
## The guild sending someone down (spec §3.5), and the clock that pays for it.
##
## Two properties carry this whole feature. **Resolution must not simulate** --
## it happens on load, after an absence that may have finished several, and a
## game that plays fights before it can draw a menu looks broken. And **the
## clock must be honest**: an idle game that miscounts an absence is a broken
## idle game, so the same window has to pay the same Soul however it is cut.


func _campaign(unlocked: bool = true) -> Campaign:
	var c := CampaignEngine.new_campaign(TestFixtures.content(), 4242, 0)
	c.sim_fights = 2
	if unlocked:
		c.upgrades.levels["expedition"] = 1
	return c


func _fast(c: Campaign) -> void:
	# The real pace is two minutes a floor; these tests care about ordering,
	# not about waiting.
	c.content.balance["expedition_seconds_per_floor"] = 60
	c.content.balance["expedition_samples"] = 2
	c.content.balance["expedition_sim_fights"] = 2


# ------------------------------------------------------------------- the lock

func test_nobody_goes_anywhere_until_the_upgrade_is_bought() -> void:
	var c := _campaign(false)
	assert_bool(Expeditions.unlocked(c)).is_false()
	assert_bool(Expeditions.can_launch(c)).is_false()
	var r := Expeditions.launch(c, 0)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(String(r["reason"])).is_equal("locked")
	assert_array(c.expeditions).is_empty()


func test_one_at_a_time_until_slots_are_bought() -> void:
	var c := _campaign()
	_fast(c)
	assert_int(Expeditions.slots(c)).is_equal(1)
	assert_bool(bool(Expeditions.launch(c, 0)["ok"])).is_true()
	var second := Expeditions.launch(c, 0)
	assert_bool(bool(second["ok"])).is_false()
	assert_str(String(second["reason"])).is_equal("full")
	c.upgrades.levels["expedition_slots"] = 1
	assert_int(Expeditions.slots(c)).is_equal(2)
	assert_bool(bool(Expeditions.launch(c, 0)["ok"])).is_true()


# ------------------------------------------------------------------ the plan

func test_it_sends_someone_somewhere_within_reach() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	assert_int(e.ghost.floor).is_greater_equal(1)
	assert_int(e.ghost.floor).override_failure_message("walked past reach") \
		.is_less_equal(maxi(1, CampaignEngine.reach(c)))


func test_a_deeper_expedition_takes_longer() -> void:
	var c := _campaign()
	assert_int(Expeditions.duration_seconds(c, 5)).is_greater(Expeditions.duration_seconds(c, 2))


func test_the_speed_upgrade_makes_it_faster() -> void:
	var c := _campaign()
	var slow := Expeditions.duration_seconds(c, 4)
	c.upgrades.levels["expedition_speed"] = 3
	assert_int(Expeditions.duration_seconds(c, 4)).is_less(slow)


func test_the_hero_it_sends_drafts_on_the_way_down() -> void:
	# Spec §3.5: the expedition hero descends "with auto-draft". Entering at
	# floor 4 means three skipped floors and three picks on top of the ten
	# starting cards.
	var c := _campaign()
	var klass: ClassDef = c.content.classes["sexton"]
	var shallow := Expeditions.hero_for(c, 1, 7)
	var deep := Expeditions.hero_for(c, 4, 7)
	assert_int(shallow.deck.size()).is_equal(klass.starting_deck.size())
	assert_int(deep.deck.size()).is_equal(klass.starting_deck.size() + 3)


func test_the_guild_trains_people_the_way_its_master_fights() -> void:
	var c := _campaign()
	c.hero.rules = ["poison_before_blades", "hold_the_line"]
	assert_array(Expeditions.hero_for(c, 2, 7).rules).is_equal(c.hero.rules)


# ------------------------------------------------------------------ the ghost

func test_what_comes_back_is_a_ghost_that_counts() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	assert_str(e.ghost.kind).is_equal("expedition")
	assert_bool(e.ghost.is_true()) \
		.override_failure_message("spec §5.1: it counts as true for the waypoint").is_true()
	assert_bool(e.ghost.prepared) \
		.override_failure_message("only manual play earns the prepared bonus").is_false()
	assert_bool(e.ghost.restless).is_false()
	assert_str(e.ghost.name).is_not_empty()


func test_its_strength_is_priced_once_and_never_again() -> void:
	# `fixed_strength` is what makes resolution free. Without it, loading after
	# an absence runs a fifty-fight simulation per expedition that landed.
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	assert_bool(e.ghost.fixed_strength).is_true()
	assert_float(e.ghost.strength).is_greater(0.0)
	assert_float(CampaignEngine.strength_for(c, e.ghost)).is_equal(e.ghost.strength)


func test_an_expedition_ghost_raises_the_waypoint() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	Expeditions.resolve_due(c, e.done_at())
	assert_int(c.ladder.waypoint()).is_greater_equal(e.ghost.floor)


# ------------------------------------------------------------------ the clock

func test_it_lands_when_its_time_is_up_and_not_before() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	var before := c.ladder.ghosts.size()
	assert_array(Expeditions.resolve_due(c, e.done_at() - 1)).is_empty()
	assert_int(c.ladder.ghosts.size()).is_equal(before)
	assert_array(Expeditions.resolve_due(c, e.done_at())).has_size(1)
	assert_int(c.ladder.ghosts.size()).is_equal(before + 1)
	assert_array(c.expeditions).is_empty()


func test_resolving_twice_does_not_place_it_twice() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	Expeditions.resolve_due(c, e.done_at())
	var after := c.ladder.ghosts.size()
	assert_array(Expeditions.resolve_due(c, e.done_at() + 10_000)).is_empty()
	assert_int(c.ladder.ghosts.size()).is_equal(after)


func test_progress_reads_zero_to_one_and_stops_there() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 1000)["expedition"]
	assert_float(e.progress(1000)).is_equal(0.0)
	assert_float(e.progress(e.done_at())).is_equal(1.0)
	assert_float(e.progress(e.done_at() + 99_999)).is_equal(1.0)
	assert_int(e.remaining(e.done_at() + 5)).is_equal(0)


func test_the_tick_pays_the_same_however_the_window_is_cut() -> void:
	# The property the segmented clock exists for. With nothing in flight, a
	# window ticked once and the same window ticked ten times must agree --
	# otherwise the segmenting itself is a payout bug.
	var one := _campaign(false)
	var many := _campaign(false)
	CampaignEngine.refresh_rate(one)
	CampaignEngine.refresh_rate(many)
	CampaignEngine.tick(one, 3600)
	for i in range(1, 11):
		CampaignEngine.tick(many, i * 360)
	assert_float(many.soul).is_equal_approx(one.soul, 0.0001)


func test_an_absence_pays_for_the_ghost_that_landed_inside_it() -> void:
	# The bug this whole design is about: one `Production.accrue` across the
	# window integrates the OLD rate for all of it, so the ghost that landed
	# an hour in earns nothing for the seven hours it stood there.
	var c := _campaign()
	_fast(c)
	CampaignEngine.refresh_rate(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	var flat := c.rate_per_hour * 4.0
	var result := CampaignEngine.tick(c, 4 * 3600)
	assert_array(result["returned"]).has_size(1)
	assert_float(float(result["soul"])) \
		.override_failure_message("the returned ghost earned nothing") \
		.is_greater(flat)


func test_the_offline_cap_still_caps() -> void:
	# Cutting a window into more pieces must never pay more than leaving it
	# whole, which is exactly what a per-segment cap would do.
	var c := _campaign()
	_fast(c)
	CampaignEngine.refresh_rate(c)
	var e: Expedition = Expeditions.launch(c, 0)["expedition"]
	var cap_hours := float(c.modifiers()["offline_cap_hours"])
	var result := CampaignEngine.tick(c, int(cap_hours * 3600.0) * 4)
	assert_bool(bool(result["capped"])).is_true()
	assert_int(int(result["counted"])).is_equal(int(round(cap_hours * 3600.0)))


func test_an_expedition_still_lands_past_the_cap() -> void:
	# The cap limits what the ladder PAYS for an absence, not what happened
	# during it. Coming back after a week to find the expedition still in the
	# field would be a bug, not a rule.
	var c := _campaign()
	_fast(c)
	CampaignEngine.refresh_rate(c)
	Expeditions.launch(c, 0)
	var result := CampaignEngine.tick(c, 7 * 24 * 3600)
	assert_array(result["returned"]).has_size(1)
	assert_array(c.expeditions).is_empty()


func test_resolution_does_not_simulate() -> void:
	# Asserted by the clock, which is the only observable that matters: a
	# resolution that simulated would take a great deal longer than this.
	var c := _campaign()
	_fast(c)
	c.content.balance["expedition_sim_fights"] = 2
	Expeditions.launch(c, 0)
	var started := Time.get_ticks_msec()
	CampaignEngine.tick(c, 30 * 24 * 3600)
	assert_int(Time.get_ticks_msec() - started) \
		.override_failure_message("resolution is doing real work").is_less(120)


# ------------------------------------------------------------------- the save

func test_an_expedition_in_flight_survives_a_save() -> void:
	var c := _campaign()
	_fast(c)
	var e: Expedition = Expeditions.launch(c, 500)["expedition"]
	var back := Campaign.from_dict(c.content, c.to_dict())
	assert_array(back.expeditions).has_size(1)
	var loaded: Expedition = back.expeditions[0]
	assert_int(loaded.id).is_equal(e.id)
	assert_int(loaded.done_at()).is_equal(e.done_at())
	assert_int(loaded.ghost.floor).is_equal(e.ghost.floor)
	assert_float(loaded.ghost.strength).is_equal_approx(e.ghost.strength, 0.0001)
	assert_str(loaded.ghost.kind).is_equal("expedition")
	assert_int(back.expedition_counter).is_equal(c.expedition_counter)


func test_a_save_from_before_expeditions_existed_still_loads() -> void:
	var c := _campaign(false)
	var raw := c.to_dict()
	raw.erase("expeditions")
	raw.erase("expedition_counter")
	var back := Campaign.from_dict(c.content, raw)
	assert_array(back.expeditions).is_empty()
	assert_int(back.expedition_counter).is_equal(0)
