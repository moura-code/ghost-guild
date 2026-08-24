class_name GuildScreen
extends VBoxContainer
## The Guild panel (spec §5.9). Upgrades in two groups, each row priced from
## the player's current Soul. Every purchase goes through Game, which settles
## production first and saves after.

const GROUP_ORDER := ["hero", "ghosts"]

var game: GameRoot
var rows: Dictionary = {}

var _groups: Dictionary = {}
var _group_order: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot) -> void:
	game = g
	if rows.is_empty():
		_build()
	if not g.soul_changed.is_connected(_on_soul_changed):
		g.soul_changed.connect(_on_soul_changed)
	if not g.ladder_changed.is_connected(refresh):
		g.ladder_changed.connect(refresh)
	refresh()


## One section per group, in GROUP_ORDER; any group the data introduces that
## the order does not name is appended after, so new content still shows up.
func _build() -> void:
	for group in GROUP_ORDER:
		if _has_group(group):
			_add_group(group)
	for id in game.content.upgrades:
		var def: UpgradeDef = game.content.upgrades[id]
		if not _groups.has(def.group):
			_add_group(def.group)
	for id in game.content.upgrades:
		var def2: UpgradeDef = game.content.upgrades[id]
		var row := UpgradeRow.new()
		row.buy_pressed.connect(_on_buy)
		var box: VBoxContainer = _groups[def2.group]
		box.add_child(row)
		rows[def2.id] = row


func _has_group(group: String) -> bool:
	for id in game.content.upgrades:
		var def: UpgradeDef = game.content.upgrades[id]
		if def.group == group:
			return true
	return false


func _add_group(group: String) -> void:
	if _groups.has(group):
		return
	add_child(ScreenLayout.centre(UiTheme.body(game.text("ui.group.%s" % group), Palette.BONE_DIM)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(ScreenLayout.centred(box, ScreenLayout.WIDE_COLUMN))
	_groups[group] = box
	_group_order.append(group)


func refresh() -> void:
	if game == null or game.campaign == null:
		return
	var soul := game.displayed_soul()
	for id in rows:
		var def: UpgradeDef = game.content.upgrades[id]
		var level := game.campaign.upgrades.level(String(id))
		var cost := game.campaign.upgrades.cost(game.content, String(id))
		var affordable := cost >= 0.0 and soul >= cost
		(rows[id] as UpgradeRow).bind(game.content, def, level, cost, affordable)


func _on_buy(id: String) -> void:
	var result := game.buy_upgrade(id)
	if not bool(result["ok"]):
		# The row was stale -- re-price everything against the real balance.
		refresh()


## Affordability tracks the ticking counter, so a row unlocks the moment the
## ladder has earned enough without the player touching anything.
func _on_soul_changed(soul: float, _rate_per_hour: float) -> void:
	for id in rows:
		var row: UpgradeRow = rows[id]
		var cost := game.campaign.upgrades.cost(game.content, String(id))
		if cost < 0.0:
			continue
		row._button.disabled = soul < cost
