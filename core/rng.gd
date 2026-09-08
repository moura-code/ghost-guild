class_name Rng
extends RefCounted
## Seeded randomness with independent named streams.
## Every stream is derived from (seed, name), so consuming one stream never
## changes another, and a clone continues every stream from the same point.

var seed_value: int
var _streams: Dictionary = {}


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed


func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, name])
		_streams[name] = rng
	return _streams[name]


func randi_range(name: String, from: int, to: int) -> int:
	return stream(name).randi_range(from, to)


func randf(name: String) -> float:
	return stream(name).randf()


func shuffle(name: String, items: Array) -> void:
	var rng := stream(name)
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


func pick(name: String, items: Array) -> Variant:
	assert(items.size() > 0, "pick from empty array")
	return items[stream(name).randi_range(0, items.size() - 1)]


func weighted_pick(name: String, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	assert(total > 0.0, "weighted_pick needs a positive total weight")
	var r := stream(name).randf() * total
	var acc := 0.0
	for i in weights.size():
		var w := float(weights[i])
		if w <= 0.0:
			continue
		acc += w
		if r < acc:
			return i
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return 0


func clone() -> Rng:
	var c := Rng.new(seed_value)
	for name in _streams:
		var src: RandomNumberGenerator = _streams[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = src.seed
		rng.state = src.state
		c._streams[name] = rng
	return c


## RNG states are 64-bit integers; decimal strings survive JSON's float parser.
func to_dict() -> Dictionary:
	var streams: Dictionary = {}
	for key in _streams:
		var source: RandomNumberGenerator = _streams[key]
		streams[key] = {"seed": str(source.seed), "state": str(source.state)}
	return {"seed": str(seed_value), "streams": streams}


static func from_dict(d: Dictionary) -> Rng:
	var rng := Rng.new(int(d.get("seed", "0")))
	for key in d.get("streams", {}):
		var raw: Dictionary = d["streams"][key]
		var stream := RandomNumberGenerator.new()
		stream.seed = int(raw["seed"])
		stream.state = int(raw["state"])
		rng._streams[key] = stream
	return rng
