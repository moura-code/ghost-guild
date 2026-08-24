class_name LadderScreen
extends VBoxContainer
## The home screen and the capsule image (spec §9): the tower in cross
## section with floor 1 at the top, the ghosts standing in their floors,
## saturation as fill, and the Soul counter ticking above it.

const HEADER_SEPARATION := 40
const ROW_SEPARATION := 1
## The tower is a tower: constrained and centred, not a full-width table.
const TOWER_WIDTH := 660.0

var game: GameRoot

var _soul: Label
var _rate: Label
var _reach: Label
var _premise: Label
var _hint: Label
var _descend: Button
var _entry: SpinBox
var _cheapest_cost: float = -1.0
var _last_shown_soul: int = -1
var _shown_soul: float = 0.0
var _soul_tween: Tween
var _tower: VBoxContainer
var _rows: Array[FloorRow] = []


func _init() -> void:
	add_theme_constant_override("separation", 6)
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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", HEADER_SEPARATION)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	_soul = UiTheme.number("0")
	_rate = UiTheme.number("0/h", Palette.BONE)
	_reach = UiTheme.number("1", Palette.BONE)
	header.add_child(_stat_block(_soul, game.text("ui.soul"), game.text("ui.tip.soul"), "soul"))
	header.add_child(_stat_block(_rate, game.text("ui.per_hour"), game.text("ui.tip.per_hour"), "ghost"))
	header.add_child(_stat_block(_reach, game.text("ui.reach"), game.text("ui.tip.reach"), "descend"))
	add_child(header)

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
	_hint = UiTheme.small("", Palette.SOUL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)

	# The way into the dungeon. Disabled while a run is already live so the
	# campaign never has to refuse the click.
	var descent_row := HBoxContainer.new()
	descent_row.add_theme_constant_override("separation", 8)
	descent_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Entry floor, bounded by reach. Seeded explicitly on every refresh
	# because Godot's Range re-clamps .value when max_value is assigned,
	# which silently defeats a plain "keep the old value" guard.
	_entry = SpinBox.new()
	_entry.min_value = 1.0
	_entry.step = 1.0
	_entry.custom_minimum_size = Vector2(72.0, 0.0)
	descent_row.add_child(_entry)

	_descend = Button.new()
	_descend.custom_minimum_size = Vector2(150.0, 40.0)
	_descend.pressed.connect(_on_descend)
	descent_row.add_child(_descend)
	add_child(descent_row)

	# Centred at a fixed width so ten floors read as a shaft going down
	# rather than as ten rows of a table.
	var tower_wrap := HBoxContainer.new()
	tower_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	_tower = VBoxContainer.new()
	_tower.add_theme_constant_override("separation", ROW_SEPARATION)
	_tower.custom_minimum_size = Vector2(TOWER_WIDTH, 0.0)
	_tower.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tower_wrap.add_child(_tower)
	add_child(tower_wrap)


## A number over its name, with the icon beside the caption rather than the
## value -- an icon next to a large number competes with it.
static func _stat_block(value: Label, caption: String, tip: String, icon: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = tip
	box.add_child(value)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 4)
	foot.add_child(Icons.make_rect(Icons.ui(icon), 15.0, Palette.BONE_DIM))
	foot.add_child(UiTheme.small(caption))
	box.add_child(foot)
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
	var reach := CampaignEngine.reach(game.campaign)
	var chosen := clampi(int(_entry.value), 1, reach)
	_entry.max_value = float(reach)
	_entry.value = float(chosen)
	_entry.editable = reach > 1 and game.campaign.run == null
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
	_rate.text = Num.rate(rate_per_hour)
	_count_to(soul)
	_punch_soul(int(soul))
	# One float compare -- the cheapest price is cached by refresh().
	var affordable := _cheapest_cost >= 0.0 and soul >= _cheapest_cost
	_hint.text = game.text("ui.hint.spend") if affordable else game.text("ui.hint.wait")


## The counter runs up to its new value instead of jumping. On an idle
## screen the number climbing IS the feedback -- a value that snaps reads
## as a field being overwritten.
func _count_to(soul: float) -> void:
	if not is_inside_tree() or absf(soul - _shown_soul) < 0.01:
		_shown_soul = soul
		_soul.text = Num.short(soul)
		return
	# A big jump (a run banked, an upgrade bought) is worth watching; the
	# 10 Hz trickle is not, so it lands almost immediately.
	var leap := absf(soul - _shown_soul) > maxf(8.0, _shown_soul * 0.05)
	if _soul_tween != null and _soul_tween.is_valid():
		_soul_tween.kill()
	_soul_tween = create_tween()
	_soul_tween.tween_method(_set_shown_soul, _shown_soul, soul, 0.55 if leap else 0.12) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown_soul(value: float) -> void:
	_shown_soul = value
	_soul.text = Num.short(value)


## A small kick whenever the whole number climbs. It is the only motion on
## an idle screen, and it is what makes the counter feel like earnings
## rather than a readout.
func _punch_soul(whole: int) -> void:
	if whole == _last_shown_soul:
		return
	var first := _last_shown_soul < 0
	_last_shown_soul = whole
	if first or not is_inside_tree():
		return
	_soul.pivot_offset = _soul.size * Vector2(0.0, 0.5)
	_soul.scale = Vector2(1.12, 1.12)
	var tween := create_tween()
	tween.tween_property(_soul, "scale", Vector2.ONE, 0.16) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
