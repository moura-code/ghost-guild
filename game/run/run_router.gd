class_name RunView
extends VBoxContainer
## Task 1 of M1-C2: the run made visible end to end. Every phase gets a
## caption and a Continue button that applies the autopilot's next choice,
## so the whole loop -- descend, fight, clear the floor, exit, epitaph --
## can be walked one step at a time before any of it is hand-played.
##
## Every run phase now has its own screen, so the button at the bottom is
## no longer a step-through: it exists solely to bank a finished run. There
## is deliberately no way to make the game play itself.

signal run_finished(result: Dictionary)

var game: GameRoot

var _floor: Label
var _phase: Label
var _continue: Button
var _body: VBoxContainer
var _map: FloorMapScreen
var _fight: FightScreen
var _choice: ChoiceScreen
var _exit: ExitScreen



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
	# A bar, not two stacked labels in the corner: where you are and what
	# you are doing belong on one line, with room either side.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_floor = UiTheme.title("")
	header.add_child(_floor)
	_phase = UiTheme.body("", Palette.BONE_DIM)
	_phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_phase)
	add_child(header)

	# Phase screens live here. Each task of M1-C2 adds one; any phase
	# without a screen falls through to the Continue button below.
	# Must expand: a VBoxContainer sizes to its children, and an anchored
	# child like FightScreen requests nothing, so without this the body is
	# zero pixels tall and every anchored layout inside it collapses.
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_body)

	_map = FloorMapScreen.new()
	_map.visible = false
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_map)

	_fight = FightScreen.new()
	_fight.visible = false
	_fight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fight.fight_ended.connect(refresh)
	_body.add_child(_fight)

	_choice = ChoiceScreen.new()
	_choice.visible = false
	_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_choice)

	_exit = ExitScreen.new()
	_exit.visible = false
	_exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_exit.decided.connect(func(_kind: String) -> void: refresh())
	_body.add_child(_exit)

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
		_choice.visible = false
		_exit.visible = false
		return
	_continue.visible = true
	_floor.text = game.text("ui.run.floor").replace("{floor}", str(run.floor))
	if run.is_over():
		_phase.text = game.text("ui.run.over")
		_continue.text = game.text("ui.run.bank")
		_map.visible = false
		_fight.visible = false
		_choice.visible = false
		_exit.visible = false
		_continue.visible = true
		return
	_phase.text = game.text("ui.run.phase.%s" % run.phase)
	_refresh_body(run)


## Shows the screen that owns this phase, if one exists yet, and hides the
## step-through button when it does.
func _refresh_body(run: RunState) -> void:
	_map.visible = run.phase == "node"
	_fight.visible = run.phase == "fight"
	_choice.visible = ChoiceScreen.handles(run.phase)
	_exit.visible = run.phase == "exit"
	if _map.visible:
		_map.bind(game, run)
	if _fight.visible:
		_fight.bind(game, run)
	if _choice.visible:
		_choice.bind(game, run)
	if _exit.visible and _exit.run != run:
		# bind() kicks off a fresh reckoning, so only rebind on a real change
		# of run -- a plain refresh must not restart the projection.
		_exit.bind(game, run)
	# Nothing to press mid-run: each phase owns its own controls.
	_continue.visible = false


func _on_continue() -> void:
	var run := game.campaign.run
	if run == null or not run.is_over():
		return
	var result := game.finish_run()
	run_finished.emit(result)
