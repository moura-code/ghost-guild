class_name LadderScreen
extends VBoxContainer
## The home screen and the capsule image (spec §9): the tower in cross
## section with floor 1 at the top, the ghosts standing in their floors,
## saturation as fill, and the Soul counter ticking above it.

const HEADER_SEPARATION := 28
const ROW_SEPARATION := 2

var game: GameRoot

var _soul: Label
var _rate: Label
var _reach: Label
var _premise: Label
var _hint: Label
var _descend: Button
var _cheapest_cost: float = -1.0
var _tower: VBoxContainer
var _rows: Array[FloorRow] = []


func _init() -> void:
	add_theme_constant_override("separation", 12)


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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", HEADER_SEPARATION)
	_soul = UiTheme.number("0")
	_rate = UiTheme.number("0/h", Palette.BONE)
	_reach = UiTheme.number("1", Palette.BONE)
	header.add_child(_stat_block(_soul, game.text("ui.soul"), game.text("ui.tip.soul")))
	header.add_child(_stat_block(_rate, game.text("ui.per_hour"), game.text("ui.tip.per_hour")))
	header.add_child(_stat_block(_reach, game.text("ui.reach"), game.text("ui.tip.reach")))
	add_child(header)

	# The one line that has to teach the whole premise to someone who has
	# never seen the game: a dead hero is still working for you.
	_premise = UiTheme.body("", Palette.BONE_DIM)
	_premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_premise)

	# What to do right now. Without this the player has a tower, four tabs
	# and no idea which one is waiting on them.
	_hint = UiTheme.small("", Palette.SOUL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

	# The way into the dungeon. Disabled while a run is already live so the
	# campaign never has to refuse the click.
	_descend = Button.new()
	_descend.pressed.connect(_on_descend)
	add_child(_descend)

	_tower = VBoxContainer.new()
	_tower.add_theme_constant_override("separation", ROW_SEPARATION)
	_tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tower)


static func _stat_block(value: Label, caption: String, tip: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = tip
	box.add_child(value)
	box.add_child(UiTheme.small(caption))
	return box


## Grows or shrinks the tower to the biome's height, then rebinds every row.
## Called on ladder_changed, which every Game mutator emits.
func refresh() -> void:
	if game == null or game.campaign == null:
		return
	var last := game.campaign.biome().last_floor
	while _rows.size() < last:
		var row := FloorRow.new()
		_tower.add_child(row)
		_rows.append(row)
	while _rows.size() > last:
		var extra: FloorRow = _rows.pop_back()
		_tower.remove_child(extra)
		extra.queue_free()
	for i in range(_rows.size()):
		_rows[i].bind(game.campaign, i + 1)
	_reach.text = str(CampaignEngine.reach(game.campaign))
	_refresh_premise()
	_cheapest_cost = _cheapest_upgrade_cost()
	_descend.text = game.text("ui.descend")
	_descend.disabled = game.campaign.run != null
	_on_soul_changed(game.displayed_soul(), game.campaign.rate_per_hour)


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


## The 10 Hz path: numbers only, never a rebind. The tower is static
## between mutations, so ticking Soul must not touch it.
func _on_soul_changed(soul: float, rate_per_hour: float) -> void:
	_soul.text = Num.short(soul)
	_rate.text = Num.rate(rate_per_hour)
	# One float compare -- the cheapest price is cached by refresh().
	var affordable := _cheapest_cost >= 0.0 and soul >= _cheapest_cost
	_hint.text = game.text("ui.hint.spend") if affordable else game.text("ui.hint.wait")


## The price of the cheapest upgrade the player has not maxed out, or -1.0
## when there is nothing left to buy.
func _on_descend() -> void:
	game.start_run(1)


func _cheapest_upgrade_cost() -> float:
	var best := -1.0
	for id in game.content.upgrades:
		var price := game.campaign.upgrades.cost(game.content, String(id))
		if price < 0.0:
			continue
		if best < 0.0 or price < best:
			best = price
	return best
