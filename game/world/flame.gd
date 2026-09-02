class_name Flame
extends RefCounted
## Fire, as a number between LOW and HIGH.
##
## Torches are the only light in the crypt, so a torch holding a constant
## `light_energy` does not merely look static -- it freezes the whole image,
## which is most of why a walked room reads as a diorama rather than a place.
##
## Two rules make the difference between fire and a fault:
##
## 1. **Bounded.** A flicker that dips toward zero reads as a bulb failing,
##    and one that spikes blows the tonemap to white -- and a blown highlight
##    has no colour, which is the exact bug the stage 7 look pass fixed.
## 2. **Out of phase.** Twenty lights breathing in time is the single tell
##    that says "one script is driving all of these". Each torch takes its
##    phase from where it stands, so the room shimmers instead of throbbing,
##    and it shimmers the same way every time you walk back into it.
##
## Summed sines rather than `randf()`, at rates with no common period. Noise
## would be legal here -- this is presentation, not `core/` -- but a
## deterministic flame is one a test can pin, and a jittered one is
## indistinguishable from a broken one.

## The band, as a multiple of the light's authored energy.
const LOW := 0.78
const HIGH := 1.14

## Cycles per second. Deliberately not in any small integer ratio: three sines
## whose rates share a period sum to a repeating wave, and the eye finds a
## one-second loop in a light instantly.
const RATE_A := 6.31
const RATE_B := 2.79
const RATE_C := 11.13

## The hero's own torch. It is a hand's length from the camera, so on the wall
## rate it would read as the whole room strobing rather than as the thing you
## are carrying. Slower, and started somewhere else in the cycle.
const HERO_RATE := 0.62
const HERO_PHASE := 1.7

## Where in the band the flame sits with nothing driving it.
const _MID := (LOW + HIGH) * 0.5
const _SWING := (HIGH - LOW) * 0.5


## The energy multiplier at time `t` for a flame with the given phase offset.
static func energy(t: float, phase: float) -> float:
	var s := sin((t * RATE_A + phase) * TAU) * 0.54 \
		+ sin((t * RATE_B + phase * 1.7) * TAU) * 0.32 \
		+ sin((t * RATE_C + phase * 0.41) * TAU) * 0.14
	return clampf(_MID + s * _SWING, LOW, HIGH)


## A torch's phase, from where it stands.
##
## The multipliers are large and mutually prime-ish so that the two torches
## the eye actually compares -- the pair on facing walls of the same corridor,
## one cell apart -- land far apart in the cycle. A hash that maps neighbours
## to neighbouring phases leaves exactly those two in sync, which is the case
## worth getting right and the one a naive `x + z` gets wrong.
static func phase_for(at: Vector3) -> float:
	return fposmod(at.x * 0.3719 + at.z * 0.6131 + at.y * 0.2477, 1.0)


## Sets `light`'s energy from its authored `rest` value. Null-tolerant because
## a floor's torches are freed while the frame that drives them is still in
## flight, which happens on every descent.
static func drive(light: Light3D, rest: float, t: float) -> void:
	if light == null or not is_instance_valid(light):
		return
	light.light_energy = rest * energy(t, phase_for(light.position))
