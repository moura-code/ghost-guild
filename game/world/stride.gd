class_name Stride
extends RefCounted
## Walking, as maths: distance travelled in, footfalls and a head-bob offset
## out.
##
## It is a pure module for the same reason `DungeonBuilder.instance_transforms`
## is one. The suite runs headless and cannot watch a camera move, so the
## parts of "you feel like a person walking" that are checkable -- how long a
## step is, how many of them a corridor buys, where the head is at the instant
## a foot lands -- are lifted out of the frame loop into functions a test can
## call. What is left in `Player` is bookkeeping.
##
## Driven by **distance**, not by time. A body that is accelerating, sliding
## along a wall or walking into one covers less ground than its speed says it
## should, and a cadence read off the clock keeps marching while you stand
## still with your face in the stone.
##
## No engine randomness anywhere: this is presentation, so it would be legal,
## but a deterministic bob is one a test can pin exactly and a jittered one is
## indistinguishable from a broken one.

## Metres per footfall at each gait. Sprinting takes LONGER steps, not merely
## faster ones -- a sprint that only raises the cadence machine-guns the feet,
## which is what a doubled walk cycle sounds like.
const WALK_STRIDE := 1.2
const SPRINT_STRIDE := 1.62

## How far the head drops between footfalls, and how far it leans to the
## outside foot, in metres. Small on purpose: a first-person bob is felt at
## three centimetres and resented at ten.
const BOB_DOWN := 0.035
const BOB_SIDE := 0.022

## The phase is carried across every frame of a run, and a float that only
## ever grows loses the fractional precision the bob is made of. Wrapped at an
## even number of steps so the two-step sway is continuous across the seam.
const PHASE_WRAP := 1024.0

## How fast the bob eases in when you start moving and out when you stop, per
## second. Stopping should settle the head, not freeze it mid-dip.
const EASE_RATE := 6.0


## Metres per footfall at `speed`. Held at the walk value below walking pace:
## creeping into a wall shortens your steps to nothing otherwise, and a
## cadence that races as you decelerate reads as stumbling.
static func stride_length(speed: float) -> float:
	var walk := float(Player.SPEED)
	var sprint := float(Player.SPRINT)
	if speed <= walk or sprint <= walk:
		return WALK_STRIDE
	var t := clampf((speed - walk) / (sprint - walk), 0.0, 1.0)
	return lerpf(WALK_STRIDE, SPRINT_STRIDE, t)


## Carries the phase forward by `distance` metres travelled at `speed`. One
## whole unit of phase is one footfall.
static func advance(phase: float, distance: float, speed: float) -> float:
	if distance <= 0.0:
		return phase
	return fposmod(phase + distance / stride_length(speed), PHASE_WRAP)


## How many feet hit the ground between two phases. Counts the boundaries the
## interval crossed rather than the ground it covered, so a frame that lands
## halfway through a step owes nothing and the next one still owes exactly
## one.
static func footfalls(from: float, to: float) -> int:
	var delta := to - from
	if delta < 0.0:
		delta += PHASE_WRAP
	return floori(from + delta) - floori(from)


## Where the head sits relative to its rest position, in local metres.
##
## The dip runs at one cycle per footfall and is at its LOWEST exactly when a
## foot lands, because that is when your weight transfers onto it. A bob that
## peaks on the footfall reads as bouncing rather than walking and is the most
## common way a first-person camera is wrong.
##
## The sway runs at half that -- one cycle per two footfalls -- because you
## have two feet, and it leans the other way on the second one.
static func bob_offset(phase: float, amount: float) -> Vector3:
	if amount <= 0.0:
		return Vector3.ZERO
	var a := clampf(amount, 0.0, 1.0)
	return Vector3(
		BOB_SIDE * a * sin(phase * PI),
		-BOB_DOWN * a * (0.5 + 0.5 * cos(phase * TAU)),
		0.0)


## Eases the bob's weight toward `target` (1 while moving, 0 while still).
## Frame-rate independent: the same wall-clock second gets you the same
## fraction of the way there whatever the frame rate was.
static func ease_amount(current: float, target: float, delta: float) -> float:
	var k := 1.0 - exp(-EASE_RATE * maxf(delta, 0.0))
	return clampf(current + (target - current) * k, 0.0, 1.0)
