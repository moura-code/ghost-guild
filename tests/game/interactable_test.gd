extends GdUnitTestSuite
## One interactable type for the whole game. It reports; it never acts.


func _it() -> Interactable:
	var i: Interactable = auto_free(Interactable.create("table", Vector3(3.0, 0.0, -2.0), "ui.guild.table"))
	add_child(i)
	return i


func test_it_stands_where_it_was_put_and_watches_only_the_player() -> void:
	var i := _it()
	assert_vector(i.position).is_equal_approx(Vector3(3.0, 0.0, -2.0), Vector3.ONE * 0.001)
	assert_int(i.collision_layer).is_equal(Interactable.LAYER_INTERACTABLE)
	assert_int(i.collision_mask).is_equal(Player.LAYER_PLAYER)


func test_walking_up_focuses_it_and_walking_off_lets_go() -> void:
	var i := _it()
	var seen: Array = []
	i.focused.connect(func(id: String) -> void: seen.append("in:" + id))
	i.blurred.connect(func(id: String) -> void: seen.append("out:" + id))
	var body: CharacterBody3D = auto_free(CharacterBody3D.new())
	i.enter(body)
	i.enter(body)
	i.leave(body)
	i.leave(body)
	assert_array(seen).is_equal(["in:table", "out:table"])


func test_pressing_e_only_does_something_while_you_are_standing_in_it() -> void:
	var i := _it()
	var used: Array = []
	i.used.connect(func(id: String) -> void: used.append(id))
	i.use()
	assert_array(used).is_empty()
	i.enter(auto_free(CharacterBody3D.new()))
	i.use()
	assert_array(used).is_equal(["table"])


func test_it_carries_the_line_to_show_while_you_are_in_it() -> void:
	assert_str(_it().label_key).is_equal("ui.guild.table")


func test_reach_is_something_you_can_widen_for_a_bigger_thing() -> void:
	var wide: Interactable = auto_free(Interactable.create("well", Vector3.ZERO, "ui.guild.well", 4.0))
	add_child(wide)
	var shape: SphereShape3D = (wide.get_node("Shape") as CollisionShape3D).shape
	assert_float(shape.radius).is_equal_approx(4.0, 0.001)
