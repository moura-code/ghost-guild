class_name Settings
extends RefCounted
## What the player chose about how the game behaves: sensitivity, field of
## view, volume, window mode. Presentation only -- nothing here reaches the
## simulation, which is why it lives in game/ and not core/.
##
## Stored beside the save rather than in it: settings belong to the machine,
## not to the campaign, and copying a save to another PC should not bring
## somebody else's mouse sensitivity with it.

const PATH := "user://settings.cfg"
const SECTION := "game"

const SENSITIVITY_MIN := 0.4
const SENSITIVITY_MAX := 3.0
const FOV_MIN := 60.0
const FOV_MAX := 110.0
## The languages the game ships. A config naming anything else falls back
## to English rather than to a screen full of raw keys.
const LOCALES: Array[String] = ["en", "es"]

## Multiplier on Player.SENSITIVITY. 1.0 is the authored default.
var sensitivity: float = 1.0
var invert_y: bool = false
var fov: float = 72.0
var master_volume: float = 0.8
var fullscreen: bool = false
var ui_scale: float = 1.0
var reduced_motion: bool = false
var minimap: bool = false
static var motion_reduced: bool = false
## Which `data/strings/<locale>.csv` is loaded over the English one.
## Beside the save rather than in it, like everything else here: a
## language is a property of the person reading, not of the campaign.
var locale: String = "en"
var active_slot: String = "slot1"
var dismissed_lessons: Array[String] = []


static func defaults() -> Settings:
	return Settings.new()


func to_dict() -> Dictionary:
	return {
		"sensitivity": sensitivity,
		"invert_y": invert_y,
		"fov": fov,
		"master_volume": master_volume,
		"fullscreen": fullscreen,
		"ui_scale": ui_scale,
		"reduced_motion": reduced_motion,
		"minimap": minimap,
		"locale": locale,
		"active_slot": active_slot,
		"dismissed_lessons": dismissed_lessons.duplicate(),
	}


## Clamped on the way in, not on the way out: a hand-edited config with a
## sensitivity of 900 should give you a usable game, not an unplayable one.
func from_dict(d: Dictionary) -> void:
	sensitivity = clampf(float(d.get("sensitivity", sensitivity)), SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_y = bool(d.get("invert_y", invert_y))
	fov = clampf(float(d.get("fov", fov)), FOV_MIN, FOV_MAX)
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	ui_scale = clampf(float(d.get("ui_scale", ui_scale)), 1.0, 1.5)
	reduced_motion = bool(d.get("reduced_motion", reduced_motion))
	minimap = bool(d.get("minimap", minimap))
	var wanted := String(d.get("locale", locale))
	locale = wanted if LOCALES.has(wanted) else "en"
	var slot := String(d.get("active_slot", "slot1"))
	active_slot = slot if slot.is_valid_identifier() else "slot1"
	dismissed_lessons.clear()
	if d.get("dismissed_lessons", []) is Array:
		for id in d.get("dismissed_lessons", []):
			if id in ["combat", "upgrade", "rooms", "ghost"] and not dismissed_lessons.has(id):
				dismissed_lessons.append(String(id))


func save(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	for key in to_dict():
		cfg.set_value(SECTION, String(key), to_dict()[key])
	return cfg.save(path)


static func load_from(path: String = PATH) -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	var d: Dictionary = {}
	for key in cfg.get_section_keys(SECTION) if cfg.has_section(SECTION) else []:
		d[key] = cfg.get_value(SECTION, String(key))
	s.from_dict(d)
	return s


## Everything that has to happen for a setting to be true of the running game.
## One function, so "applied" and "stored" can never drift apart.
func apply(player: Player) -> void:
	motion_reduced = reduced_motion
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master_volume)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if player != null:
		player.sensitivity_scale = sensitivity
		player.invert_y = invert_y
		player.reduced_motion = reduced_motion
		if player.camera != null:
			player.camera.fov = fov
