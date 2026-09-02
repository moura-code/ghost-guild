class_name Torches
extends Node3D
## The floor's flames, and the clock that drives them.
##
## `DungeonBuilder` already grouped every torch under one node; this makes
## that node do the work, so the flicker costs one `_process` per floor rather
## than one per light, and so it dies with the floor it belongs to instead of
## outliving it in `Crawl`.
##
## Rest energies are captured when the light is adopted, so `Flame` scales
## whatever the light was authored at: tuning a torch's brightness never means
## re-tuning the flicker.

var _rest: Array[float] = []
var _lights: Array[Light3D] = []
var _t: float = 0.0


## Takes a light into the rig at whatever brightness it arrived with.
func adopt(light: Light3D) -> void:
	add_child(light)
	_lights.append(light)
	_rest.append(light.light_energy)


func _process(delta: float) -> void:
	_t += delta
	for i in _lights.size():
		Flame.drive(_lights[i], _rest[i], _t)
