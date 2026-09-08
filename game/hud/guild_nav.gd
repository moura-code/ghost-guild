class_name GuildNav
extends HFlowContainer
## Stations and tabs name the same persistent panels.

signal chosen(station: String)
signal closed()

const TABS := [GuildRoom.WELL, GuildRoom.DESK, GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.HALL]
const KEYS := ["ui.nav.depths", "ui.hero", "ui.nav.upgrades", "ui.seance", "ui.hall.title"]
var buttons: Dictionary = {}
var last_tab: String = GuildRoom.WELL
var close_button: Button


func _init() -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER
	add_theme_constant_override("h_separation", 5)
	add_theme_constant_override("v_separation", 3)
	for i in TABS.size():
		var id := String(TABS[i])
		var button := Button.new()
		button.custom_minimum_size.y = 22
		button.pressed.connect(func() -> void: chosen.emit(id))
		add_child(button)
		buttons[id] = button
	close_button = Button.new()
	close_button.custom_minimum_size.y = 22
	close_button.pressed.connect(func() -> void: closed.emit())
	add_child(close_button)


func refresh(content: Content, selected: String) -> void:
	last_tab = selected
	for i in TABS.size():
		var button: Button = buttons[TABS[i]]
		button.text = content.text(KEYS[i])
		button.disabled = String(TABS[i]) == selected
		button.add_theme_color_override("font_disabled_color", Palette.SOUL)
		# The screens show the existing per-action unlock requirements. Tabs
		# themselves have never had progression gates in the walkable guild.
	close_button.text = content.text("ui.close") + " · " + HelpPanel.binding("guild_menu")
