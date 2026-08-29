extends GdUnitTestSuite
## The fight, staged where you are standing. The camera never cuts away --
## this is a first-person game, so "the camera locks to it" means your own
## body is frozen and your own head turns. What is asserted here is the
## staging maths, the freeze, and the one rule the whole pivot rests on: the
## only thing that reaches the run is a RunEngine action.

const TMP := "user://test_saves/fight_director_test.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 4
	return g


func _hud() -> HudRoot:
	var h: HudRoot = auto_free(HudRoot.new())
	add_child(h)
	h.fit(Vector2(1280.0, 720.0))
	return h


func _player() -> Player:
	var p: Player = auto_free(Player.new())
	add_child(p)
	return p


## A run parked in a fight against `enemies`, ready to stage.
func _fight_run(g: GameRoot, enemies: Array) -> RunState:
	var run := g.start_run(1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": enemies}])
	RunEngine.apply(run, {"kind": "enter"})
	return run


func _director(g: GameRoot, enemies: Array = ["bone_rat"]) -> FightDirector:
	_fight_run(g, enemies)
	var d: FightDirector = auto_free(FightDirector.new())
	add_child(d)
	d.begin(g, _hud(), _player(), Vector3(9.0, 0.0, 12.0))
	return d


func test_the_stage_seats_everyone_in_front_of_you() -> void:
	var at := Vector3(9.0, 0.0, 12.0)
	var facing := Vector3(0.0, 0.0, -1.0)
	for count in [1, 2, 3]:
		var points := FightDirector.stage_points(count, at, facing)
		assert_array(points).has_size(count)
		for raw in points:
			var p: Vector3 = raw
			# In front, not behind: the enemies are between you and the far
			# wall, never at your back.
			assert_float((p - at).dot(facing)).override_failure_message("enemy behind the player").is_greater(0.0)


func test_nobody_stands_inside_anybody_else() -> void:
	var points := FightDirector.stage_points(3, Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	for i in points.size():
		for j in range(i + 1, points.size()):
			assert_float((points[i] as Vector3).distance_to(points[j])).is_greater(0.7)


func test_the_stage_is_symmetric_and_moves_with_you() -> void:
	var facing := Vector3(0.0, 0.0, -1.0)
	var here := FightDirector.stage_points(3, Vector3.ZERO, facing)
	var there := FightDirector.stage_points(3, Vector3(20.0, 0.0, -5.0), facing)
	for i in 3:
		assert_vector((there[i] as Vector3) - Vector3(20.0, 0.0, -5.0)).is_equal_approx(here[i], Vector3.ONE * 0.001)
	# The middle of a three-enemy line is straight ahead.
	assert_float((here[1] as Vector3).x).is_equal_approx(0.0, 0.001)


func test_it_stands_a_body_up_for_every_enemy() -> void:
	var d := _director(_game(), ["bone_rat", "shambler"])
	assert_array(d.bodies).has_size(2)
	assert_int(d.bodies[0].index).is_equal(0)
	assert_int(d.bodies[1].index).is_equal(1)


func test_a_fight_leaves_you_in_your_body_but_frees_the_mouse_for_the_cards() -> void:
	# You can walk the room during a fight. The movement is atmospheric, not
	# tactical: core/combat has no concept of space, so where you stand cannot
	# change the rules -- and promising positional agency without delivering it
	# would be worse than the freeze it replaces.
	var d := _director(_game())
	assert_bool(d.player.frozen).is_false()
	assert_bool(d.player.look_enabled).is_false()
	assert_bool(d.hud.pointer_free).is_true()


func test_you_are_fenced_into_the_room_you_are_fighting_in() -> void:
	# Walking off down the corridor mid-fight is not "atmospheric".
	var d := _director(_game())
	var ring: StaticBody3D = d.get_node("Ring")
	assert_int(ring.collision_layer).is_equal(DungeonBuilder.LAYER_WORLD)
	var walls := 0
	for child in ring.get_children():
		if child is CollisionShape3D:
			walls += 1
	assert_int(walls).is_equal(4)


func test_the_fence_comes_down_when_the_fight_ends() -> void:
	var g := _game()
	var d := _director(g, ["bone_rat"])
	TestFixtures.autofight(g.campaign.run)
	d.check_over()
	await await_idle_frame()
	assert_object(d.get_node_or_null("Ring")).is_null()


func test_the_hand_you_are_holding_is_on_screen() -> void:
	var d := _director(_game())
	assert_int(d.hand.visible_count()).is_equal(d.fight().hand.size())
	assert_int(d.hand.visible_count()).is_greater(0)


func test_the_engine_is_the_authority_on_what_can_be_played() -> void:
	var d := _director(_game())
	var legal: Dictionary = {}
	for action in CombatEngine.legal_actions(d.fight()):
		if String(action.get("kind", "")) == "play":
			legal[int(action["hand_index"])] = true
	assert_int(d.playable.size()).is_equal(legal.size())
	for index in legal:
		assert_bool(d.playable.has(index)).is_true()


func test_playing_a_card_reaches_the_run_and_nothing_else_does() -> void:
	var g := _game()
	var d := _director(g)
	# Combat events land on the fight's own log, not the run's: RunEngine.apply
	# returns them to the caller but only appends run-level events to
	# `run.events`. The fight is where a played card is recorded.
	var f := d.fight()
	var before := f.events.size()
	var index: int = d.playable.keys()[0]
	d.play_card(index, -1)
	assert_int(f.events.size()).is_greater(before)
	# The whole pivot's invariant: what happened is exactly what the engine
	# logged, because there is no other way in.
	assert_array(TestFixtures.events_of(f, "card_played")).is_not_empty()


func test_a_single_enemy_needs_no_target_chosen() -> void:
	var d := _director(_game(), ["bone_rat"])
	assert_bool(d.needs_target(d.playable.keys()[0])).is_false()


func test_ending_the_turn_ends_the_turn() -> void:
	var g := _game()
	var d := _director(g)
	var run := g.campaign.run
	var f := d.fight()
	var turn := f.turn
	var before := f.events.size()
	d.end_turn()
	assert_int(f.events.size()).is_greater(before)
	# Either the enemies took their turn and it is yours again, or they
	# finished the fight. Both are "the turn ended".
	assert_bool(run.phase != "fight" or run.fight.turn > turn).is_true()


func test_a_dead_body_is_no_longer_a_target() -> void:
	var d := _director(_game(), ["bone_rat", "shambler"])
	d.bodies[0].die()
	var living := d.living_bodies()
	assert_array(living).has_size(1)
	assert_int((living[0] as EnemyBody).index).is_equal(1)


func test_winning_gives_you_back_your_body_and_says_so_once() -> void:
	var g := _game()
	var d := _director(g, ["bone_rat"])
	var done := [0]
	d.fight_finished.connect(func() -> void: done[0] += 1)
	TestFixtures.autofight(g.campaign.run)
	d.check_over()
	d.check_over()
	assert_int(int(done[0])).is_equal(1)
	assert_bool(d.player.frozen).is_false()
	assert_bool(d.player.look_enabled).is_true()
	assert_bool(d.hud.pointer_free).is_false()


func test_the_anchors_it_hands_the_animator_name_the_hero_and_every_enemy() -> void:
	var d := _director(_game(), ["bone_rat", "shambler"])
	var anchors := d.anchors()
	assert_bool(anchors.has("hero")).is_true()
	assert_bool(anchors.has(0)).is_true()
	assert_bool(anchors.has(1)).is_true()


func test_a_finished_fight_takes_its_interface_off_the_screen() -> void:
	# The hand, the vitals and the end-turn button are children of the HUD,
	# not of the director, so freeing the director does not free them. Without
	# an explicit teardown a second fight deals a second hand beside the first
	# one, forever.
	var g := _game()
	var hud := _hud()
	var d: FightDirector = auto_free(FightDirector.new())
	add_child(d)
	_fight_run(g, ["bone_rat"])
	d.begin(g, hud, _player(), Vector3(9.0, 0.0, 12.0))
	var before := hud.ui.get_child_count()
	assert_int(before).is_greater(0)
	remove_child(d)
	d._exit_tree()
	await await_idle_frame()
	var left := 0
	for child in hud.ui.get_children():
		if is_instance_valid(child):
			left += 1
	assert_int(left).is_equal(before - 1)
	add_child(d)


func test_you_end_up_facing_what_you_are_fighting() -> void:
	# Walking in from a corner used to leave the enemies off to one side while
	# the camera obediently looked at the geometric centre of the floor.
	var g := _game()
	var d := _director(g, ["bone_rat", "shambler"])
	# The turn is tweened, not snapped -- the head whipping round is the
	# difference between "a fight started" and "the screen changed".
	await await_millis(int(FightDirector.TURN_SECONDS * 1000.0) + 250)
	var forward := -d.player.global_transform.basis.z
	for b in d.bodies:
		var to_body: Vector3 = (b as EnemyBody).global_position - d.player.global_position
		to_body.y = 0.0
		assert_float(forward.normalized().dot(to_body.normalized())).override_failure_message(
			"enemy %d is not in front of the player" % (b as EnemyBody).index).is_greater(0.35)
