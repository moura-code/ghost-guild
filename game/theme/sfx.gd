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
	"step_a", "step_b", "step_c",
]

## The footstep variants, in rotation order. Three and not one because a
## corridor is thirty footfalls long: a single sample at three per second
## stops being a footstep and becomes a rhythm, which is the fastest way to
## make walking read as a machine rather than as a person.
const STEPS := ["step_a", "step_b", "step_c"]

## Feet are the most repeated sound in the game by an order of magnitude. At
## the level of a blow landing they would be the entire mix.
const STEP_LEVEL := 0.34

## Room tone. Separate from the catalogue because it is played on its own
## looping voice rather than from the pool, and because it is the one sound
## the player is meant not to notice until it stops.
const AMBIENCE := "amb_crypt"

## A torch, from two metres away. Not in the catalogue for the same reason
## AMBIENCE is not: it is played on its own looping 3D voice by `Torches`,
## from where the fire actually is, rather than pulled from the flat pool.
const TORCH := "amb_torch"

const ROOT := "res://assets/sfx"

## Three buses, because a crypt has a tail and a menu does not happen in the
## crypt. One reverb over everything makes the UI sound underwater; none at
## all leaves a blow landing in a stone corridor sounding like a button.
const BUS_UI := "Ui"
const BUS_WORLD := "World"
const BUS_AMBIENCE := "Ambience"

## Everything that happens on the HUD rather than in the room. The rest of the
## catalogue is in the world, so this is the shorter list and the safer
## default: a new sound is a world sound until someone says otherwise.
const DRY := [
	"click", "hover", "back",
	"card_play", "card_draw", "card_take",
	"soul", "purchase",
]
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


## The stream behind an id, or null for anything not in the catalogue.
##
## Static because `Voices3D` needs the same catalogue guard from a different
## pool, and two answers to "is there a sound called this" is one too many.
## Uncached on purpose: `ResourceLoader` already keeps one copy per path, and a
## second cache here would be a second thing to release at shutdown, which is
## precisely what the ambience notes below are about.
static func load_sound(id: String) -> AudioStream:
	if not CATALOGUE.has(id):
		return null
	var path := path_for(id)
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Builds the bus tree, once, whatever the order things boot in.
##
## In code rather than in a `default_bus_layout.tres` because the layout is a
## decision with a reason, and a reason does not survive a binary resource
## nobody can read a diff of. Idempotent because every Sfx that boots calls
## it and the suite boots a great many.
static func ensure_buses() -> void:
	for id in [BUS_UI, BUS_WORLD, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(id) >= 0:
			continue
		var at := AudioServer.bus_count
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, id)
		# Through Master, always: `Settings` turns the volume down by setting
		# bus 0, so a bus that sends anywhere else is a sound the volume
		# slider cannot reach.
		AudioServer.set_bus_send(at, "Master")
		if id == BUS_WORLD:
			AudioServer.add_bus_effect(at, _crypt_reverb())


## Stone, not a cathedral. A long tail on a corridor three metres wide reads
## as a mistake, and the wet level is kept low because every one of these
## sounds is short and transient -- reverb on a transient is audible at a
## fraction of what a sustained sound needs.
static func _crypt_reverb() -> AudioEffectReverb:
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.62
	verb.damping = 0.58
	verb.spread = 0.70
	verb.predelay_msec = 26.0
	verb.predelay_feedback = 0.25
	verb.wet = 0.24
	verb.dry = 1.0
	return verb


## Which bus a sound belongs on. Pure, so the routing is assertable: a typo'd
## bus name is routed to Master silently, which means the sound still plays
## and only the reverb is missing -- exactly the kind of wrong nobody hears.
static func bus_for(id: String) -> String:
	if id == AMBIENCE:
		return BUS_AMBIENCE
	return BUS_UI if DRY.has(id) else BUS_WORLD


func _ready() -> void:
	ensure_buses()
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS_AMBIENCE
	add_child(_ambience)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		# Sound effects, not music: they should duck under nothing and never
		# hold up the scene tree when it is torn down mid-fight.
		player.bus = BUS_WORLD
		add_child(player)
		_players.append(player)


## Plays `id`, or does nothing if there is no such sound. Silence is always
## the failure mode -- content and screens will ask for sounds that do not
## exist yet and that must never interrupt a fight.
func play(id: String, pitch: float = 1.0, level: float = 1.0) -> void:
	if muted or _players.is_empty():
		return
	var stream := _stream(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.bus = bus_for(id)
	player.volume_db = linear_to_db(maxf(0.0001, volume * clampf(level, 0.0, 1.0)))
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


## Which variant footfall number `index` uses. Pure, and separate from `step`,
## because the rotation is the part worth asserting and the audio server is
## the part a headless suite cannot hear.
static func step_sound(index: int) -> String:
	return STEPS[posmod(index - 1, STEPS.size())]


## A foot on stone. `index` is the footfall number from `Player.footfall`; the
## pitch jitter on top of the rotation is what stops even three samples
## reading as a loop over a long corridor.
func step(index: int) -> void:
	play(step_sound(index), randf_range_pitch(0.90, 1.12), STEP_LEVEL)


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
	var stream := load_sound(id)
	_cache[id] = stream
	return stream
