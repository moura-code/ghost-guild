extends GdUnitTestSuite


func test_small_numbers_keep_one_decimal() -> void:
	assert_str(Num.short(0.0)).is_equal("0")
	assert_str(Num.short(7.0)).is_equal("7")
	assert_str(Num.short(7.5)).is_equal("7.5")
	assert_str(Num.short(52.04)).is_equal("52")
	assert_str(Num.short(999.0)).is_equal("999")


func test_thousands_and_up_use_letter_suffixes() -> void:
	assert_str(Num.short(1000.0)).is_equal("1.00K")
	assert_str(Num.short(1250.0)).is_equal("1.25K")
	assert_str(Num.short(12500.0)).is_equal("12.5K")
	assert_str(Num.short(125000.0)).is_equal("125K")
	assert_str(Num.short(1.0e6)).is_equal("1.00M")
	assert_str(Num.short(1.0e9)).is_equal("1.00B")
	assert_str(Num.short(1.0e12)).is_equal("1.00T")


func test_past_trillions_it_counts_in_two_letter_tiers() -> void:
	assert_str(Num.short(1.0e15)).is_equal("1.00aa")
	assert_str(Num.short(1.0e18)).is_equal("1.00ab")
	assert_str(Num.short(1.0e21)).is_equal("1.00ac")
	assert_str(Num.short(1.0e99)).is_equal("1.00bc")


func test_negatives_and_non_finite_values_never_crash() -> void:
	assert_str(Num.short(-1500.0)).is_equal("-1.50K")
	assert_str(Num.short(NAN)).is_equal("0")
	assert_str(Num.short(INF)).is_equal("0")


func test_rate_percent_and_signed() -> void:
	assert_str(Num.rate(52.0)).is_equal("52/h")
	assert_str(Num.rate(1250.0)).is_equal("1.25K/h")
	assert_str(Num.percent(0.62)).is_equal("62%")
	assert_str(Num.percent(1.4)).is_equal("140%")
	assert_str(Num.percent(0.0)).is_equal("0%")
	assert_str(Num.signed(12.0)).is_equal("+12")
	assert_str(Num.signed(-12.0)).is_equal("-12")
	assert_str(Num.signed(0.0)).is_equal("+0")


func test_duration_reads_as_hours_and_minutes() -> void:
	assert_str(Num.duration(0)).is_equal("0m")
	assert_str(Num.duration(59)).is_equal("0m")
	assert_str(Num.duration(60)).is_equal("1m")
	assert_str(Num.duration(3600)).is_equal("1h")
	assert_str(Num.duration(3660)).is_equal("1h 1m")
	assert_str(Num.duration(28800)).is_equal("8h")
	assert_str(Num.duration(-5)).is_equal("0m")


func test_the_tier_boundary_rounds_the_way_it_reads() -> void:
	assert_str(Num.short(999.4)).is_equal("999.4")
	assert_str(Num.short(1_000_000.0 - 1.0)).is_equal("1000K")
