extends GdUnitTestSuite


func _placed(seed: int, count: int = 5) -> FloorLayout:
	var layout := FloorLayout.create(LayoutGenerator.GRID, LayoutGenerator.GRID)
	LayoutGenerator.place_rooms(layout, count, Rng.new(seed))
	return layout


func test_it_places_every_room_it_was_asked_for() -> void:
	for seed in 12:
		assert_array(_placed(seed).rooms).has_size(5)


func test_rooms_stay_inside_the_grid() -> void:
	for seed in 12:
		var layout := _placed(seed)
		for raw in layout.rooms:
			var r: Dictionary = raw
			assert_bool(int(r["x"]) >= 0).is_true()
			assert_bool(int(r["y"]) >= 0).is_true()
			assert_bool(int(r["x"]) + int(r["w"]) <= layout.width).is_true()
			assert_bool(int(r["y"]) + int(r["h"]) <= layout.height).is_true()
			assert_bool(int(r["w"]) >= LayoutGenerator.ROOM_MIN).is_true()
			assert_bool(int(r["h"]) <= LayoutGenerator.ROOM_MAX).is_true()


func test_rooms_never_overlap_or_touch() -> void:
	for seed in 12:
		var rooms := _placed(seed).rooms
		for i in rooms.size():
			for j in range(i + 1, rooms.size()):
				var a: Dictionary = rooms[i]
				var b: Dictionary = rooms[j]
				var apart_x: bool = int(a["x"]) + int(a["w"]) < int(b["x"]) or int(b["x"]) + int(b["w"]) < int(a["x"])
				var apart_y: bool = int(a["y"]) + int(a["h"]) < int(b["y"]) or int(b["y"]) + int(b["h"]) < int(a["y"])
				assert_bool(apart_x or apart_y).is_true()


func test_placement_is_deterministic_and_varies_by_seed() -> void:
	assert_array(_placed(4).rooms).is_equal(_placed(4).rooms)
	var seen: Dictionary = {}
	for seed in 20:
		seen[str(_placed(seed).rooms)] = true
	assert_int(seen.size()).is_greater(1)
