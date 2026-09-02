extends GdUnitTestSuite
## The rite (spec §6.1): what a prestige keeps and what it takes.
##
## This is the riskiest list in the game. Keep too little and a player loses
## progress they earned; keep too much and the reset is free. So it is asserted
## field by field rather than "the campaign still looks about right".


func _campaign() -> Campaign:
	var c := CampaignEngine.new_campaign(TestFixtures.content(), 4242, 0)
	c.sim_fights = 2
	return c


func _plant(c: Campaign, floor: int, strength: float = 120.0) -> Ghost:
	var hero := Hero.create(c.content, "sexton", "Deepwalker", {}, 1)
	var g := c.ladder.add(Ghost.from_expedition(hero, floor, 0))
	g.strength = strength
	g.fixed_strength = true
	return g


func _ready_to_prestige() -> Campaign:
	var c := _campaign()
	_plant(c, 15)
	c.soul = 9000.0
	c.record_depth = 22
	c.upgrades.levels["might"] = 3
	CampaignEngine.refresh_rate(c)
	return c


# ----------------------------------------------------------------- the gate

func test_it_is_refused_until_someone_stands_deep_enough() -> void:
	var c := _campaign()
	_plant(c, 14)
	assert_bool(CampaignEngine.can_prestige(c)).is_false()
	var r := CampaignEngine.prestige(c, 1000)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(String(r["reason"])).is_equal("too_shallow")
	assert_array(c.legends).is_empty()


func test_an_echo_standing_deep_does_not_open_the_rite() -> void:
	# The waypoint is computed from standing *true* ghosts, and an echo you
	# bought is not a hero who got there.
	var c := _campaign()
	var source := _plant(c, 4)
	c.ladder.add(source.clone_as_echo(15, 0))
	assert_bool(CampaignEngine.can_prestige(c)).is_false()


func test_it_is_refused_mid_run() -> void:
	var c := _ready_to_prestige()
	CampaignEngine.start_run(c, 1, 100)
	var r := CampaignEngine.prestige(c, 1000)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(String(r["reason"])).is_equal("in_run")


func test_the_bar_rises_with_every_legend() -> void:
	var c := _ready_to_prestige()
	assert_int(CampaignEngine.prestige_threshold(c)).is_equal(15)
	assert_bool(CampaignEngine.prestige(c, 1000)["ok"]).is_true()
	assert_int(CampaignEngine.prestige_threshold(c)).is_equal(30)


# ---------------------------------------------------------------- what stays

func test_it_keeps_what_you_earned_by_going_deep() -> void:
	# Spec §6.1: reach, unlocks, biome claims, upgrades, Legends, Ink.
	var c := _ready_to_prestige()
	var reach_before := c.record_depth
	var might := c.upgrades.level("might")
	var watch := c.onboarding.watch_unlocked
	assert_bool(bool(CampaignEngine.prestige(c, 1000)["ok"])).is_true()
	assert_int(c.record_depth).override_failure_message("reach was reset").is_equal(reach_before)
	assert_int(c.upgrades.level("might")).is_equal(might)
	assert_bool(c.onboarding.watch_unlocked).is_equal(watch)
	assert_int(c.ink).is_equal(1)
	assert_array(c.legends).has_size(1)


func test_the_next_cycle_starts_at_the_old_frontier() -> void:
	# "Because reach persists, the next cycle starts with a Descent straight to
	# the old frontier, not a replay." Reach is the whole point of prestige.
	var c := _ready_to_prestige()
	CampaignEngine.prestige(c, 1000)
	assert_int(CampaignEngine.reach(c)).is_equal(22)


# ---------------------------------------------------------------- what goes

func test_the_ladder_is_wiped_down_to_a_new_founder() -> void:
	var c := _ready_to_prestige()
	_plant(c, 8)
	CampaignEngine.prestige(c, 1000)
	assert_array(c.ladder.ghosts).override_failure_message(
		"the new cycle should start with exactly one Founder").has_size(1)
	assert_int((c.ladder.ghosts[0] as Ghost).floor).is_equal(1)
	assert_str((c.ladder.ghosts[0] as Ghost).cause).is_equal("founder")


func test_the_soul_is_gone_and_the_rate_is_recomputed() -> void:
	var c := _ready_to_prestige()
	CampaignEngine.prestige(c, 1000)
	assert_float(c.soul).is_equal(0.0)
	assert_float(c.rate_per_hour).is_greater(0.0)


func test_expeditions_in_the_field_do_not_survive_the_rite() -> void:
	# They would land into the next cycle carrying the last one's strength.
	var c := _ready_to_prestige()
	c.upgrades.levels["expedition"] = 1
	c.content.balance["expedition_samples"] = 1
	c.content.balance["expedition_sim_fights"] = 2
	Expeditions.launch(c, 900)
	assert_array(c.expeditions).is_not_empty()
	CampaignEngine.prestige(c, 1000)
	assert_array(c.expeditions).is_empty()


func test_the_living_hero_starts_again() -> void:
	var c := _ready_to_prestige()
	c.hero.camp = 12
	CampaignEngine.prestige(c, 1000)
	assert_int(c.hero.camp).override_failure_message(
		"the new hero inherited the last cycle's camp").is_equal(0)
	assert_int(c.hero.runs).is_equal(0)


# ------------------------------------------------------------- the memorial

func test_nobody_is_forgotten() -> void:
	var c := _ready_to_prestige()
	_plant(c, 8)
	var names: Array[String] = []
	for g in c.ladder.ghosts:
		names.append((g as Ghost).name)
	CampaignEngine.prestige(c, 1000)
	var kept: Array[String] = []
	for row in (c.legends[0] as Legend).epitaphs:
		kept.append(String(row["name"]))
	for name in names:
		assert_bool(kept.has(name)).override_failure_message(
			"%s was merged and forgotten" % name).is_true()


func test_the_rite_is_announced() -> void:
	var c := _ready_to_prestige()
	CampaignEngine.prestige(c, 1000)
	var events: Array = TestFixtures.campaign_events_of(c, "prestige")
	assert_array(events).has_size(1)
	assert_int(int(events[0]["cycle"])).is_equal(1)
	assert_float(float(events[0]["multiplier"])).is_greater(1.0)


# ------------------------------------------------------------------ the save

func test_a_legend_survives_the_save_file() -> void:
	var c := _ready_to_prestige()
	CampaignEngine.prestige(c, 1000)
	var back := Campaign.from_dict(c.content, c.to_dict())
	assert_array(back.legends).has_size(1)
	assert_int(back.ink).is_equal(c.ink)
	assert_float((back.legends[0] as Legend).multiplier) \
		.is_equal_approx((c.legends[0] as Legend).multiplier, 0.0001)
	assert_float(CampaignEngine.blessing(back)).is_equal_approx(CampaignEngine.blessing(c), 0.0001)


func test_a_save_from_before_legends_existed_still_loads() -> void:
	var c := _campaign()
	var raw := c.to_dict()
	raw.erase("legends")
	raw.erase("ink")
	var back := Campaign.from_dict(c.content, raw)
	assert_array(back.legends).is_empty()
	assert_int(back.ink).is_equal(0)
	assert_float(CampaignEngine.blessing(back)).is_equal(1.0)
