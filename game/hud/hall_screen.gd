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
## The Chronicle (spec §6.2), under the Hall because it is the layer above
## the rite and the only place Ink is ever seen.
var _ink: Label
var _chronicle: VBoxContainer
var _body: VBoxContainer


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
	# Scrolled. Six Legends and a Chronicle under them is taller than a
	# 360-pixel frame, and the half that went off the bottom was the half
	# with the buttons on it.
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_body.add_child(ScreenLayout.centre(UiTheme.title(game.text("ui.hall.title"))))

	# What the guild is worth, which is the only permanent number in the game.
	_blessing = ScreenLayout.centre(UiTheme.number("", Palette.PREPARED))
	_body.add_child(_blessing)
	_body.add_child(ScreenLayout.centre(UiTheme.small(game.text("ui.hall.blessing"))))

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
	_body.add_child(ScreenLayout.plate(rite, ScreenLayout.WIDE_COLUMN))

	# Centred to the same column as the plates under it. A section header
	# expands to fill, so added straight to the screen its rule runs the full
	# width and the heading detaches from the thing it heads.
	_body.add_child(ScreenLayout.centred(
		ScreenLayout.section(game.text("ui.hall.legends"), Palette.PREPARED),
		ScreenLayout.WIDE_COLUMN))
	_hall = VBoxContainer.new()
	_hall.add_theme_constant_override("separation", 4)
	_body.add_child(ScreenLayout.centred(_hall, ScreenLayout.WIDE_COLUMN))

	_body.add_child(ScreenLayout.centred(
		ScreenLayout.section(game.text("ui.chronicle.title"), Palette.GHOST),
		ScreenLayout.WIDE_COLUMN))
	_ink = ScreenLayout.centre(UiTheme.small("", Palette.GHOST))
	_ink.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(ScreenLayout.centred(_ink, ScreenLayout.WIDE_COLUMN))
	_chronicle = VBoxContainer.new()
	_chronicle.add_theme_constant_override("separation", 3)
	_body.add_child(ScreenLayout.centred(_chronicle, ScreenLayout.WIDE_COLUMN))


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
	_refresh_chronicle(c)


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
		# What the trait actually does. A Legend named after the tag it came
		# from tells you which cycle made it and nothing about why you would
		# take it down there with you.
		var does := _trait_text(legend.trait_tag)
		if does != "":
			box.add_child(UiTheme.small(does, Palette.GHOST))
		for i in mini(MAX_EPITAPHS, legend.epitaphs.size()):
			var row: Dictionary = legend.epitaphs[i]
			# Body weight, not fine print. These lines are the reason the
			# feature is a memorial rather than a reset button.
			box.add_child(UiTheme.body(String(row["epitaph"]), Palette.BONE_DIM))
		if legend.epitaphs.size() > MAX_EPITAPHS:
			box.add_child(UiTheme.small(game.text("ui.hall.and_more") \
				.replace("{count}", str(legend.epitaphs.size() - MAX_EPITAPHS)),
				Palette.BONE_FAINT))
		# One Legend walks with you per descent, and choosing which is the only
		# decision the Hall offers. It lives on the row rather than in a picker
		# elsewhere, because the thing you are choosing between is the
		# epitaphs, not a list of tag names.
		var carried := c.invoked_legend == legend.id
		var carry := Button.new()
		carry.name = "Carry%d" % legend.id
		carry.text = game.text("ui.hall.carried" if carried else "ui.hall.carry")
		carry.disabled = c.run != null
		carry.custom_minimum_size = Vector2(150.0, 20.0)
		if carried:
			carry.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.GHOST))
		var wanted := 0 if carried else legend.id
		carry.pressed.connect(func() -> void: _on_carry(wanted))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(carry)
		box.add_child(row)
		_hall.add_child(ScreenLayout.plate(box, ScreenLayout.WIDE_COLUMN))


## What a Legend carries, spelled out. The tag's name alone ("Poison") says
## which cycle it came from and nothing about what it does for you, and the
## whole point of invoking one is the decision between them.
## The Chronicle: what Ink has bought and what it could buy next.
##
## Shut until the guild has closed enough cycles, and it says so with the
## count rather than by hiding -- a currency that accrues with nothing to
## spend it on is worse than a locked shelf.
func _refresh_chronicle(c: Campaign) -> void:
	for old in _chronicle.get_children():
		_chronicle.remove_child(old)
		old.queue_free()
	if not Chronicle.is_open(c):
		_ink.text = game.text("ui.chronicle.locked") \
			.replace("{count}", str(Chronicle.threshold(c.content))) \
			.replace("{have}", str(c.legends.size()))
		return
	_ink.text = "%s %d" % [game.text("ui.chronicle.ink"), c.ink]
	var ids: Array = c.content.chapters.keys()
	ids.sort()
	for raw in ids:
		var id := String(raw)
		var def: ChapterDef = c.content.chapters[id]
		var level := Chronicle.level_of(c, id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 0)
		text_box.add_child(UiTheme.body(game.text(def.name_key), Palette.PREPARED))
		text_box.add_child(UiTheme.small(game.text(def.text_key), Palette.BONE_DIM))
		text_box.add_child(UiTheme.small(game.text("ui.chronicle.level")
			.replace("{level}", str(level)).replace("{max}", str(def.max_level)),
			Palette.GHOST))
		row.add_child(text_box)
		var price := Chronicle.cost_of(c, id)
		var write := Button.new()
		write.name = "Write_" + id
		write.custom_minimum_size = Vector2(96.0, 18.0)
		write.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if price < 0:
			write.text = game.text("ui.chronicle.written")
			write.disabled = true
		else:
			write.text = "%s %d" % [game.text("ui.chronicle.write"), price]
			write.disabled = not Chronicle.can_write(c, id)
		write.pressed.connect(func() -> void: _on_write(id))
		row.add_child(write)
		_chronicle.add_child(ScreenLayout.plate(row, ScreenLayout.WIDE_COLUMN))
	_add_seal_row(c)


## The Depth Seal for the next descent. On this screen because the Chronicle
## is what sells it, and because setting one is a prestige-layer decision
## rather than a run-layer one: it is the guild betting a cycle's dead.
func _add_seal_row(c: Campaign) -> void:
	var most := Chronicle.seals_available(c)
	if most <= 0:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for seal in range(0, most + 1):
		var pick := Button.new()
		pick.name = "Seal%d" % seal
		pick.custom_minimum_size = Vector2(110.0, 18.0)
		if seal == 0:
			pick.text = game.text("ui.seal.none")
		else:
			pick.text = game.text("ui.seal.set") \
				.replace("{seal}", str(seal)) \
				.replace("{harder}", Num.percent(Chronicle.seal_scaling(c.content, seal) - 1.0)) \
				.replace("{richer}", Num.percent(Chronicle.seal_yield(c.content, seal) - 1.0))
		pick.disabled = c.run != null
		if c.seal == seal:
			pick.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.DANGER))
		var wanted := seal
		pick.pressed.connect(func() -> void: _on_seal(wanted))
		row.add_child(pick)
	_chronicle.add_child(ScreenLayout.plate(row, ScreenLayout.WIDE_COLUMN))


func _on_write(id: String) -> void:
	game.write_chapter(id)
	refresh()


func _on_seal(seal: int) -> void:
	game.set_seal(seal)
	refresh()


func _trait_name(tag: String) -> String:
	if tag == "":
		return game.text("ui.none")
	var carried := Traits.for_tag(game.content, tag)
	if carried == null:
		return game.text("tag.%s.name" % tag)
	return game.text(carried.name_key)


func _trait_text(tag: String) -> String:
	var carried := Traits.for_tag(game.content, tag)
	return game.text(carried.text_key) if carried != null else ""


func _on_carry(id: int) -> void:
	game.invoke_legend(id)
	refresh()


func _on_rite() -> void:
	game.prestige()
	refresh()
