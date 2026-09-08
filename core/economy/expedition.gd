class_name Expedition
extends RefCounted
## One expedition in flight (spec §3.5): a hero the guild sent down, and the
## ghost they will become when the clock runs out.
##
## **It carries its own result.** Everything expensive -- how deep the hero got,
## what they drafted on the way, how hard the ghost will farm -- is decided
## when the expedition is launched, and stored here. Resolution is
## `ladder.add(ghost)` and nothing else.
##
## That is not an optimisation, it is the requirement. Launching is a click and
## can afford a survival projection and a strength simulation; resolving
## happens on load, after an absence that may have finished several of these,
## and a game that simulates fights before it can show you a menu is a game
## that looks broken.

var id: int = 0
## The ghost this becomes. Complete and priced at launch, with
## `fixed_strength` set, so nothing about it is recomputed later.
var ghost: Ghost = Ghost.new()
## Unix seconds. `done_at` is derived rather than stored so a change to the
## pace cannot leave a saved expedition disagreeing with itself about when it
## started.
var started_at: int = 0
var seconds: int = 0
## What the projection said about the floor this hero was sent to. Kept for
## the UI, which has to justify the depth to a player who thinks it is timid.
var survival: float = 0.0


func done_at() -> int:
	return started_at + seconds


func is_done(now: int) -> bool:
	return now >= done_at()


## How far along, 0..1. Clamped, because a load after a long absence hands
## this an elapsed time far past the end.
func progress(now: int) -> float:
	if seconds <= 0:
		return 1.0
	return clampf(float(now - started_at) / float(seconds), 0.0, 1.0)


func remaining(now: int) -> int:
	return maxi(0, done_at() - now)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"ghost": ghost.to_dict(),
		"started_at": started_at,
		"seconds": seconds,
		"survival": survival,
	}


static func from_dict(d: Dictionary) -> Expedition:
	var e := Expedition.new()
	e.id = int(d.get("id", 0))
	e.ghost = Ghost.from_dict(d.get("ghost", {}))
	e.started_at = int(d.get("started_at", 0))
	e.seconds = int(d.get("seconds", 0))
	e.survival = float(d.get("survival", 0.0))
	return e
