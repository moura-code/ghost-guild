class_name RunView
extends VBoxContainer
## Task 1 of M1-C2: the run made visible end to end. Every phase gets a
## caption and a Continue button that applies the autopilot's next choice,
## so the whole loop -- descend, fight, clear the floor, exit, epitaph --
## can be walked one step at a time before any of it is hand-played.
##
## Tasks 2-8 replace this placeholder body phase by phase with real screens.
## The Continue button survives as the fallback for phases not yet built.

signal run_finished(result: Dictionary)

const LOG_LINES := 14

var game: GameRoot

var _floor: Label
var _phase: Label
var _log: Label
var _continue: Button
var _body: VBoxContainer
var _map: FloorMapScreen
var _fight: FightScreen

var _autopilot: RunAutopilot = RunAutopilot.new()
var _lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	add_theme_constant_override("separation", 10)


func bind(g: GameRoot) -> void:
	game = g
	if _floor == null:
		_build()
	if not g.run_changed.is_connected(refresh):
		g.run_changed.connect(refresh)
	refresh()


func _build() -> void:
	_floor = UiTheme.title("")
	add_child(_floor)

	_phase = UiTheme.body("", Palette.BONE_DIM)
	add_child(_phase)

	# Phase screens live here. Each task of M1-C2 adds one; any phase
	# without a screen falls through to the Continue button below.
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)

	_map = FloorMapScreen.new()
	_map.visible = false
	_body.add_child(_map)

	_fight = FightScreen.new()
	_fight.visible = false
	_fight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fight.fight_ended.connect(refresh)
	_body.add_child(_fight)

	_log = UiTheme.small("", Palette.BONE_FAINT)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_log)

	_continue = Button.new()
	_continue.pressed.connect(_on_continue)
	add_child(_continue)


func refresh() -> void:
	if game == null or game.campaign == null:
		return
	var run := game.campaign.run
	if run == null:
		_floor.text = ""
		_phase.text = game.text("ui.run.over")
		_continue.visible = false
		_map.visible = false
		_fight.visible = false
		return
	_continue.visible = true
	_floor.text = game.text("ui.run.floor").replace("{floor}", str(run.floor))
	if run.is_over():
		_phase.text = game.text("ui.run.over")
		_continue.text = game.text("ui.run.bank")
		_map.visible = false
		_fight.visible = false
		_continue.visible = true
		return
	_phase.text = game.text("ui.run.phase.%s" % run.phase)
	_continue.text = game.text("ui.run.continue")
	_refresh_body(run)


## Shows the screen that owns this phase, if one exists yet, and hides the
## step-through button when it does.
func _refresh_body(run: RunState) -> void:
	_map.visible = run.phase == "node"
	_fight.visible = run.phase == "fight"
	if _map.visible:
		_map.bind(game, run)
	if _fight.visible:
		_fight.bind(game, run)
	_continue.visible = not (_map.visible or _fight.visible)


func _on_continue() -> void:
	var run := game.campaign.run
	if run == null:
		return
	if run.is_over():
		var result := game.finish_run()
		run_finished.emit(result)
		return
	# RunAutopilot.choose() deliberately has no fight case -- play_run drives
	# fights through the combat autopilot instead. Stepping one card at a
	# time is the whole point here, so take only the first action of the
	# planned turn and re-plan on the next press.
	if run.phase == "fight":
		var turn: Array = _autopilot.fight_ap.choose_turn(run.fight)
		if turn.is_empty():
			return
		_append_log(game.run_action(turn[0]))
		return
	var action := _autopilot.choose(run)
	if action.is_empty():
		push_error("run view: no action available in phase " + run.phase)
		return
	_append_log(game.run_action(action))


## A plain reading of the event stream. It is a debugging aid in Task 1 and
## the reference for what the fight animator will render in Task 4.
func _append_log(events: Array) -> void:
	for event in events:
		var line := String(event.get("type", "?"))
		if event.has("amount"):
			line += " %s" % Num.short(float(event["amount"]))
		if event.has("card"):
			line += " %s" % String(event["card"])
		if event.has("enemy"):
			line += " -> %s" % String(event["enemy"])
		_lines.append(line)
	while _lines.size() > LOG_LINES:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)
