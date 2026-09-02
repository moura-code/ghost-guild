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
const TOWER_WIDTH := 186.0
const TOWER_HEIGHT := 236.0

var game: GameRoot

var _premise: Label
var _hint: Label
var _descend: Button
var _entry: SpinBox
var _cheapest_cost: float = -1.0
var _tower: TowerView


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
	# Soul, rate and reach are not here any more: they are WalletBar, mounted
	# by MainScreen above every tab, because the Guild and the Séance need
	# them at least as much as the Ladder does.
	# The one line that has to teach the whole premise to someone who has
	# never seen the game: a dead hero is still working for you.
	_premise = UiTheme.body("", Palette.BONE_DIM)
	_premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_premise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_premise)

	# What to do right now. Without this the player has a tower, four tabs
	# and no idea which one is waiting on them.
	# Sits beside the premise rather than under it: two stacked sentences
	# above the tower pushed the tower itself off the bottom of the screen.
	# Beside the premise rather than under it: two stacked sentences above the
	# tower cost it fifteen pixels of depth, and depth is the whole point of
	# the image.
	_hint = UiTheme.small("", Palette.SOUL)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.clip_text = true
	add_child(_hint)

	# The way into the dungeon. Disabled while a run is already live so the
	# campaign never has to refuse the click.
	var descent_row := HBoxContainer.new()
	descent_row.add_theme_constant_override("separation", 4)
	descent_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Entry floor, bounded by reach. Seeded explicitly on every refresh
	# because Godot's Range re-clamps .value when max_value is assigned,
	# which silently defeats a plain "keep the old value" guard.
	_entry = SpinBox.new()
	_entry.min_value = 1.0
	_entry.step = 1.0
	_entry.custom_minimum_size = Vector2(40.0, 0.0)
	descent_row.add_child(_entry)

	_descend = Button.new()
	_descend.custom_minimum_size = Vector2(72.0, 20.0)
	_descend.pressed.connect(_on_descend)
	descent_row.add_child(_descend)
	add_child(descent_row)

	# One drawn shaft rather than a stack of rows. Centred, and given the
	# vertical space, because it is the subject of the screen.
	var tower_wrap := HBoxContainer.new()
	tower_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	tower_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tower = TowerView.new()
	# A real minimum height: the shaft divides its own height into chambers,
	# so a zero-height tower piles all ten floor numbers on one pixel.
	_tower.custom_minimum_size = Vector2(TOWER_WIDTH, TOWER_HEIGHT)
	_tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tower.floor_clicked.connect(_on_floor_clicked)
	tower_wrap.add_child(_tower)
	add_child(tower_wrap)


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


## The shaft. It is the capsule image, the first screenshot and the first
## three seconds of the trailer, so it gets the light on this screen and the
## premise line above it does not.
func focus_rect() -> Rect2:
	if _tower == null or not _tower.is_inside_tree():
		return Rect2()
	var box := _tower.get_global_rect()
	return Rect2(box.position - global_position - Vector2(30.0, 15.0),
		box.size + Vector2(60.0, 30.0))


## Names the deepest true ghost, because that one is both the waypoint and
## the best example of what the player is looking at.
func _refresh_premise() -> void:
	var deepest: Ghost = null
	for ghost in game.campaign.ladder.ghosts:
		if not ghost.is_true():
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
