extends GdUnitTestSuite

func test_harness_runs() -> void:
	assert_int(1 + 1).is_equal(2)

func test_can_read_project_file() -> void:
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_str(text).contains("Ghost Guild")
