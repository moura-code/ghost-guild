class_name SaveGame
extends RefCounted
## The campaign on disk (spec §8): one JSON file with a version field,
## rotating backups and one migration per version. The only file I/O in core/.

const VERSION := 1
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
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return null
	var d: Dictionary = Content.normalize_json(parsed)
	return Campaign.from_dict(content, migrate(d))


static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var version := int(out.get("version", 0))
	while version < VERSION:
		match version:
			0:
				pass
		version += 1
		out["version"] = version
	return out


static func load_and_catch_up(content: Content, now: int, path: String = DEFAULT_PATH) -> Dictionary:
	var c := load_campaign(content, path)
	if c == null:
		return {"campaign": null, "offline": {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0}}
	var offline := CampaignEngine.tick(c, now)
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
