class_name SaveGame
extends RefCounted
## The campaign on disk (spec §8): one JSON file with a version field,
## rotating backups and one migration per version; a corrupt main file
## falls back through the backups before giving up. The only file I/O
## in core/.

const VERSION := 2
const DEFAULT_PATH := "user://saves/slot1.json"
const BACKUPS := 2


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func save(c: Campaign, path: String = DEFAULT_PATH) -> Error:
	var dir := path.get_base_dir()
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and made != ERR_ALREADY_EXISTS:
		return made
	_rotate(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var d := c.to_dict()
	d["version"] = VERSION
	file.store_string(JSON.stringify(d, "\t"))
	file.close()
	return OK


static func load_campaign(content: Content, path: String = DEFAULT_PATH) -> Campaign:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = _parse(path)
	if not (parsed is Dictionary):
		parsed = _parse(path + ".bak1")
	if not (parsed is Dictionary):
		parsed = _parse(path + ".bak2")
	if not (parsed is Dictionary):
		return null
	var d: Dictionary = Content.normalize_json(parsed)
	return Campaign.from_dict(content, migrate(d))


static func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var version := int(out.get("version", 0))
	while version < VERSION:
		match version:
			0:
				pass
			1:
				_fill_run_resolved(out)
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
	var c := load_campaign(content, path)
	if c == null:
		return {"campaign": null, "offline": {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0, "returned": []}}
	var offline := CampaignEngine.tick(c, now)
	CampaignEngine.refresh_rate(c)
	return {"campaign": c, "offline": offline}


static func _rotate(path: String) -> void:
	var da := DirAccess.open(path.get_base_dir())
	if da == null:
		return
	var file := path.get_file()
	for i in range(BACKUPS, 0, -1):
		var newer := file if i == 1 else "%s.bak%d" % [file, i - 1]
		var older := "%s.bak%d" % [file, i]
		if da.file_exists(newer):
			if da.file_exists(older):
				da.remove(older)
			da.rename(newer, older)
