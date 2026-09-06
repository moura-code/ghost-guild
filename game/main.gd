class_name MainScreen
extends Control
## The root of the running game: applies the theme, boots the campaign,
## routes between the four idle screens, shows the offline summary once and
## saves on the way out. Tests bind their own GameRoot before adding this to
## the tree; the shipped scene picks up the autoload instead.

const TABS := [
	{"id": "ladder", "key": "ui.ladder", "icon": "ghost"},
	{"id": "guild", "key": "ui.guild", "icon": "guild"},
	{"id": "seance", "key": "ui.seance", "icon": "seance"},
	{"id": "hero", "key": "ui.hero", "icon": "hero"},
]
const MARGIN := 16

var game: GameRoot
var current_tab: String = ""
var manages_quit: bool = false
## Injectable so a test can exercise the close-request path without killing
## the test runner. Production behaviour is unchanged.
var quit_action: Callable = func() -> void: get_tree().quit()

var _screens: Dictionary = {}
var _body: Control
var _tab_bar: NavBar
var _offline: OfflineSummary
var _run_view: RunView
var _epitaph: EpitaphScreen
var _atmosphere: Atmosphere
var _transition: Transition
var _wallet: WalletBar
var _palette: PaletteLayer


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
	if _transition.get_parent() == null:
		add_child(_transition)
	show_tab(String(TABS[0]["id"]))
	if not g.run_changed.is_connected(_refresh_run_visibility):
		g.run_changed.connect(_refresh_run_visibility)
	_refresh_run_visibility()
	_maybe_show_offline()


func _build() -> void:
	# Behind everything, and added first so it stays there.
	_atmosphere = Atmosphere.new()
	add_child(_atmosphere)

	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, MARGIN)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margins.add_child(column)

	_tab_bar = NavBar.new()
	_tab_bar.tab_pressed.connect(show_tab)
	column.add_child(_tab_bar)

	# Soul, income and reach, above whichever tab is showing. It lived inside
	# the Ladder before, which left the two screens that spend Soul with no
	# way to show how much you had.
	_wallet = WalletBar.new()
	column.add_child(_wallet)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_body)

	# Above everything, including the epitaph: it covers whatever is swapping.
	_transition = Transition.new()

	var nav: Array = []
	for tab in TABS:
		var id := String(tab["id"])
		nav.append({"id": id, "label": game.text(String(tab["key"])), "icon": String(tab["icon"])})
		_screens[id] = _make_screen(id)
	_tab_bar.accent = Palette.biome_accent(game.campaign.biome_id)
	_tab_bar.build_tabs(nav)
	_wallet.bind(game)

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

	# On top of everything, not in the column: as a sibling of the screens it
	# took its own share of the height and squashed whatever was above it.
	_offline = OfflineSummary.new()
	_offline.visible = false
	_offline.dismissed.connect(_on_offline_dismissed)
	add_child(_offline)

	# Keep the 3D material shading and font antialiasing intact. PaletteLayer
	# remains available for pixel-art previews, but is not a screen filter.

	# Every button in the game gets a click and a hover from one place. A
	# silent button is the single most "unfinished" thing a UI can do, and
	# wiring them screen by screen is how three of them end up forgotten.
	UiTheme.voice_buttons(self, game.sfx)


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
	# Vertical too, so a screen shorter than the window centres in it. A
	# ScrollContainer otherwise sizes its child to the content's minimum
	# height and leaves the rest of the frame empty below it, which is what
	# put every panel screen in the top third.
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	# Swapping behind a wipe, unless nothing is on screen yet.
	if current_tab != "" and current_tab != id and _transition != null:
		var target := id
		_transition.midpoint.connect(func() -> void: _apply_tab(target), CONNECT_ONE_SHOT)
		_transition.play()
		current_tab = id
		return
	_apply_tab(id)


func _apply_tab(id: String) -> void:
	current_tab = id
	for other in _screens:
		var screen: Control = _screens[other]
		var wrapper := screen.get_parent() as Control
		var on: bool = other == id
		screen.visible = on
		if wrapper != null:
			wrapper.visible = on
	_tab_bar.select(id)
	if game != null and _screens.has(id):
		UiTheme.voice_buttons(_screens[id] as Node, game.sfx)
	# The light follows the tab: each screen puts its content somewhere
	# different, and a focus left pointing at the last one is worse than none.
	_refresh_focus()
	_enter(_screens[id] as Control)


## A screen rises into place rather than blinking on. Small -- eight pixels
## and a fifth of a second -- but the difference between a page that loads
## and a screen that arrives.
func _enter(screen: Control) -> void:
	if screen == null or not screen.is_inside_tree():
		return
	screen.modulate.a = 0.0
	var rest := screen.position.y
	screen.position.y = rest + 8.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(screen, "modulate:a", 1.0, 0.18)
	tween.tween_property(screen, "position:y", rest, 0.22) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The run view and the tab shell are mutually exclusive.
func _refresh_run_visibility() -> void:
	if _run_view == null or game == null or game.campaign == null:
		return
	var mourning := _epitaph != null and _epitaph.visible
	var in_run := game.campaign.run != null
	_refresh_atmosphere(in_run)
	_run_view.visible = in_run and not mourning
	_tab_bar.visible = not in_run and not mourning
	_body.visible = not in_run and not mourning
	if _wallet != null:
		_wallet.visible = not in_run and not mourning
	if _run_view.visible:
		_run_view.refresh()


## The ground darkens as the hero descends and lifts again in the guild, and
## the light gathers wherever the screen on top put its content.
func _refresh_atmosphere(in_run: bool) -> void:
	if _atmosphere == null:
		return
	_atmosphere.set_biome(game.campaign.biome_id)
	if in_run:
		_atmosphere.set_floor(game.campaign.run.floor, game.campaign.biome().last_floor)
	else:
		_atmosphere.set_floor(1, game.campaign.biome().last_floor)
	_refresh_focus()


## Asks whichever screen is on top where its content lives and points the
## light at it. A screen that does not answer gets an open frame, so this is
## additive: nothing goes dark because a screen has not been recomposed yet.
func _refresh_focus() -> void:
	if _atmosphere == null:
		return
	var top := _top_screen()
	if top == null or not top.has_method("focus_rect"):
		_atmosphere.clear_focus()
		return
	var rect: Rect2 = top.call("focus_rect")
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_atmosphere.clear_focus()
		return
	# Screens answer in their own coordinates; the atmosphere sits behind the
	# whole window, so the rect has to be carried across.
	var offset := top.global_position - _atmosphere.global_position
	_atmosphere.focus_on(Rect2(rect.position + offset, rect.size))


func _top_screen() -> Control:
	if _epitaph != null and _epitaph.visible:
		return _epitaph
	if _run_view != null and _run_view.visible:
		return _run_view.current_panel()
	return _screens.get(current_tab, null) as Control


## A run that left a ghost earns the epitaph beat before the guild comes
## back. A retreat does not: nobody was left behind.
func _on_run_finished(result: Dictionary) -> void:
	if EpitaphScreen.should_show(result):
		_epitaph.bind(game, result)
		_epitaph.visible = true
		# The dungeon notices when someone is left behind.
		if _atmosphere != null:
			_atmosphere.pulse(1.0)
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


## The Atmosphere draws the ground now; this stays as the backstop for the
## one frame before it is built, and if its shader ever fails to load.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.STONE)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not manages_quit:
		return
	if game != null and game.is_booted:
		game.save()
		# The room is still playing at this point and a looping stream never
		# finishes on its own, so it has to be told to stop before the tree
		# comes down.
		if game.sfx != null:
			game.sfx.release()
	quit_action.call()
