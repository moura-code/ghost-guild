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
	header.add_child(_stat_block(_soul, game.text("ui.soul")))
	header.add_child(_stat_block(_rate, game.text("ui.per_hour")))
	header.add_child(_stat_block(_reach, game.text("ui.reach")))
	add_child(header)

	_tower = VBoxContainer.new()
	_tower.add_theme_constant_override("separation", ROW_SEPARATION)
	_tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tower)


static func _stat_block(value: Label, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
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
	_on_soul_changed(game.displayed_soul(), game.campaign.rate_per_hour)


## The 10 Hz path: numbers only, never a rebind. The tower is static
## between mutations, so ticking Soul must not touch it.
func _on_soul_changed(soul: float, rate_per_hour: float) -> void:
	_soul.text = Num.short(soul)
	_rate.text = Num.rate(rate_per_hour)
