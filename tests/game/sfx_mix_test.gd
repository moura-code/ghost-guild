extends GdUnitTestSuite
## The mix, measured off the files rather than trusted.
##
## `tools/audio/generate.py` is re-runnable, and the whole set was re-cut once
## already. That pass shipped four sounds at the wrong level and one that was
## a rattle where a body should have fallen, and every one of those was found
## by measuring rather than by reading the recipe. This is that measurement,
## kept.
##
## It asserts a HIERARCHY, not numbers: the biggest events are the loudest, the
## menu sits under the room, nothing clips and nothing is silent. Tuning a
## sound is meant to be free; inverting the mix is not.
##
## The source wavs are read straight off disk. The imported streams are QOA-
## compressed, so `AudioStreamWAV.data` is not PCM and cannot be measured --
## and the question here is about what the generator produced anyway.

## Loud enough to be heard over the room, quiet enough not to be the mix.
const MIN_RMS := 0.005


class Level:
	var rms: float = 0.0
	var peak: float = 0.0
	var samples: int = 0


## Reads a 16-bit mono RIFF wav and measures it. Chunks are walked rather than
## assumed at a fixed offset: a wav writer is free to put anything between the
## header and the audio.
func _measure(id: String) -> Level:
	var out := Level.new()
	var file := FileAccess.open(Sfx.path_for(id), FileAccess.READ)
	if file == null:
		return out
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return out
	var at := 12
	while at + 8 <= bytes.size():
		var chunk := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		var body := at + 8
		if chunk == "data":
			var count := mini(int(size), bytes.size() - body) / 2
			var sum := 0.0
			for i in count:
				var value := float(bytes.decode_s16(body + i * 2)) / 32768.0
				sum += value * value
				out.peak = maxf(out.peak, absf(value))
			out.samples = count
			out.rms = sqrt(sum / maxf(1.0, float(count)))
			return out
		# Chunks are word-aligned, so an odd size is followed by a pad byte.
		at = body + int(size) + (int(size) & 1)
	return out


func _rms(id: String) -> float:
	return _measure(id).rms


func test_nothing_in_the_catalogue_is_silence() -> void:
	# A sound that never plays is the hardest kind of bug to notice, and a
	# generator that writes an empty file is one bad recipe away.
	var quiet: Array[String] = []
	for id in Sfx.CATALOGUE:
		var level := _measure(String(id))
		if level.samples <= 0 or level.rms < MIN_RMS:
			quiet.append("%s (%d samples, rms %.4f)" % [id, level.samples, level.rms])
	assert_array(quiet).override_failure_message("silent or near-silent: %s" % ", ".join(quiet)).is_empty()


func test_nothing_clips() -> void:
	# A clipped sample is distortion, and distortion under a reverb is mud.
	# Every sound ends in `normalize` at a stated peak, so anything at 1.0
	# means two layers were summed after the normalize rather than before.
	var loud: Array[String] = []
	for id in Sfx.CATALOGUE + [Sfx.AMBIENCE, Sfx.TORCH]:
		var level := _measure(String(id))
		if level.peak >= 0.999:
			loud.append(String(id))
	assert_array(loud).override_failure_message("clipping: %s" % ", ".join(loud)).is_empty()


func test_a_heavy_blow_is_the_biggest_thing_in_a_fight() -> void:
	# The threshold exists so the player can tell the two apart without
	# reading the number. If they measure the same, the number is all there is.
	assert_float(_rms("hit_heavy")).override_failure_message("the heavy hit does not land").is_greater(_rms("hit_light") * 1.3)
	assert_float(_rms("hit_light")).is_greater(_rms("block"))


func test_your_feet_do_not_drown_out_the_fight() -> void:
	# Footsteps are the most repeated sound in the game by an order of
	# magnitude, and they are played at STEP_LEVEL on top of this.
	for id in Sfx.STEPS:
		assert_float(_rms(String(id)) * Sfx.STEP_LEVEL) \
			.override_failure_message("%s is louder than a blow" % id) \
			.is_less(_rms("hit_light") * 0.5)


func test_the_menu_sits_under_the_room() -> void:
	# A UI tick at the level of a creature dying is a game that shouts at you
	# for moving the mouse.
	var loudest_blow := minf(_rms("hit_light"), _rms("enemy_die"))
	for id in Sfx.DRY:
		assert_float(_rms(String(id))) \
			.override_failure_message("%s is as loud as the fight" % id) \
			.is_less(loudest_blow)


func test_the_dead_get_the_longest_sound_in_the_game() -> void:
	# Spec calls the epitaph the emotional centre, and it is the one sound
	# allowed to take a whole second. Anything longer than it is a mistake.
	var epitaph := _measure("epitaph").samples
	assert_int(epitaph).is_greater(0)
	for id in Sfx.CATALOGUE:
		if String(id) == "epitaph":
			continue
		assert_int(_measure(String(id)).samples) \
			.override_failure_message("%s outlasts the epitaph" % id) \
			.is_less_equal(epitaph)


func test_the_room_tone_and_the_torch_are_the_quiet_ones() -> void:
	# Both loop forever. Loud ambience is the fastest way to make a player
	# turn the sound off.
	assert_float(_rms(Sfx.AMBIENCE) * Sfx.AMBIENCE_LEVEL).is_less(_rms("hit_light"))
	assert_float(_rms(Sfx.TORCH) * Torches.CRACKLE_LEVEL).is_less(_rms("hit_light"))
