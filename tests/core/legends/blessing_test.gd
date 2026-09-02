extends GdUnitTestSuite
## The Legend's Blessing (spec §4.4): the multiplier applies to hero damage
## dealt and block gained, not only to ghosts.
##
## The failure mode is not that it does nothing. It is that it reaches some
## paths and not others -- a ghost priced *without* the Blessing it fights
## *with* makes every yield number in the game quietly wrong, in the direction
## of under-reporting, which is the direction nobody notices.


func _content() -> Content:
	return TestFixtures.content()


func _fight(blessing: float, hand: Array) -> FightState:
	var s := TestFixtures.bare_state(["shambler"], 1, 5)
	s.blessing = blessing
	TestFixtures.give_hand(s, hand)
	return s


func _play(s: FightState, index: int) -> void:
	CombatEngine.apply(s, {"kind": "play", "hand_index": index, "target": 0})


# --------------------------------------------------------------- the default

func test_a_fight_with_no_blessing_is_the_fight_it_always_was() -> void:
	# Every demo in the repo depends on this being exactly 1.0.
	assert_float(FightState.new().blessing).is_equal(1.0)


func test_it_survives_the_clone_the_autopilot_makes() -> void:
	# The autopilot scores by cloning the state and replaying it. A clone that
	# dropped the Blessing would make the hero plan for a weaker version of
	# itself and pick the wrong card.
	var s := _fight(1.5, ["strike"])
	assert_float(s.clone().blessing).is_equal(1.5)


# ------------------------------------------------------------------ the hero

func test_a_blessed_hero_hits_harder() -> void:
	var plain := _fight(1.0, ["strike"])
	var blessed := _fight(2.0, ["strike"])
	var before := (plain.enemies[0] as EnemyState).hp
	_play(plain, 0)
	_play(blessed, 0)
	var plain_dealt := before - (plain.enemies[0] as EnemyState).hp
	var blessed_dealt := before - (blessed.enemies[0] as EnemyState).hp
	assert_int(blessed_dealt).override_failure_message(
		"the Blessing did not reach hero damage").is_greater(plain_dealt)


func test_a_blessed_hero_blocks_harder() -> void:
	var plain := _fight(1.0, ["brace"])
	var blessed := _fight(2.0, ["brace"])
	_play(plain, 0)
	_play(blessed, 0)
	assert_int(blessed.hero_block).is_greater(plain.hero_block)


func test_it_does_not_make_the_enemy_hit_harder() -> void:
	# It is the hero's Blessing. An enemy that scaled with it would cancel out.
	var plain := _fight(1.0, ["strike"])
	var blessed := _fight(3.0, ["strike"])
	CombatEngine.apply(plain, {"kind": "end_turn"})
	CombatEngine.apply(blessed, {"kind": "end_turn"})
	assert_int(blessed.hero_hp).is_equal(plain.hero_hp)


func test_it_does_not_touch_a_status() -> void:
	# Doubling poison and doubling damage are not the same lever, and §4.4
	# names damage and block only.
	var plain := _fight(1.0, ["plague_vial"])
	var blessed := _fight(4.0, ["plague_vial"])
	_play(plain, 0)
	_play(blessed, 0)
	assert_int((blessed.enemies[0] as EnemyState).status("poison")) \
		.is_equal((plain.enemies[0] as EnemyState).status("poison"))


# ----------------------------------------------------------------- the ghost

func test_a_blessed_ghost_earns_more() -> void:
	# Not the Founder: its strength is fixed at placement, so it is never
	# re-simulated and the test would pass on a cached number.
	var c := CampaignEngine.new_campaign(_content(), 909, 0)
	c.sim_fights = 12
	var walker := Hero.create(c.content, "sexton", "Walker", {}, 1)
	# Deep enough that the fight is not already over in two turns: strength is
	# kills per hour, and a Blessing cannot make a one-turn fight shorter.
	var ghost := c.ladder.add(Ghost.from_expedition(walker, 8, 0))
	ghost.fixed_strength = false
	var plain := CampaignEngine.strength_for(c, ghost)
	var legend := Legend.new()
	legend.multiplier = 2.0
	c.legends.append(legend)
	assert_float(CampaignEngine.strength_for(c, ghost)) \
		.override_failure_message("the Blessing did not reach ghost strength") \
		.is_greater(plain)


func test_the_hero_and_the_dead_are_blessed_by_the_same_number() -> void:
	# A ghost priced without the Blessing it fights with would make every
	# yield number in the game quietly wrong.
	var c := CampaignEngine.new_campaign(_content(), 909, 0)
	var legend := Legend.new()
	legend.multiplier = 1.4
	c.legends.append(legend)
	assert_float(CampaignEngine.blessing(c)).is_equal_approx(1.4, 0.0001)
	var run := CampaignEngine.start_run(c, 1, 100)
	assert_float(run.blessing).override_failure_message(
		"the run was started without the guild's Blessing").is_equal_approx(1.4, 0.0001)
