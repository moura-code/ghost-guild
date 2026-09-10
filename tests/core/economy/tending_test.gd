extends GdUnitTestSuite
## Tending past restless (spec §5.5): "spend Soul to upgrade a card in a
## ghost's deck or add a relic from the compendium; the ghost re-simulates."
##
## Both of these make a dead hero permanently worth more, which makes them the
## first Soul sink in the game that is an investment rather than a repair. The
## properties that matter are that the money buys something real, that it
## reaches the echoes, and that it cannot be spent on nothing.


func _campaign() -> Campaign:
	var c := TestFixtures.campaign()
	c.soul = 100000.0
	return c


## A true ghost with a real deck, standing where it can be tended.
func _dead(c: Campaign, floor: int = 3) -> Ghost:
	var hero := Hero.create(c.content, Classes.starting(c.content), "Tended", {}, 1)
	var g := Ghost.from_expedition(hero, floor, 1000)
	g.kind = "true"
	g.fixed_strength = false
	g.strength = 50.0
	return c.ladder.add(g)


# ------------------------------------------------------------- the sharpening

func test_sharpening_upgrades_a_card_the_ghost_was_carrying() -> void:
	var c := _campaign()
	var g := _dead(c)
	var before := 0
	for card in g.deck:
		if (card as CardInstance).upgraded:
			before += 1
	assert_bool(Seance.tend_upgrade(c, g.id)["ok"]).is_true()
	var after := 0
	for card in g.deck:
		if (card as CardInstance).upgraded:
			after += 1
	assert_int(after).is_equal(before + 1)


func test_it_sharpens_the_best_thing_the_ghost_carries() -> void:
	# Chosen rather than picked, so the choice has to be a good one.
	var c := _campaign()
	var g := _dead(c)
	var wanted := Seance.next_upgrade(c, g)
	assert_object(wanted).is_not_null()
	Seance.tend_upgrade(c, g.id)
	assert_bool(wanted.upgraded).is_true()
	# And the next one it offers is a different card.
	var next := Seance.next_upgrade(c, g)
	assert_object(next).is_not_same(wanted)


func test_sharpening_costs_soul_and_makes_the_ghost_worth_more() -> void:
	var c := _campaign()
	var g := _dead(c)
	var purse := c.soul
	var was := g.strength
	var r := Seance.tend_upgrade(c, g.id)
	assert_float(float(r["cost"])).is_greater(0.0)
	assert_float(c.soul).is_equal_approx(purse - float(r["cost"]), 0.001)
	assert_float(g.strength).override_failure_message(
		"the guild paid and the ghost is no better").is_not_equal(was)


func test_a_ghost_with_nothing_left_to_sharpen_is_not_charged_for_it() -> void:
	var c := _campaign()
	var g := _dead(c)
	for card in g.deck:
		(card as CardInstance).upgraded = true
	var purse := c.soul
	var r := Seance.tend_upgrade(c, g.id)
	assert_bool(r["ok"]).is_false()
	assert_str(String(r["reason"])).is_equal("nothing_left")
	assert_float(c.soul).is_equal(purse)


func test_a_poor_guild_is_refused_rather_than_put_in_debt() -> void:
	var c := _campaign()
	var g := _dead(c)
	c.soul = 1.0
	var r := Seance.tend_upgrade(c, g.id)
	assert_bool(r["ok"]).is_false()
	assert_str(String(r["reason"])).is_equal("soul")
	assert_float(c.soul).is_equal(1.0)


func test_tending_reprices_a_ghost_that_was_priced_once_and_never_again() -> void:
	# The Founder is a flat number out of balance.json. Sharpening it and
	# leaving `fixed_strength` set would take the Soul and change nothing,
	# which is the worst kind of bug: the player is told it worked.
	var c := _campaign()
	var founder := c.ladder.ghosts[0]
	assert_bool(founder.fixed_strength).is_true()
	Seance.tend_upgrade(c, founder.id)
	assert_bool(founder.fixed_strength).override_failure_message(
		"the Founder is still quoting its authored price").is_false()


# ------------------------------------------------------------------ the arming

func test_a_guild_can_only_arm_a_ghost_with_what_it_has_found() -> void:
	var c := _campaign()
	var g := _dead(c)
	c.compendium.clear()
	var r := Seance.tend_relic(c, g.id)
	assert_bool(r["ok"]).is_false()
	assert_str(String(r["reason"])).is_equal("nothing_left")


func test_arming_hands_over_a_relic_out_of_the_compendium() -> void:
	var c := _campaign()
	var g := _dead(c)
	var relic := ""
	for id in c.content.relics:
		if not g.relics.has(String(id)):
			relic = String(id)
			break
	c.compendium = [relic] as Array[String]
	var r := Seance.tend_relic(c, g.id)
	assert_bool(r["ok"]).is_true()
	assert_bool(g.relics.has(relic)).is_true()
	# And not twice.
	assert_str(Seance.next_relic(c, g)).is_empty()


func test_arming_costs_more_than_sharpening() -> void:
	# A relic fires in every fight the ghost will ever have.
	var c := _campaign()
	var g := _dead(c)
	assert_float(Seance.relic_cost(c, g)).is_greater(Seance.upgrade_cost(c, g))
	assert_float(Seance.upgrade_cost(c, g)).is_greater(Seance.tend_cost(c, g))


func test_tending_costs_more_the_deeper_the_ghost_stands() -> void:
	var c := _campaign()
	var shallow := _dead(c, 2)
	var deep := _dead(c, 20)
	assert_float(Seance.upgrade_cost(c, deep)).is_greater(Seance.upgrade_cost(c, shallow))


# ------------------------------------------------------------------ the echoes

func test_tending_the_source_reaches_its_echoes() -> void:
	# Spec §5.5: "echoes stay linked to their source: tending the source
	# updates all its echoes". An echo is a copy of its source's strength, so
	# a source that got better and echoes that did not would be the one place
	# in the economy where a copy stops being a copy.
	var c := _campaign()
	var g := _dead(c, 2)
	c.record_depth = 4
	var made := Seance.create_echo(c, g.id, 2, 1000)
	assert_bool(made["ok"]).override_failure_message(String(made["reason"])).is_true()
	var echo := c.ladder.find(int(made["ghost_id"])) if made.has("ghost_id") else _last_echo(c)
	var before: Array = echo.to_dict()["deck"]
	Seance.tend_upgrade(c, g.id)
	assert_array(echo.to_dict()["deck"]).is_not_equal(before)
	assert_array(echo.to_dict()["deck"]).is_equal(g.to_dict()["deck"])
	assert_float(echo.strength).is_equal(Seance.echo_strength(c, g, echo.floor))
	assert_bool(echo.deck.size() == g.deck.size()).is_true()


# ------------------------------------------------------------- the compendium

func test_the_guild_remembers_what_its_heroes_carried() -> void:
	var c := TestFixtures.campaign()
	var carried := c.hero.relics.duplicate()
	assert_bool(carried.is_empty()).override_failure_message(
		"the starting hero carries nothing, so this proves nothing").is_false()
	TestFixtures.die_on_floor(c, 2, 2000)
	for relic in carried:
		assert_bool(c.compendium.has(String(relic))).override_failure_message(
			"the guild forgot the %s it just buried somebody holding" % relic).is_true()


func test_the_compendium_survives_the_rite() -> void:
	# Spec §6.1 lists the compendium among the things a prestige keeps.
	var c := TestFixtures.campaign()
	c.compendium = ["bone_charm"] as Array[String]
	c.record_depth = 40
	TestFixtures.end_at_exit(c, CampaignEngine.prestige_threshold(c), "watch", 3000)
	var r := CampaignEngine.prestige(c, 4000)
	if not bool(r["ok"]):
		return
	assert_bool(c.compendium.has("bone_charm")).override_failure_message(
		"the rite took the guild's memory with its dead").is_true()


func test_the_compendium_survives_a_save() -> void:
	var c := TestFixtures.campaign()
	c.compendium = ["bone_charm", "sextons_lantern"] as Array[String]
	var back := Campaign.from_dict(c.content, c.to_dict())
	assert_int(back.compendium.size()).is_equal(2)
	assert_bool(back.compendium.has("bone_charm")).is_true()


func _last_echo(c: Campaign) -> Ghost:
	var found: Ghost = null
	for g in c.ladder.ghosts:
		if (g as Ghost).kind == "echo":
			found = g
	return found
