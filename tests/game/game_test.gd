extends GdUnitTestSuite

const TMP := "user://test_saves/game_test.json"


func _fresh() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	return g


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func test_a_fresh_boot_creates_a_campaign_with_the_founder() -> void:
	var g := _fresh()
	var r := g.boot()
	assert_bool(r["ok"]).is_true()
	assert_bool(r["new_game"]).is_true()
	assert_object(g.campaign).is_not_null()
	assert_int(g.campaign.ladder.ghosts.size()).is_equal(1)
	assert_bool(g.is_booted).is_true()


func test_boot_is_inert_until_called() -> void:
	var g: GameRoot = auto_free(GameRoot.new())
	add_child(g)
	await await_idle_frame()
	assert_bool(g.is_booted).is_false()
	assert_object(g.campaign).is_null()
	assert_object(g.content).is_null()


func test_displayed_soul_projects_the_rate_without_mutating_core() -> void:
	var g := _fresh()
	g.boot()
	var banked := g.campaign.soul
	var rate := g.campaign.rate_per_hour
	assert_float(rate).is_greater(0.0)
	g.clock = func() -> int: return 1000 + 3600
	assert_float(g.displayed_soul()).is_equal_approx(banked + rate, 0.001)
	assert_float(g.campaign.soul).is_equal_approx(banked, 0.0001)
	assert_int(g.campaign.last_tick).is_equal(1000)


func test_settle_banks_the_projection_into_core() -> void:
	var g := _fresh()
	g.boot()
	var rate := g.campaign.rate_per_hour
	g.clock = func() -> int: return 1000 + 3600
	g.settle()
	assert_float(g.campaign.soul).is_equal_approx(rate, 0.001)
	assert_int(g.campaign.last_tick).is_equal(4600)


func test_buy_upgrade_settles_first_so_the_purchase_uses_earned_soul() -> void:
	var g := _fresh()
	g.boot()
	g.clock = func() -> int: return 1000 + 7200
	var r := g.buy_upgrade("vigor")
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(20.0, 0.0001)
	assert_float(g.campaign.soul).is_equal_approx(104.0 - 20.0, 0.001)
	assert_int(g.campaign.upgrades.level("vigor")).is_equal(1)


func test_a_failed_purchase_reports_why_and_changes_nothing() -> void:
	var g := _fresh()
	g.boot()
	var r := g.buy_upgrade("offline_cap")
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("soul")
	assert_int(g.campaign.upgrades.level("offline_cap")).is_equal(0)


func test_save_then_boot_restores_the_campaign_and_reports_offline() -> void:
	var g := _fresh()
	g.boot()
	g.campaign.soul = 500.0
	g.save()
	var rate := g.campaign.rate_per_hour

	var g2 := _fresh()
	g2.clock = func() -> int: return 1000 + 3600
	var r := g2.boot()
	assert_bool(r["new_game"]).is_false()
	assert_float(g2.campaign.soul).is_equal_approx(500.0 + rate, 0.001)
	assert_float(float(g2.offline["soul"])).is_equal_approx(rate, 0.001)
	assert_int(int(g2.offline["counted"])).is_equal(3600)


func test_drain_events_empties_the_campaign_stream() -> void:
	var g := _fresh()
	g.boot()
	var first := g.drain_events()
	assert_int(first.size()).is_greater(0)
	assert_int(g.campaign.events.size()).is_equal(0)
	assert_int(g.drain_events().size()).is_equal(0)
