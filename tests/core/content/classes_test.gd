extends GdUnitTestSuite
## Which classes the guild can send down (spec §3.4, §5.6).
##
## The game had one class for its whole life, and "the class" was written into
## six places as the string "sexton". A starting class is a *rule* -- the class
## nothing has to be unlocked for -- and this is where that rule lives.


func _content() -> Content:
	return Content.load_from("res://data")


func _ladder(content: Content, floors: Array) -> Ladder:
	var l := Ladder.new()
	for floor in floors:
		var hero := Hero.create(content, "sexton", "G%d" % int(floor), {}, 1)
		l.add(Ghost.from_expedition(hero, int(floor), 0))
	return l


func test_there_is_exactly_one_class_you_start_with() -> void:
	# Zero and the game cannot make a hero; two and "which one" is undefined.
	var c := _content()
	var starters: Array[String] = []
	for id in c.classes:
		if (c.classes[id] as ClassDef).unlocked_by == "":
			starters.append(String(id))
	assert_array(starters).has_size(1)
	assert_str(Classes.starting(c)).is_equal(starters[0])


func test_a_locked_class_names_a_biome_that_exists() -> void:
	var c := _content()
	for id in c.classes:
		var klass: ClassDef = c.classes[id]
		if klass.unlocked_by == "":
			continue
		assert_bool(c.biomes.has(klass.unlocked_by)).override_failure_message(
			"class %s is unlocked by '%s', which is not a biome" % [id, klass.unlocked_by]) \
			.is_true()


func test_a_fresh_guild_can_only_send_the_starting_class() -> void:
	var c := _content()
	var open := Classes.unlocked(c, _ladder(c, [1]))
	assert_array(open).is_equal([Classes.starting(c)])


func test_standing_in_a_biome_unlocks_what_it_holds() -> void:
	var c := _content()
	var open := Classes.unlocked(c, _ladder(c, [1, 14]))
	assert_array(open).contains(["hexer"])
	assert_array(open).contains([Classes.starting(c)])


func test_the_starting_class_is_never_locked_out() -> void:
	# Whatever the ladder says, and even when it says nothing at all.
	assert_array(Classes.unlocked(_content(), Ladder.new())).contains([Classes.starting(_content())])


func test_an_unknown_class_is_not_unlocked() -> void:
	assert_bool(Classes.is_unlocked(_content(), Ladder.new(), "no_such_class")).is_false()


func test_the_order_is_stable() -> void:
	# It becomes a list of buttons, and a list that reorders itself between
	# frames is a list you misclick.
	var c := _content()
	var l := _ladder(c, [1, 14])
	assert_array(Classes.unlocked(c, l)).is_equal(Classes.unlocked(c, l))
