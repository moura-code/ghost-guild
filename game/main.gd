class_name MainScreen
extends Control
## The root of the running game: applies the theme, boots the campaign,
## routes between the four idle screens, shows the offline summary once and
## saves on the way out. Tests bind their own GameRoot before adding this to
## the tree; the shipped scene picks up the autoload instead.

const TABS := [
	{"id": "ladder", "key": "ui.ladder"},
	{"id": "guild", "key": "ui.guild"},
	{"id": "seance", "key": "ui.seance"},
	{"id": "hero", "key": "ui.hero"},
]
const MARGIN := 16
const TAB_SEPARATION := 6

var game: GameRoot
var current_tab: String = ""
var manages_quit: bool = false
## Injectable so a test can exercise the close-request path without killing
## the test runner. Production behaviour is unchanged.
var quit_action: Callable = func() -> void: get_tree().quit()

var _screens: Dictionary = {}
var _buttons: Dictionary = {}
var _body: Control
var _tab_bar: HBoxContainer
var _offline: OfflineSummary
var _run_view: RunView
var _epitaph: EpitaphScreen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if game != null:
		return
	var autoload := get_node_or_null("/root/Game")
	if autoload is GameRoot:
		manages_quit = true
		get_tree().auto_accept_quit = false
		bind(autoload as GameRoot)


func bind(g: GameRoot) -> void:
	game = g
	if not g.is_booted:
		var result := g.boot()
		if not bool(result["ok"]):
			push_error("main: boot failed: %s" % result["reason"])
			return
	theme = UiTheme.build()
	if _body == null:
		_build()
	show_tab(String(TABS[0]["id"]))
	if not g.run_changed.is_connected(_refresh_run_visibility):
		g.run_changed.connect(_refresh_run_visibility)
	_refresh_run_visibility()
	_maybe_show_offline()


func _build() -> void:
	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, MARGIN)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margins.add_child(column)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", TAB_SEPARATION)
	column.add_child(_tab_bar)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_body)

	for tab in TABS:
		var id := String(tab["id"])
		var button := Button.new()
		button.text = game.text(String(tab["key"]))
		button.toggle_mode = true
		button.pressed.connect(show_tab.bind(id))
		_tab_bar.add_child(button)
		_buttons[id] = button
		_screens[id] = _make_screen(id)

	# A live run takes over the whole window: the tabs are the guild, and
	# you are not in the guild while you are underground.
	_run_view = RunView.new()
	_run_view.visible = false
	_run_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_view.bind(game)
	_run_view.run_finished.connect(_on_run_finished)
	column.add_child(_run_view)

	# The death beat sits above everything, including the run it ended.
	_epitaph = EpitaphScreen.new()
	_epitaph.visible = false
	_epitaph.dismissed.connect(_on_epitaph_dismissed)
	column.add_child(_epitaph)

	_offline = OfflineSummary.new()
	_offline.visible = false
	_offline.dismissed.connect(_on_offline_dismissed)
	column.add_child(_offline)


## Each screen goes in its own ScrollContainer so a long Guild or a crowded
## Séance scrolls instead of clipping.
func _make_screen(id: String) -> Control:
	var inner: Control
	match id:
		"ladder":
			var ladder := LadderScreen.new()
			ladder.bind(game)
			inner = ladder
		"guild":
			var guild := GuildScreen.new()
			guild.bind(game)
			inner = guild
		"seance":
			var seance := SeanceScreen.new()
			seance.bind(game)
			inner = seance
		_:
			var hero := HeroScreen.new()
			hero.bind(game)
			inner = hero
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(inner)
	scroll.visible = false
	_body.add_child(scroll)
	return inner


func show_tab(id: String) -> void:
	if not _screens.has(id):
		return
	current_tab = id
	for other in _screens:
		var screen: Control = _screens[other]
		var wrapper := screen.get_parent() as Control
		var on: bool = other == id
		screen.visible = on
		if wrapper != null:
			wrapper.visible = on
		(_buttons[other] as Button).button_pressed = on


## The run view and the tab shell are mutually exclusive.
func _refresh_run_visibility() -> void:
	if _run_view == null or game == null or game.campaign == null:
		return
	var mourning := _epitaph != null and _epitaph.visible
	var in_run := game.campaign.run != null
	_run_view.visible = in_run and not mourning
	_tab_bar.visible = not in_run and not mourning
	_body.visible = not in_run and not mourning
	if _run_view.visible:
		_run_view.refresh()


## A run that left a ghost earns the epitaph beat before the guild comes
## back. A retreat does not: nobody was left behind.
func _on_run_finished(result: Dictionary) -> void:
	if EpitaphScreen.should_show(result):
		_epitaph.bind(game, result)
		_epitaph.visible = true
	_refresh_run_visibility()


func _on_epitaph_dismissed() -> void:
	_epitaph.visible = false
	_refresh_run_visibility()


func _maybe_show_offline() -> void:
	if game == null or not OfflineSummary.should_show(game.offline):
		return
	_offline.bind(game.content, game.offline)
	_offline.visible = true


func _on_offline_dismissed() -> void:
	_offline.visible = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.STONE)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not manages_quit:
		return
	if game != null and game.is_booted:
		game.save()
	quit_action.call()
