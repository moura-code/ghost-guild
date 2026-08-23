class_name Num
extends RefCounted

const SUFFIXES := ["", "K", "M", "B", "T"]
const LETTERS := "abcdefghijklmnopqrstuvwxyz"


static func short(v: float) -> String:
	if not is_finite(v):
		return "0"
	var sign_text := "-" if v < 0.0 else ""
	var a := absf(v)
	if a < 1000.0:
		return sign_text + _trim(a)
	var tier := int(floorf(log(a) / log(10.0) / 3.0))
	tier = maxi(1, tier)
	var scaled := a / pow(1000.0, float(tier))
	if scaled >= 1000.0:
		tier += 1
		scaled = a / pow(1000.0, float(tier))
	elif scaled < 1.0:
		tier -= 1
		scaled = a / pow(1000.0, float(tier))
	if tier <= 0:
		return sign_text + _trim(a)
	return sign_text + _mantissa(scaled) + _suffix(tier)


static func rate(v: float) -> String:
	return short(v) + "/h"


static func percent(v: float) -> String:
	if not is_finite(v):
		return "0%"
	return "%d%%" % int(roundf(v * 100.0))


static func signed(v: float) -> String:
	return ("-" if v < 0.0 else "+") + short(absf(v))


static func duration(seconds: int) -> String:
	var s := maxi(0, seconds)
	var hours := s / 3600
	var minutes := (s % 3600) / 60
	if hours > 0 and minutes > 0:
		return "%dh %dm" % [hours, minutes]
	if hours > 0:
		return "%dh" % hours
	return "%dm" % minutes


static func _trim(a: float) -> String:
	var rounded := roundf(a * 10.0) / 10.0
	if is_equal_approx(rounded, roundf(rounded)):
		return "%d" % int(roundf(rounded))
	return "%.1f" % rounded


static func _mantissa(scaled: float) -> String:
	if scaled < 10.0:
		return "%.2f" % scaled
	if scaled < 100.0:
		return "%.1f" % scaled
	return "%d" % int(roundf(scaled))


static func _suffix(tier: int) -> String:
	if tier < SUFFIXES.size():
		return String(SUFFIXES[tier])
	var index := tier - SUFFIXES.size()
	var first := index / 26
	var second := index % 26
	if first >= 26:
		return "??"
	return LETTERS[first] + LETTERS[second]
