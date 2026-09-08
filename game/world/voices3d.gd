class_name Voices3D
extends Node3D
## Sound that happens somewhere.
##
## `Sfx` is a flat pool: everything it plays arrives at the same level from
## the same nowhere, which is right for a card being played and wrong for a
## blow landing on the left-hand one of three creatures. This is the same
## pool with a position on it.
##
## It is not a replacement for `Sfx` and should not become one. A UI click has
## no place in the room, and putting it in one is how a game ends up with a
## menu that pans.
##
## Levels and the mute switch are read from the `Sfx` it is given rather than
## kept here, so there is still exactly one answer to "how loud is the game".

## Fewer than the flat pool: an enemy phase resolves several blows, but they
## land a beat apart and only a handful can be in the air at once.
const VOICES := 6
## The distance at which a sound is at full level, and the distance past which
## it is gone. A fight is staged a few metres away, so CLOSE is about "in the
## room with you" and REACH is generous -- these are events, and an event that
## fades out because you backed up is an event you missed.
const CLOSE := 2.4
const REACH := 32.0

## Where levels and the mute switch come from. Optional: a director that has
## no sound still stages a fight.
var sfx: Sfx

var _players: Array[AudioStreamPlayer3D] = []
var _next: int = 0


func _ready() -> void:
	# Before any player is built, for the same reason `Torches` does it:
	# assigning a bus name that names no bus leaves the sound playing dry on
	# Master, which is a mix bug that sounds like a working game.
	Sfx.ensure_buses()
	for i in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.name = "Voice%d" % i
		player.bus = Sfx.BUS_WORLD
		player.unit_size = CLOSE
		player.max_distance = REACH
		add_child(player)
		_players.append(player)


## Plays `id` at `at`, in global space. Silence is always the failure mode: a
## sound that does not exist, a pool that has not booted and a muted game all
## resolve to nothing rather than to an error mid-fight.
func play_at(id: String, at: Vector3, pitch: float = 1.0, level: float = 1.0) -> void:
	if _players.is_empty() or (sfx != null and sfx.muted):
		return
	var stream := Sfx.load_sound(id)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.global_position = at
	var gain := (sfx.volume if sfx != null else 1.0) * clampf(level, 0.0, 1.0)
	player.volume_db = linear_to_db(maxf(0.0001, gain))
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


## A blow, at the weight the engine says it landed with, from where it landed.
## Mirrors `Sfx.hit` so the two never disagree about which blows are heavy.
func hit_at(amount: int, at: Vector3) -> void:
	if amount >= Sfx.BIG_HIT:
		play_at("hit_heavy", at, _jitter(0.96, 1.04))
	else:
		play_at("hit_light", at, _jitter(0.92, 1.10))


## Varies the voice, not the simulation, so engine randomness is legal here in
## a way it never is under `core/`.
func _jitter(low: float, high: float) -> float:
	return low + (high - low) * randf()
