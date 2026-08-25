class_name ExitScreen
extends VBoxContainer
## The exit decision (spec §3.2, §9): the three numbers the player learns to
## read — what a ghost left here would earn, what one left on the next floor
## would earn, and the chance of surviving to get there — then push, retreat,
## or take the watch.
##
## The numbers cost real time. Measured on this content: at floor 1 the full
## reckoning takes 337 ms, at floor 9 it takes 3.0 s -- and a player meets
## this screen at every floor exit, so three seconds of "Reckoning..." is
## three seconds of nothing happening.
##
## Two things keep it honest. It runs on a WorkerThreadPool task rather than
## the frame, and it arrives in two parts: the yield here is measured from
## the run that just happened and is nearly free, so it lands immediately,
## while the next-floor estimate and the survival odds simulate and follow.
## The player reads the first number while the other two are still coming.
##
## The preview also simulates fewer fights than the balance tools do
## (PREVIEW_FIGHTS): an estimate the player glances at does not need the
## accuracy a balance invariant does.

signal decided(kind: String)

## Tests set this false to compute inline and keep assertions deterministic.
var threaded: bool = true

## Fights per ghost-strength estimate, and floors sampled for the survival
## odds. Both are well below the balance defaults, which is the trade the
## docstring describes.
const PREVIEW_FIGHTS := 8
const PREVIEW_SAMPLES := 6

var game: GameRoot
var run: RunState
var numbers: Dictionary = {}
var pending: bool = false

var _title: Label
var _here: Label
var _next: Label
var _survival: Label
var _note: Label
var _push: Button
var _retreat: Button
var _watch: Button


func _init() -> void:
	add_theme_constant_override("separation", 18)
	alignment = BoxContainer.ALIGNMENT_CENTER


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
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	# The three numbers side by side, each in its own panel. Spec §9 says
	# these are the numbers the player learns to read, and a stack of
	# labels does not teach anyone to compare them -- a row does.
	var numbers_row := HBoxContainer.new()
	numbers_row.add_theme_constant_override("separation", 12)
	numbers_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_here = UiTheme.number("", Palette.SOUL)
	_next = UiTheme.number("", Palette.BONE)
	_survival = UiTheme.number("", Palette.BONE)
	numbers_row.add_child(_reading(_here, game.text("ui.exit.here"), "soul"))
	numbers_row.add_child(_reading(_next, game.text("ui.exit.next"), "descend"))
	numbers_row.add_child(_reading(_survival, game.text("ui.exit.survival"), "hp"))
	add_child(numbers_row)

	# Why a reading is blank, when it is. An em-dash alone tells the player
	# nothing about why they cannot go deeper.
	_note = UiTheme.small("", Palette.BONE_DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	choices.alignment = BoxContainer.ALIGNMENT_CENTER

	_push = Button.new()
	_push.custom_minimum_size = Vector2(88.0, 22.0)
	_push.pressed.connect(func() -> void: _decide("push"))
	choices.add_child(_push)

	_retreat = Button.new()
	_retreat.custom_minimum_size = Vector2(88.0, 22.0)
	_retreat.pressed.connect(func() -> void: _decide("retreat"))
	choices.add_child(_retreat)

	_watch = Button.new()
	_watch.custom_minimum_size = Vector2(150.0, 22.0)
	_watch.pressed.connect(func() -> void: _decide("watch"))
	choices.add_child(_watch)
	add_child(choices)


## One reading: an icon, the value, and what it means underneath.
static func _reading(value: Label, caption: String, icon: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(102.0, 46.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(Icons.make_rect(Icons.ui(icon), 15.0, Palette.BONE_FAINT))
	head.add_child(value)
	box.add_child(head)
	var label := UiTheme.small(caption)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	panel.add_child(box)
	return panel


## The cheap half: what a ghost left on this floor would earn. Measured from
## the fights that just happened, so it needs no simulation at all when the
## hero fought here -- which they always have, by definition.
static func reckon_here(campaign: Campaign, p_run: RunState) -> Dictionary:
	var balance := campaign.balance()
	var prepared := 1.0 + float(balance.get("prepared_bonus", 0.25))
	var here := YieldSimulator.strength_here(campaign, p_run)
	return {"here": campaign.ladder.marginal_yield(
		p_run.floor, here * prepared, balance, campaign.modifiers())}


## The expensive half: the next floor has never been fought, so its yield and
## the odds of surviving it both have to be simulated. Pure reads -- nothing
## here mutates the run or the campaign.
static func reckon_ahead(campaign: Campaign, p_run: RunState, samples: int) -> Dictionary:
	var balance := campaign.balance()
	var prepared := 1.0 + float(balance.get("prepared_bonus", 0.25))
	var summary := RunEngine.exit_summary(p_run, samples)
	var out := {"summary": summary, "next": 0.0}
	if bool(summary["can_push"]):
		var ahead := YieldSimulator.strength_at(campaign, p_run, p_run.floor + 1)
		out["next"] = campaign.ladder.marginal_yield(
			p_run.floor + 1, ahead * prepared, balance, campaign.modifiers())
	return out


## Both halves, for the tests and for the inline path.
static func reckon(campaign: Campaign, p_run: RunState, samples: int) -> Dictionary:
	var out := reckon_here(campaign, p_run)
	out.merge(reckon_ahead(campaign, p_run, samples))
	return out


func _start_projection() -> void:
	pending = true
	var campaign := game.campaign
	var live := run
	# Trimmed for the preview: the balance tools keep the full counts.
	var restore := campaign.sim_fights
	campaign.sim_fights = PREVIEW_FIGHTS

	# The measured half is nearly free, so it lands before the first frame
	# and the player has something to read immediately.
	numbers = reckon_here(campaign, live)
	_refresh_labels()
	_refresh_buttons()

	if not threaded:
		campaign.sim_fights = restore
		_on_reckoned(reckon(campaign, live, PREVIEW_SAMPLES))
		return
	# The screen can be freed while the task is still running -- leaving a
	# fight, quitting, a test tearing down. Capture the id and check the
	# object is still alive before calling back into it, or the deferred
	# call lands on freed memory.
	var id := get_instance_id()
	WorkerThreadPool.add_task(func() -> void:
		var result := reckon_ahead(campaign, live, PREVIEW_SAMPLES)
		campaign.sim_fights = restore
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
	numbers.merge(result, true)
	pending = false
	_refresh_labels()
	_refresh_buttons()


func _refresh_labels() -> void:
	_title.text = game.text("ui.exit.title").replace("{floor}", str(run.floor))
	var waiting := game.text("ui.exit.pending")
	_here.text = Num.rate(float(numbers["here"])) if numbers.has("here") else waiting
	if not numbers.has("summary"):
		_next.text = waiting
		_survival.text = waiting
		_note.text = ""
		return
	var summary: Dictionary = numbers["summary"]
	if bool(summary["can_push"]):
		_next.text = Num.rate(float(numbers["next"]))
		var survival := float(summary["survival"])
		_survival.text = Num.percent(survival)
		# The odds colour themselves: this is the number the decision hangs
		# on, and it should read before it is parsed.
		_survival.add_theme_color_override("font_color",
			Palette.DANGER if survival < 0.4 else (Palette.PREPARED if survival < 0.7 else Palette.GOOD))
		_note.text = ""
	else:
		_next.text = "—"
		_survival.text = "—"
		_note.text = game.text("ui.exit.no_push")


func _refresh_buttons() -> void:
	var summary: Dictionary = numbers.get("summary", {})
	var can_push := bool(summary.get("can_push", RunEngine.can_push(run)))
	var can_retreat := bool(summary.get("can_retreat", run.hero.resolve > 0))
	var can_watch := bool(summary.get("can_watch", RunEngine.can_watch(run)))

	# The three choices are not equal and should not look it. Pushing risks
	# everything and gets the warm accent; retreating banks the run and
	# stays quiet; taking the watch is the deliberate death and reads in
	# ghost-cyan, the colour the game uses for the dead.
	_push.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.PREPARED))
	_push.add_theme_stylebox_override("hover", UiTheme.lit_box(Palette.STONE_HIGH, Palette.PREPARED))
	_watch.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.GHOST))
	_watch.add_theme_stylebox_override("hover", UiTheme.lit_box(Palette.STONE_HIGH, Palette.GHOST))
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
