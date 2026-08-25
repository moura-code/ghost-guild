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
var _circle: Prop

## Matched to the Guild's tablets so the two spending screens read as the
## same game.
const TILE_SIZE := Vector2(176.0, 132.0)
const DEAD_WIDTH := 640.0


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

	# The rites as a price board of tablets, the same language as the Guild's
	# wall. This was two numbers floating in the top-left of a 900px black
	# box with a Mend row under them and two thirds of the width empty --
	# which is what a form looks like, not a rite.
	var rites := HBoxContainer.new()
	rites.alignment = BoxContainer.ALIGNMENT_CENTER
	rites.add_theme_constant_override("separation", 12)
	_echo_price = UiTheme.number("0")
	_call_price = UiTheme.number("0")
	rites.add_child(_rite_tile(_echo_price, game.text("ui.echo"), "seance"))
	rites.add_child(_rite_tile(_call_price, game.text("ui.call"), "ghost"))

	_mend_label = UiTheme.number("", Palette.BONE)
	_mend_button = Button.new()
	_mend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mend_button.pressed.connect(_on_mend)
	rites.add_child(_mend_tile())
	add_child(rites)

	# Your dead stand inside the circle. This section used to be a bare list
	# in a black box with two thirds of its width empty -- the screen is
	# called the Séance and it looked like a settings page, which is exactly
	# the "spreadsheet, not a game" problem the overhaul exists to fix.
	var dead := VBoxContainer.new()
	dead.add_theme_constant_override("separation", 11)
	dead.add_child(ScreenLayout.section(game.text("ui.seance.dead"), Palette.GHOST))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	dead.add_child(_list)

	_circle = Prop.of(Prop.Kind.CIRCLE)
	_circle.custom_minimum_size = Vector2(330.0, 330.0)
	_circle.size = _circle.custom_minimum_size
	var stage := ScreenLayout.staged(dead, [_circle])
	ScreenLayout.centre_prop(stage, _circle)
	# Sized to the dead standing in it. At the shared wide column this was a
	# single row of one ghost adrift in a black field.
	add_child(ScreenLayout.plate(stage, DEAD_WIDTH))

	# Candles at the foot of the rite, on their own phases so they do not
	# pulse in unison like a row of LEDs.
	var candles := HBoxContainer.new()
	candles.alignment = BoxContainer.ALIGNMENT_CENTER
	candles.add_theme_constant_override("separation", 130)
	for i in 3:
		candles.add_child(Prop.of(Prop.Kind.CANDLE, i * 5 + 1))
	add_child(candles)


## Where the light gathers on this screen: the circle and the dead standing
## in it, not the price header above them.
func focus_rect() -> Rect2:
	if _list == null or not _list.is_inside_tree():
		return Rect2()
	var box := _list.get_global_rect()
	return Rect2(box.position - global_position - Vector2(120.0, 90.0),
		box.size + Vector2(240.0, 180.0))


## One rite, as a tablet: what it is, and what it costs.
func _rite_tile(value: Label, caption: String, icon: String) -> PanelContainer:
	var tile := _tile_shell()
	var column := tile.get_child(0) as VBoxContainer
	var plate := Icons.make_plate(Icons.ui(icon), 26.0, Palette.BONE,
		Palette.PLATE_NEUTRAL, Palette.STONE_EDGE)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(plate)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	column.add_child(ScreenLayout.centre(UiTheme.small(caption)))
	return tile


## Mend is the one rite on this board you can actually perform from here, so
## its tablet carries the button rather than just the price.
func _mend_tile() -> PanelContainer:
	var tile := _tile_shell()
	var column := tile.get_child(0) as VBoxContainer
	var plate := Icons.make_plate(Icons.ui("hero"), 26.0, Palette.BONE,
		Palette.PLATE_NEUTRAL, Palette.STONE_EDGE)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(plate)
	_mend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_mend_label)
	column.add_child(_mend_button)
	return tile


static func _tile_shell() -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(column)
	return tile


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
	# The tablet already says Mend under it, so the number is just the hero's
	# health -- repeating the word inside the tile it labels was the row
	# layout's habit, not the board's.
	_mend_label.text = "%d/%d" % [hero.hp, hero.max_hp]
	_mend_button.text = "%s  %s" % [game.text("ui.mend"), Num.short(cost)]
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
