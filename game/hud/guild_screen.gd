class_name GuildScreen
extends VBoxContainer
## The Guild panel (spec §5.9): who the guild has in the field, pinned above a
## wall of everything it can buy. Every purchase goes through Game, which
## settles production first and saves after.
##
## The expedition band and upgrade groups share the bounded panel scroll.
## Upgrade tablets wrap to the available width at each UI scale.

## Spec §5.9's own order, which is also the order they are earned in: what the
## living hero is, what the dead do, how far down the guild reaches, and what
## can be done to a ghost afterwards. `seance` has no nodes yet and is listed
## anyway, so it appears in the right place on the day it does.
const GROUP_ORDER := ["hero", "ghosts", "descent", "seance"]
## Preferred width for a full group; compact windows wrap the same tablets.
const WALL_GAP := 5.0
const WALL_WIDTH := UpgradePlaque.COLUMNS * UpgradePlaque.PLAQUE_SIZE.x \
	+ (UpgradePlaque.COLUMNS - 1) * WALL_GAP + 44.0

var game: GameRoot
var rows: Dictionary = {}
## One per slot, in flight or open. Empty until the Descent upgrade is bought.
var slots: Array[ExpeditionLine] = []

var _groups: Dictionary = {}
var _group_order: Array[String] = []
var _band: Control
var _band_slots: VBoxContainer
var _wall: VBoxContainer


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
	if not g.expeditions_changed.is_connected(refresh):
		g.expeditions_changed.connect(refresh)
	refresh()


## One section per group, in GROUP_ORDER; any group the data introduces that
## the order does not name is appended after, so new content still shows up.
func _build() -> void:
	_build_band()
	_wall = VBoxContainer.new()
	_wall.add_theme_constant_override("separation", 12)
	_wall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_wall)
	for group in GROUP_ORDER:
		if _has_group(group):
			_add_group(group)
	for id in game.content.upgrades:
		var def: UpgradeDef = game.content.upgrades[id]
		if not _groups.has(def.group):
			_add_group(def.group)
	for id in game.content.upgrades:
		var def2: UpgradeDef = game.content.upgrades[id]
		var row := UpgradePlaque.new()
		row.buy_pressed.connect(_on_buy)
		var wall: HFlowContainer = _groups[def2.group]
		wall.add_child(row)
		rows[def2.id] = row


## Who the guild has in the field, above the wall of what it can buy.
##
## Above, because it is the only thing on this screen that changes on its own:
## a player who opens the Guild while an expedition is out came to look at
## this, and the upgrades are still there underneath. It is hidden outright
## until the upgrade is bought, so the screen a new player sees is unchanged.
func _build_band() -> void:
	_band_slots = VBoxContainer.new()
	_band_slots.add_theme_constant_override("separation", 3)
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.add_child(ScreenLayout.section(game.text("ui.expedition.title"), Palette.GHOST))
	section.add_child(_band_slots)
	_band = ScreenLayout.plate(section, WALL_WIDTH)
	_band.visible = false
	add_child(_band)


func _has_group(group: String) -> bool:
	for id in game.content.upgrades:
		var def: UpgradeDef = game.content.upgrades[id]
		if def.group == group:
			return true
	return false


## A wrapping group of upgrade tablets.
func _add_group(group: String) -> void:
	if _groups.has(group):
		return
	var wall := HFlowContainer.new()
	wall.add_theme_constant_override("h_separation", int(WALL_GAP))
	wall.add_theme_constant_override("v_separation", int(WALL_GAP))
	wall.alignment = FlowContainer.ALIGNMENT_CENTER
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.add_child(ScreenLayout.section(game.text("ui.group.%s" % group),
		Palette.SOUL if group == "hero" else Palette.GHOST))
	section.add_child(wall)
	_wall.add_child(ScreenLayout.plate(section, WALL_WIDTH))
	_groups[group] = wall
	_group_order.append(group)


func refresh() -> void:
	if game == null or game.campaign == null:
		return
	refresh_expeditions()
	var soul := game.displayed_soul()
	for id in rows:
		var def: UpgradeDef = game.content.upgrades[id]
		var level := game.campaign.upgrades.level(String(id))
		var cost := game.campaign.upgrades.cost(game.content, String(id))
		var affordable := cost >= 0.0 and soul >= cost
		(rows[id] as UpgradePlaque).bind(game.content, def, level, cost, affordable)


## One row per slot -- filled ones first, so an expedition landing does not
## make the open slot jump over the one still in the field. The row count only
## changes when the slots upgrade is bought.
func refresh_expeditions() -> void:
	var count := Expeditions.slots(game.campaign)
	_band.visible = count > 0
	while slots.size() > count:
		var gone: ExpeditionLine = slots.pop_back()
		_band_slots.remove_child(gone)
		gone.queue_free()
	while slots.size() < count:
		var line := ExpeditionLine.new()
		line.send_pressed.connect(_on_send)
		_band_slots.add_child(line)
		slots.append(line)
	var now := game.now()
	var flying := game.campaign.expeditions
	for i in slots.size():
		slots[i].bind(game.content, flying[i] if i < flying.size() else null, now)


func _on_send() -> void:
	game.launch_expedition()
	refresh()


func _on_buy(id: String) -> void:
	var result := game.buy_upgrade(id)
	if not bool(result["ok"]):
		# The row was stale -- re-price everything against the real balance.
		refresh()


## Affordability tracks the ticking counter, and so does the countdown on an
## expedition in the field -- this signal is the game's only heartbeat, and a
## bar that only moved when something was bought would be worse than no bar.
func _on_soul_changed(soul: float, _rate_per_hour: float) -> void:
	refresh_expeditions()
	for id in rows:
		var row: UpgradePlaque = rows[id]
		var cost := game.campaign.upgrades.cost(game.content, String(id))
		if cost < 0.0:
			continue
		row._button.disabled = soul < cost
