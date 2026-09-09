extends GdUnitTestSuite
## The game in another language (spec §11, M3: Spanish localization).
##
## The design is one line long: English is always loaded first, and the chosen
## locale is loaded on top of it. A partial translation is the normal state of
## a translation, and that fallback is the only thing standing between a
## missing row and a raw key printed on screen where a sentence should be.


func _en() -> Content:
	return Content.load_from("res://data")


func _es() -> Content:
	return Content.load_from("res://data", "es")


# ------------------------------------------------------------- the mechanism

func test_english_is_the_default_and_says_so() -> void:
	var c := _en()
	assert_str(c.locale).is_equal("en")
	assert_array(c.load_errors).is_empty()


func test_another_locale_loads_clean() -> void:
	var c := _es()
	assert_str(c.locale).is_equal("es")
	assert_array(c.load_errors).override_failure_message(
		"loading Spanish reported: %s" % str(c.load_errors)).is_empty()


func test_a_language_nobody_has_written_falls_back_rather_than_failing() -> void:
	# A missing locale file is a language that does not exist yet, not a
	# broken content set -- the game still has to boot in English.
	var c := Content.load_from("res://data", "qq")
	assert_array(c.load_errors).override_failure_message(
		"a missing translation broke the content load").is_empty()
	assert_str(c.text("ui.soul")).is_equal(_en().text("ui.soul"))


func test_a_missing_row_falls_back_to_english_rather_than_to_its_own_key() -> void:
	# The property the whole design exists for. Simulated rather than trusted:
	# every key is translated today, so the fallback is proved by loading a
	# locale that translates nothing.
	var c := Content.load_from("res://data", "qq")
	for key in ["ui.descend", "ui.exit.watch", "card.strike.name"]:
		assert_str(c.text(key)).override_failure_message(
			"%s came back as its own key" % key).is_not_equal(key)


# ------------------------------------------------------------- the Spanish

## The handful of rows that are the same in both languages, and why.
##
## A translation is not wrong for agreeing with the original. Listing them
## explicitly is what turns 'this row was never translated' from invisible
## into a test failure -- the coverage check below is only worth anything
## because this list is closed.
const SAME_IN_BOTH := {
	"room.engage": "key binding and placeholder",
	"ghost.founder.name": "a person's name",
	"ui.menu.title": "the game's title",
	"ui.upgraded": "a plus sign",
	"ui.card.cost_x": "the letter X",
	"stat.vigor.name": "the same word in Spanish",
	"status.vulnerable.name": "the same word in Spanish",
	"card.miasma.name": "the same word in Spanish",
	"ui.run.mutation": "two placeholders and a dash",
	"ui.language.en": "a language is named in its own language",
	"ui.language.es": "a language is named in its own language",
}


func test_every_english_string_has_a_spanish_row() -> void:
	# Required by the claim that the game ships in Spanish. A half-translated
	# screen is worse than an English one.
	var en := _en()
	var rows := _rows_of("res://data/strings/es.csv")
	var missing: Array[String] = []
	for key in en.strings:
		if not rows.has(String(key)):
			missing.append(String(key))
	assert_array(missing).override_failure_message(
		"%d keys have no row in es.csv: %s"
		% [missing.size(), str(missing.slice(0, 12))]).is_empty()


func test_the_rows_that_read_the_same_are_the_ones_we_know_about() -> void:
	var en := _en()
	var es := _es()
	var same: Array[String] = []
	for key in en.strings:
		if String(es.strings.get(key, "")) == String(en.strings[key]):
			if not SAME_IN_BOTH.has(String(key)):
				same.append(String(key))
	assert_array(same).override_failure_message(
		"%d rows are still English and are not on the list: %s"
		% [same.size(), str(same.slice(0, 12))]).is_empty()


## Every key with a row in a strings file, however it reads.
func _rows_of(path: String) -> Dictionary:
	var out: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var first := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if first:
			first = false
			continue
		if row.size() >= 2 and row[0].strip_edges() != "":
			out[row[0]] = row[1]
	file.close()
	return out


func test_the_spanish_actually_changes_what_is_on_screen() -> void:
	assert_str(_es().text("ui.descend")).is_not_equal(_en().text("ui.descend"))
	assert_str(_es().text("ui.soul")).is_equal("Alma")


func test_no_spanish_string_is_cut_in_half_by_its_own_comma() -> void:
	# The same trap `slice_content_test` guards en.csv against, and Spanish
	# reaches for a comma more often than English does.
	var file := FileAccess.open("res://data/strings/es.csv", FileAccess.READ)
	assert_object(file).is_not_null()
	var line_no := 0
	while not file.eof_reached():
		var raw := file.get_line()
		line_no += 1
		if raw.strip_edges() == "":
			continue
		var first := raw.find(",")
		if first == -1:
			continue
		var value := raw.substr(first + 1)
		if value.begins_with("\""):
			continue
		assert_bool(value.contains(",")).override_failure_message(
			"line %d of es.csv loses everything after its comma: %s" % [line_no, raw]) \
			.is_false()
	file.close()


func test_every_placeholder_survives_translation() -> void:
	# `{floor}` is not a word. A translator who drops one leaves a sentence
	# with a hole in it, and nothing else in the game would ever notice.
	var en := _en()
	var es := _es()
	var broken: Array[String] = []
	for key in en.strings:
		if _holes(String(en.strings[key])) != _holes(String(es.strings.get(key, ""))):
			broken.append(String(key))
	assert_array(broken).override_failure_message(
		"placeholders differ in: %s" % str(broken.slice(0, 12))).is_empty()


# ------------------------------------------------------------- the settings

func test_a_config_naming_a_language_we_do_not_ship_reads_as_english() -> void:
	# A hand-edited config should give you a playable game, not a screen of
	# raw keys -- the same rule the rest of Settings follows.
	var s := Settings.new()
	s.from_dict({"locale": "klingon"})
	assert_str(s.locale).is_equal("en")
	s.from_dict({"locale": "es"})
	assert_str(s.locale).is_equal("es")


func test_the_chosen_language_survives_a_save() -> void:
	var s := Settings.new()
	s.locale = "es"
	var back := Settings.new()
	back.from_dict(s.to_dict())
	assert_str(back.locale).is_equal("es")


## Every `{placeholder}` in a string, as a sorted list.
func _holes(text: String) -> Array[String]:
	var out: Array[String] = []
	var rest := text
	while true:
		var open := rest.find("{")
		if open == -1:
			break
		var shut := rest.find("}", open)
		if shut == -1:
			break
		out.append(rest.substr(open + 1, shut - open - 1))
		rest = rest.substr(shut + 1)
	out.sort()
	return out
