class_name RunStats
extends RefCounted
## Per-floor fight measurements for one run (spec §5.2): how the player
## actually fought on each floor. Turns are summed over wins only, because
## ghost strength is computed from winning fights.

var floors: Dictionary = {}


func record(floor: int, won: bool, turns: int) -> void:
	var row: Dictionary = floors.get(floor, {"fights": 0, "wins": 0, "turns": 0})
	row["fights"] = int(row["fights"]) + 1
	if won:
		row["wins"] = int(row["wins"]) + 1
		row["turns"] = int(row["turns"]) + turns
	floors[floor] = row


func measured(floor: int) -> Dictionary:
	var row: Dictionary = floors.get(floor, {"fights": 0, "wins": 0, "turns": 0})
	var fights := int(row["fights"])
	var wins := int(row["wins"])
	return {
		"fights": fights,
		"wins": wins,
		"win_rate": (float(wins) / fights) if fights > 0 else 0.0,
		"avg_turns": (float(row["turns"]) / wins) if wins > 0 else 0.0,
	}


func to_dict() -> Dictionary:
	var out := {}
	for floor in floors:
		var row: Dictionary = floors[floor]
		out[str(floor)] = row.duplicate()
	return out


static func from_dict(d: Dictionary) -> RunStats:
	var s := RunStats.new()
	for key in d:
		var row: Dictionary = d[key]
		s.floors[int(key)] = {"fights": int(row.get("fights", 0)), "wins": int(row.get("wins", 0)), "turns": int(row.get("turns", 0))}
	return s
