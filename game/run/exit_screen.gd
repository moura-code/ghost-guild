class_name ExitScreen
extends VBoxContainer
## The exit decision (spec §3.2, §9): the three numbers the player learns to
## read — what a ghost left here would earn, what one left on the next floor
## would earn, and the chance of surviving to get there — then push, retreat,
## or take the watch.
##
## The numbers cost real time: the survival projection and both yield
## estimates each run fight simulations, measured at 300 ms to 3 s in the
## balance work. So they are computed on a WorkerThreadPool task and the
## screen shows a pending state until they land. Spec §11 wants a yield
## simulation under 100 ms on a worker thread; this is the seam where that
## requirement bites.

signal decided(kind: String)

## Tests set this false to compute inline and keep assertions deterministic.
var threaded: bool = true

var game: GameRoot
var run: RunState
var numbers: Dictionary = {}
var pending: bool = false

var _title: Label
var _here: Label
var _next: Label
var _survival: Label
var _push: Button
var _retreat: Button
var _watch: Button


func _init() -> void:
	add_theme_constant_override("separation", 10)


func bind(g: GameRoot, p_run: RunState) -> void:
	game = g
	run = p_run
	if _title == null:
		_build()
	numbers = {}
	_refresh_labels()
	_refresh_buttons()
	_start_projection()


func _build() -> void:
	_title = UiTheme.title("")
	add_child(_title)

	_here = UiTheme.number("", Palette.SOUL)
	add_child(_here)
	add_child(UiTheme.small(""))

	_next = UiTheme.number("", Palette.BONE)
	add_child(_next)

	_survival = UiTheme.number("", Palette.BONE)
	add_child(_survival)

	_push = Button.new()
	_push.pressed.connect(func() -> void: _decide("push"))
	add_child(_push)

	_retreat = Button.new()
	_retreat.pressed.connect(func() -> void: _decide("retreat"))
	add_child(_retreat)

	_watch = Button.new()
	_watch.pressed.connect(func() -> void: _decide("watch"))
	add_child(_watch)


## Everything expensive in one place, so it can be lifted onto a thread as a
## unit. Pure reads: nothing here mutates the run or the campaign.
static func reckon(campaign: Campaign, p_run: RunState, samples: int) -> Dictionary:
	var balance := campaign.balance()
	var modifiers := campaign.modifiers()
	var prepared := 1.0 + float(balance.get("prepared_bonus", 0.25))
	var here := YieldSimulator.strength_here(campaign, p_run)
	var summary := RunEngine.exit_summary(p_run, samples)
	var out := {
		"summary": summary,
		"here": campaign.ladder.marginal_yield(p_run.floor, here * prepared, balance, modifiers),
		"next": 0.0,
	}
	if bool(summary["can_push"]):
		var ahead := YieldSimulator.strength_at(campaign, p_run, p_run.floor + 1)
		out["next"] = campaign.ladder.marginal_yield(p_run.floor + 1, ahead * prepared, balance, modifiers)
	return out


func _start_projection() -> void:
	pending = true
	_refresh_labels()
	var campaign := game.campaign
	var live := run
	var samples := int(game.content.balance.get("survival_samples", 20))
	if not threaded:
		_on_reckoned(reckon(campaign, live, samples))
		return
	# The screen can be freed while the task is still running -- leaving a
	# fight, quitting, a test tearing down. Capture the id and check the
	# object is still alive before calling back into it, or the deferred
	# call lands on freed memory.
	var id := get_instance_id()
	WorkerThreadPool.add_task(func() -> void:
		var result := reckon(campaign, live, samples)
		_deliver.bind(id, result).call_deferred())


## Runs on the main thread after the worker finishes. Static, so it can
## verify the screen still exists before touching it.
static func _deliver(id: int, result: Dictionary) -> void:
	var screen := instance_from_id(id) as ExitScreen
	if screen == null or not is_instance_valid(screen):
		return
	screen._on_reckoned(result)


func _on_reckoned(result: Dictionary) -> void:
	# The player may have left the exit before the thread finished.
	if run == null or run.phase != "exit":
		return
	numbers = result
	pending = false
	_refresh_labels()
	_refresh_buttons()


func _refresh_labels() -> void:
	_title.text = game.text("ui.exit.title").replace("{floor}", str(run.floor))
	if pending or numbers.is_empty():
		var waiting := game.text("ui.exit.pending")
		_here.text = waiting
		_next.text = waiting
		_survival.text = waiting
		return
	var summary: Dictionary = numbers["summary"]
	_here.text = "%s  %s" % [game.text("ui.exit.here"), Num.rate(float(numbers["here"]))]
	if bool(summary["can_push"]):
		_next.text = "%s  %s" % [game.text("ui.exit.next"), Num.rate(float(numbers["next"]))]
		_survival.text = "%s  %s" % [game.text("ui.exit.survival"), Num.percent(float(summary["survival"]))]
	else:
		_next.text = game.text("ui.exit.no_push")
		_survival.text = ""


func _refresh_buttons() -> void:
	var summary: Dictionary = numbers.get("summary", {})
	var can_push := bool(summary.get("can_push", RunEngine.can_push(run)))
	var can_retreat := bool(summary.get("can_retreat", run.hero.resolve > 0))
	var can_watch := bool(summary.get("can_watch", RunEngine.can_watch(run)))

	_push.text = game.text("ui.exit.push")
	_push.disabled = not can_push or pending
	_push.visible = can_push

	_retreat.text = game.text("ui.exit.retreat")
	_retreat.disabled = not can_retreat or pending
	_retreat.visible = true

	# Locked until the first death (spec §3.4) -- shown but disabled, because
	# the player has to know the rite exists before they earn it.
	_watch.text = game.text("ui.exit.watch") if can_watch else game.text("ui.exit.watch_locked")
	_watch.disabled = not can_watch or pending
	_watch.visible = true


func _decide(kind: String) -> void:
	if run == null or run.phase != "exit":
		return
	game.run_action({"kind": kind})
	decided.emit(kind)
