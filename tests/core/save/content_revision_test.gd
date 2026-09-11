extends GdUnitTestSuite

const PATH := "user://revision/campaign.json"


func test_old_income_is_banked_once_before_sources_then_echoes_are_repriced() -> void:
	_assert_revision_catchup("baseline")


func test_clarity_r2_income_and_promises_survive_the_next_revision() -> void:
	_assert_revision_catchup("clarity-2026-09-09-r2")


func test_saved_r2_fight_keeps_hp_while_future_moves_and_spawns_use_current_content() -> void:
	var old := Content.load_from("res://data")
	old.balance["revision"] = "clarity-2026-09-09-r2"
	old.enemies["shambler"].hp = 30
	old.enemies["bone_rat"].hp = 18
	old.enemies["bone_rat"].moves["bite"]["damage"] = 6
	var c := CampaignEngine.new_campaign(old, 887, 1000)
	var run := CampaignEngine.start_run(c, 1, 1000)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["shambler", "bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	var saved_fight := run.fight.to_dict()
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	var current := Content.load_from("res://data")
	var loaded: Campaign = SaveGame.load_and_catch_up(current, 1000, PATH)["campaign"]
	assert_dict(loaded.run.fight.to_dict()).is_equal(saved_fight)
	assert_int(loaded.run.fight.enemies[0].max_hp).is_equal(30)
	assert_int(loaded.run.fight.enemies[1].max_hp).is_equal(18)
	var fight := loaded.run.fight
	fight.hero_block = 0
	fight.enemies[1].next_move = "bite"
	var before := fight.hero_hp
	EnemyAI.execute_move(fight, 1)
	assert_int(fight.hero_hp).is_equal(before - 5)
	var next := CombatEngine.start_fight(current, loaded.hero.snapshot(), ["shambler", "bone_rat"], 1, Rng.new(1))
	assert_int(next.enemies[0].max_hp).is_equal(27)
	assert_int(next.enemies[1].max_hp).is_equal(17)


func _assert_revision_catchup(previous_revision: String) -> void:
	var c := TestFixtures.campaign(887, 1000)
	c.content_revision = previous_revision
	c.soul = 10000
	var source := Ghost.from_expedition(c.hero, 2, 1000)
	source.kind = "true"
	source.fixed_strength = false
	source.strength = 999
	c.ladder.add(source)
	var echo := source.clone_as_echo(2, 1000)
	echo.strength = 888
	c.ladder.add(echo)
	var promised := Expedition.new()
	promised.id = 1
	promised.ghost = Ghost.from_expedition(c.hero, 3, 1000)
	promised.ghost.strength = 123.0
	promised.ghost.fixed_strength = true
	promised.started_at = 1000
	promised.seconds = 10000
	c.expeditions.append(promised)
	var future := promised.to_dict()
	var founder := c.ladder.ghosts[0].to_dict()
	CampaignEngine.refresh_rate(c)
	var old_rate := c.rate_per_hour
	var run := CampaignEngine.start_run(c, 1, 1000)
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	RunEngine.apply(run, {"kind": "end_turn"})
	var active := run.to_dict()
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	var report := SaveGame.load_and_catch_up(c.content, 4600, PATH)
	var back: Campaign = report["campaign"]
	assert_float(report["offline"]["soul"]).is_equal_approx(old_rate, 0.00001)
	assert_float(back.soul).is_equal_approx(10000 + old_rate, 0.00001)
	assert_dict(back.run.to_dict()).is_equal(active)
	assert_dict(back.ladder.ghosts[0].to_dict()).is_equal(founder)
	assert_dict(back.expeditions[0].to_dict()).is_equal(future)
	var refreshed := back.ladder.find(source.id)
	assert_float(refreshed.strength).is_equal(CampaignEngine.strength_for(back, refreshed))
	assert_float(back.ladder.find(echo.id).strength).is_equal(Seance.echo_strength(back, refreshed, 2))
	assert_bool(CampaignEngine.refresh_content_revision(back)).is_false()
	assert_int(SaveGame.save(back, PATH)).is_equal(OK)
	var again := SaveGame.load_and_catch_up(c.content, 4600, PATH)
	assert_float(again["offline"]["soul"]).is_zero()
	assert_float((again["campaign"] as Campaign).soul).is_equal(back.soul)
	assert_array(TestFixtures.campaign_events_of(again["campaign"], "content_revised")).is_empty()
	# Its precomputed strength remains a promise when it returns, too.
	CampaignEngine.tick(back, 11000)
	var returned := back.ladder.ghosts.back() as Ghost
	assert_float(returned.strength).is_equal(123.0)
	assert_bool(returned.fixed_strength).is_true()
