extends GdUnitTestSuite


func _legacy(phase: String) -> Dictionary:
	var c := TestFixtures.campaign()
	var run := CampaignEngine.start_run(c, 1, 1000)
	var kind := phase if phase in ["shop", "rest", "event"] else "fight"
	TestFixtures.set_nodes(run, [{"kind": "shop"}, {"kind": kind, "enemies": ["bone_rat"], "event": "whispering_well"}])
	run.resolve(0)
	RunEngine.apply(run, {"kind": "enter", "index": 1})
	if phase == "reward":
		TestFixtures.autofight(run)
	elif phase == "exit":
		TestFixtures.autofight(run)
		RunEngine.apply(run, {"kind": "skip_card"})
	elif phase == "node":
		run.phase = "node"
	var raw := c.to_dict()
	raw["version"] = 3
	for key in ["room_records", "layout_snapshot", "legacy_floor", "floor_clear_emitted", "action_revision", "previous_presets"]:
		raw["run"].erase(key)
	return raw


func test_schema_three_phases_preserve_closed_shop_requirements_and_active_state() -> void:
	var c := TestFixtures.content()
	for phase in ["node", "fight", "reward", "event", "rest", "shop", "exit"]:
		var old := _legacy(phase)
		var migrated := SaveGame.migrate(old)
		assert_str(SaveValidation.check(c, migrated)).is_empty()
		var run := Campaign.from_dict(c, migrated).run
		assert_str(run.phase).is_equal(phase)
		assert_bool(run.legacy_floor).is_true()
		assert_bool(run.can_enter(0)).is_false()
		assert_bool(run.room_record(1)["required"]).is_true()
		assert_dict(run.layout_snapshot).is_empty()
		assert_dict(SaveGame.migrate(migrated)).is_equal(migrated)
		if phase == "shop":
			assert_dict(run.shop).is_equal(old["run"]["shop"])
		if phase == "fight":
			assert_dict(run.fight.to_dict()).is_equal(old["run"]["fight"])


func test_current_save_rejects_malformed_records_and_layout_before_construction() -> void:
	var c := TestFixtures.campaign()
	CampaignEngine.start_run(c, 1, 1000)
	var valid := c.to_dict()
	valid["version"] = 4
	assert_str(SaveValidation.check(c.content, valid)).is_empty()
	for mutation in ["missing", "identity", "cells", "rooms", "anchors", "indices"]:
		var raw := valid.duplicate(true)
		match mutation:
			"missing": raw["run"].erase("room_records")
			"identity": raw["run"]["room_records"][0]["room_id"] = "2:0"
			"cells": raw["run"]["layout_snapshot"]["cells"] = [1]
			"rooms": raw["run"]["layout_snapshot"]["rooms"][0]["w"] = "bad"
			"anchors": raw["run"]["layout_snapshot"]["torch_anchors"] = [["bad"]]
			"indices": raw["run"]["layout_snapshot"]["node_rooms"][0] = 99
		assert_str(SaveValidation.check(c.content, raw)).is_equal("invalid")
