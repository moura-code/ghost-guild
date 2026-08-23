class_name Content
extends RefCounted
## Loads every JSON file under a data root into typed definitions.
## Never throws: problems are collected in load_errors so the validator
## (and the test suite) can report them all at once.

var cards: Dictionary = {}
var enemies: Dictionary = {}
var relics: Dictionary = {}
var classes: Dictionary = {}
var biomes: Dictionary = {}
var affinity: Dictionary = {}
var balance: Dictionary = {}
var strings: Dictionary = {}
var load_errors: Array[String] = []


static func load_from(root: String) -> Content:
	var c := Content.new()
	if not DirAccess.dir_exists_absolute(root):
		c.load_errors.append("missing content root: " + root)
		return c
	c._load_dir(root.path_join("cards"), func(d: Dictionary) -> void: c.cards[d["id"]] = CardDef.from_dict(d))
	c._load_dir(root.path_join("enemies"), func(d: Dictionary) -> void: c.enemies[d["id"]] = EnemyDef.from_dict(d))
	c._load_dir(root.path_join("relics"), func(d: Dictionary) -> void: c.relics[d["id"]] = RelicDef.from_dict(d))
	c._load_dir(root.path_join("classes"), func(d: Dictionary) -> void: c.classes[d["id"]] = ClassDef.from_dict(d))
	c._load_dir(root.path_join("biomes"), func(d: Dictionary) -> void: c.biomes[d["id"]] = BiomeDef.from_dict(d))
	c.affinity = c._load_object(root.path_join("affinity.json"))
	c.balance = c._load_object(root.path_join("balance.json"))
	c._load_strings(root.path_join("strings").path_join("en.csv"))
	return c


func text(key: String) -> String:
	return String(strings.get(key, key))


## Godot 4.7's JSON.parse_string returns every JSON number as a float
## (5 -> 5.0). Recurses into Array/Dictionary and downcasts any float that
## is integral and within int range to int, so def classes and tests can
## treat whole-number JSON fields as int. Non-integral floats, strings,
## bools and null pass through unchanged.
static func normalize_json(value: Variant) -> Variant:
	if value is Array:
		var out_array: Array = []
		for item in value:
			out_array.append(normalize_json(item))
		return out_array
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = normalize_json(value[key])
		return out_dict
	if value is float:
		var f: float = value
		if f == floor(f) and f >= -9223372036854775808.0 and f < 9223372036854775808.0:
			return int(f)
		return f
	return value


func _load_dir(dir: String, add: Callable) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		load_errors.append("missing directory: " + dir)
		return
	var files := Array(da.get_files())
	files.sort()
	var seen: Dictionary = {}
	for f in files:
		var file_name := String(f)
		if not file_name.ends_with(".json"):
			continue
		var path := dir.path_join(file_name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			load_errors.append("invalid JSON: " + path)
			continue
		parsed = normalize_json(parsed)
		var items: Array = parsed if parsed is Array else [parsed]
		for item in items:
			if not (item is Dictionary) or not item.has("id"):
				load_errors.append("entry without id in " + path)
				continue
			var id := String(item["id"])
			if seen.has(id):
				load_errors.append("duplicate id '%s' in %s" % [id, path])
				continue
			seen[id] = true
			add.call(item)


func _load_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("missing file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		load_errors.append("invalid JSON object: " + path)
		return {}
	return normalize_json(parsed)


func _load_strings(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_errors.append("missing strings file: " + path)
		return
	var first := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if first:
			first = false
			continue
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		strings[row[0]] = row[1]
