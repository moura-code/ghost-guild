extends GdUnitTestSuite


func test_new_campaign_seeds_the_founder_and_a_hero() -> void:
	var c := TestFixtures.campaign(1, 1000)
	assert_array(c.ladder.ghosts).has_size(1)
	assert_str(c.ladder.ghosts[0].name).is_equal("Ilse")
	assert_int(c.ladder.waypoint()).is_equal(1)
	assert_bool(c.onboarding.founder_seeded).is_true()
	assert_bool(c.onboarding.watch_unlocked).is_false()
	assert_int(c.hero.id).is_equal(1)
	assert_bool(Hero.NAMES.has(c.hero.name)).is_true()
	assert_int(c.hero.resolve).is_equal(1)
	assert_float(c.soul).is_equal(0.0)
	assert_float(c.rate_per_hour).is_equal_approx(52.0, 0.0001)
	assert_int(CampaignEngine.reach(c)).is_equal(1)
	assert_int(c.last_tick).is_equal(1000)
	assert_object(c.run).is_null()
	assert_array(TestFixtures.campaign_events_of(c, "campaign_start")).has_size(1)


func test_same_seed_same_campaign() -> void:
	var a := TestFixtures.campaign(7)
	var b := TestFixtures.campaign(7)
	assert_str(a.hero.name).is_equal(b.hero.name)
	assert_int(a.ladder.ghosts[0].created_at).is_equal(b.ladder.ghosts[0].created_at)


func test_start_run_validates_entry_and_uses_watch_flag() -> void:
	var c := TestFixtures.campaign()
	assert_object(CampaignEngine.start_run(c, 0, 1001)).is_null()
	assert_object(CampaignEngine.start_run(c, 2, 1001)).is_null()
	var run := CampaignEngine.start_run(c, 1, 1001)
	assert_object(run).is_not_null()
	assert_bool(run.watch_unlocked).is_false()
	assert_int(c.run_counter).is_equal(1)
	assert_object(CampaignEngine.start_run(c, 1, 1002)).is_same(run)
	assert_int(c.run_counter).is_equal(1)


func test_death_places_a_restless_ghost_and_replaces_the_hero() -> void:
	var c := TestFixtures.campaign(3, 1000)
	var old_name := c.hero.name
	var result := TestFixtures.die_on_floor(c, 1, 2000)
	assert_str(result["kind"]).is_equal("death")
	assert_int(result["floor"]).is_equal(1)
	assert_bool(result["new_hero"]).is_true()
	assert_array(c.ladder.ghosts).has_size(2)
	var ghost := c.ladder.find(int(result["ghost_id"]))
	assert_str(ghost.name).is_equal(old_name)
	assert_bool(ghost.restless).is_true()
	assert_str(ghost.killer).is_equal("shambler")
	assert_str(result["epitaph"]).is_equal("%s fell to Shambler on Floor 1" % old_name)
	assert_float(ghost.strength).is_greater(0.0)
	assert_int(c.hero.id).is_equal(2)
	assert_int(c.hero.hp).is_equal(70)
	assert_bool(c.onboarding.first_death_seen).is_true()
	assert_bool(c.onboarding.watch_unlocked).is_true()
	assert_array(result["rite_events"]).has_size(2)
	assert_object(c.run).is_null()
	assert_int(c.record_depth).is_equal(0)
	assert_array(TestFixtures.campaign_events_of(c, "ghost_placed")).has_size(1)


func test_watch_places_a_prepared_ghost_and_raises_record_depth() -> void:
	var c := TestFixtures.campaign(4, 1000)
	c.onboarding.watch_unlocked = true
	var result := TestFixtures.end_at_exit(c, 3, "watch", 2000)
	assert_str(result["kind"]).is_equal("watch")
	var ghost := c.ladder.find(int(result["ghost_id"]))
	assert_bool(ghost.prepared).is_true()
	assert_int(ghost.floor).is_equal(3)
	assert_float(ghost.strength).is_greater(0.0)
	assert_int(c.record_depth).is_equal(3)
	assert_int(c.ladder.waypoint()).is_equal(3)
	assert_int(CampaignEngine.reach(c)).is_equal(3)
	assert_int(c.hero.id).is_equal(2)
	assert_float(c.rate_per_hour).is_greater(52.0)
	assert_array(result["rite_events"]).is_empty()


func test_retreat_keeps_the_hero_and_sets_camp() -> void:
	var c := TestFixtures.campaign(5, 1000)
	var hero := c.hero
	var result := TestFixtures.end_at_exit(c, 2, "retreat", 2000)
	assert_str(result["kind"]).is_equal("retreat")
	assert_bool(result["new_hero"]).is_false()
	assert_object(c.hero).is_same(hero)
	assert_int(c.hero.camp).is_equal(2)
	assert_int(c.hero.resolve).is_equal(0)
	assert_int(CampaignEngine.reach(c)).is_equal(2)
	assert_int(c.record_depth).is_equal(2)
	assert_array(c.ladder.ghosts).has_size(1)
	assert_float(c.soul).is_greater_equal(0.0)


func test_tick_banks_production_with_the_offline_cap() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var r := CampaignEngine.tick(c, 1000 + 3600)
	assert_float(r["soul"]).is_equal_approx(52.0, 0.0001)
	assert_float(c.soul).is_equal_approx(52.0, 0.0001)
	assert_int(c.last_tick).is_equal(4600)
	var far := CampaignEngine.tick(c, 4600 + 30 * 3600)
	assert_bool(far["capped"]).is_true()
	assert_float(far["soul"]).is_equal_approx(52.0 * 8.0, 0.0001)
	CampaignEngine.tick(c, 100)
	assert_int(c.last_tick).is_equal(100)


func test_buy_upgrade_spends_and_applies() -> void:
	var c := TestFixtures.campaign()
	assert_bool(CampaignEngine.buy_upgrade(c, "might")["ok"]).is_false()
	c.soul = 100.0
	var r := CampaignEngine.buy_upgrade(c, "might")
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(25.0, 0.0001)
	assert_float(c.soul).is_equal_approx(75.0, 0.0001)
	assert_int(c.hero.stats["might"]).is_equal(1)
	assert_int(c.upgrades.level("might")).is_equal(1)
	c.soul = 1000.0
	CampaignEngine.buy_upgrade(c, "vigor")
	assert_int(c.hero.max_hp).is_equal(73)
	CampaignEngine.buy_upgrade(c, "resolve")
	assert_int(c.hero.max_resolve).is_equal(2)
	assert_int(c.hero.resolve).is_equal(2)
	var before := c.rate_per_hour
	CampaignEngine.buy_upgrade(c, "ghost_strength")
	assert_float(c.rate_per_hour).is_greater(before)
	assert_bool(CampaignEngine.buy_upgrade(c, "nothing")["ok"]).is_false()
	var next := CampaignEngine.new_hero(c, 5000)
	assert_int(next.stats["might"]).is_equal(1)
	assert_int(next.max_resolve).is_equal(2)


func test_finish_run_accrues_the_run_time_at_the_old_rate() -> void:
	var c := TestFixtures.campaign(9, 1000)
	var run := CampaignEngine.start_run(c, 1, 1000)
	run.hero.hp = 1
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["shambler", "shambler", "shambler"]}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	var result := CampaignEngine.finish_run(c, 1000 + 3600)
	assert_int(c.last_tick).is_equal(1000 + 3600)
	assert_float(c.soul).is_equal_approx(52.0 + float(result["soul"]), 0.0001)
