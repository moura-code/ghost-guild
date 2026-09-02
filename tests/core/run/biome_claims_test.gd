extends GdUnitTestSuite
## Biome claims (spec §5.6): "the first true ghost standing in a biome unlocks
## that biome's card pool for the Descent draft and shops".
##
## The reward for reaching the Deep is not only that the Deep is there. It is
## that Deep cards start turning up in your Catacombs runs, which is the first
## thing in the game the player earns by *standing* somewhere rather than by
## spending.


const TMP := "user://test_saves/biome_claims_test.json"


func _campaign() -> Campaign:
	var c := CampaignEngine.new_campaign(TestFixtures.content(), 909, 0)
	c.sim_fights = 2
	return c


func _plant(c: Campaign, floor: int) -> Ghost:
	var hero := Hero.create(c.content, "sexton", "Deepwalker", {}, 1)
	return c.ladder.add(Ghost.from_expedition(hero, floor, 0))


# ------------------------------------------------------------ what unlocks

func test_a_run_carries_the_pools_the_guild_has_claimed() -> void:
	var c := _campaign()
	c.record_depth = 12
	_plant(c, 12)
	var run := CampaignEngine.start_run(c, 1, 100)
	assert_array(run.claimed_pools).contains(["fungal_deep"])


func test_an_unclaimed_biome_contributes_nothing() -> void:
	# A fresh campaign has the Founder on floor 1 and nothing else.
	var c := _campaign()
	var run := CampaignEngine.start_run(c, 1, 100)
	assert_array(run.claimed_pools).contains(["catacombs"])
	assert_array(run.claimed_pools).not_contains(["fungal_deep"])


func test_the_claim_survives_a_save() -> void:
	var c := _campaign()
	c.record_depth = 12
	_plant(c, 12)
	var run := CampaignEngine.start_run(c, 1, 100)
	var back := RunState.from_dict(c.content, run.to_dict())
	assert_array(back.claimed_pools).is_equal(run.claimed_pools)


func test_a_claim_you_already_had_is_credited_on_load() -> void:
	# Derived from the ladder rather than stored, so a ghost that was already
	# standing in the Deep before claims existed claims it the moment the save
	# is opened. A stored flag would have to be migrated.
	var c := _campaign()
	_plant(c, 15)
	var raw := c.to_dict()
	var back := Campaign.from_dict(c.content, raw)
	assert_array(Biomes.claimed(back.content, back.ladder)).contains(["fungal_deep"])


# ------------------------------------------------------------- what it does

func test_a_claimed_pool_shows_up_in_a_shallow_run() -> void:
	# The point of the whole feature: the Deep's cards reach a Catacombs run.
	var c := _campaign()
	c.record_depth = 12
	_plant(c, 12)
	var run := CampaignEngine.start_run(c, 1, 100)
	var pools := RunEngine.pools(run)
	assert_array(pools).contains(["fungal_deep"])
	assert_array(pools).contains(["catacombs"])


func test_the_floor_you_are_on_is_always_in_the_pool() -> void:
	# Even unclaimed: walking into a biome has to be able to offer its cards,
	# or the first run into the Deep draws entirely from the Catacombs.
	var c := _campaign()
	var run := CampaignEngine.start_run(c, 1, 100)
	run.floor = 14
	assert_array(RunEngine.pools(run)).contains(["fungal_deep"])


func test_a_pool_is_never_listed_twice() -> void:
	# Rewards draw uniformly across the pools it is given; a pool listed twice
	# is a pool with double the odds.
	var c := _campaign()
	_plant(c, 4)
	var run := CampaignEngine.start_run(c, 1, 100)
	var pools := RunEngine.pools(run)
	var seen: Array = []
	for pool in pools:
		assert_bool(seen.has(pool)).override_failure_message(
			"pool %s listed twice" % pool).is_false()
		seen.append(pool)


func test_an_echo_in_the_deep_claims_nothing() -> void:
	var c := _campaign()
	var source := _plant(c, 3)
	c.ladder.add(source.clone_as_echo(14, 0))
	var run := CampaignEngine.start_run(c, 1, 100)
	assert_array(run.claimed_pools).not_contains(["fungal_deep"])
