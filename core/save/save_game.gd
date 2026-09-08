class_name SaveGame
extends RefCounted
## The campaign on disk (spec §8): one JSON file with a version field,
## rotating backups and one migration per version; a corrupt main file
## falls back through the backups before giving up. The only file I/O
## in core/.

const VERSION := 3
const DEFAULT_PATH := "user://saves/slot1.json"
const BACKUPS := 2


static func exists(path: String = DEFAULT_PATH) -> bool:
	for suffix in ["", ".bak1", ".bak2"]:
		if FileAccess.file_exists(path + suffix):
			return true
	return false


static func save(c: Campaign, path: String = DEFAULT_PATH) -> Error:
	var d := c.to_dict()
	d["version"] = VERSION
	if SaveValidation.check(c.content, d) != "":
		return ERR_INVALID_DATA
	var made := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if made != OK and made != ERR_ALREADY_EXISTS:
		return made
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(d, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if SaveValidation.check(c.content, _parse(temporary)) != "":
		return ERR_FILE_CORRUPT
	# The primary is never moved/deleted to make room for a write. Only
	# validated copies enter the backup chain. Failure leaves it playable.
	if FileAccess.file_exists(path) and SaveValidation.check(c.content, _parse(path)) == "":
		if FileAccess.file_exists(path + ".bak1") and SaveValidation.check(c.content, _parse(path + ".bak1")) == "":
			error = _copy_atomic(path + ".bak1", path + ".bak2")
			if error != OK:
				return error
		error = _copy_atomic(path, path + ".bak1")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temporary, path)


static func _copy_atomic(from: String, to: String) -> Error:
	var error := DirAccess.copy_absolute(from, to + ".tmp")
	if error != OK:
		return error
	return DirAccess.rename_absolute(to + ".tmp", to)


static func load_report(content: Content, path: String = DEFAULT_PATH) -> Dictionary:
	var reason := "missing"
	for suffix in ["", ".bak1", ".bak2"]:
		if not FileAccess.file_exists(path + suffix):
			continue
		var raw: Variant = _parse(path + suffix)
		var invalid := SaveValidation.check(content, raw)
		if invalid == "future" and suffix == "":
			return {"campaign": null, "reason": "future", "recovered": ""}
		if invalid != "":
			reason = invalid
			continue
		var d: Dictionary = Content.normalize_json(raw)
		return {"campaign": Campaign.from_dict(content, migrate(d)), "reason": "", "recovered": suffix}
	return {"campaign": null, "reason": reason, "recovered": ""}


static func load_campaign(content: Content, path: String = DEFAULT_PATH) -> Campaign:
	return load_report(content, path)["campaign"]


static func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var version := int(out.get("version", 0))
	if version > VERSION:
		return {}
	while version < VERSION:
		match version:
			0:
				pass
			1:
				_fill_run_resolved(out)
			2:
				pass # Historical saves restart the unresolved fight node; no lost state can be inferred.
		version += 1
		out["version"] = version
	return out


## Version 2 gave every node its own resolved flag so a floor can be walked in
## any order. A version 1 run always cleared its nodes in index order, so
## everything before node_index is exactly what was already done. A save that
## already carries flags is left alone, so this is safe to run twice.
static func _fill_run_resolved(d: Dictionary) -> void:
	var raw: Variant = d.get("run", {})
	if not (raw is Dictionary):
		return
	var run: Dictionary = raw
	if run.is_empty() or run.has("resolved"):
		return
	var nodes: Array = run.get("nodes", [])
	var index := int(run.get("node_index", 0))
	var flags: Array = []
	for i in nodes.size():
		flags.append(i < index)
	run["resolved"] = flags


static func load_and_catch_up(content: Content, now: int, path: String = DEFAULT_PATH) -> Dictionary:
	var report := load_report(content, path)
	var c: Campaign = report["campaign"]
	if c == null:
		return {"campaign": null, "offline": {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0, "returned": []}}
	var offline := CampaignEngine.tick(c, now)
	CampaignEngine.refresh_rate(c)
	return {"campaign": c, "offline": offline, "recovered": report["recovered"], "reason": report["reason"]}


static func slot_path(slot: String) -> String:
	return "user://saves/" + slot + ".json" if slot.is_valid_identifier() else DEFAULT_PATH


static func slots(content: Content, directory: String = "user://saves") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return out
	var names: Dictionary = {}
	for file in dir.get_files():
		var base := String(file).trim_suffix(".bak1").trim_suffix(".bak2")
		if base.ends_with(".json"):
			names[base] = true
	var sorted: Array = names.keys()
	sorted.sort()
	for file in sorted:
		var path := directory.path_join(file)
		var report := load_report(content, path)
		var c: Campaign = report["campaign"]
		out.append({"slot": String(file).get_basename(), "path": path,
			"name": c.hero.name if c != null else String(file), "reason": report["reason"],
			"seed": c.campaign_seed if c != null else 0, "recovered": report["recovered"]})
	return out


static func import_copy(content: Content, source: String, now: int, directory: String = "user://saves") -> Dictionary:
	var report := load_report(content, source)
	var c: Campaign = report["campaign"]
	if c == null:
		return {"ok": false, "reason": report["reason"]}
	var index := 1
	var destination := directory.path_join("import_%d.json" % index)
	while exists(destination):
		index += 1
		destination = directory.path_join("import_%d.json" % index)
	var offline := CampaignEngine.tick(c, now)
	CampaignEngine.refresh_rate(c)
	var error := save(c, destination)
	if error != OK:
		return {"ok": false, "reason": "write"}
	return {"ok": true, "reason": "", "path": destination,
		"slot": destination.get_file().get_basename(), "name": c.hero.name,
		"recovered": report["recovered"], "offline": offline}
