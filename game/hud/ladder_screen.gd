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
## Two lines shorter than it was: the haunting line under the shaft has to
## fit inside the frame, and a sentence clipped by the bottom edge teaches
## nobody anything.
const TOWER_HEIGHT := 222.0

signal floor_selected(floor: int)
signal ghost_inspected(ghost_id: int)
var selected_floor: int = 1
var _floor_details: Label
var _residents: VBoxContainer
var _preview: ModelPreview
var _floor_picker: SpinBox
var game: GameRoot

var _premise: Label
var _hint: Label
var _descend: Button
var _entry: SpinBox
var _cheapest_cost: float = -1.0
var _tower: TowerView
## What a haunting is and whether the guild has one. Under the shaft rather
## than on it: the tower can colour a number amber, and only a sentence can
## teach the player why standing three Poison dead together was worth doing.
var _haunting: Label


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
	var floors := HFlowContainer.new()
	floors.alignment = FlowContainer.ALIGNMENT_CENTER
	floors.add_theme_constant_override("h_separation", 14)
	floors.add_child(tower_wrap)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 210
	details.add_theme_constant_override("separation", 6)
	_floor_picker = SpinBox.new()
	_floor_picker.min_value = 1
	_floor_picker.max_value = 1000000000
	_floor_picker.value_changed.connect(func(value: float) -> void: select_floor(int(value)))
	details.add_child(_floor_picker)
	_floor_details = UiTheme.body("")
	_floor_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_floor_details)
	_preview = ModelPreview.new()
	details.add_child(_preview)
	_residents = VBoxContainer.new()
	details.add_child(_residents)
	floors.add_child(details)
	add_child(floors)

	_haunting = UiTheme.small("", Palette.PREPARED)
	_haunting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# One line and no wrapping: this VBox gives a Label about forty characters
	# whatever it is told about widths, and a wrapped second line is simply
	# never drawn. The sentence is written to fit rather than argued with.
	# Given a width, not left to find one. A bare Label in this VBox got a
	# rect about ninety pixels across -- narrower than the shaft above it --
	# and quietly cut the sentence off after four words.
	_haunting.custom_minimum_size = Vector2(0.0, 22.0)
	add_child(ScreenLayout.centred(_haunting, ScreenLayout.WIDE_COLUMN))


## A number over its name, with the icon beside the caption rather than the
## value -- an icon next to a large number competes with it.
## Rebinds the whole shaft. Called on ladder_changed, which every Game
## mutator emits.
func refresh() -> void:
	if game == null or game.campaign == null:
		return
	_tower.bind(game.campaign)
	select_floor(selected_floor)
	_refresh_premise()
	_refresh_haunting()
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


## The deepest haunting the guild has, or the rule for making one.
##
## The deepest rather than the first, because that is the one paying most and
## the one the player is working toward -- and naming a floor 1 haunting while
## floor 20 is also haunted would read as the feature being about the shallow
## end.
func _refresh_haunting() -> void:
	var c := game.campaign
	var bal := c.balance()
	var floors := c.ladder.floors()
	floors.reverse()
	for floor in floors:
		var told := Hauntings.describe(c.content, c.ladder, floor, bal)
		if told.is_empty():
			continue
		_haunting.text = game.text("ui.haunting") \
			.replace("{floor}", str(floor)) \
			.replace("{count}", str(int(told["count"]))) \
			.replace("{tag}", game.text("tag.%s.name" % String(told["tag"]))) \
			.replace("{bonus}", Num.percent(float(told["bonus"])))
		return
	_haunting.text = game.text("ui.haunting.none")


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
	_premise.text = game.text("ui.premise") \
		.replace("{name}", deepest.name) \
		.replace("{floor}", str(deepest.floor))


## Clicking a floor you can reach sets it as the entry for the next descent
## -- the tower is the floor picker, which is more intuitive than a spinner
## that happens to sit above it.
func _on_floor_clicked(floor: int) -> void:
	if game == null or game.campaign == null:
		return
	select_floor(floor)
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


func select_floor(floor: int) -> void:
	selected_floor = maxi(1, floor)
	_floor_picker.set_value_no_signal(selected_floor)
	_tower.selected_floor = selected_floor
	_tower.queue_redraw()
	var c := game.campaign
	var residents := c.ladder.on_floor(selected_floor)
	var rate := c.ladder.floor_output(selected_floor, c.balance(), c.modifiers())
	_floor_details.text = game.text("ui.floor.details").replace("{floor}", str(selected_floor)) \
		.replace("{count}", str(residents.size())).replace("{rate}", Num.short(rate))
	_floor_details.text += "\n" + game.text("ui.floor.eligible" if selected_floor <= CampaignEngine.reach(c) else "ui.floor.locked")
	var haunting := Hauntings.describe(c.content, c.ladder, selected_floor, c.balance())
	if not haunting.is_empty():
		_floor_details.text += "\n" + game.text("ui.haunting").replace("{floor}", str(selected_floor)) \
			.replace("{count}", str(int(haunting["count"]))).replace("{tag}", game.text("tag.%s.name" % haunting["tag"])) \
			.replace("{bonus}", Num.percent(float(haunting["bonus"])))
	if selected_floor > WellView.MAX_FLOORS:
		_floor_details.text += "\n" + game.text("ui.floor.deeper")
	for child in _residents.get_children():
		child.free()
	_preview.visible = not residents.is_empty()
	if not residents.is_empty():
		_preview.show_ghost(residents[0])
	for ghost in residents:
		var button := Button.new()
		button.text = ghost.name + " · " + game.text("ui.inspect.ghost")
		button.pressed.connect(func() -> void: ghost_inspected.emit(ghost.id))
		_residents.add_child(button)
	floor_selected.emit(selected_floor)
