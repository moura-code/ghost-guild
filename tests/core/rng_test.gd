extends GdUnitTestSuite

func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 10:
		assert_int(a.randi_range("x", 0, 1000)).is_equal(b.randi_range("x", 0, 1000))

func test_different_seeds_differ() -> void:
	var a := Rng.new(1)
	var b := Rng.new(2)
	var same := 0
	for i in 20:
		if a.randi_range("x", 0, 100000) == b.randi_range("x", 0, 100000):
			same += 1
	assert_int(same).is_less(5)

func test_streams_are_independent() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	a.randi_range("other", 0, 1000)
	a.randi_range("other", 0, 1000)
	assert_int(a.randi_range("x", 0, 1000)).is_equal(b.randi_range("x", 0, 1000))

func test_shuffle_is_deterministic_and_permutes() -> void:
	var items := [1, 2, 3, 4, 5, 6, 7, 8]
	var x := items.duplicate()
	var y := items.duplicate()
	Rng.new(7).shuffle("s", x)
	Rng.new(7).shuffle("s", y)
	assert_array(x).is_equal(y)
	assert_array(x).is_not_equal(items)
	x.sort()
	assert_array(x).is_equal(items)

func test_clone_continues_identically() -> void:
	var a := Rng.new(3)
	a.randi_range("x", 0, 100)
	a.randf("y")
	var c := a.clone()
	for i in 5:
		assert_int(a.randi_range("x", 0, 100)).is_equal(c.randi_range("x", 0, 100))
		assert_float(a.randf("y")).is_equal(c.randf("y"))

func test_weighted_pick_skips_zero_weights() -> void:
	var a := Rng.new(1)
	for i in 50:
		assert_int(a.weighted_pick("w", [0.0, 1.0, 0.0])).is_equal(1)

func test_weighted_pick_covers_all_positive_weights() -> void:
	var a := Rng.new(9)
	var seen := {}
	for i in 200:
		seen[a.weighted_pick("w", [1.0, 1.0, 1.0])] = true
	assert_int(seen.size()).is_equal(3)

func test_pick_returns_member() -> void:
	var a := Rng.new(5)
	var items := ["a", "b", "c"]
	for i in 20:
		assert_bool(items.has(a.pick("p", items))).is_true()
