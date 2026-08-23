class_name GameRoot
extends Node
## The only bridge between the RefCounted core and the scene tree. Owns the
## Content, the Campaign, the clock and autosave. Screens read the campaign
## through this node and mutate it only through the wrappers below, which
## settle production to the current time before touching the wallet or the
## ladder -- Seance and buy_upgrade take no `now`, so this is the single place
## that guarantees the accrue-then-mutate rule.
##
## The autoload instance is inert until boot() is called, so the headless test
## runner never loads content or writes to user:// by accident. Tests build
## their own GameRoot with an injected clock and a temp save path.

signal booted()
signal soul_changed(soul: float, rate_per_hour: float)
signal ladder_changed()
signal hero_changed()

const CONTENT_ROOT := "res://data"
const REFRESH_HZ := 10.0

var content: Content
var campaign: Campaign
var offline: Dictionary = {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0}
var is_booted: bool = false
var save_path: String = SaveGame.DEFAULT_PATH
var autosave_seconds: float = 60.0
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

var _refresh_accum: float = 0.0
var _autosave_accum: float = 0.0


func now() -> int:
	return int(clock.call())


func text(key: String) -> String:
	return content.text(key) if content != null else key


func boot() -> Dictionary:
	content = Content.load_from(CONTENT_ROOT)
	if not content.load_errors.is_empty():
		push_error("boot: content failed to load: %s" % ", ".join(content.load_errors))
		return {"ok": false, "reason": "content", "errors": content.load_errors, "new_game": false, "offline": offline}
	var loaded := SaveGame.load_and_catch_up(content, now(), save_path)
	var c: Campaign = loaded["campaign"]
	var new_game := c == null
	if new_game:
		c = CampaignEngine.new_campaign(content, now(), now())
	else:
		offline = loaded["offline"]
	campaign = c
	is_booted = true
	booted.emit()
	_emit_all()
	return {"ok": true, "reason": "", "errors": [], "new_game": new_game, "offline": offline}


func _process(delta: float) -> void:
	if not is_booted:
		return
	_refresh_accum += delta
	if _refresh_accum >= 1.0 / REFRESH_HZ:
		_refresh_accum = 0.0
		soul_changed.emit(displayed_soul(), campaign.rate_per_hour)
	if autosave_seconds > 0.0:
		_autosave_accum += delta
		if _autosave_accum >= autosave_seconds:
			_autosave_accum = 0.0
			save()


func displayed_soul() -> float:
	if campaign == null:
		return 0.0
	var cap := float(campaign.modifiers()["offline_cap_hours"])
	var pending := Production.accrue(campaign.rate_per_hour, now() - campaign.last_tick, cap)
	return campaign.soul + float(pending["soul"])


func settle() -> Dictionary:
	if campaign == null:
		return {}
	return CampaignEngine.tick(campaign, now())


func buy_upgrade(id: String) -> Dictionary:
	settle()
	var r := CampaignEngine.buy_upgrade(campaign, id)
	if bool(r["ok"]):
		_after_mutation()
	return r


func create_echo(source_id: int, floor: int) -> Dictionary:
	settle()
	var r := Seance.create_echo(campaign, source_id, floor, now())
	if bool(r["ok"]):
		_after_mutation()
	return r


func call_echo(echo_id: int, floor: int) -> Dictionary:
	settle()
	var r := Seance.call_echo(campaign, echo_id, floor)
	if bool(r["ok"]):
		_after_mutation()
	return r


func tend(ghost_id: int) -> Dictionary:
	settle()
	var r := Seance.tend(campaign, ghost_id)
	if bool(r["ok"]):
		_after_mutation()
	return r


func mend() -> Dictionary:
	settle()
	var r := Seance.mend(campaign)
	if bool(r["ok"]):
		_after_mutation()
	return r


func drain_events() -> Array:
	if campaign == null:
		return []
	var out := campaign.events.duplicate()
	campaign.events.clear()
	return out


func save() -> Error:
	if campaign == null:
		return ERR_UNCONFIGURED
	settle()
	return SaveGame.save(campaign, save_path)


func _after_mutation() -> void:
	_emit_all()
	save()


func _emit_all() -> void:
	soul_changed.emit(displayed_soul(), campaign.rate_per_hour)
	ladder_changed.emit()
	hero_changed.emit()
