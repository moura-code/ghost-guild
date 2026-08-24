class_name SeanceScreen
extends VBoxContainer
## The Séance panel (spec §5.5): echoes, Calls, Tend and Mend -- every Soul
## sink that is not a meta upgrade. All four go through Game, which settles
## production first and saves after.

var game: GameRoot
var lines: Dictionary = {}

var _echo_price: Label
var _call_price: Label
var _mend_label: Label
var _mend_button: Button
var _list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot) -> void:
	game = g
	if _list == null:
		_build()
	if not g.ladder_changed.is_connected(refresh):
		g.ladder_changed.connect(refresh)
	if not g.hero_changed.is_connected(refresh):
		g.hero_changed.connect(refresh)
	if not g.soul_changed.is_connected(_on_soul_changed):
		g.soul_changed.connect(_on_soul_changed)
	refresh()


func _build() -> void:
	add_child(ScreenLayout.centre(UiTheme.title(game.text("ui.seance"))))

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 44)
	_echo_price = UiTheme.number("0")
	_call_price = UiTheme.number("0")
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(_price_block(_echo_price, game.text("ui.echo")))
	header.add_child(_price_block(_call_price, game.text("ui.call")))
	add_child(header)

	var mend_row := HBoxContainer.new()
	mend_row.add_theme_constant_override("separation", 8)
	_mend_label = UiTheme.body("")
	_mend_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mend_button = Button.new()
	_mend_button.pressed.connect(_on_mend)
	mend_row.add_child(_mend_label)
	mend_row.add_child(_mend_button)
	add_child(ScreenLayout.centred(mend_row))

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(ScreenLayout.centred(_list))


static func _price_block(value: Label, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(value)
	box.add_child(UiTheme.small(caption))
	return box


func refresh() -> void:
	if game == null or game.campaign == null:
		return
	var c := game.campaign
	var soul := game.displayed_soul()
	_echo_price.text = Num.short(Seance.echo_cost(c))
	_call_price.text = Num.short(Seance.call_cost(c))
	_refresh_mend(soul)

	var ctx := {
		"waypoint": c.ladder.waypoint(),
		"echo_cost": Seance.echo_cost(c),
		"call_cost": Seance.call_cost(c),
		"tend_cost": 0.0,
		"soul": soul,
	}
	var seen := {}
	for ghost in c.ladder.ghosts:
		seen[ghost.id] = true
		var line: GhostLine = lines.get(ghost.id) as GhostLine
		if line == null:
			line = GhostLine.new()
			line.echo_pressed.connect(_on_echo)
			line.call_pressed.connect(_on_call)
			line.tend_pressed.connect(_on_tend)
			_list.add_child(line)
			lines[ghost.id] = line
		ctx["tend_cost"] = Seance.tend_cost(c, ghost)
		line.bind(game.content, ghost, ctx)
	for id in lines.keys():
		if not seen.has(id):
			var stale: GhostLine = lines[id]
			_list.remove_child(stale)
			stale.queue_free()
			lines.erase(id)


func _refresh_mend(soul: float) -> void:
	var hero := game.campaign.hero
	if hero == null:
		_mend_label.text = ""
		_mend_button.disabled = true
		return
	var cost := Seance.mend_cost(game.campaign)
	_mend_label.text = "%s  %d/%d" % [game.text("ui.mend"), hero.hp, hero.max_hp]
	_mend_button.text = Num.short(cost)
	_mend_button.disabled = hero.hp >= hero.max_hp or soul < cost


func _on_echo(ghost_id: int, floor: int) -> void:
	if not bool(game.create_echo(ghost_id, floor)["ok"]):
		refresh()


func _on_call(ghost_id: int, floor: int) -> void:
	if not bool(game.call_echo(ghost_id, floor)["ok"]):
		refresh()


func _on_tend(ghost_id: int) -> void:
	if not bool(game.tend(ghost_id)["ok"]):
		refresh()


func _on_mend() -> void:
	if not bool(game.mend()["ok"]):
		refresh()


func _on_soul_changed(soul: float, _rate_per_hour: float) -> void:
	if game == null or game.campaign == null:
		return
	var hero := game.campaign.hero
	if hero != null:
		_mend_button.disabled = hero.hp >= hero.max_hp or soul < Seance.mend_cost(game.campaign)
	for id in lines:
		(lines[id] as GhostLine).set_affordability(soul)
