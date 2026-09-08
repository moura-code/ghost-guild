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
signal run_changed()
## An expedition was sent, or landed. Distinct from ladder_changed because a
## slot filling and emptying is a different thing to look at than a ghost
## arriving, and the Guild is the only screen that cares about the first.
signal expeditions_changed()

const CONTENT_ROOT := "res://data"
const REFRESH_HZ := 10.0

## The game's sound. Lives on the bridge because every screen wants it and
## none of them should own it -- and because a single pool of voices is the
## point (see Sfx).
var sfx: Sfx
var content: Content
var campaign: Campaign
var offline: Dictionary = {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0, "returned": []}
var is_booted: bool = false
var load_notice: String = ""
var save_blocked: bool = false
var save_path: String = SaveGame.DEFAULT_PATH
var autosave_seconds: float = 60.0
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

var _refresh_accum: float = 0.0
var _autosave_accum: float = 0.0


func now() -> int:
	return int(clock.call())


func text(key: String) -> String:
	return content.text(key) if content != null else key


## The language the content is loaded in. Set before `boot` -- `Crawl` reads
## it out of Settings, which is on disk beside the save rather than in it.
var locale: String = "en"


## Swaps the language under a running game (spec §11, M3).
##
## Three objects hold a `Content`: the campaign, the run inside it and the
## fight inside that. Everything else looks its defs up by id, so re-pointing
## those three and re-emitting is the whole of it -- and it is worth the six
## lines, because a language that only takes effect after a restart is a
## setting the player changes once, restarts, and finds they preferred the
## other one.
func set_locale(wanted: String) -> bool:
	if content != null and content.locale == wanted:
		return true
	var next := Content.load_from(CONTENT_ROOT, wanted)
	if not next.load_errors.is_empty():
		push_error("set_locale: %s failed to load: %s" % [wanted, next.load_errors])
		return false
	locale = wanted
	content = next
	if campaign != null:
		campaign.content = next
		if campaign.run != null:
			campaign.run.content = next
			if campaign.run.fight != null:
				campaign.run.fight.content = next
	_emit_all()
	return true


func boot() -> Dictionary:
	if sfx == null:
		sfx = Sfx.new()
		add_child(sfx)
		# Deferred: the pool builds itself in _ready, which has not run yet on
		# the frame the node is added.
		sfx.start_ambience.call_deferred()
	content = Content.load_from(CONTENT_ROOT, locale)
	if not content.load_errors.is_empty():
		push_error("boot: content failed to load: %s" % ", ".join(content.load_errors))
		return {"ok": false, "reason": "content", "errors": content.load_errors, "new_game": false, "offline": offline}
	var loaded := SaveGame.load_and_catch_up(content, now(), save_path)
	var c: Campaign = loaded["campaign"]
	var new_game := c == null
	save_blocked = c == null and SaveGame.exists(save_path)
	load_notice = String(SaveGame.load_report(content, save_path)["reason"]) if save_blocked else ("recovered" if loaded.get("recovered", "") != "" else "")
	if new_game:
		c = CampaignEngine.new_campaign(content, now(), now())
	else:
		offline = loaded["offline"]
	campaign = c
	is_booted = true
	if not new_game:
		# Persist the catch-up timestamp before another load can repeat it.
		SaveGame.save(campaign, save_path)
	booted.emit()
	_emit_all()
	return {"ok": true, "reason": "", "errors": [], "new_game": new_game, "offline": offline}


func _process(delta: float) -> void:
	if not is_booted:
		return
	_refresh_accum += delta
	if _refresh_accum >= 1.0 / REFRESH_HZ:
		_refresh_accum = 0.0
		_land_due()
		soul_changed.emit(displayed_soul(), campaign.rate_per_hour)
	if autosave_seconds > 0.0:
		_autosave_accum += delta
		if _autosave_accum >= autosave_seconds:
			_autosave_accum = 0.0
			save()


func displayed_soul() -> float:
	if campaign == null:
		return 0.0
	var cap := campaign.offline_cap_hours()
	var pending := Production.accrue(campaign.rate_per_hour, now() - campaign.last_tick, cap)
	return campaign.soul + float(pending["soul"])


func settle() -> Dictionary:
	if campaign == null:
		return {}
	return CampaignEngine.tick(campaign, now())


func buy_upgrade(id: String) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	settle()
	var r := CampaignEngine.buy_upgrade(campaign, id)
	if bool(r["ok"]):
		_after_mutation()
	return r


func create_echo(source_id: int, floor: int) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	settle()
	var r := Seance.create_echo(campaign, source_id, floor, now())
	if bool(r["ok"]):
		_after_mutation()
	return r


func call_echo(echo_id: int, floor: int) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	settle()
	var r := Seance.call_echo(campaign, echo_id, floor)
	if bool(r["ok"]):
		_after_mutation()
	return r


func tend(ghost_id: int) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	settle()
	var r := Seance.tend(campaign, ghost_id)
	if bool(r["ok"]):
		_after_mutation()
	return r


func mend() -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	settle()
	var r := Seance.mend(campaign)
	if bool(r["ok"]):
		_after_mutation()
	return r


## Sends an expedition down (spec §3.5). It costs no Soul: the upgrade was the
## price, and what it spends is a slot and the clock.
##
## The launch does all of the expensive work -- the survival projection, the
## draft, the strength simulation -- which is exactly why it happens on a click
## and not on load. See Expeditions.
func launch_expedition() -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	if campaign == null:
		return {"ok": false, "expedition": null, "reason": "unbooted"}
	settle()
	var r := Expeditions.launch(campaign, now())
	if bool(r["ok"]):
		if sfx != null:
			sfx.play("descend")
		_emit_all()
		expeditions_changed.emit()
		save()
	return r


## An expedition that finishes while the player is standing in the guild has
## to land while they are standing in the guild.
##
## Everything else in the campaign settles because the player did something --
## bought, tended, descended -- and an expedition is the first thing in the
## game that completes on its own. Without this it would sit at "0s" until the
## next purchase or the next autosave noticed it, which is the exact shape of
## a bug even though nothing would be lost.
func _land_due() -> void:
	var due := Expeditions.next_due(campaign)
	if due < 0 or due > now():
		return
	var result := settle()
	if (result.get("returned", []) as Array).is_empty():
		return
	if sfx != null:
		sfx.play("ghost_place")
	_emit_all()
	expeditions_changed.emit()
	save()


## Re-makes the living hero as another class (spec §3.4). Costs no Soul, so
## it does not go through `_after_mutation` and its purchase sound.
func choose_class(class_id: String) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	if campaign == null:
		return {"ok": false, "reason": "unbooted"}
	settle()
	var r := CampaignEngine.choose_class(campaign, class_id)
	if bool(r["ok"]):
		_emit_all()
		save()
	return r


## Performs the rite (spec §6.1). Merges every ghost into a Legend and starts
## the cycle again. Everything the player is about to lose is spelled out on
## the Hall screen before this can be reached.
## Which Legend walks with you on the next descent (spec §6.1). Nothing under
## `game/` writes to the campaign; this is the channel.
func invoke_legend(id: int) -> bool:
	if campaign != null and campaign.run != null:
		return false
	if campaign == null:
		return false
	var ok := CampaignEngine.invoke_legend(campaign, id, now())
	if ok:
		_emit_all()
		save()
	return ok


## Sharpening a ghost's best card, and handing one a relic out of the
## compendium (spec §5.5). Both re-price the ghost and every echo of it.
func tend_upgrade(ghost_id: int) -> Dictionary:
	return _seance_action(func() -> Dictionary: return Seance.tend_upgrade(campaign, ghost_id))


func tend_relic(ghost_id: int) -> Dictionary:
	return _seance_action(func() -> Dictionary: return Seance.tend_relic(campaign, ghost_id))


func _seance_action(act: Callable) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	if campaign == null:
		return {"ok": false, "cost": 0.0, "reason": "unbooted"}
	settle()
	var r: Dictionary = act.call()
	if bool(r["ok"]):
		_emit_all()
		save()
	return r


## Writing a Chapter of the Chronicle, and setting the Depth Seal for the
## next descent (spec §6.2). Nothing under `game/` writes to the campaign.
func write_chapter(id: String) -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	if campaign == null:
		return {"ok": false, "cost": 0, "reason": "unbooted"}
	settle()
	var r := Chronicle.write(campaign, id, now())
	if bool(r["ok"]):
		CampaignEngine.refresh_rate(campaign)
		_emit_all()
		save()
	return r


func set_seal(seal: int) -> bool:
	if campaign != null and campaign.run != null:
		return false
	if campaign == null:
		return false
	var ok := CampaignEngine.set_seal(campaign, seal, now())
	if ok:
		_emit_all()
		save()
	return ok


func prestige() -> Dictionary:
	if campaign != null and campaign.run != null:
		return {"ok": false, "reason": "in_run", "cost": 0.0, "expedition": null}
	if campaign == null:
		return {"ok": false, "reason": "unbooted", "legend": null}
	settle()
	var r := CampaignEngine.prestige(campaign, now())
	if bool(r["ok"]):
		if sfx != null:
			sfx.play("epitaph")
		_emit_all()
		save()
	return r


## Starts a descent. CampaignEngine validates the entry floor against reach
## and refuses an unbanked finished run, returning null either way.
##
## start_run and finish_run tick production internally, so unlike the other
## wrappers these do not call settle() first -- a second tick with zero
## elapsed would be a no-op, but the intent should be visible here.
func start_run(entry_floor: int) -> RunState:
	if campaign == null:
		return null
	if sfx != null:
		sfx.play("descend")
	var run := CampaignEngine.start_run(campaign, entry_floor, now())
	if run != null:
		_emit_all()
		run_changed.emit()
		save()
	return run


## Applies one action to the live run and returns the events it produced.
## The fight screen animates from those events rather than diffing state.
func run_action(action: Dictionary) -> Array:
	if campaign == null or campaign.run == null:
		return []
	var events := RunEngine.apply(campaign.run, action)
	run_changed.emit()
	return events


## Banks a finished run: the Soul, the ghost, the epitaph and the new hero.
func finish_run() -> Dictionary:
	if campaign == null or campaign.run == null or not campaign.run.is_over():
		return {}
	var result := CampaignEngine.finish_run(campaign, now())
	_emit_all()
	run_changed.emit()
	save()
	return result


func drain_events() -> Array:
	if campaign == null:
		return []
	var out := campaign.events.duplicate()
	campaign.events.clear()
	return out


func save() -> Error:
	if save_blocked:
		return ERR_FILE_CORRUPT
	if campaign == null:
		return ERR_UNCONFIGURED
	settle()
	return SaveGame.save(campaign, save_path)


## Every Soul spend in the game -- upgrades, echoes, Calls, tending, Mend --
## reaches here on success and nowhere else, which makes it the one place
## that has to know a purchase makes a sound.
func _after_mutation() -> void:
	if sfx != null:
		sfx.play("purchase")
	_emit_all()
	save()


func _emit_all() -> void:
	soul_changed.emit(displayed_soul(), campaign.rate_per_hour)
	ladder_changed.emit()
	hero_changed.emit()


func import_campaign(source: String) -> Dictionary:
	return SaveGame.import_copy(content, source, now(), save_path.get_base_dir())


func continue_slot(path: String) -> Dictionary:
	var report := SaveGame.load_report(content, path)
	var next: Campaign = report["campaign"]
	if next == null:
		return {"ok": false, "reason": report["reason"]}
	if not save_blocked and save() != OK:
		return {"ok": false, "reason": "write"}
	# Re-read after saving when the selected slot is already active.
	if path == save_path:
		next = SaveGame.load_campaign(content, path)
	var catchup := CampaignEngine.tick(next, now())
	CampaignEngine.refresh_rate(next)
	if SaveGame.save(next, path) != OK:
		return {"ok": false, "reason": "write"}
	campaign = next
	save_path = path
	save_blocked = false
	load_notice = "recovered" if report["recovered"] != "" else ""
	offline = catchup
	_emit_all()
	return {"ok": true, "reason": ""}
