class_name FightAnimator
extends Control
## Turns the combat engine's event stream into feel (spec §9): floating
## numbers, screen shake scaled to the hit, and a fade when something dies.
##
## This exists because the engine already returns the events an action
## produced — `apply(state, action) -> events` — so the UI never has to diff
## state to work out what just happened. Every number that appears here is
## something the engine actually said.
##
## Tested for state, not pixels: which numbers were spawned, with what text
## and colour, and how much shake an event asked for.

signal shake_requested(strength: float)
## Fired as each hit actually lands, so the thing that was hit reacts at
## the moment its number appears rather than all at once up front.
signal hit_landed(event: Dictionary)

const SHAKE_PER_DAMAGE := 0.7
const SHAKE_MAX := 14.0
const BIG_HIT := 10
## How long the sequence holds after a heavy blow or a kill.
const HIT_STOP := 0.09
const STAGGER := 14.0
## Seconds between one hit and the next. The combat engine resolves an
## entire enemy phase inside a single apply() call and hands back one flat
## array, so three enemies attacking used to land in the same rendered
## frame: a whole round played as one burst rather than as a sequence of
## blows. This is what made the fight feel flat.
const BEAT := 0.14

var content: Content
## The ear and the eye are driven from the same event stream, at the same
## beat, so a blow you see land is a blow you hear land. Optional: the
## animator works silently if nothing set it, which is what tests get.
var sfx: Sfx
## The numbers spawned by the most recent play() call. Tests read this.
var last_spawned: Array[FloatNumber] = []

var _queue: Array = []
var _anchors: Dictionary = {}
var _cursor: int = 0
var _beat: Tween
var _beat_counts: Dictionary = {}
var _hold: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func bind(c: Content) -> void:
	content = c


## `anchors` maps "hero" and each living enemy index to a screen position.
## Events whose anchor is missing are still counted but spawn nothing, so a
## fight can animate before layout has settled.
func play(events: Array, anchors: Dictionary) -> void:
	last_spawned.clear()
	_queue = events.duplicate()
	_anchors = anchors.duplicate()
	_cursor = 0
	_beat_counts.clear()
	if _beat != null and _beat.is_valid():
		_beat.kill()
	_step()


## One beat of the sequence: everything that should land together lands,
## then the next beat is scheduled. Events with no visible effect are
## consumed without spending a beat on them, so a turn does not stall on
## bookkeeping.
func _step() -> void:
	while _cursor < _queue.size():
		var event: Dictionary = _queue[_cursor]
		_cursor += 1
		if _render(event, _stagger_for(event)):
			break
	if _cursor < _queue.size() and is_inside_tree():
		_beat = create_tween()
		# Hit-stop: a heavy blow holds the sequence a moment longer before
		# the next one lands, which is what gives it weight. Scoped to this
		# animator's own pacing rather than Engine.time_scale, because the
		# simulation must not know the presentation exists.
		_beat.tween_interval(BEAT + (_hold if _hold > 0.0 else 0.0))
		_beat.tween_callback(_step)
	_hold = 0.0


## Numbers from the same beat stagger vertically so a multi-hit attack does
## not stack every number on one pixel.
func _stagger_for(event: Dictionary) -> int:
	# Keyed by what was hit, so numbers landing on the same target in one
	# beat stack upward instead of on top of each other. `target` is a
	# String on damage events but an int on card_played, so it cannot be
	# typed -- str() takes either.
	var target: Variant = event.get("target", "")
	var key := "%s%d" % [str(target), int(event.get("index", -1))]
	var n := int(_beat_counts.get(key, 0))
	_beat_counts[key] = n + 1
	return n


## Returns true when the event was worth a beat.
func _render(event: Dictionary, stagger: int) -> bool:
	var type := String(event.get("type", ""))
	match type:
		"damage":
			var amount := int(event.get("amount", 0))
			if amount <= 0:
				# A fully absorbed hit is still an event the player should
				# feel -- it is the block doing its job.
				_spawn(content.text("ui.fight.blocked"), Palette.SOUL, _anchor(event), stagger)
				_sound("block")
				hit_landed.emit(event)
				return true
			var at: Variant = _anchor(event)
			_spawn(str(amount), Palette.DANGER, at, stagger, amount >= BIG_HIT)
			if at != null:
				_spark(at as Vector2, Palette.DANGER, amount >= BIG_HIT)
			if amount >= BIG_HIT:
				_hold = HIT_STOP
			if String(event.get("target", "")) == "hero":
				shake_requested.emit(minf(SHAKE_MAX, float(amount) * SHAKE_PER_DAMAGE))
				_sound("hero_hurt")
			elif sfx != null:
				sfx.hit(amount)
			hit_landed.emit(event)
			return true
		"block_gained":
			var block := int(event.get("amount", 0))
			if block <= 0:
				return false
			_spawn("+%d" % block, Palette.SOUL, _anchor(event), stagger)
			_sound("block")
			return true
		"heal":
			var healed := int(event.get("amount", 0))
			if healed <= 0:
				return false
			_spawn("+%d" % healed, Palette.GOOD, _anchor(event), stagger)
			return true
		"status_applied":
			var stacks := int(event.get("stacks", 0))
			if stacks <= 0:
				return false
			_spawn(content.text("status.%s.name" % String(event.get("status", ""))),
				Palette.PREPARED, _anchor(event), stagger)
			return true
		"enemy_died":
			var died_at: Variant = _anchor(event)
			_spawn(content.text("ui.fight.slain"), Palette.BONE_DIM, died_at, stagger, true)
			if died_at != null:
				# A death throws more, and throws it in bone.
				_spark(died_at as Vector2, Palette.BONE, true)
			_hold = HIT_STOP * 1.6
			_sound("enemy_die")
			hit_landed.emit(event)
			return true
	return false


func _sound(id: String) -> void:
	if sfx != null:
		sfx.play(id)


## Damage to the hero shakes; damage to an enemy does not. The screen only
## lurches when the player is the one being hit.
static func shake_for(events: Array) -> float:
	var shake := 0.0
	for event in events:
		if String(event.get("type", "")) != "damage":
			continue
		if String(event.get("target", "")) != "hero":
			continue
		shake = maxf(shake, minf(SHAKE_MAX, float(int(event.get("amount", 0))) * SHAKE_PER_DAMAGE))
	return shake


func _anchor(event: Dictionary) -> Variant:
	if String(event.get("target", "")) == "hero":
		return _anchors.get("hero")
	if event.has("index"):
		return _anchors.get(int(event["index"]))
	return _anchors.get("hero")


## True while a sequence is still playing out.
func is_playing() -> bool:
	return _cursor < _queue.size()


## A burst of sparks where the blow landed. Text alone tells the player
## what happened; this makes it feel like it happened. One-shot, cheap, and
## frees itself -- no art, just points.
func _spark(at: Vector2, colour: Color, big: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12 if big else 7
	p.lifetime = 0.22 if big else 0.16
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2(0.0, 220.0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0 if big else 105.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6 if big else 1.8
	p.color = colour
	add_child(p)
	# CPUParticles2D does not tidy up after a one-shot burst.
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)


## Several events land in one action; staggering them vertically keeps a
## multi-hit attack from stacking every number on the same pixel.
func _spawn(text: String, colour: Color, at: Variant, stagger: int, big: bool = false) -> void:
	if at == null:
		return
	var number := FloatNumber.make(text, colour, big)
	add_child(number)
	last_spawned.append(number)
	number.launch((at as Vector2) + Vector2(0.0, -STAGGER * float(stagger)))
