class_name HallScreen
extends VBoxContainer
## The Hall of Legends (spec §6.1): every cycle the guild has closed, and the
## rite that closes the next one.
##
## The screen has one job beyond listing things: **say what the rite takes
## before it is pressed.** A prestige button that surprises somebody is the
## worst button a game can have, and this one wipes a ladder the player spent
## hours filling. So the cost is written out in the same size as the reward,
## and the Hall keeps every merged epitaph afterwards -- §6.1's own words, "the
## Legend is a memorial, not a deletion", are the whole design.

## One line per Legend, oldest first.
const MAX_EPITAPHS := 4

var game: GameRoot
var rows: Array[Label] = []

var _standing: Label
var _blessing: Label
var _cost: Label
var _rite: Button
var _hall: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot) -> void:
	game = g
	if _hall == null:
		_build()
	if not g.ladder_changed.is_connected(refresh):
		g.ladder_changed.connect(refresh)
	refresh()


func _build() -> void:
	add_child(ScreenLayout.centre(UiTheme.title(game.text("ui.hall.title"))))

	# What the guild is worth, which is the only permanent number in the game.
	_blessing = ScreenLayout.centre(UiTheme.number("", Palette.PREPARED))
	add_child(_blessing)
	add_child(ScreenLayout.centre(UiTheme.small(game.text("ui.hall.blessing"))))

	var rite := VBoxContainer.new()
	rite.add_theme_constant_override("separation", 3)
	_standing = ScreenLayout.centre(UiTheme.body(""))
	_standing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rite.add_child(_standing)
	# The cost, in the same weight as the reward. It is not fine print.
	_cost = ScreenLayout.centre(UiTheme.small("", Palette.DANGER))
	_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rite.add_child(_cost)
	_rite = Button.new()
	_rite.custom_minimum_size = Vector2(120.0, 18.0)
	_rite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rite.pressed.connect(_on_rite)
	rite.add_child(_rite)
	add_child(ScreenLayout.plate(rite, ScreenLayout.WIDE_COLUMN))

	# Centred to the same column as the plates under it. A section header
	# expands to fill, so added straight to the screen its rule runs the full
	# width and the heading detaches from the thing it heads.
	add_child(ScreenLayout.centred(
		ScreenLayout.section(game.text("ui.hall.legends"), Palette.PREPARED),
		ScreenLayout.WIDE_COLUMN))
	_hall = VBoxContainer.new()
	_hall.add_theme_constant_override("separation", 4)
	add_child(ScreenLayout.centred(_hall, ScreenLayout.WIDE_COLUMN))


func refresh() -> void:
	if game == null or game.campaign == null:
		return
	var c := game.campaign
	var blessing := CampaignEngine.blessing(c)
	_blessing.text = "+%s" % Num.percent(blessing - 1.0)
	_rite.text = game.text("ui.hall.rite")

	var need := CampaignEngine.prestige_threshold(c)
	var standing := c.ladder.waypoint()
	_standing.text = game.text("ui.hall.needed") \
		.replace("{floor}", str(need)).replace("{standing}", str(standing))
	_rite.disabled = not CampaignEngine.can_prestige(c)
	# Only worth spelling out the cost when the button can actually be pressed:
	# a warning about something you cannot do yet is noise.
	_cost.visible = not _rite.disabled
	_cost.text = game.text("ui.hall.cost") \
		.replace("{ghosts}", str(c.ladder.ghosts.size())) \
		.replace("{soul}", Num.short(game.displayed_soul()))
	_refresh_hall(c)


## One row per Legend: what it is worth, what it carries, and who it was made
## of. The epitaphs are the point -- a list of multipliers would be a
## spreadsheet of the people who died for them.
func _refresh_hall(c: Campaign) -> void:
	for old in _hall.get_children():
		_hall.remove_child(old)
		old.queue_free()
	rows.clear()
	if c.legends.is_empty():
		var none := ScreenLayout.centre(UiTheme.small(game.text("ui.hall.none")))
		_hall.add_child(none)
		return
	for entry in c.legends:
		var legend := entry as Legend
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		var head := UiTheme.body(game.text("ui.hall.legend") \
			.replace("{name}", legend.name) \
			.replace("{cycle}", str(legend.cycle)) \
			.replace("{bonus}", Num.percent(legend.multiplier - 1.0)) \
			.replace("{trait}", _trait_name(legend.trait_tag)), Palette.PREPARED)
		box.add_child(head)
		rows.append(head)
		for i in mini(MAX_EPITAPHS, legend.epitaphs.size()):
			var row: Dictionary = legend.epitaphs[i]
			# Body weight, not fine print. These lines are the reason the
			# feature is a memorial rather than a reset button.
			box.add_child(UiTheme.body(String(row["epitaph"]), Palette.BONE_DIM))
		if legend.epitaphs.size() > MAX_EPITAPHS:
			box.add_child(UiTheme.small(game.text("ui.hall.and_more") \
				.replace("{count}", str(legend.epitaphs.size() - MAX_EPITAPHS)),
				Palette.BONE_FAINT))
		_hall.add_child(ScreenLayout.plate(box, ScreenLayout.WIDE_COLUMN))


func _trait_name(tag: String) -> String:
	if tag == "":
		return game.text("ui.none")
	return game.text("tag.%s.name" % tag)


func _on_rite() -> void:
	game.prestige()
	refresh()
