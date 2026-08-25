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

const ROOT := "res://assets/sfx"
## Enough for a full enemy phase plus the UI sound that lands on top of it.
const VOICES := 12

var muted: bool = false:
	set(value):
		muted = value
		if muted:
			stop_all()

var volume: float = 0.8:
	set(value):
		volume = clampf(value, 0.0, 1.0)

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next: int = 0


static func path_for(id: String) -> String:
	return "%s/%s.wav" % [ROOT, id]


func _ready() -> void:
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


func stop_all() -> void:
	for player in _players:
		player.stop()


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
