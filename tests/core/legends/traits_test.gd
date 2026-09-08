extends GdUnitTestSuite
## What a Legend is worth in a fight (spec §6.1: "a trait from the dominant
## archetype -- a Poison Legend makes the hero's Poison cards apply +1 stack").
##
## The property everything else hangs off is the identity at nothing: a guild
## that has never prestiged has no Legend, no trait, and a game byte-identical
## to the one it played before any of this existed.


func _content() -> Content:
	return TestFixtures.content()


func _legend(tag: String) -> Legend:
	var l := Legend.new()
	l.id = 1
	l.trait_tag = tag
	return l


# ----------------------------------------------------------- the identity

func test_no_trait_adds_nothing_to_anything() -> void:
	for op in TraitDef.OPS:
		assert_int(Traits.bonus(null, op, ["poison", "bone"])).override_failure_message(
			"a guild with no Legends is playing a different game at op %s" % op).is_equal(0)


func test_a_guild_with_no_legends_invokes_nobody() -> void:
	var c := TestFixtures.campaign()
	assert_object(Traits.invoked(c)).is_null()
	assert_str(CampaignEngine.invoked_tag(c)).is_empty()


# --------------------------------------------------------------- the lookup

func test_every_tag_the_cards_use_is_worth_a_trait() -> void:
	# A cycle spent on a tag with no trait authored buys the player nothing and
	# never errors -- the guild just quietly gets a Legend that does not do
	# anything.
	var c := Content.load_from("res://data")
	var used: Dictionary = {}
	for id in c.cards:
		for tag in (c.cards[id] as CardDef).tags:
			used[String(tag)] = true
	for tag in used:
		assert_object(Traits.for_tag(c, String(tag))).override_failure_message(
			"cards are tagged '%s' and no Legend is ever worth anything for it" % tag) \
			.is_not_null()


func test_a_tag_nothing_is_authored_for_is_worth_nothing() -> void:
	assert_object(Traits.for_tag(_content(), "no_such_tag")).is_null()
	assert_object(Traits.for_tag(_content(), "")).is_null()


func test_a_legend_carries_the_trait_of_the_deck_it_was_made_from() -> void:
	var c := Content.load_from("res://data")
	var carried := Traits.of(c, _legend("poison"))
	assert_object(carried).is_not_null()
	assert_str(carried.tag).is_equal("poison")


# ---------------------------------------------------------------- the bonus

func test_a_poison_legend_makes_poison_cards_apply_one_more_stack() -> void:
	# Spec §6.1's own worked example, end to end through the resolver.
	var c := Content.load_from("res://data")
	var poison := Traits.for_tag(c, "poison")
	assert_str(poison.op).is_equal("status")
	assert_int(Traits.bonus(poison, "status", ["poison"])).is_equal(1)


func test_a_trait_only_touches_the_cards_it_is_named_after() -> void:
	# Otherwise it is a global modifier wearing a tag's name, and the player
	# has no way to see which of their cards it applies to.
	var c := Content.load_from("res://data")
	var poison := Traits.for_tag(c, "poison")
	assert_int(Traits.bonus(poison, "status", ["bone", "shield"])).is_equal(0)


func test_a_trait_only_touches_the_kind_of_effect_it_boosts() -> void:
	var c := Content.load_from("res://data")
	var poison := Traits.for_tag(c, "poison")
	assert_int(Traits.bonus(poison, "damage", ["poison"])).is_equal(0)
	assert_int(Traits.bonus(poison, "block", ["poison"])).is_equal(0)


# ------------------------------------------------------------ the invocation

func test_invoking_a_legend_that_does_not_exist_is_refused() -> void:
	var c := TestFixtures.campaign()
	assert_bool(CampaignEngine.invoke_legend(c, 7, 1000)).is_false()
	assert_int(c.invoked_legend).is_equal(0)


func test_one_legend_walks_with_you_and_only_one() -> void:
	var c := TestFixtures.campaign()
	c.legends.append(_legend("poison"))
	var second := _legend("bone")
	second.id = 2
	c.legends.append(second)

	assert_bool(CampaignEngine.invoke_legend(c, 1, 1000)).is_true()
	assert_str(CampaignEngine.invoked_tag(c)).is_equal("poison")
	assert_bool(CampaignEngine.invoke_legend(c, 2, 1000)).is_true()
	assert_str(CampaignEngine.invoked_tag(c)).override_failure_message(
		"both Legends came down with you").is_equal("bone")


func test_you_can_walk_down_alone() -> void:
	var c := TestFixtures.campaign()
	c.legends.append(_legend("poison"))
	CampaignEngine.invoke_legend(c, 1, 1000)
	assert_bool(CampaignEngine.invoke_legend(c, 0, 1000)).is_true()
	assert_str(CampaignEngine.invoked_tag(c)).is_empty()


func test_an_invocation_is_by_grave_not_by_position() -> void:
	# The Hall lists them oldest first. Storing the choice as an index would
	# re-point it at somebody else the next time the guild prestiges.
	var c := TestFixtures.campaign()
	var older := _legend("poison")
	older.id = 4
	c.legends.append(older)
	CampaignEngine.invoke_legend(c, 4, 1000)
	var newer := _legend("bone")
	newer.id = 5
	c.legends.insert(0, newer)
	assert_str(CampaignEngine.invoked_tag(c)).override_failure_message(
		"the next prestige moved which Legend was invoked").is_equal("poison")


func test_the_invocation_survives_a_save() -> void:
	var c := TestFixtures.campaign()
	c.legends.append(_legend("poison"))
	CampaignEngine.invoke_legend(c, 1, 1000)
	var back := Campaign.from_dict(c.content, c.to_dict())
	assert_int(back.invoked_legend).is_equal(1)
	assert_str(CampaignEngine.invoked_tag(back)).is_equal("poison")


# ------------------------------------------------------------ into the fight

func test_a_run_carries_the_trait_it_started_with() -> void:
	# A run is a closed system that replays from its seed, so the trait is
	# snapshotted at the door rather than read live off the campaign.
	var run := RunEngine.start_run(_content(), TestFixtures.hero(), 1, 42, true, [], 1.0, 0, "poison")
	assert_str(run.trait_tag).is_equal("poison")
	assert_object(run.hero_trait()).is_not_null()
	var back := RunState.from_dict(run.content, run.to_dict())
	assert_str(back.trait_tag).is_equal("poison")


func test_a_run_with_no_legend_carries_nothing() -> void:
	var run := RunEngine.start_run(_content(), TestFixtures.hero(), 1, 42, true)
	assert_str(run.trait_tag).is_empty()
	assert_object(run.hero_trait()).is_null()


func test_the_fight_is_handed_the_trait() -> void:
	var c := _content()
	var carried := Traits.for_tag(c, "poison")
	var s := CombatEngine.start_fight(c, HeroSnapshot.starter(c, Classes.starting(c)),
		[], 1, Rng.new(3), null, carried)
	assert_object(s.hero_trait).is_same(carried)
	assert_object(s.clone().hero_trait).override_failure_message(
		"a simulated copy of the fight forgot the Legend").is_same(carried)


func test_a_poison_card_played_under_a_poison_legend_lands_one_more_stack() -> void:
	# The claim end to end, through the real card, the real resolver and the
	# real enemy. Everything above this is arithmetic; this is the feature.
	var c := _content()
	var plain := TestFixtures.bare_state(["bone_rat"])
	TestFixtures.give_hand(plain, ["wither"])
	CombatEngine.apply(plain, {"kind": "play", "hand_index": 0, "target": 0})
	var without := (plain.enemies[0] as EnemyState).status("poison")
	assert_int(without).override_failure_message(
		"the card under test applies no Poison at all").is_greater(0)

	var blessed := TestFixtures.bare_state(["bone_rat"])
	blessed.hero_trait = Traits.for_tag(c, "poison")
	TestFixtures.give_hand(blessed, ["wither"])
	CombatEngine.apply(blessed, {"kind": "play", "hand_index": 0, "target": 0})
	var with_legend := (blessed.enemies[0] as EnemyState).status("poison")
	var note := "the Legend added %d stacks, not one" % (with_legend - without)
	assert_int(with_legend).override_failure_message(note).is_equal(without + 1)


func test_a_bone_card_played_under_a_poison_legend_is_unchanged() -> void:
	var c := _content()
	var plain := TestFixtures.bare_state(["shambler"])
	TestFixtures.give_hand(plain, ["strike"])
	CombatEngine.apply(plain, {"kind": "play", "hand_index": 0, "target": 0})
	var without := (plain.enemies[0] as EnemyState).hp

	var blessed := TestFixtures.bare_state(["shambler"])
	blessed.hero_trait = Traits.for_tag(c, "poison")
	TestFixtures.give_hand(blessed, ["strike"])
	CombatEngine.apply(blessed, {"kind": "play", "hand_index": 0, "target": 0})
	assert_int((blessed.enemies[0] as EnemyState).hp).override_failure_message(
		"a Poison Legend made a Strike hit harder").is_equal(without)
