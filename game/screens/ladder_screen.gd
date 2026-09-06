class_name LadderScreen
extends VBoxContainer
## The home screen and the capsule image (spec §9): the tower in cross
## section with floor 1 at the top, the ghosts standing in their floors,
## saturation as fill, and the Soul counter ticking above it.

const ROW_SEPARATION := 1
## The tower is a tower: constrained and centred, not a full-width table.
## Narrow and deep, because that is what a shaft is.
##
## Ten floors in a 360px frame gives each chamber about 24 pixels of height
## whatever else changes -- so the only lever on whether it reads as a well
## or as a bar chart is width. Wide chambers at that height are bars; narrow
## ones are ledges down a shaft, which is the image the whole game is named
## after.
const TOWER_WIDTH := 190.0
const TOWER_HEIGHT := 242.0

var game: GameRoot

var _premise: Label
var _hint: Label
var _descend: Button
var _entry: SpinBox
var _cheapest_cost: float = -1.0
var _tower: TowerView
var _room: CryptView
var _floor_title: Label
var _residents: Label
var _floor_rate: Label


func _init() -> void:
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot) -> void:
	game = g
	if _tower == null:
		_build()
	if not g.soul_changed.is_connected(_on_soul_changed):
		g.soul_changed.connect(_on_soul_changed)
	if not g.ladder_changed.is_connected(refresh):
		g.ladder_changed.connect(refresh)
	refresh()


func _build() -> void:
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 18)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spread)

	var chamber := VBoxContainer.new()
	chamber.add_theme_constant_override("separation", 5)
	chamber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(chamber)
	chamber.add_child(UiTheme.small(game.text("ui.crypt.chapter"), Palette.EDGE_LIGHT))
	var heading := HBoxContainer.new()
	_floor_title = UiTheme.title(game.text("ui.crypt.title"))
	_floor_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_floor_title)
	_floor_rate = UiTheme.body("", Palette.SOUL)
	_floor_rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_floor_rate)
	chamber.add_child(heading)

	_room = CryptView.new()
	_room.custom_minimum_size = Vector2(390, 174)
	_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chamber.add_child(_room)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	footer.add_child(footer_row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	footer_row.add_child(copy)
	_residents = UiTheme.body("", Palette.BONE)
	copy.add_child(_residents)
	_premise = UiTheme.small("", Palette.BONE_DIM)
	_premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_premise)

	var action := VBoxContainer.new()
	action.add_theme_constant_override("separation", 3)
	var entry_row := HBoxContainer.new()
	entry_row.add_child(UiTheme.small(game.text("ui.crypt.entry")))
	_entry = SpinBox.new()
	_entry.min_value = 1.0
	_entry.step = 1.0
	_entry.custom_minimum_size = Vector2(45, 0)
	_entry.value_changed.connect(_on_entry_changed)
	entry_row.add_child(_entry)
	action.add_child(entry_row)
	_descend = Button.new()
	_descend.custom_minimum_size = Vector2(112, 27)
	_descend.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.EDGE_LIGHT))
	_descend.pressed.connect(_on_descend)
	action.add_child(_descend)
	footer_row.add_child(action)
	chamber.add_child(footer)

	_hint = UiTheme.small("", Palette.BONE_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chamber.add_child(_hint)

	var ledger := PanelContainer.new()
	ledger.add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE))
	spread.add_child(ledger)
	var ledger_column := VBoxContainer.new()
	ledger_column.add_theme_constant_override("separation", 5)
	ledger.add_child(ledger_column)
	ledger_column.add_child(ScreenLayout.section(game.text("ui.crypt.depths"), Palette.EDGE_LIGHT))
	_tower = TowerView.new()
	_tower.custom_minimum_size = Vector2(TOWER_WIDTH, TOWER_HEIGHT)
	_tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tower.floor_clicked.connect(_on_floor_clicked)
	ledger_column.add_child(_tower)
	ledger_column.add_child(UiTheme.small(game.text("ui.crypt.choose"), Palette.BONE_DIM))


func _on_entry_changed(_value: float) -> void:
	_refresh_chamber()


func _refresh_chamber() -> void:
	if _room == null or game == null or game.campaign == null:
		return
	var floor := int(_entry.value)
	_room.show_floor(game.campaign, floor)
	_tower.selected_floor = floor
	_tower.queue_redraw()
	var count := game.campaign.ladder.on_floor(floor).size()
	_residents.text = game.text("ui.crypt.residents").replace("{floor}", str(floor)).replace("{count}", str(count))
	var output := game.campaign.ladder.floor_output(floor, game.campaign.balance(), game.campaign.modifiers())
	_floor_rate.text = Num.rate(output)


## A number over its name, with the icon beside the caption rather than the
## value -- an icon next to a large number competes with it.
## Rebinds the whole shaft. Called on ladder_changed, which every Game
## mutator emits.
func refresh() -> void:
	if game == null or game.campaign == null:
		return
	_tower.bind(game.campaign)
	_refresh_premise()
	_cheapest_cost = _cheapest_upgrade_cost()
	var reach := CampaignEngine.reach(game.campaign)
	var chosen := clampi(int(_entry.value), 1, reach)
	_entry.max_value = float(reach)
	_entry.value = float(chosen)
	_entry.editable = reach > 1 and game.campaign.run == null
	_descend.text = game.text("ui.descend")
	_descend.disabled = game.campaign.run != null
	_on_soul_changed(game.displayed_soul(), game.campaign.rate_per_hour)
	_refresh_chamber()


## The shaft. It is the capsule image, the first screenshot and the first
## three seconds of the trailer, so it gets the light on this screen and the
## premise line above it does not.
func focus_rect() -> Rect2:
	if _room == null or not _room.is_inside_tree():
		return Rect2()
	var box := _room.get_global_rect()
	return Rect2(box.position - global_position - Vector2(30.0, 15.0),
		box.size + Vector2(60.0, 30.0))


## Names the deepest true ghost, because that one is both the waypoint and
## the best example of what the player is looking at.
func _refresh_premise() -> void:
	var deepest: Ghost = null
	for ghost in game.campaign.ladder.ghosts:
		if ghost.kind != "true":
			continue
		if deepest == null or ghost.floor > deepest.floor:
			deepest = ghost
	if deepest == null:
		_premise.text = game.text("ui.premise.empty")
		return
	_premise.text = game.text("ui.premise") 		.replace("{name}", deepest.name) 		.replace("{floor}", str(deepest.floor))


## Clicking a floor you can reach sets it as the entry for the next descent
## -- the tower is the floor picker, which is more intuitive than a spinner
## that happens to sit above it.
func _on_floor_clicked(floor: int) -> void:
	if game == null or game.campaign == null:
		return
	if floor <= CampaignEngine.reach(game.campaign) and game.campaign.run == null:
		_entry.value = float(floor)


## The 10 Hz path. The counter itself is WalletBar's job now; what is left
## here is the one line telling the player whether they can afford anything,
## and it must stay a numbers-only path -- the tower is static between
## mutations and a ticking Soul must never rebuild it.
func _on_soul_changed(soul: float, _rate_per_hour: float) -> void:
	# One float compare -- the cheapest price is cached by refresh().
	var affordable := _cheapest_cost >= 0.0 and soul >= _cheapest_cost
	_hint.text = game.text("ui.hint.spend") if affordable else game.text("ui.hint.wait")


## The price of the cheapest upgrade the player has not maxed out, or -1.0
## when there is nothing left to buy.
func _on_descend() -> void:
	game.start_run(int(_entry.value))


func _cheapest_upgrade_cost() -> float:
	var best := -1.0
	for id in game.content.upgrades:
		var price := game.campaign.upgrades.cost(game.content, String(id))
		if price < 0.0:
			continue
		if best < 0.0 or price < best:
			best = price
	return best
