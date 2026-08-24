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

const SHAKE_PER_DAMAGE := 0.7
const SHAKE_MAX := 14.0
const BIG_HIT := 10
const STAGGER := 14.0

var content: Content
## The numbers spawned by the most recent play() call. Tests read this.
var last_spawned: Array[FloatNumber] = []


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
	var shake := 0.0
	var stagger := 0
	for event in events:
		var type := String(event.get("type", ""))
		match type:
			"damage":
				var amount := int(event.get("amount", 0))
				if amount <= 0:
					continue
				_spawn(str(amount), Palette.DANGER, _anchor(event, anchors), stagger, amount >= BIG_HIT)
				stagger += 1
				if String(event.get("target", "")) == "hero":
					shake = maxf(shake, minf(SHAKE_MAX, float(amount) * SHAKE_PER_DAMAGE))
			"block_gained":
				var block := int(event.get("amount", 0))
				if block <= 0:
					continue
				_spawn("+%d" % block, Palette.SOUL, _anchor(event, anchors), stagger)
				stagger += 1
			"heal":
				var healed := int(event.get("amount", 0))
				if healed <= 0:
					continue
				_spawn("+%d" % healed, Palette.GOOD, _anchor(event, anchors), stagger)
				stagger += 1
			"status_applied":
				var stacks := int(event.get("stacks", 0))
				if stacks <= 0:
					continue
				var name_key := "status.%s.name" % String(event.get("status", ""))
				_spawn(content.text(name_key), Palette.PREPARED, _anchor(event, anchors), stagger)
				stagger += 1
			"enemy_died":
				_spawn(content.text("ui.fight.slain"), Palette.BONE_DIM, _anchor(event, anchors), stagger, true)
				stagger += 1
	if shake > 0.0:
		shake_requested.emit(shake)


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


func _anchor(event: Dictionary, anchors: Dictionary) -> Variant:
	if String(event.get("target", "")) == "hero":
		return anchors.get("hero")
	if event.has("index"):
		return anchors.get(int(event["index"]))
	return anchors.get("hero")


## Several events land in one action; staggering them vertically keeps a
## multi-hit attack from stacking every number on the same pixel.
func _spawn(text: String, colour: Color, at: Variant, stagger: int, big: bool = false) -> void:
	if at == null:
		return
	var number := FloatNumber.make(text, colour, big)
	add_child(number)
	last_spawned.append(number)
	number.launch((at as Vector2) + Vector2(0.0, -STAGGER * float(stagger)))
