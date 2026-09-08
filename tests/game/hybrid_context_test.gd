extends GdUnitTestSuite

const PATH := "user://hybrid_tests/context.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for suffix in ["", ".bak1", ".bak2", ".cfg"]:
		DirAccess.remove_absolute(PATH + suffix)
	Settings.motion_reduced = false


func after_test() -> void:
	Settings.motion_reduced = false


func _crawl(host: Node = null) -> Crawl:
	if host == null:
		host = self
	var game: GameRoot = auto_free(GameRoot.new())
	game.save_path = PATH
	game.clock = func() -> int: return 1000
	game.autosave_seconds = 0
	host.add_child(game)
	game.boot()
	game.campaign.sim_fights = 2
	var crawl: Crawl = auto_free(Crawl.new())
	crawl.game = game
	crawl.settings_path = PATH + ".cfg"
	crawl.show_title = false
	host.add_child(crawl)
	crawl.bind(game)
	return crawl


func _key(crawl: Crawl, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	crawl._unhandled_input(event)


func _fight(crawl: Crawl) -> FightDirector:
	crawl.game.start_run(1)
	var run := crawl.game.campaign.run
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat", "bone_rat"]}, {"kind": "rest"}])
	crawl.build_floor()
	crawl._on_marker_entered(0)
	return crawl.director


func test_quick_tabs_reuse_station_panels_and_stop_velocity_immediately() -> void:
	var c := _crawl()
	c.player.velocity = Vector3(4, 0, 3)
	_key(c, "guild_menu")
	assert_bool(c.nav.visible).is_true()
	assert_vector(c.player.velocity).is_equal(Vector3.ZERO)
	c.open_guild(GuildRoom.DESK)
	var sheet := c.panel
	c.close_panel()
	c.guild.station(GuildRoom.DESK).enter(c.player)
	c.guild.station(GuildRoom.DESK).use()
	assert_object(c.panel).is_same(sheet)
	c.close_panel()
	_key(c, "guild_menu")
	assert_object(c.panel).is_same(sheet)
	assert_bool(c.player.frozen).is_true()


func test_help_and_options_return_to_the_mandatory_reward() -> void:
	var c := _crawl()
	c.game.start_run(1)
	var run := c.game.campaign.run
	run.phase = "reward"
	run.reward = {"cards": ["strike"]}
	c._sync()
	var before := JSON.stringify(run.to_dict())
	_key(c, "ui_cancel")
	assert_object(c.panel).is_same(c.pause)
	c._open_options()
	c.options.closed.emit()
	assert_object(c.panel).is_same(c.pause)
	c.pause.resumed.emit()
	assert_object(c.panel).is_same(c.choice)
	_key(c, "help")
	c.help.closed.emit()
	assert_object(c.panel).is_same(c.choice)
	_key(c, "guild_menu")
	_key(c, "floor_map")
	assert_str(JSON.stringify(run.to_dict())).is_equal(before)


func test_pause_during_staging_holds_the_camera_and_restores_card_cursor() -> void:
	var c := _crawl()
	var d := _fight(c)
	c._open_pause()
	var at := c.player.global_position
	await await_millis(700)
	assert_vector(c.player.global_position).is_equal_approx(at, Vector3.ONE * 0.001)
	assert_bool(c.player.frozen).is_true()
	c.close_panel()
	await await_millis(700)
	assert_bool(d.staging).is_false()
	assert_bool(c.player.frozen).is_false()
	assert_bool(c.player.look_enabled).is_false()
	assert_bool(c.hud.pointer_free).is_true()
	assert_bool(d._hud_layer.visible).is_true()


func test_escape_cancels_selection_once_then_pauses_and_help_keeps_selection() -> void:
	var c := _crawl()
	var d := _fight(c)
	d.hand.select(0)
	_key(c, "ui_cancel")
	assert_int(d.hand.selected).is_equal(-1)
	assert_object(c.panel).is_null()
	d.hand.select(1)
	_key(c, "help")
	c.close_panel()
	assert_int(d.hand.selected).is_equal(1)
	_key(c, "ui_cancel")
	_key(c, "ui_cancel")
	assert_object(c.panel).is_same(c.pause)


func test_hidden_combat_controls_and_dead_targets_cannot_apply_actions() -> void:
	var c := _crawl()
	var d := _fight(c)
	var f := d.fight()
	f.hand = [CardInstance.new(900, "strike")] as Array[CardInstance]
	d.refresh()
	d.hand.select(0)
	c._open_pause()
	var before := JSON.stringify(f.to_dict())
	d.tags[0].targeted.emit(0)
	d.end_turn()
	d._on_card_pressed(0)
	assert_str(JSON.stringify(f.to_dict())).is_equal(before)
	c.close_panel()
	f.enemies[0].alive = false
	before = JSON.stringify(f.to_dict())
	d.play_card(0, 0)
	assert_str(JSON.stringify(f.to_dict())).is_equal(before)
	d.tags[1].targeted.emit(1)
	assert_int(f.cards_played_this_turn).is_equal(1)
	d.tags[1].targeted.emit(1)
	assert_int(f.cards_played_this_turn).is_equal(1)


func test_pause_on_a_killing_action_resumes_the_sequence_and_reward_once() -> void:
	var c := _crawl()
	var d := _fight(c)
	var f := d.fight()
	f.hand = [CardInstance.new(901, "strike")] as Array[CardInstance]
	f.enemies[0].hp = 1
	f.enemies[1].alive = false
	d.refresh()
	d.play_card(0, 0)
	c._open_pause()
	var cursor := d.animator._cursor
	await await_millis(900)
	assert_int(d.animator._cursor).is_equal(cursor)
	assert_object(c.director).is_same(d)
	assert_object(c.panel).is_same(c.pause)
	c.close_panel()
	await await_millis(1800)
	assert_object(c.director).is_null()
	assert_object(c.panel).is_same(c.choice)
	assert_str(c.game.campaign.run.phase).is_equal("reward")
	assert_int(c.game.campaign.run.stats.measured(1)["fights"]).is_equal(1)


func test_inspection_does_not_consume_rng_or_change_draw_order() -> void:
	var c := _crawl()
	var d := _fight(c)
	var before := JSON.stringify(d.fight().to_dict())
	c._inspect_pile("draw")
	assert_object(c.panel).is_same(c.inspector)
	assert_array(c.inspector.cards).has_size(d.fight().draw_pile.size())
	c.close_panel()
	assert_str(JSON.stringify(d.fight().to_dict())).is_equal(before)
	assert_bool(c.hud.pointer_free).is_true()


func test_map_and_marker_are_read_only_and_share_the_world_grid() -> void:
	var c := _crawl()
	c.game.start_run(1)
	var run := c.game.campaign.run
	var before := JSON.stringify(c.game.campaign.to_dict())
	var at := c.player.global_position
	_key(c, "floor_map")
	assert_object(c.floor_map.layout).is_same(c.layout)
	var cell := c.layout.room_center(c.layout.stairs_room)
	c.floor_map.select_cell(cell)
	assert_vector(c._map_marker).is_equal(cell)
	assert_str(JSON.stringify(c.game.campaign.to_dict())).is_equal(before)
	c.close_panel()
	assert_vector(c.player.global_position).is_equal(at)
	assert_bool(c.player.look_enabled).is_true()
	assert_str(run.phase).is_equal("node")


func test_preview_identity_and_lifetime_follow_the_selected_record() -> void:
	var c := _crawl()
	var ghost := c.game.campaign.ladder.ghosts[0]
	c.inspect_ghost(ghost.id)
	await await_idle_frame()
	assert_bool(c.ghost_detail._back.has_focus()).is_true()
	assert_int((c._frames[c.ghost_detail] as PanelFrame).scroll.scroll_vertical).is_equal(0)
	var preview := c.ghost_detail.preview
	assert_str(preview.identity).is_equal("ghost:" + str(ghost.id))
	var old := preview.visual
	preview.show_ghost(ghost)
	assert_bool(is_instance_valid(old)).is_false()
	assert_int(preview.stage.get_child_count()).is_equal(4)
	c.close_panel()
	assert_int(preview.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	assert_bool(preview.is_processing()).is_false()


func test_deep_ledger_does_not_falsely_place_a_ghost_on_floor_sixty() -> void:
	var c := _crawl()
	for floor in [1, 30, 31, 61, 75]:
		var ghost := c.game.campaign.ladder.add(Ghost.from_expedition(c.game.campaign.hero, floor, 1000))
		c.inspect_ghost(ghost.id)
		assert_int(c.ghost_detail.preview.visual.ghost_floor).is_equal(floor)
		assert_int(c.guild.well.selected_floor).is_equal(floor)
		c.close_panel()


func test_guild_mutations_are_unavailable_in_a_run() -> void:
	var c := _crawl()
	c.game.campaign.soul = 100000
	c.game.start_run(1)
	var before := JSON.stringify(c.game.campaign.to_dict())
	assert_bool(c.game.buy_upgrade("vigor")["ok"]).is_false()
	assert_bool(c.game.tend(1)["ok"]).is_false()
	assert_bool(c.game.launch_expedition()["ok"]).is_false()
	assert_str(JSON.stringify(c.game.campaign.to_dict())).is_equal(before)


func test_keyboard_focus_survives_hover_and_reaches_targets_and_end_turn() -> void:
	var c := _crawl()
	var d := _fight(c)
	await await_millis(650)
	var first := d.hand.views[0]
	var next := first.get_node(first.focus_next)
	d.hand.hover(0)
	assert_object(first.get_node(first.focus_next)).is_same(next)
	var seen: Array[Control] = []
	var control: Control = first
	for _i in 30:
		if seen.has(control):
			break
		seen.append(control)
		control = control.get_node(control.focus_next)
	assert_array(seen).contains([d.tags[0], d.tags[1], d._end_turn])
	var action: Dictionary = CombatEngine.legal_actions(d.fight()).filter(func(a: Dictionary) -> bool: return a.get("target", -1) >= 0)[0]
	d._on_card_pressed(action["hand_index"])
	assert_bool(d.tags[0].has_focus()).is_true()
	var key := InputEventAction.new()
	key.action = "ui_accept"
	key.pressed = true
	var before := d.fight().cards_played_this_turn
	d.tags[0]._gui_input(key)
	d.tags[0]._gui_input(key)
	assert_int(d.fight().cards_played_this_turn).is_equal(before + 1)


func test_choice_cards_and_deck_inspect_without_taking_the_reward() -> void:
	var c := _crawl()
	c.game.start_run(1)
	var run := c.game.campaign.run
	run.phase = "reward"
	run.reward = {"cards": ["strike"]}
	c._sync()
	var before := JSON.stringify(run.to_dict())
	c.choice._cards[0].inspected.emit(c.choice._cards[0].record)
	assert_object(c.panel).is_same(c.inspector)
	c.close_panel()
	assert_object(c.panel).is_same(c.choice)
	c.choice.deck_requested.emit()
	assert_int(c.inspector.cards.size()).is_equal(run.hero.deck.size())
	c.close_panel()
	assert_str(JSON.stringify(run.to_dict())).is_equal(before)


func test_map_world_cell_centres_and_clicks_agree() -> void:
	var c := _crawl()
	c.game.start_run(1)
	_key(c, "floor_map")
	await await_idle_frame()
	var cell := c.layout.room_center(c.layout.entry_room)
	var expected := c.floor_map.origin() + (Vector2(cell) + Vector2.ONE * 0.5) * c.floor_map.cell_size()
	assert_vector(c.floor_map.map_point(Kit.cell_to_world(cell))).is_equal(expected)
	c.floor_map.select_at(expected)
	assert_vector(c.floor_map.marker).is_equal(cell)


func test_death_sequence_pauses_and_commits_the_same_ghost_once() -> void:
	var c := _crawl()
	var d := _fight(c)
	await await_millis(650)
	var hero_name := c.game.campaign.hero.name
	var count := c.game.campaign.ladder.ghosts.size()
	d.fight().hero_hp = 1
	d.end_turn()
	await await_millis(2500)
	assert_object(c.panel).is_same(c.epitaph)
	_key(c, "ui_cancel")
	var stage := c.epitaph.stage
	await await_millis(700)
	assert_int(c.epitaph.stage).is_equal(stage)
	assert_bool(c._world.can_process()).is_false()
	c.close_panel()
	assert_object(c.panel).is_same(c.epitaph)
	assert_bool(c._world.can_process()).is_true()
	await await_millis(700)
	c._sync()
	assert_int(c.game.campaign.ladder.ghosts.size()).is_equal(count + 1)
	assert_str(c.game.campaign.ladder.ghosts.back().name).is_equal(hero_name)
	c._on_epitaph_dismissed()
	assert_int(c.guild.well.figures.size()).is_equal(count + 1)


func test_each_legacy_phase_loads_into_a_valid_world_and_resolves_once() -> void:
	for file in DirAccess.get_files_at("res://tests/fixtures/legacy_v1"):
		if not file.ends_with(".json"):
			continue
		var original := SaveGame.load_campaign(TestFixtures.content(), "res://tests/fixtures/legacy_v1/" + file)
		assert_int(SaveGame.save(original, PATH)).is_equal(OK)
		var c := _crawl()
		c.exit_panel.threaded = false
		await await_idle_frame()
		var run := c.game.campaign.run
		if run == null:
			assert_bool(c.place == Crawl.Place.GUILD or c.panel == c.epitaph).is_true()
		else:
			if run.phase in ChoiceScreen.PHASES:
				assert_object(c.panel).is_same(c.choice)
			if run.phase != "descent":
				assert_int(c.place).is_equal(Crawl.Place.DUNGEON)
				var cell := Kit.world_to_cell(c.player.global_position)
				assert_bool(c.layout.is_walkable(cell.x, cell.y)).is_true()
			if run.phase == "exit":
				c._on_stairs_entered(-1)
				assert_object(c.panel).is_same(c.exit_panel)
		var after := JSON.stringify(c.game.campaign.to_dict())
		c._sync()
		c._sync()
		assert_str(JSON.stringify(c.game.campaign.to_dict())).is_equal(after)
		c.game.sfx.release()
		c.game.queue_free()
		c.queue_free()
		await await_idle_frame()
		await await_idle_frame()


func test_current_fight_reload_preserves_state_and_scene_without_an_extra_turn() -> void:
	var c := _crawl()
	var d := _fight(c)
	await await_millis(650)
	d.end_turn()
	await await_millis(2000)
	assert_str(c.game.campaign.run.phase).is_equal("fight")
	assert_int(c.game.save()).is_equal(OK)
	var expected := c.game.campaign.run.fight.to_dict()
	var loaded := _crawl()
	assert_object(loaded.director).is_not_null()
	assert_dict(loaded.director.fight().to_dict()).is_equal(expected)
	assert_bool(loaded.player.look_enabled).is_false()
	_key(loaded, "help")
	loaded.close_panel()
	assert_dict(loaded.director.fight().to_dict()).is_equal(expected)


func test_ui_settings_persist_and_refresh_the_actual_caller() -> void:
	var c := _crawl()
	c.open_guild(GuildRoom.DESK)
	var sheet: HeroScreen = c.panel
	var frame: PanelFrame = c._frames[sheet]
	c._open_options()
	c.settings.ui_scale = 1.5
	c.settings.reduced_motion = true
	c.settings.locale = "es"
	c._on_settings_changed(c.settings)
	c.close_panel()
	assert_object(c.panel).is_same(sheet)
	assert_object(c._frames[sheet]).is_same(frame)
	assert_str(sheet._class.text).is_equal(c.game.text("class.sexton.name"))
	assert_bool(c.player.reduced_motion).is_true()
	assert_bool(Settings.motion_reduced).is_true()
	var saved := Settings.load_from(c.settings_path)
	assert_float(saved.ui_scale).is_equal(1.5)
	assert_str(saved.locale).is_equal("es")
	assert_bool(saved.reduced_motion).is_true()


func test_offline_summary_reuses_its_frame_and_restores_the_required_exit() -> void:
	var c := _crawl()
	c.game.start_run(1)
	var run := c.game.campaign.run
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	run.phase = "exit"
	c.build_floor()
	c._on_stairs_entered(0)
	assert_object(c.panel).is_same(c.exit_panel)
	c.game.offline = {"counted": 3600, "soul": 50.0, "returned": []}
	var before := JSON.stringify(c.game.campaign.to_dict())
	c._maybe_show_offline()
	var summary := c.panel
	var count := c._frames.size()
	c.close_panel()
	assert_object(c.panel).is_same(c.exit_panel)
	c._maybe_show_offline()
	assert_object(c.panel).is_same(summary)
	assert_int(c._frames.size()).is_equal(count)
	c.close_panel()
	assert_str(JSON.stringify(c.game.campaign.to_dict())).is_equal(before)


func test_expedition_arrival_updates_an_open_floor_without_duplicate_accrual() -> void:
	var c := _crawl()
	c.open_guild(GuildRoom.WELL)
	var screen: LadderScreen = c.panel
	screen.select_floor(7)
	var expedition := Expedition.new()
	expedition.id = 1
	expedition.started_at = 1000
	expedition.seconds = 60
	expedition.ghost = Ghost.from_expedition(c.game.campaign.hero, 7, 1000)
	expedition.ghost.strength = 40.0
	expedition.ghost.fixed_strength = true
	c.game.campaign.expeditions.append(expedition)
	var count := c.game.campaign.ladder.ghosts.size()
	c.game.clock = func() -> int: return 1060
	c.game._process(0.5)
	await await_idle_frame()
	assert_object(c.panel).is_same(screen)
	assert_int(screen.selected_floor).is_equal(7)
	assert_int(c.guild.well.selected_floor).is_equal(7)
	assert_int(c.game.campaign.ladder.ghosts.size()).is_equal(count + 1)
	assert_str(screen._preview.identity).is_equal("ghost:" + str(expedition.ghost.id))
	var after := JSON.stringify(c.game.campaign.to_dict())
	c.game._process(0.5)
	assert_str(JSON.stringify(c.game.campaign.to_dict())).is_equal(after)


func test_primary_panels_fit_a_compact_spanish_viewport_at_large_ui_scale() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(960, 540)
	add_child(viewport)
	var c := _crawl(viewport)
	c.settings.ui_scale = 1.5
	c.settings.locale = "es"
	c._on_settings_changed(c.settings)
	for station in [GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.DESK, GuildRoom.HALL, GuildRoom.WELL]:
		c.open_guild(station)
		await await_millis(60)
		var frame: PanelFrame = c._frames[c.panel]
		assert_float(frame.get_global_rect().end.x).is_less_equal(961.0)
		assert_float(c.panel.size.x).is_less_equal(frame.scroll.size.x)
		c.close_panel()

	c.game.offline = {"counted": 3600, "soul": 50.0, "returned": [c.game.campaign.ladder.ghosts[0]]}
	c._maybe_show_offline()
	await await_millis(60)
	var offline_frame: PanelFrame = c._frames[c.panel]
	assert_float(c.panel.get_combined_minimum_size().y).is_greater(offline_frame.scroll.size.y)
	assert_bool(offline_frame.scroll.get_v_scroll_bar().visible).is_true()


func test_scaled_keyboard_focus_scrolls_primary_actions_into_view() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(2560, 1080)
	add_child(viewport)
	var c := _crawl(viewport)
	c.settings.ui_scale = 1.25
	c._on_settings_changed(c.settings)
	c.game.campaign.record_depth = 44
	c.game.campaign.ladder.add(Ghost.from_expedition(c.game.campaign.hero, 42, 1000))
	c.open_guild(GuildRoom.WELL)
	var ladder: LadderScreen = c.panel
	ladder.select_floor(42)
	await await_millis(60)
	var frame: PanelFrame = c._frames[ladder]
	for button: Control in [ladder._descend, ladder._residents.get_child(0), ladder._descend]:
		button.grab_focus()
		await await_millis(60)
		var visible := frame.scroll.get_global_rect()
		var bounds := button.get_global_rect()
		assert_float(bounds.position.y).is_greater_equal(visible.position.y - 1.0)
		assert_float(bounds.end.y).is_less_equal(visible.end.y + 1.0)
