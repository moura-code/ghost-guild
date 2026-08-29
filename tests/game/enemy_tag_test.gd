extends GdUnitTestSuite
## The numbers you read every turn -- how much health is left, how hard the
## next blow lands -- drawn in 2D over the enemy rather than on it. A texture
## on a mesh in a dark corridor at whatever angle the fight left it is not
## something you can read.


func _fight(ids: Array = ["bone_rat"]) -> FightState:
	return TestFixtures.bare_state(ids)


func _tag(index: int = 0) -> EnemyTag:
	var t: EnemyTag = auto_free(EnemyTag.create(index))
	add_child(t)
	return t


func test_a_tag_knows_which_enemy_it_belongs_to() -> void:
	assert_int(_tag(2).index).is_equal(2)


func test_it_shows_the_enemy_by_name() -> void:
	var f := _fight(["shambler"])
	var t := _tag()
	t.bind(TestFixtures.content(), f, 0)
	var def: EnemyDef = TestFixtures.content().enemies["shambler"]
	assert_str(t._name.text).is_equal(TestFixtures.content().text(def.name_key))
	assert_str(t._name.text).is_not_equal(def.name_key)


func test_the_intent_is_read_from_the_engine_and_never_invented() -> void:
	var f := _fight()
	var text := EnemyTag.intent_text(TestFixtures.content(), f, 0)
	assert_str(text).is_not_empty()
	# Whatever it says, it resolves to words rather than to a bare key.
	assert_bool(text.begins_with("ui.")).is_false()


func test_a_multi_hit_attack_says_so() -> void:
	# Not asserted against a specific enemy's numbers, which balance can
	# change -- asserted on the shape the formatter produces.
	var f := _fight()
	var intent := EnemyAI.intent_of(f, 0)
	if String(intent.get("kind", "")) != "attack":
		return
	var text := EnemyTag.intent_text(TestFixtures.content(), f, 0)
	if int(intent.get("hits", 1)) > 1:
		assert_str(text).contains("x")
	else:
		assert_str(text).is_equal(str(int(intent.get("damage", 0))))


func test_a_dead_enemy_has_no_tag_on_screen() -> void:
	var f := _fight()
	f.enemies[0].alive = false
	var t := _tag()
	t.bind(TestFixtures.content(), f, 0)
	assert_bool(t.visible).is_false()


func test_the_tag_floats_above_the_head_it_was_given() -> void:
	var t := _tag()
	t.place(Vector2(300.0, 200.0))
	# Centred horizontally, and clear of the point vertically.
	assert_float(t.position.x + EnemyTag.WIDTH * 0.5).is_equal_approx(300.0, 0.01)
	assert_float(t.position.y + t.size.y).is_less(200.0)


func test_it_never_swallows_a_click_meant_for_a_card() -> void:
	assert_int(_tag().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
