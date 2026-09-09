class_name Torches
extends Node3D
## The floor's flames, and the clock that drives them.
##
## `DungeonBuilder` already grouped every torch under one node; this makes
## that node do the work, so the flicker costs one `_process` per floor rather
## than one per light, and so it dies with the floor it belongs to instead of
## outliving it in `Crawl`.
##
## Rest energies are captured when the light is adopted, so `Flame` scales
## whatever the light was authored at: tuning a torch's brightness never means
## re-tuning the flicker.

## How far a torch carries. A few cells, so walking a corridor is walking past
## them one at a time -- twenty audible torches is a wall of noise, and a
## crackle you can hear from across the floor tells you nothing about where
## you are.
const REACH := Kit.CELL * 4.0
## The distance at which the crackle is at full level. Roughly "standing next
## to it".
const CLOSE := Kit.CELL * 0.8
## The most irrational number there is, which is what makes it the best step
## to walk a loop with: n steps of it are about as evenly spread over the
## cycle as n points can be, for every n.
const GOLDEN := 0.6180339887

## Well under the room tone. A torch is a texture you notice by walking away
## from it, not a sound that asks for attention.
const CRACKLE_LEVEL := 0.34

var _rest: Array[float] = []
var _lights: Array[Light3D] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _offsets: Array[float] = []
var _t: float = 0.0
## Looped once and shared. `load()` hands back one cached resource to every
## caller, so looping the loaded copy would edit what everyone else sees --
## the same trap `Sfx.start_ambience` documents. Duplicated once here instead
## of once per torch, because twenty copies of a six-second buffer is six
## megabytes to say the same thing twenty times.
var _crackle: AudioStreamWAV


## Takes a light into the rig at whatever brightness it arrived with, and
## gives it a voice.
func adopt(light: Light3D) -> void:
	add_child(light)
	_lights.append(light)
	_rest.append(light.light_energy)
	_add_voice(light)


## How many torches are in the rig. Not `get_child_count()`: since every torch
## also carries a voice, child count answers a different question and answers
## it with twice the number.
func count() -> int:
	return _lights.size()


## Torch `i`'s light. An accessor rather than `get_child(i)` because the rig
## also holds a voice per torch, so child order stopped meaning "the lights"
## the moment they got one.
func light(i: int) -> Light3D:
	return _lights[i] if i >= 0 and i < _lights.size() else null


## The crackle attached to torch `i`, or null if there was no sound to give it.
func voice(i: int) -> AudioStreamPlayer3D:
	return _voices[i] if i >= 0 and i < _voices.size() else null


## Where in the loop torch `i` was started, in seconds. Exposed because "do
## twenty torches crackle in unison" is the difference between a room and a
## flanged wall of noise, and it is not observable any other way.
func voice_offset(i: int) -> float:
	return _offsets[i] if i >= 0 and i < _offsets.size() else 0.0


func _add_voice(light: Light3D) -> void:
	var stream := _crackle_stream()
	if stream == null:
		return
	# Before the bus is assigned, not after: Godot silently keeps a name that
	# names no bus, and the sound then plays dry on Master -- which is a mix
	# bug that sounds exactly like a working game.
	Sfx.ensure_buses()
	var player := AudioStreamPlayer3D.new()
	player.name = "Crackle%d" % _voices.size()
	player.stream = stream
	player.bus = Sfx.BUS_AMBIENCE
	player.position = light.position
	player.unit_size = CLOSE
	player.max_distance = REACH
	player.volume_db = linear_to_db(CRACKLE_LEVEL)
	add_child(player)
	# Its own place in the loop, so the same six seconds on twenty players does
	# not comb into a single flanged voice. Where it stands, PLUS a golden-
	# ratio step per torch: position alone is a hash, and a hash is allowed to
	# put two of them next to each other, which is exactly the case this is
	# guarding. The golden step spreads any number of torches about as evenly
	# as they can be spread.
	var spread := fposmod(Flame.phase_for(light.position) + _voices.size() * GOLDEN, 1.0)
	var offset := spread * _loop_seconds(stream)
	_voices.append(player)
	_offsets.append(offset)
	player.play(offset)


func _crackle_stream() -> AudioStreamWAV:
	if _crackle != null:
		return _crackle
	var path := Sfx.path_for(Sfx.TORCH)
	if not ResourceLoader.exists(path):
		return null
	var source := load(path) as AudioStreamWAV
	if source == null:
		return null
	_crackle = source.duplicate() as AudioStreamWAV
	_crackle.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_crackle.loop_begin = 0
	_crackle.loop_end = _crackle.data.size() / 2
	return _crackle


static func _loop_seconds(stream: AudioStreamWAV) -> float:
	return float(stream.data.size() / 2) / float(maxi(1, stream.mix_rate))


func _process(delta: float) -> void:
	_t += delta
	var camera := get_viewport().get_camera_3d()
	for i in _lights.size():
		if Settings.motion_reduced:
			_lights[i].light_energy = _rest[i]
		elif camera == null or camera.global_position.distance_squared_to(_lights[i].global_position) <= REACH * REACH:
			Flame.drive(_lights[i], _rest[i], _t)
