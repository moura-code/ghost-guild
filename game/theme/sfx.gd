class_name Sfx
extends Node
## The game's sound.
##
## Ghost Guild shipped its whole vertical slice without one AudioStream in
## it. On a game this restrained visually that was the largest remaining gap
## in how it feels: the art direction deliberately does not shout, so almost
## everything the player is meant to feel about a blow landing has to arrive
## through the ear.
##
## Every sound is synthesised by `tools/audio/generate.py` -- square waves,
## triangles, noise and short envelopes, the same handful of parts a sound
## chip had. That is not a shortcut around licensing (though it is also
## that); it is the sonic equivalent of a 28-colour palette at 640x360. A
## library sample of a real sword would sit against this game the way a
## photograph sits against a sprite.
##
## A fixed pool of players rather than one per call: an enemy phase resolves
## several blows in a single apply() and the animator fires them a beat
## apart, so the pool has to absorb a burst without either allocating during
## a fight or dropping the last hits of a round.

## Every id the game may ask for. Anything not here is silence, and a test
## fails if a name in this list has no file behind it -- a sound that never
## plays is the hardest kind of bug to notice.
const CATALOGUE := [
	"click", "hover", "back",
	"card_play", "card_draw", "card_take",
	"hit_light", "hit_heavy", "block", "enemy_die", "hero_hurt",
	"turn_start", "descend", "floor_clear",
	"soul", "purchase",
	"epitaph", "ghost_place",
]

## Room tone. Separate from the catalogue because it is played on its own
## looping voice rather than from the pool, and because it is the one sound
## the player is meant not to notice until it stops.
const AMBIENCE := "amb_crypt"

const ROOT := "res://assets/sfx"
## Enough for a full enemy phase plus the UI sound that lands on top of it.
const VOICES := 12
## Room tone sits well under everything else. Loud ambience is the fastest
## way to make a player turn the sound off.
const AMBIENCE_LEVEL := 0.45

var muted: bool = false:
	set(value):
		muted = value
		if muted:
			stop_all()

var volume: float = 0.8:
	set(value):
		volume = clampf(value, 0.0, 1.0)

var _players: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _cache: Dictionary = {}
var _next: int = 0
var _duck: Tween


static func path_for(id: String) -> String:
	return "%s/%s.wav" % [ROOT, id]


func _ready() -> void:
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Master"
	add_child(_ambience)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		# Sound effects, not music: they should duck under nothing and never
		# hold up the scene tree when it is torn down mid-fight.
		player.bus = "Master"
		add_child(player)
		_players.append(player)


## Plays `id`, or does nothing if there is no such sound. Silence is always
## the failure mode -- content and screens will ask for sounds that do not
## exist yet and that must never interrupt a fight.
func play(id: String, pitch: float = 1.0) -> void:
	if muted or _players.is_empty():
		return
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.0001, volume))
	# A little variation, so ten identical blows in a row do not read as one
	# sound repeating -- which is what makes a hit sound cheap.
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


## A blow, at the weight the engine says it landed with. Kept here rather
## than in the animator so "what does damage sound like" is one decision.
func hit(amount: int) -> void:
	if amount >= BIG_HIT:
		play("hit_heavy", randf_range_pitch(0.96, 1.04))
	else:
		play("hit_light", randf_range_pitch(0.92, 1.10))


## The same threshold the animator uses for hit-stop and shake, so the ear
## and the eye agree about which blows were the heavy ones.
const BIG_HIT := 10


## Deterministic enough for a game that replays from a seed: this varies the
## voice, not the simulation, so it may use engine randomness where `core/`
## may not.
func randf_range_pitch(low: float, high: float) -> float:
	return low + (high - low) * randf()


## Starts the room. Loops forever, quietly -- a crypt is not silent, it is
## still, and the difference between those two is most of what makes a drawn
## room feel occupied rather than merely lit.
func start_ambience() -> void:
	if muted or _ambience == null or _ambience.playing:
		return
	var source := load(path_for(AMBIENCE)) as AudioStreamWAV
	if source == null:
		return
	# Duplicated, then looped here. Godot's wav importer ignores
	# `edit/loop_mode` for this file, so the loop has to be set at runtime --
	# and setting it on `load`'s shared cached resource would edit the copy
	# every other caller sees. The duplicate is released in _exit_tree.
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	_ambience.stream = stream
	_ambience.volume_db = linear_to_db(maxf(0.0001, volume * AMBIENCE_LEVEL))
	_ambience.play()


## Pulls the room down under something that needs the space, and lets it back
## up after. The epitaph is the case this exists for: a drone under the beat
## the spec calls the emotional centre is a drone competing with it.
func duck(seconds: float = 1.2, depth: float = 0.25) -> void:
	if _ambience == null or not _ambience.playing:
		return
	if _duck != null and _duck.is_valid():
		_duck.kill()
	var full := linear_to_db(maxf(0.0001, volume * AMBIENCE_LEVEL))
	var under := linear_to_db(maxf(0.0001, volume * AMBIENCE_LEVEL * depth))
	_ambience.volume_db = under
	_duck = create_tween()
	_duck.tween_property(_ambience, "volume_db", full, seconds) 		.set_delay(seconds * 0.5).set_trans(Tween.TRANS_SINE)


func stop_all() -> void:
	for player in _players:
		player.stop()
	if _ambience != null:
		_ambience.stop()


## The ambience holds a duplicated stream and a running tween, neither of
## which the scene tree tears down on its own -- both showed up as leaked
## resources at exit.
## A looping stream never finishes, so at shutdown its playback is still live
## and both it and the stream show up as leaked instances. Released on the way
## out through both paths, because an autoload's children are not guaranteed
## to see _exit_tree before the audio server goes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		release()


func _exit_tree() -> void:
	release()


func release() -> void:
	if _duck != null and _duck.is_valid():
		_duck.kill()
	_duck = null
	if _ambience != null:
		_ambience.stop()
		_ambience.stream = null
	for player in _players:
		player.stop()
		player.stream = null
	_cache.clear()


func _stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	if not CATALOGUE.has(id):
		_cache[id] = null
		return null
	var path := path_for(id)
	var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_cache[id] = stream
	return stream
