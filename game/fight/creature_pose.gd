class_name CreaturePose
extends RefCounted
## How a creature stands, breathes, flinches and falls.
##
## Pure. Every function here takes numbers and returns a table of joint name ->
## `Transform3D` **offset from rest**, and touches nothing in the scene tree.
## That is not tidiness: the suite runs `--headless`, so anything handed to the
## RenderingServer is invisible to it, and a body's motion was previously a
## tween on a node position that a test could only read back as the number it
## had just written. Motion expressed as maths is motion a test can actually
## check -- that a flinch peaks and returns, that a collapse only ever goes
## down, that two creatures of the same kind do not breathe in lockstep.
##
## `CreatureRig` applies these; `EnemyBody` decides which to ask for.

## The joints a creature may have. A rig applies whichever of these it built
## and ignores the rest, so one pose function serves all five archetypes.
const ROOT := "Root"
const CHEST := "Chest"
const HEAD := "Head"
const JAW := "Jaw"
const ARM_L := "ArmL"
const ARM_R := "ArmR"
const LEG_L := "LegL"
const LEG_R := "LegR"
const TAIL := "Tail"

## Seconds for a flinch to settle. Short: a hit that is still visibly settling
## when the next card lands reads as lag rather than as impact.
const HIT_SECONDS := 0.34
## Seconds for a body to finish falling.
const DEATH_SECONDS := 0.9


## A creature's own phase, so a room of three bone rats does not breathe as one
## animal. Derived from the index rather than randomised, because a fight
## replays from its seed and the room should replay with it.
static func phase_for(index: int) -> float:
	return fposmod(float(index) * 2.399963, TAU)


## One full idle cycle for an archetype, in seconds. Slower for heavy things:
## a boss that fidgets at a rat's rate reads as weightless.
static func idle_seconds(kind: int) -> float:
	match kind:
		EnemyShape.Kind.WISP:
			return 2.6
		EnemyShape.Kind.BEAST:
			return 1.1
		EnemyShape.Kind.HULK:
			return 3.4
		EnemyShape.Kind.STACK:
			return 2.2
		_:
			return 1.9


## The whole pose, which is what a rig asks for once a frame.
##
## `hurt` and `dead` are 0..1 progress values rather than seconds so the caller
## owns the clock -- `EnemyBody` drives them from tweens, and a test drives
## them directly.
static func pose(kind: int, time: float, phase: float, hurt: float = 0.0,
		dead: float = 0.0) -> Dictionary:
	var out := idle(kind, time, phase)
	if hurt > 0.0:
		_add(out, flinch(kind, clampf(hurt, 0.0, 1.0)))
	if dead > 0.0:
		var going := clampf(dead, 0.0, 1.0)
		# The breathing goes out with the lights. Adding a collapse on top of a
		# running idle leaves a corpse that is still breathing on the floor,
		# which is the one thing about a kill nobody forgives.
		_fade(out, 1.0 - going)
		_add(out, collapse(kind, going))
	return out


## Breathing, swaying, drifting. What the thing does when it is not doing
## anything -- and the reason to put it in the room with you rather than on a
## card, so it is the one animation that is never allowed to be nothing.
static func idle(kind: int, time: float, phase: float) -> Dictionary:
	var w := TAU / idle_seconds(kind)
	var t := time * w + phase
	var out := {}

	match kind:
		EnemyShape.Kind.WISP:
			# No ground contact, so all of it is drift. Two frequencies, or it
			# reads as a metronome.
			out[ROOT] = _at(Vector3(sin(t * 0.7) * 0.09, sin(t) * 0.11, cos(t * 0.53) * 0.07))
			out[HEAD] = _rot(Vector3(sin(t * 0.9) * 0.12, cos(t * 0.6) * 0.3, 0.0))
		EnemyShape.Kind.BEAST:
			# Low and quick: the shoulders work and the head hangs.
			out[ROOT] = _at(Vector3(0.0, absf(sin(t)) * 0.022, 0.0))
			out[CHEST] = _rot(Vector3(sin(t) * 0.05, sin(t * 0.5) * 0.06, 0.0))
			out[HEAD] = _rot(Vector3(0.16 + sin(t * 1.3) * 0.09, sin(t * 0.41) * 0.34, 0.0))
			out[TAIL] = _rot(Vector3(0.0, sin(t * 0.8) * 0.5, sin(t) * 0.16))
		EnemyShape.Kind.STACK:
			# A pile is only ever settling. Nothing about it is symmetrical.
			out[ROOT] = _at(Vector3(sin(t * 0.6) * 0.012, 0.0, cos(t * 0.43) * 0.01))
			out[CHEST] = _rot(Vector3(sin(t * 0.7) * 0.05, sin(t * 0.31) * 0.12, cos(t * 0.5) * 0.06))
			out[HEAD] = _rot(Vector3(cos(t * 0.9) * 0.07, sin(t * 0.6) * 0.2, sin(t * 0.8) * 0.05))
		EnemyShape.Kind.HULK:
			out[ROOT] = _at(Vector3(0.0, sin(t) * 0.035, 0.0))
			out[CHEST] = _rot(Vector3(0.1 + sin(t) * 0.035, sin(t * 0.37) * 0.07, 0.0))
			out[HEAD] = _rot(Vector3(sin(t * 0.8) * 0.06, sin(t * 0.29) * 0.22, 0.0))
			out[ARM_L] = _rot(Vector3(sin(t + 0.6) * 0.09, 0.0, 0.22))
			out[ARM_R] = _rot(Vector3(sin(t - 0.6) * 0.09, 0.0, -0.22))
			out[JAW] = _rot(Vector3(maxf(0.0, sin(t * 0.5)) * 0.22, 0.0, 0.0))
		_:
			out[ROOT] = _at(Vector3(0.0, sin(t) * 0.025, 0.0))
			out[CHEST] = _rot(Vector3(sin(t) * 0.03, sin(t * 0.43) * 0.08, 0.0))
			out[HEAD] = _rot(Vector3(sin(t * 1.1) * 0.05, sin(t * 0.33) * 0.28, cos(t * 0.7) * 0.04))
			out[ARM_L] = _rot(Vector3(sin(t + 1.1) * 0.13, 0.0, 0.10))
			out[ARM_R] = _rot(Vector3(sin(t - 1.1) * 0.13, 0.0, -0.10))
			# The jaw hangs and knocks. A skull with a fused mouth is a helmet.
			out[JAW] = _rot(Vector3(0.06 + maxf(0.0, sin(t * 1.7)) * 0.16, 0.0, 0.0))
	return out


## Taking a hit. `amount` is 0..1 of the way through the flinch, so 1.0 is the
## moment of impact and 0.0 is settled.
##
## The body goes back and the head goes back further and later, which is the
## whole of why a jointed creature reads better than a sliding one: the parts
## lag behind the blow.
static func flinch(kind: int, amount: float) -> Dictionary:
	var give := 1.0
	if kind == EnemyShape.Kind.HULK:
		give = 0.45
	elif kind == EnemyShape.Kind.WISP:
		give = 1.4
	var a := amount * give
	var out := {}
	out[ROOT] = _at(Vector3(0.0, 0.0, a * 0.16))
	out[CHEST] = _rot(Vector3(-a * 0.24, 0.0, 0.0))
	out[HEAD] = _rot(Vector3(-a * 0.42, 0.0, a * 0.1))
	out[JAW] = _rot(Vector3(a * 0.5, 0.0, 0.0))
	out[ARM_L] = _rot(Vector3(-a * 0.3, 0.0, a * 0.2))
	out[ARM_R] = _rot(Vector3(-a * 0.3, 0.0, -a * 0.2))
	return out


## Falling apart. `t` is 0..1 through the death.
##
## Monotonic downward by construction -- every vertical term is negative and
## scales with `t` -- because a corpse that bobs back up on the way down is the
## single most obvious way for procedural death to look wrong, and it is the
## one thing a headless test can pin.
static func collapse(kind: int, t: float) -> Dictionary:
	var e := t * t
	var out := {}
	out[ROOT] = Transform3D(Basis(Vector3.RIGHT, -e * PI * 0.42),
		Vector3(0.0, -e * _drop(kind), e * 0.12))
	out[CHEST] = _rot(Vector3(-e * 0.5, e * 0.2, e * 0.3))
	out[HEAD] = _rot(Vector3(e * 0.9, -e * 0.5, e * 0.6))
	out[JAW] = _rot(Vector3(e * 0.7, 0.0, 0.0))
	out[ARM_L] = _rot(Vector3(e * 1.1, 0.0, e * 0.9))
	out[ARM_R] = _rot(Vector3(e * 1.3, 0.0, -e * 0.7))
	out[LEG_L] = _rot(Vector3(e * 0.5, 0.0, e * 0.4))
	out[LEG_R] = _rot(Vector3(e * 0.4, 0.0, -e * 0.5))
	out[TAIL] = _rot(Vector3(e * 0.6, 0.0, 0.0))
	return out


## How far a body sinks as it goes down. A wisp does not fall, it gutters out
## on the spot, and a hulk hits the floor from higher up.
static func _drop(kind: int) -> float:
	match kind:
		EnemyShape.Kind.WISP:
			return 0.1
		EnemyShape.Kind.HULK:
			return 0.5
		EnemyShape.Kind.BEAST:
			return 0.18
		_:
			return 0.34


static func _rot(euler: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(euler), Vector3.ZERO)


static func _at(offset: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, offset)


## Scales everything in `table` toward rest by `k`. `k` of 1 leaves it alone
## and 0 erases it.
static func _fade(table: Dictionary, k: float) -> void:
	for joint in table:
		var t: Transform3D = table[joint]
		table[joint] = Transform3D(Basis.IDENTITY.slerp(t.basis, k), t.origin * k)


## Composes `extra` onto `into`. Rotations multiply and offsets add, which is
## what "the flinch is on top of the breathing" means.
static func _add(into: Dictionary, extra: Dictionary) -> void:
	for joint in extra:
		var add: Transform3D = extra[joint]
		if into.has(joint):
			var base: Transform3D = into[joint]
			into[joint] = Transform3D(base.basis * add.basis, base.origin + add.origin)
		else:
			into[joint] = add
