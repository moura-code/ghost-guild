extends GdUnitTestSuite

const ROOT := "user://hybrid_saves"
const PATH := ROOT + "/slot1.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	for file in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(file))


func _write(d: Variant, path: String = PATH) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(d))
	file.close()


func test_each_preserved_v1_fixture_migrates_idempotently_and_keeps_identity() -> void:
	var content := TestFixtures.content()
	for file in DirAccess.get_files_at("res://tests/fixtures/legacy_v1"):
		if not file.ends_with(".json"):
			continue
		var source := "res://tests/fixtures/legacy_v1/" + file
		var original: Dictionary = Content.normalize_json(JSON.parse_string(FileAccess.get_file_as_string(source)))
		var report := SaveGame.load_report(content, source)
		assert_str(report["reason"]).override_failure_message(file + ": " + str(report["reason"])).is_empty()
		var c: Campaign = report["campaign"]
		assert_int(c.campaign_seed).is_equal(original["campaign_seed"])
		assert_float(c.soul).is_equal(float(original["soul"]))
		assert_str(c.hero.name).is_equal(original["hero"]["name"])
		assert_int(c.record_depth).is_equal(original["record_depth"])
		assert_array(c.ladder.ghosts).has_size(original["ladder"]["ghosts"].size())
		assert_dict(SaveGame.migrate(SaveGame.migrate(original))).is_equal(SaveGame.migrate(original))
		assert_int(SaveGame.save(c, PATH)).is_equal(OK)
		assert_dict(SaveGame.load_campaign(content, PATH).to_dict()).is_equal(c.to_dict())


func test_missing_primary_and_both_backup_levels_recover() -> void:
	var c := TestFixtures.campaign(8, 1000)
	for soul in [10.0, 20.0, 30.0]:
		c.soul = soul
		assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	DirAccess.remove_absolute(PATH)
	assert_bool(SaveGame.exists(PATH)).is_true()
	assert_float(SaveGame.load_campaign(c.content, PATH).soul).is_equal(20.0)
	_write({"broken": true}, PATH + ".bak1")
	var report := SaveGame.load_report(c.content, PATH)
	assert_str(report["recovered"]).is_equal(".bak2")
	assert_float(report["campaign"].soul).is_equal(10.0)


func test_future_schema_and_wrong_content_are_rejected_without_fallback_loss() -> void:
	var c := TestFixtures.campaign(9, 1000)
	SaveGame.save(c, PATH)
	SaveGame.save(c, PATH)
	var d := c.to_dict()
	d["version"] = SaveGame.VERSION + 1
	_write(d)
	assert_str(SaveGame.load_report(c.content, PATH)["reason"]).is_equal("future")
	assert_bool(SaveGame.import_copy(c.content, PATH, 2000, ROOT)["ok"]).is_false()
	d["version"] = 1
	d["hero"]["deck"][0]["def_id"] = "missing_card"
	assert_str(SaveValidation.check(c.content, d)).is_equal("content")
	d["hero"] = null
	assert_str(SaveValidation.check(c.content, d)).is_equal("invalid")


func test_failed_temporary_write_preserves_the_primary_and_backups() -> void:
	var c := TestFixtures.campaign(10, 1000)
	SaveGame.save(c, PATH)
	c.soul = 77
	SaveGame.save(c, PATH)
	var primary := FileAccess.get_file_as_string(PATH)
	var backup := FileAccess.get_file_as_string(PATH + ".bak1")
	DirAccess.make_dir_absolute(PATH + ".tmp")
	c.soul = 999
	assert_int(SaveGame.save(c, PATH)).is_not_equal(OK)
	assert_str(FileAccess.get_file_as_string(PATH)).is_equal(primary)
	assert_str(FileAccess.get_file_as_string(PATH + ".bak1")).is_equal(backup)
	DirAccess.remove_absolute(PATH + ".tmp")


func test_import_keeps_both_campaigns_and_applies_offline_production_once() -> void:
	var content := TestFixtures.content()
	var current := TestFixtures.campaign(11, 1000)
	SaveGame.save(current, PATH)
	var before := FileAccess.get_file_as_string(PATH)
	var source := "res://tests/fixtures/legacy_v1/guild.json"
	var old := FileAccess.get_file_as_string(source)
	var result := SaveGame.import_copy(content, source, 4600, ROOT)
	assert_bool(result["ok"]).is_true()
	assert_str(FileAccess.get_file_as_string(PATH)).is_equal(before)
	assert_str(FileAccess.get_file_as_string(source)).is_equal(old)
	var loaded := SaveGame.load_and_catch_up(content, 4600, result["path"])
	assert_float(loaded["offline"]["soul"]).is_equal(0.0)
	assert_int(loaded["campaign"].last_tick).is_equal(4600)
	SaveGame.save(loaded["campaign"], result["path"])
	assert_float(SaveGame.load_and_catch_up(content, 4600, result["path"])["offline"]["soul"]).is_equal(0.0)
	var second := SaveGame.import_copy(content, source, 4600, ROOT)
	assert_str(second["path"]).is_not_equal(result["path"])


func test_malformed_nested_data_is_rejected_before_typed_construction() -> void:
	var c := TestFixtures.campaign(51, 1000)
	var run := CampaignEngine.start_run(c, 1, 1000)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	var mutations: Array[Callable] = [
		func(d: Dictionary) -> void: d["hero"]["stats"]["might"] = [],
		func(d: Dictionary) -> void: d["run"]["stats"]["1"] = "bad",
		func(d: Dictionary) -> void: d["run"]["fight"]["statuses"]["poison"] = {},
		func(d: Dictionary) -> void: d["run"]["fight"]["rng"]["streams"]["deck"] = 4,
		func(d: Dictionary) -> void: d["run"]["fight"]["rng"]["seed"] = "invalid",
		func(d: Dictionary) -> void: d["run"]["fight"]["enemies"][0]["next_move"] = "missing",
		func(d: Dictionary) -> void: d["hero"]["deck"][0].erase("def_id"),
		func(d: Dictionary) -> void: d["legends"] = [{"epitaphs": [1]}],
		func(d: Dictionary) -> void: d["expeditions"] = [{"ghost": {}}],
	]
	for mutate in mutations:
		var d := c.to_dict()
		mutate.call(d)
		_write(d)
		assert_object(SaveGame.load_campaign(c.content, PATH)).is_null()
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)


func test_a_hero_who_removed_the_last_card_can_still_be_saved() -> void:
	var c := TestFixtures.campaign(52, 1000)
	c.hero.deck.clear()
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_array(SaveGame.load_campaign(c.content, PATH).hero.deck).is_empty()
