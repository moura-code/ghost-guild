extends GdUnitTestSuite

const PATH := "user://test_saves/slot.json"


func before_test() -> void:
	_wipe()


func after_test() -> void:
	_wipe()


func _wipe() -> void:
	var da := DirAccess.open("user://")
	if da == null or not da.dir_exists("test_saves"):
		return
	var dir := DirAccess.open("user://test_saves")
	for f in dir.get_files():
		dir.remove(f)
	da.remove("test_saves")


func test_campaign_round_trip_between_runs() -> void:
	var c := TestFixtures.campaign(3, 1000)
	c.onboarding.watch_unlocked = true
	TestFixtures.end_at_exit(c, 2, "watch", 2000)
	c.soul = 123.5
	CampaignEngine.buy_upgrade(c, "vigor")
	var back := Campaign.from_dict(TestFixtures.content(), JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_int(back.campaign_seed).is_equal(3)
	assert_array(back.ladder.ghosts).has_size(2)
	assert_int(back.ladder.waypoint()).is_equal(2)
	assert_str(back.hero.name).is_equal(c.hero.name)
	assert_int(back.hero.id).is_equal(2)
	assert_int(back.hero.max_hp).is_equal(73)
	assert_float(back.soul).is_equal_approx(c.soul, 0.0001)
	assert_int(back.upgrades.level("vigor")).is_equal(1)
	assert_bool(back.onboarding.watch_unlocked).is_true()
	assert_int(back.record_depth).is_equal(2)
	assert_int(back.hero_counter).is_equal(2)
	assert_int(back.run_counter).is_equal(1)
	assert_int(back.last_tick).is_equal(2000)
	assert_float(back.rate_per_hour).is_equal_approx(c.rate_per_hour, 0.0001)
	assert_object(back.run).is_null()
	assert_array(back.events).is_empty()


func test_round_trip_with_a_run_in_progress_adopts_the_run_hero() -> void:
	var c := TestFixtures.campaign(4, 1000)
	var run := CampaignEngine.start_run(c, 1, 1500)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "take_card", "card": run.reward["cards"][0]})
	var back := Campaign.from_dict(TestFixtures.content(), JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_object(back.run).is_not_null()
	assert_object(back.hero).is_same(back.run.hero)
	assert_array(back.hero.deck).has_size(11)
	assert_str(back.run.phase).is_equal("node")
	assert_bool(back.run.is_resolved(0)).is_true()
	assert_int(back.run.next_unresolved()).is_equal(1)
	RunEngine.apply(back.run, {"kind": "enter"})
	RunEngine.apply(back.run, {"kind": "rest_heal"})
	RunEngine.apply(back.run, {"kind": "retreat"})
	var result := CampaignEngine.finish_run(back, 3000)
	assert_str(result["kind"]).is_equal("retreat")
	assert_int(back.hero.camp).is_equal(1)


func test_save_writes_file_and_rotates_backups() -> void:
	var c := TestFixtures.campaign(5, 1000)
	assert_bool(SaveGame.exists(PATH)).is_false()
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_bool(SaveGame.exists(PATH)).is_true()
	assert_bool(FileAccess.file_exists(PATH + ".bak1")).is_false()
	c.soul = 1.0
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_bool(FileAccess.file_exists(PATH + ".bak1")).is_true()
	c.soul = 2.0
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_bool(FileAccess.file_exists(PATH + ".bak2")).is_true()
	var loaded := SaveGame.load_campaign(TestFixtures.content(), PATH)
	assert_float(loaded.soul).is_equal(2.0)
	var older := Campaign.from_dict(TestFixtures.content(), Content.normalize_json(JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak1"))))
	assert_float(older.soul).is_equal(1.0)


func test_load_missing_or_corrupt_returns_null() -> void:
	assert_object(SaveGame.load_campaign(TestFixtures.content(), PATH)).is_null()
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_object(SaveGame.load_campaign(TestFixtures.content(), PATH)).is_null()


func test_migrate_raises_the_version() -> void:
	var d := SaveGame.migrate({"campaign_seed": 1})
	assert_int(d["version"]).is_equal(SaveGame.VERSION)
	assert_int(SaveGame.migrate({"version": 1, "campaign_seed": 1})["version"]).is_equal(1)


func test_load_and_catch_up_banks_offline_soul() -> void:
	var c := TestFixtures.campaign(6, 1000)
	SaveGame.save(c, PATH)
	var r := SaveGame.load_and_catch_up(TestFixtures.content(), 1000 + 2 * 3600, PATH)
	var loaded: Campaign = r["campaign"]
	assert_object(loaded).is_not_null()
	assert_float(r["offline"]["soul"]).is_equal_approx(104.0, 0.0001)
	assert_float(loaded.soul).is_equal_approx(104.0, 0.0001)
	assert_int(loaded.last_tick).is_equal(1000 + 2 * 3600)
	assert_float(loaded.rate_per_hour).is_equal_approx(52.0, 0.0001)
	var capped := SaveGame.load_and_catch_up(TestFixtures.content(), 1000 + 100 * 3600, PATH)
	assert_bool(capped["offline"]["capped"]).is_true()
	assert_float(capped["offline"]["soul"]).is_equal_approx(52.0 * 8.0, 0.0001)
	assert_object(SaveGame.load_and_catch_up(TestFixtures.content(), 5, "user://test_saves/nothing.json")["campaign"]).is_null()


func test_load_falls_back_to_a_backup_when_the_main_file_is_corrupt() -> void:
	var c := TestFixtures.campaign(11, 1000)
	c.soul = 7.0
	SaveGame.save(c, PATH)
	c.soul = 8.0
	SaveGame.save(c, PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var back := SaveGame.load_campaign(TestFixtures.content(), PATH)
	assert_object(back).is_not_null()
	assert_float(back.soul).is_equal(7.0)
