class_name Crawl
extends Node3D
## The scene root, and the only file under game/ that talks to GameRoot.
##
## Two places, one root: the guild when there is no run, the crypt when there
## is. Nothing under it ever writes to RunState -- the one channel is
## GameRoot.run_action (spec §4).
##
## Every phase has a host and nothing resolves behind the player's back: a
## fight is staged in the room, and reward, event, rest, shop, the descent
## draft, the exit decision, the four guild stations and the epitaph are all
## panels on the HUD over whichever place is live.

signal floor_built(floor: int)
signal place_changed(place: int)

enum Place { NONE, GUILD, DUNGEON }

var game: GameRoot
var place: int = Place.NONE
var layout: FloorLayout
var player: Player
var hud: HudRoot
var prompts: Prompts
var _offline_summary: OfflineSummary
var crosshair: Crosshair
var compass: Compass
var director: FightDirector
var guild: GuildRoom
var choice: ChoiceScreen
var exit_panel: ExitScreen
## Soul, income and reach, over every screen where any of the three is
## earned, spent or looked at.
##
## It was written for the 2D shell, mounted by the shell, and then the
## pivot rebuilt the shell as a room and left it behind -- so the number
## this whole game is about was not on screen anywhere. You could tell an
## upgrade was unaffordable only by noticing its button was grey.
var wallet: WalletBar
var epitaph: EpitaphScreen
var title: TitleMenu
var pause: PauseMenu
var options: OptionsMenu
var settings: Settings
## Where settings are read from and written to. Overridable for the same
## reason save_path is: a test that writes the real file changes the
## developer's mouse sensitivity.
var settings_path: String = Settings.PATH
## Off for tests, which want the game already running rather than a menu.
var show_title: bool = true
var markers: Array[EncounterMarker] = []
var stairs: EncounterMarker
var _map_button: Button
var _room_focus: EncounterMarker
var _room_hint: bool = false
var _signs: Array = []
## The station the player is standing in, or null.
var focused: Interactable
## Whichever panel currently owns the screen, or null.
var panel: Control

## True only when this crawl picked up the /root/Game autoload, i.e. it is the
## shipped scene rather than one a test built. Saving on quit is the autoload
## owner's job and nobody else's.
var manages_quit: bool = false
## Injectable so a test can exercise the close path without killing the runner.
var quit_action: Callable = func() -> void: get_tree().quit()

var _world: Node3D
var _built_floor: int = -1
## The biome the last announced floor was in, so crossing into a new one can
## be announced and walking down inside one cannot.
var _announced_biome: String = ""
var _stations: Dictionary = {}
var _mourning: bool = false
var _had_save: bool = false
var context := UiContext.new()
var nav: GuildNav
var help: HelpPanel
var teaching: TeachingMoment
var recap: RunRecap
var _recap_result: Dictionary = {}
var _panel_focus: Dictionary = {}
var _frames: Dictionary = {}
var campaign_menu: CampaignMenu
var floor_map: FloorMap
var _focused_ghost_id: int = 0
var _map_marker := Vector2i(-1, -1)
var ghost_detail: GhostDetail
var inspector: CardInspector
var _dungeon_ghosts: Array[GhostFigure] = []
var _ghost_signature: String = ""
var panel_return: Button


## Picks up the autoload only if nobody has claimed this node already. Tests
## assign `game` before adding the crawl to the tree, which is what keeps the
## suite off the real save file -- the autoload boots against
## SaveGame.DEFAULT_PATH.
func _ready() -> void:
	if game != null:
		return
	var autoload := get_node_or_null("/root/Game")
	if autoload is GameRoot:
		manages_quit = true
		get_tree().auto_accept_quit = false
		bind(autoload as GameRoot)


func bind(g: GameRoot) -> void:
	game = g
	# Settings before boot: the language is one of them, and content is
	# loaded once, during boot, in whatever language it is told.
	settings = Settings.load_from(settings_path)
	settings.apply(null)
	g.locale = settings.locale
	if not g.is_booted and g.save_path == SaveGame.DEFAULT_PATH:
		g.save_path = SaveGame.slot_path(settings.active_slot)
	if not g.is_booted:
		var result := g.boot()
		if not bool(result["ok"]):
			push_error("crawl: boot failed: %s" % result["reason"])
			return
	_had_save = SaveGame.exists(g.save_path) and not g.save_blocked
	_build_hud()
	if not g.run_changed.is_connected(_sync):
		g.run_changed.connect(_sync)
	_sync()
	# After `_sync`, because `_sync` is what builds the player. `apply`
	# guards on null, so calling it before meant sensitivity, invert and
	# field of view were silently thrown away on every launch.
	settings.apply(player)
	hud.ui_scale = settings.ui_scale
	hud.fit(get_viewport().get_visible_rect().size)
	if show_title:
		# Built AFTER _sync, so the world behind the title is the world you are
		# about to walk back into rather than an empty frame.
		title.build(g.content, _had_save)
		if g.load_notice != "":
			var notice := UiTheme.body(g.text("ui.saves." + g.load_notice))
			notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			title._column.add_child(notice)
		open(title)
	else:
		_maybe_show_offline()


# ---------------------------------------------------------------- the screen

## How much room the wallet takes at the top, and how far down the panels
## that show it start.
const WALLET_HEIGHT := 30.0


## The screens that show the wallet: the five the guild opens, which are
## the only ones where Soul is earned, spent or looked at. A run's own
## panels do not -- a reward screen with a Soul counter on it is asking the
## player to do arithmetic in the middle of a fight.
static func wants_wallet(screen: Control) -> bool:
	return screen is LadderScreen or screen is GuildScreen \
		or screen is SeanceScreen or screen is HeroScreen or screen is HallScreen


func _build_hud() -> void:
	if hud != null:
		return
	hud = HudRoot.new()
	hud.name = "Hud"
	add_child(hud)

	prompts = Prompts.new()
	hud.ui.add_child(prompts)

	wallet = WalletBar.new()
	wallet.name = "Wallet"
	wallet.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wallet.offset_top = 2.0
	wallet.offset_bottom = WALLET_HEIGHT
	wallet.visible = false
	hud.ui.add_child(wallet)

	crosshair = Crosshair.new()
	hud.ui.add_child(crosshair)

	_map_button = Button.new()
	_map_button.text = game.text("room.map")
	_map_button.position = Vector2(8, 30)
	_map_button.pressed.connect(_open_map)
	hud.ui.add_child(_map_button)
	compass = Compass.new()
	hud.ui.add_child(compass)

	# Built once and toggled, not rebuilt per phase: a shop refreshes on every
	# purchase, and rebuilding the panel each time would throw away the scroll
	# position along with the node.
	choice = ChoiceScreen.new()
	choice.card_inspected.connect(inspect_card)
	choice.deck_requested.connect(_inspect_run_deck)
	_host(choice)
	exit_panel = ExitScreen.new()
	exit_panel.deck_requested.connect(_inspect_run_deck)
	exit_panel.decided.connect(_on_exit_decided)
	_host(exit_panel)
	epitaph = EpitaphScreen.new()
	epitaph.dismissed.connect(_on_epitaph_dismissed)
	_host(epitaph)

	title = TitleMenu.new()
	title.continued.connect(_leave_title)
	title.started_new.connect(_start_new_guild)
	title.options_requested.connect(_open_options)
	title.quit_requested.connect(_quit)
	title.campaigns_requested.connect(_open_campaigns)
	_host(title)

	pause = PauseMenu.new()
	pause.resumed.connect(close_panel)
	pause.options_requested.connect(_open_options)
	pause.abandon_requested.connect(_abandon_run)
	pause.quit_requested.connect(_quit)
	_host(pause)

	options = OptionsMenu.new()
	options.closed.connect(close_panel)
	options.campaigns_requested.connect(_open_campaigns)
	options.changed.connect(_on_settings_changed)
	_host(options)

	for id in [GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.DESK, GuildRoom.HALL,
			GuildRoom.WELL]:
		var screen := _guild_panel(String(id))
		_stations[id] = screen
		_host(screen)
		if screen is HeroScreen:
			screen.card_inspected.connect(inspect_card)
		if screen is LadderScreen:
			screen.floor_selected.connect(_select_floor)
		if screen is LadderScreen or screen is SeanceScreen:
			screen.ghost_inspected.connect(inspect_ghost)

	nav = GuildNav.new()
	nav.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nav.offset_top = WALLET_HEIGHT
	nav.chosen.connect(open_guild)
	nav.closed.connect(close_panel)
	nav.visible = false
	hud.ui.add_child(nav)
	help = HelpPanel.new()
	help.closed.connect(close_panel)
	_host(help)
	teaching = TeachingMoment.new()
	teaching.position = Vector2(8, 76)
	teaching.dismissed.connect(_dismiss_lesson)
	teaching.details_requested.connect(func() -> void:
		help.build(game.content, place == Place.GUILD, _exploring())
		overlay(help))
	hud.ui.add_child(teaching)
	recap = RunRecap.new()
	recap.closed.connect(close_panel)
	_host(recap)
	campaign_menu = CampaignMenu.new()
	campaign_menu.selected.connect(_continue_campaign)
	campaign_menu.import_requested.connect(_import_campaign)
	campaign_menu.closed.connect(close_panel)
	_host(campaign_menu)
	floor_map = FloorMap.new()
	floor_map.closed.connect(close_panel)
	floor_map.marked.connect(func(cell: Vector2i) -> void:
		_map_marker = cell
		_refresh_marks())
	_host(floor_map)
	ghost_detail = GhostDetail.new()
	ghost_detail.closed.connect(close_panel)
	ghost_detail.card_inspected.connect(inspect_card)
	_host(ghost_detail)
	game.ladder_changed.connect(_refresh_ghosts)
	inspector = CardInspector.new()
	inspector.closed.connect(close_panel)
	_host(inspector)
	panel_return = Button.new()
	panel_return.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel_return.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel_return.offset_right = -10
	panel_return.offset_top = 5
	panel_return.text = game.text("ui.close")
	panel_return.pressed.connect(close_panel)
	panel_return.visible = false
	hud.ui.add_child(panel_return)
	nav.resized.connect(_layout_frames)
	hud.set_pointer(false)


## The four guild stations open the four panels that already existed. They are
## kept rather than rewritten: the spec's argument for cards in 2D -- "a card
## rendered in perspective is a card you cannot read" -- is an argument about
## text and choice, and a ladder of twenty ghosts is the same object.
func _guild_panel(id: String) -> Control:
	match id:
		GuildRoom.TABLE:
			return GuildScreen.new()
		GuildRoom.CIRCLE:
			return SeanceScreen.new()
		GuildRoom.DESK:
			return HeroScreen.new()
		GuildRoom.HALL:
			return HallScreen.new()
		_:
			return LadderScreen.new()


func _host(screen: Control) -> void:
	var frame := PanelFrame.new()
	frame.visible = false
	_frames[screen] = frame
	hud.ui.add_child(frame)
	frame.host(screen)
	screen.visible = false
	_layout_frames()


func _layout_frames() -> void:
	for screen in _frames:
		var frame: PanelFrame = _frames[screen]
		frame.offset_top = WALLET_HEIGHT + maxf(26.0, nav.size.y if nav != null else 26.0) + 5.0 if wants_wallet(screen) and place == Place.GUILD else 30.0


## A panel takes the screen, the cursor and the body at the same time, so "the
## mouse is free" and "the player cannot walk off mid-choice" can never
## disagree.
func open(screen: Control) -> void:
	if panel != null and is_instance_valid(panel):
		_panel_focus[panel] = get_viewport().gui_get_focus_owner()
	panel = screen
	context.remember(game.campaign.run)
	for child in hud.ui.get_children():
		if child is Control and child != prompts and child != wallet:
			(child as Control).visible = child == _frames.get(screen, screen)
	for hosted in _frames:
		(hosted as Control).visible = hosted == screen
		(hosted as Control).process_mode = Node.PROCESS_MODE_INHERIT if hosted == screen else Node.PROCESS_MODE_DISABLED
	_layout_frames()
	if panel_return != null:
		panel_return.visible = screen != null and _can_close(screen) and not (wants_wallet(screen) and place == Place.GUILD)
		panel_return.text = game.text("ui.close")
	var management := screen != null and wants_wallet(screen) and place == Place.GUILD
	wallet.visible = management
	if management:
		wallet.bind(game)
	if nav != null:
		nav.visible = management
		if management:
			for id in _stations:
				if _stations[id] == screen:
					nav.refresh(game.content, String(id))
	_apply_input_context()
	hud.set_dim(screen != null)
	if screen != null:
		prompts.clear_prompt()
		prompts.hush()
		prompts.clear_objective()
		prompts.clear_rule()
		_restore_focus.call_deferred(screen, _panel_focus.get(screen))


func _apply_input_context() -> void:
	var fighting := director != null and not director.is_settled()
	if director != null:
		director.set_suspended(panel != null)
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED if panel != null else Node.PROCESS_MODE_INHERIT
		player.frozen = panel != null or (fighting and director.staging)
		if player.frozen:
			player.velocity.x = 0.0
			player.velocity.z = 0.0
		player.look_enabled = panel == null and not fighting
	if _world != null:
		_world.process_mode = Node.PROCESS_MODE_DISABLED if panel != null and panel != epitaph else Node.PROCESS_MODE_INHERIT
	hud.set_pointer(panel != null or fighting)
	crosshair.visible = panel == null and not fighting
	compass.visible = panel == null and not fighting
	_map_button.visible = _exploring() and place == Place.DUNGEON
	_refresh_teaching()


func _restore_focus(screen: Control, previous: Variant = null) -> void:
	if screen == null or panel != screen or not screen.is_visible_in_tree():
		return
	if is_instance_valid(previous) and previous is Control and previous.is_visible_in_tree():
		previous.grab_focus()
		return
	_focus_first(screen)


func _focus_first(root: Control) -> bool:
	if root.focus_mode == Control.FOCUS_ALL and root.is_visible_in_tree() and not (root is BaseButton and root.disabled):
		root.grab_focus()
		return true
	for child in root.get_children():
		if child is Control and _focus_first(child):
			return true
	return false


func overlay(screen: Control) -> void:
	if panel == screen:
		return
	context.push(panel, get_viewport().gui_get_focus_owner())
	open(screen)


func close_panel() -> void:
	var caller := context.pop() if context.valid(game.campaign.run) else {}
	if not caller.is_empty():
		var previous: Control = caller.get("panel")
		open(previous if is_instance_valid(previous) else null)
		_restore_focus.call_deferred(panel, caller.get("focus"))
	else:
		context.clear()
		open(null)
		# Required phases are re-hosted, including a save continued from title.
		if game.campaign.run != null and ChoiceScreen.handles(game.campaign.run.phase) and director == null:
			choice.bind(game, game.campaign.run)
			open(choice)
	_refresh_prompt()
	_refresh_objective()


func open_guild(id: String) -> void:
	if place != Place.GUILD or game.campaign.run != null or _mourning:
		return
	var screen: Control = _stations.get(id)
	if screen == null:
		return
	context.clear()
	screen.call("bind", game)
	open(screen)


func panel_open() -> bool:
	return panel != null and is_instance_valid(panel) and panel.visible


# ------------------------------------------------------------------ the loop

## The one place that decides where the player is and what they are looking
## at. Driven by GameRoot.run_changed, so a panel that applies an action
## re-hosts itself without knowing anything about the world behind it.
func _sync() -> void:
	if game.campaign == null or _mourning:
		return
	var run := game.campaign.run
	# Engine mutation precedes animation. Even death waits for its final beat.
	if director != null and not director.is_settled():
		return
	if panel != null and not context.valid(run):
		context.clear()
		open(null)
	if run == null:
		_enter_guild()
		return
	if run.is_over():
		_end_run()
		return
	_enter_dungeon(run)


func _enter_dungeon(run: RunState) -> void:
	if place != Place.DUNGEON:
		_leave_guild()
		place = Place.DUNGEON
		_built_floor = -1
		# A new descent names where it is arriving, even when that is the
		# biome the last one ended in.
		_announced_biome = ""
		place_changed.emit(place)
	if not run.nodes.is_empty() and (layout == null or _built_floor != run.floor):
		build_floor()
	if run.phase == "fight":
		if director == null:
			_stage_fight(run.node_index)
		return
	# A fight that has ended but is still settling keeps the screen. The run
	# leaves the fight phase on the frame the killing card is played, which
	# is before the blow has been animated; hosting the reward panel here
	# hid the fight HUD and then freed it mid-animation. `fight_finished`
	# calls back into `_sync` when the last event has played.
	if director != null and not director.is_settled():
		return
	if ChoiceScreen.handles(run.phase):
		# Includes "descent", which happens before there is a floor to stand
		# in: start_run leaves `nodes` empty until the last offer is taken.
		choice.lesson_settings = settings
		choice.lesson_settings_path = settings_path
		choice.bind(game, run)
		if context.callers.is_empty():
			open(choice)
		return
	if panel == null or not context.valid(run):
		close_panel()
	if layout == null or _built_floor != run.floor:
		build_floor()
	else:
		_close_room()


func build_floor() -> void:
	var run := game.campaign.run
	if run == null or run.nodes.is_empty():
		return
	if _world != null:
		# Renamed before it goes, because queue_free is deferred: for the rest
		# of this frame the old floor is still a child, and add_child would
		# rename the NEW one to dodge the collision, leaving get_node("World")
		# pointing at the floor that is on its way out.
		_world.name = "OldWorld"
		_world.queue_free()
	markers.clear()
	_signs.clear()
	_room_focus = null
	stairs = null

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	_map_marker = Vector2i(-1, -1)
	_focused_ghost_id = 0
	_dungeon_ghosts.clear()
	_ghost_signature = ""
	layout = RunEngine.layout_for(run)
	_built_floor = run.floor
	DungeonBuilder.build(layout, _world, run.biome().id)
	_world.add_child(Grade.world_environment(grade_depth(run.content, run.floor), run.biome().id))
	_dress()
	var arrival := layout.room_of_node(run.node_index) if run.phase in ["fight", "reward", "event", "shop", "rest"] else layout.entry_room
	_place_player(_stand_in(arrival), _open_facing(layout.room_center(arrival)))

	# Your dead are standing on the floor they died on, in the corridors you
	# walk back down. This is the pivot's first pillar (spec §2.1) and the
	# layout already emits the anchors, so it is nearly free.
	_place_ghosts(run)

	for i in run.nodes.size():
		var marker := EncounterMarker.create(i, layout.room_rect(layout.room_of_node(i)))
		marker.observe(run)
		marker.entered.connect(_on_marker_entered)
		_world.add_child(marker)
		markers.append(marker)
		_signs.append_array(RoomSigns.build(_world, layout, run, i))

	stairs = EncounterMarker.create(-1, layout.room_rect(layout.stairs_room))
	stairs.name = "Stairs"
	stairs.entered.connect(_on_stairs_entered)
	_world.add_child(stairs)
	_refresh_stairs()
	_refresh_marks()
	_refresh_objective()

	prompts.announce(floor_banner(run))
	print("crawl: floor %d, %d rooms, %d encounters left" % [run.floor, layout.rooms.size(), markers.size()])
	floor_built.emit(run.floor)


## What the banner says on arriving at this floor.
##
## The biome's name only where it is news: on the first floor of a run and on
## the floor a descent crosses into a different biome. "Floor 4 · The
## Catacombs" nine times in a row is noise, and the one time it matters -- the
## step out of the Catacombs and into the Deep -- would read as more of it.
func floor_banner(run: RunState) -> String:
	var here := run.biome()
	var tier := run.tier()
	# Past the first cycle the biome alone no longer says where you are: the
	# Catacombs at tier 3 and the Catacombs at tier 1 are the same walls and
	# nothing like the same fight. The tier goes on every banner down there.
	if tier > 1:
		_announced_biome = here.id
		return game.text("ui.run.floor_tier") \
			.replace("{floor}", str(run.floor)) \
			.replace("{biome}", game.text(here.name_key)) \
			.replace("{tier}", str(tier))
	if here.id == _announced_biome:
		return game.text("ui.run.floor").replace("{floor}", str(run.floor))
	_announced_biome = here.id
	return game.text("ui.run.floor_biome") \
		.replace("{floor}", str(run.floor)) \
		.replace("{biome}", game.text(here.name_key))


## The rule in force on this floor, spelled out, or "" on the first tier.
##
## Shown as the objective line rather than the banner: the banner fades, and a
## rule you have to play around for ten floors is not an announcement.
func mutation_line(run: RunState) -> String:
	var rule := run.mutation()
	if rule == null:
		return ""
	return game.text("ui.run.mutation") \
		.replace("{name}", game.text(rule.name_key)) \
		.replace("{text}", game.text(rule.text_key))


## How deep the room should look, 0..1.
##
## It cycles with the biomes rather than running off the end (§2). Floor 34 is
## the Catacombs again and the Catacombs are the same walls in every cycle;
## lighting them like the bottom of the Kiln would leave every floor past
## thirty the same colour, and the colour bands are the only thing on screen
## that says which biome you are standing in. What makes a tier different is
## its rule, not its light.
##
## Pure, so the rule can be checked without building a floor.
static func grade_depth(content: Content, floor: int) -> float:
	return Grade.depth_of(Biomes.in_tier(content, floor), Biomes.depth(content))


## Props against the walls. A boxy empty room reads as a prototype however
## good the lighting is.
func _dress() -> void:
	var run := game.campaign.run
	if layout.generator_version >= 2:
		RoomComposition.build(_world, layout, game.content)
		return
	# The entry room's centre is where you spawn, and a stairs room you cannot
	# cross is a floor you cannot leave.
	var keep_clear: Array = [layout.room_center(layout.entry_room), layout.room_center(layout.stairs_room)]
	for entry in Dressing.plan(layout, run.sub_rng("dressing", run.floor), keep_clear):
		var prop := Dressing.spawn(entry)
		if prop != null:
			_world.add_child(prop)


## Your dead stand on the floor they died on. Never in a room that still has
## an encounter in it: the ghost anchors are room centres and so is the fight
## staging, so a ghost would end up standing inside the thing you are fighting.
func _place_ghosts(run: RunState) -> void:
	var here := game.campaign.ladder.on_floor(run.floor)
	var signature := str(here.map(func(ghost: Ghost) -> Array:
		return [ghost.id, ghost.floor, ghost.name, ghost.kind, ghost.prepared, ghost.restless])) + str(run.resolved)
	if signature == _ghost_signature:
		return
	_ghost_signature = signature
	for figure in _dungeon_ghosts:
		if is_instance_valid(figure):
			figure.free()
	_dungeon_ghosts.clear()
	_focused_ghost_id = 0
	var taken: Dictionary = {}
	for i in run.nodes.size():
		if not run.is_resolved(i):
			taken[layout.room_of_node(i)] = true
	var free: Array = []
	for anchor in layout.ghost_anchors:
		var cell: Vector2i = anchor
		var busy := false
		for room in taken:
			if layout.room_center(int(room)) == cell:
				busy = true
				break
		if not busy:
			free.append(cell)
	for i in mini(here.size(), free.size()):
		var figure := GhostFigure.create(here[i], Kit.cell_to_world(free[i]))
		_world.add_child(figure)
		_dungeon_ghosts.append(figure)
		var area := Area3D.new()
		area.collision_layer = 8
		area.collision_mask = 0
		area.set_meta("ghost_id", here[i].id)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = GhostFigure.HEIGHT
		shape.shape = capsule
		shape.position.y = GhostFigure.HEIGHT * 0.5
		area.add_child(shape)
		figure.add_child(area)


func _on_marker_entered(index: int) -> void:
	var run := game.campaign.run
	if run == null or not run.phase in ["node", "exit"] or panel_open():
		return
	game.run_action({"kind": "enter", "index": index, "context": run.action_context()})


## The fight happens where you are standing. The camera does not cut away.
func _stage_fight(index: int) -> void:
	if director != null:
		director.queue_free()
	open(null)
	prompts.hush()
	director = FightDirector.new()
	director.name = "Fight"
	add_child(director)
	director.inspection_requested.connect(_inspect_pile)
	director.card_inspection_requested.connect(inspect_card)
	director.input_context_changed.connect(_apply_input_context)
	director.fight_finished.connect(_on_fight_finished, CONNECT_ONE_SHOT)
	director.begin(game, hud, player, _stand_in(layout.room_of_node(index)))
	_apply_input_context()


func _on_fight_finished() -> void:
	if director != null:
		director.queue_free()
		director = null
	_sync()


func _on_stairs_entered(_index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "exit" or panel_open():
		return
	exit_panel.bind(game, run)
	open(exit_panel)


## The panel applied the decision before it told anyone; this only takes the
## panel down.
##
## It used to apply the action a second time. For a watch or a retreat that was
## invisible -- the run was already over and `campaign.run` was already null, so
## the guard caught it -- but pushing to the next floor left the run in phase
## "node" and the second apply reached `push_error("expected enter, got push")`
## on every single descent. One owner per action: the screen that made the
## decision is the one that carries it, because it is also the only one that
## knows what was chosen with it.
func _on_exit_decided(_kind: String) -> void:
	if panel == exit_panel:
		close_panel()


## Marks every node the engine now considers resolved, and re-checks the
## stairs.
func _close_room() -> void:
	var run := game.campaign.run
	if run == null:
		return
	for m in markers:
		var marker: EncounterMarker = m
		marker.observe(run)
	for sign in _signs:
		RoomSigns.refresh(sign, run)
	_refresh_stairs()
	_refresh_marks()
	_refresh_objective()


func _refresh_stairs() -> void:
	if stairs == null:
		return
	var open_now := game.campaign.run != null and game.campaign.run.exit_ready()
	stairs.visible = true
	stairs.monitoring = open_now
	stairs._fired = false
	var glow := stairs.get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_energy = 0.8 if open_now else 0.2


# ----------------------------------------------------------------- the guild

func _enter_guild() -> void:
	if place == Place.GUILD and guild != null:
		return
	_leave_dungeon()
	place = Place.GUILD
	guild = GuildRoom.new()
	guild.name = "Guild"
	add_child(guild)
	guild.build(game.campaign)
	for s in guild.stations:
		var station: Interactable = s
		station.focused.connect(_on_station_focused)
		station.blurred.connect(_on_station_blurred)
		station.used.connect(_on_station_used)
	# Facing the well: it is the way down, the pitch image, and the only thing
	# in the room worth looking at first.
	var to_well := Kit.cell_to_world(GuildRoom.WELL_CELL) - guild.spawn_point()
	_place_player(guild.spawn_point(), atan2(-to_well.x, -to_well.z))
	close_panel()
	_refresh_marks()
	prompts.clear_objective()
	prompts.show_objective(game.text("ui.help.guild_hint").replace("{guild}", HelpPanel.binding("guild_menu"))
		.replace("{use}", HelpPanel.binding("interact")).replace("{back}", HelpPanel.binding("ui_cancel"))
		.replace("{help}", HelpPanel.binding("help")))
	place_changed.emit(place)


func _leave_guild() -> void:
	if guild == null:
		return
	guild.queue_free()
	guild = null
	focused = null


func _leave_dungeon() -> void:
	if director != null:
		director.queue_free()
		director = null
	if _world != null:
		_world.name = "OldWorld"
		_world.queue_free()
		_world = null
	markers.clear()
	_signs.clear()
	_room_focus = null
	stairs = null
	layout = null
	_built_floor = -1


## Both guarded against a guild that is on its way out. Descending frees the
## guild, and the Area3D the player was standing in emits body_exited AFTER
## that -- on the frame the player stops overlapping it -- so the handler runs
## with `guild` already null. It happens every single time you take the well
## down, which is why it is worth a guard rather than an assert.
func _on_station_focused(_id: String) -> void:
	_refocus()


func _on_station_blurred(_id: String) -> void:
	_refocus()


func _refocus() -> void:
	focused = null
	if guild != null and is_instance_valid(guild):
		for s in guild.stations:
			if (s as Interactable).focus:
				focused = s
	_refresh_prompt()


func _on_station_used(id: String) -> void:
	open_guild(id)


func _refresh_prompt() -> void:
	if panel_open() or focused == null:
		prompts.clear_prompt()
		return
	prompts.show_prompt(game.text(focused.label_key))


func _maybe_show_offline() -> void:
	if not OfflineSummary.should_show(game.offline):
		return
	if _offline_summary == null:
		_offline_summary = OfflineSummary.new()
		_offline_summary.dismissed.connect(close_panel)
		_host(_offline_summary)
	_offline_summary.bind(game.content, game.offline)
	overlay(_offline_summary)


# ------------------------------------------------------------------- the end

## A run that left a ghost earns the epitaph beat before the guild comes back.
## A retreat does not: nobody was left behind.
func _end_run() -> void:
	_mourning = true
	if director != null:
		director.queue_free()
		director = null
	var result := game.finish_run()
	_recap_result = result.duplicate(true)
	if EpitaphScreen.should_show(result):
		_raise_the_dead()
		epitaph.bind(game, result)
		open(epitaph)
		return
	_mourning = false
	_enter_guild()
	_show_recap()


## The hero rises where it fell, and the epitaph fades up over it. This is the
## shot the trailer opens on (spec §8), so it is a sequence with beats and not
## a screen swap: the world stays, the killer stays, and the thing that stands
## up is the ghost you will walk past on the way down next time.
func _raise_the_dead() -> void:
	if _world == null or player == null or game.campaign.ladder.ghosts.is_empty():
		return
	var newest: Ghost = game.campaign.ladder.ghosts[game.campaign.ladder.ghosts.size() - 1]
	var figure := GhostFigure.create(newest, player.global_position)
	_world.add_child(figure)
	figure.rise()
	# Keep the ghost at the fallen body's position and reveal it from a
	# short, collision-bounded camera retreat. A camera inside the shroud
	# otherwise fills the entire Watch result with its back faces.
	var from := player.camera.global_position
	var backward := player.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + backward * 2.4)
	query.collision_mask = DungeonBuilder.LAYER_WORLD
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var distance := 2.2 if hit.is_empty() else maxf(0, from.distance_to(hit["position"]) - 0.2)
	var reveal := epitaph.create_tween().set_parallel(true)
	var seconds := 0.0 if settings.reduced_motion else 0.6
	reveal.tween_property(player.camera, "position:z", distance, seconds)
	reveal.tween_property(player.camera, "rotation:x", -0.22, seconds)


func _on_epitaph_dismissed() -> void:
	_mourning = false
	open(null)
	_enter_guild()
	_show_recap()


# ------------------------------------------------------------------ plumbing

func _place_player(at: Vector3, yaw: float = 0.0) -> void:
	if player == null:
		player = Player.new()
		player.name = "Player"
		# The body counts its own footfalls; what one sounds like is the
		# HUD-side decision, so the wire is made here rather than in Player.
		if game != null and game.sfx != null:
			player.footfall.connect(game.sfx.step)
		add_child(player)
	player.place_at(at, yaw)


## Which way to face on arrival: down the longest open run from where you are
## standing. Spawning nose-to-the-wall is the first thing the player sees and
## it reads as the game being broken before they have taken a step.
func _open_facing(cell: Vector2i) -> float:
	var best := 0.0
	var best_run := -1
	var steps: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for step in steps:
		var run := 0
		var at := cell + step
		while layout.is_walkable(at.x, at.y) and run < 40:
			run += 1
			at += step
		if run > best_run:
			best_run = run
			# Godot yaw 0 looks down -Z, and +Y turns left.
			best = atan2(float(-step.x), float(-step.y))
	return best


## The centre of a room, on the floor. Room centres are always carved, so this
## is always somewhere you can stand.
func _stand_in(room_index: int) -> Vector3:
	return Kit.cell_to_world(layout.room_center(room_index))


## The reticle opens on anything you could act on: a station in the guild, a
## room you have not cleared, the stairs once they are open.
func _process(_delta: float) -> void:
	if _exploring():
		_focus_room()
		if _room_focus == null and not _room_hint:
			_focus_ghost()
	if player != null and compass != null and compass.visible:
		compass.look(player.global_position, player.rotation.y)
	if crosshair == null or not crosshair.visible:
		return
	crosshair.set_target(focused != null or _focused_ghost_id > 0 or _looking_at_a_door())


## What still wants something from you, as compass marks. The stairs only
## appear once they can actually be used: a mark pointing at a locked door is
## a mark that lies.
func _refresh_marks() -> void:
	if compass == null:
		return
	var out: Array = []
	if place == Place.GUILD and guild != null:
		for station in guild.stations:
			out.append({"at": (station as Interactable).position, "kind": "ghost"})
		compass.set_marks(out)
		return
	var run := game.campaign.run
	if run == null or layout == null:
		compass.set_marks([])
		return
	for i in run.nodes.size():
		if run.can_enter(i):
			out.append({"at": Kit.cell_to_world(layout.room_center(layout.room_of_node(i))), "kind": String(run.nodes[i]["kind"])})
	out.append({"at": Kit.cell_to_world(layout.room_center(layout.stairs_room)), "kind": "stairs"})
	if _map_marker.x >= 0:
		out.append({"at": Kit.cell_to_world(_map_marker), "kind": "marker"})
	compass.set_marks(out)


## The one line that says what the floor still wants. Without it the compass
## shows marks and never says what they are.
func _refresh_objective() -> void:
	if prompts == null or place != Place.DUNGEON:
		return
	var run := game.campaign.run
	if run == null:
		return
	prompts.show_rule(mutation_line(run))
	prompts.show_objective(RoomPresentation.stairs_text(run))


func _looking_at_a_door() -> bool:
	if player == null or player.camera == null or place != Place.DUNGEON:
		return false
	var space := get_world_3d().direct_space_state
	var from := player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_transform.basis.z * 6.0)
	query.collision_mask = EncounterMarker.LAYER_INTERACTABLE
	return not space.intersect_ray(query).is_empty()


func _input(event: InputEvent) -> void:
	# Keys that belong to the coordinator are consumed before hidden controls
	# or the player see them. Ordinary focus/activation remains GUI-owned.
	if event is InputEventKey and not event.is_echo():
		_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or game == null or hud == null:
		return
	var handled := true
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2 and teaching.visible:
		_dismiss_lesson(teaching.lesson)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2 and panel == choice and choice.lesson != null and choice.lesson.visible:
		choice.lesson.dismissed.emit(choice.lesson.lesson)
	elif event.is_action_pressed("ui_cancel"):
		if panel == title:
			pass
		elif panel == null and director != null and director.cancel_selection():
			pass
		elif panel == choice and not choice.selected.is_empty():
			choice.cancel_selection()
		elif panel == choice and game.campaign.run != null and game.campaign.run.phase == "shop":
			game.run_action({"kind": "leave", "context": game.campaign.run.action_context()})
		elif panel == null or not _can_close(panel):
			_open_pause()
		else:
			close_panel()
	elif event.is_action_pressed("help"):
		if panel == help:
			close_panel()
		else:
			help.build(game.content, place == Place.GUILD, _exploring())
			overlay(help)
	elif event.is_action_pressed("guild_menu"):
		if nav.visible:
			close_panel()
		elif _exploring() and place == Place.GUILD:
			open_guild(nav.last_tab)
	elif event.is_action_pressed("inspect_hero"):
		if _exploring():
			var hero: Control = _stations[GuildRoom.DESK]
			hero.call("bind", game)
			overlay(hero)
	elif event.is_action_pressed("floor_map"):
		if panel == floor_map:
			close_panel()
		else:
			_open_map()
	elif event.is_action_pressed("interact"):
		if _exploring():
			if _room_focus != null:
				_room_focus.engage()
			elif _focused_ghost_id > 0:
				inspect_ghost(_focused_ghost_id)
			elif focused != null:
				focused.use()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _exploring() -> bool:
	return game != null and game.campaign != null and panel == null and director == null and not _mourning and (game.campaign.run == null or game.campaign.run.phase in ["node", "exit"])


## A run's phase panels cannot be walked away from -- leaving a reward
## unchosen would strand the run in a phase with nothing to do -- but pausing
## over them is always allowed, which is what the pause branch above is for.
func _can_close(screen: Control) -> bool:
	return screen != choice and screen != exit_panel and screen != epitaph and screen != title


## Leaving the title is the moment the game actually begins: the offline
## summary belongs here, not on boot, or it fires behind the menu.
func _leave_title() -> void:
	close_panel()
	_maybe_show_offline()


## A new guild throws the campaign away and starts one. Destructive, so it is
## only reachable from the title -- never from the pause menu, where a
## mis-click would cost a player their whole ladder.
func _start_new_guild() -> void:
	if game.save_blocked:
		var number := 1
		while SaveGame.exists(SaveGame.slot_path("new_%d" % number)):
			number += 1
		settings.active_slot = "new_%d" % number
		game.save_path = SaveGame.slot_path(settings.active_slot)
		game.save_blocked = false
		settings.save(settings_path)
	context.clear()
	open(null)
	game.campaign = CampaignEngine.new_campaign(game.content, game.now(), game.now())
	place = Place.NONE
	_leave_dungeon()
	_leave_guild()
	game.save()
	_sync()


func _open_pause() -> void:
	pause.build(game.content, game.campaign != null and game.campaign.run != null)
	overlay(pause)


func _open_options() -> void:
	options.build(game.content, settings)
	overlay(options)


func _on_settings_changed(s: Settings) -> void:
	s.apply(player)
	hud.ui_scale = s.ui_scale
	hud.fit(get_viewport().get_visible_rect().size)
	s.save(settings_path)
	# A language change reloads the content underneath everything, so the
	# menu that asked for it has to be rebuilt in the language it asked for.
	if game.content != null and game.content.locale != s.locale:
		var previous := game.content
		if game.set_locale(s.locale):
			_translate_labels(hud.ui, previous, game.content)
			options.build(game.content, s)
			if director != null:
				director.refresh()
			if choice.run != null and ChoiceScreen.handles(choice.run.phase):
				choice.refresh()
			if ghost_detail.campaign != null:
				ghost_detail.refresh()
			prompts.clear_objective()
			prompts.clear_rule()


## Static captions stay on their existing controls, retaining scroll/focus.
## Dynamic record values are refreshed by the panels' campaign signals.
func _translate_labels(node: Node, previous: Content, current: Content) -> void:
	for property in (["text", "tooltip_text"] if node is Label or node is BaseButton else (["tooltip_text"] if node is Control else [])):
		var value := String(node.get(property))
		if value.is_empty():
			continue
		for key in previous.strings:
			if value == previous.strings[key]:
				node.set(property, current.text(key))
				break
	for child in node.get_children():
		_translate_labels(child, previous, current)


## Giving up goes through RunEngine like everything else. The engine ends it
## as a retreat from whatever phase you were in, including mid-fight.
func _abandon_run() -> void:
	context.clear()
	if director != null:
		director.queue_free()
		director = null
	open(null)
	var run := game.campaign.run
	if run == null or run.is_over():
		return
	game.run_action({"kind": "abandon"})
	_sync()


func _quit() -> void:
	if game != null and game.is_booted:
		game.save()
		if game.sfx != null:
			game.sfx.release()
	quit_action.call()


## The quit path used to live on MainScreen, which the pivot stopped booting.
## Without this the game does not save when you close the window, and the
## looping ambience is still playing when the tree comes down -- which is what
## the two leaked AudioStream instances at exit were.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not manages_quit:
		return
	if game != null and game.is_booted:
		game.save()
		if game.sfx != null:
			game.sfx.release()
	quit_action.call()


func _inspect_pile(pile: String) -> void:
	if panel != null or director == null or director.fight() == null:
		return
	var fight := director.fight()
	var cards: Array[CardInstance] = []
	match pile:
		"draw": cards = fight.draw_pile
		"discard": cards = fight.discard_pile
		"deck": cards = game.campaign.run.hero.deck
		"hand": cards = fight.hand
	inspector.build(game.content, cards, "ui.inspect." + pile, fight)
	overlay(inspector)


func inspect_card(card: CardInstance) -> void:
	inspector.build(game.content, [card] as Array[CardInstance], "ui.inspect.card", director.fight() if director != null else null, game.campaign.run.hero_snapshot().stats if game.campaign.run != null else game.campaign.hero.stats)
	overlay(inspector)


func _inspect_run_deck() -> void:
	if game.campaign.run == null:
		return
	inspector.build(game.content, game.campaign.run.hero.deck, "ui.inspect.deck", null, game.campaign.run.hero_snapshot().stats)
	overlay(inspector)


func inspect_ghost(id: int) -> void:
	var ghost := game.campaign.ladder.find(id)
	if ghost == null:
		return
	ghost_detail.bind(game.campaign, id)
	var ladder: LadderScreen = _stations[GuildRoom.WELL]
	if ladder.game == null:
		ladder.bind(game)
	ladder.select_floor(ghost.floor)
	_select_floor(ghost.floor)
	overlay(ghost_detail)


func _select_floor(floor: int) -> void:
	if guild != null:
		guild.well.select_floor(floor)


func _refresh_ghosts() -> void:
	if guild != null:
		guild.well.refresh(game.campaign)
		guild.refresh_history(game.campaign)
	if panel == ghost_detail:
		ghost_detail.refresh()
	if place == Place.DUNGEON and game.campaign.run != null and is_instance_valid(_world):
		_place_ghosts(game.campaign.run)


func _focus_ghost() -> void:
	if player == null or player.camera == null or place != Place.DUNGEON:
		return
	var from := player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 3.5)
	query.collision_mask = 8 | DungeonBuilder.LAYER_WORLD
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var id := 0
	if not hit.is_empty():
		id = int(hit["collider"].get_meta("ghost_id", 0))
	if id != _focused_ghost_id:
		_focused_ghost_id = id
		if id > 0:
			var ghost := game.campaign.ladder.find(id)
			prompts.show_prompt(HelpPanel.binding("interact") + " · " + ghost.name + " · " + game.text("ui.inspect.ghost"))
		else:
			_refresh_prompt()


func _open_campaigns() -> void:
	campaign_menu.build(game.content, SaveGame.slots(game.content, game.save_path.get_base_dir()), game.save_path)
	overlay(campaign_menu)


func _import_campaign(source: String) -> void:
	var result := game.import_campaign(source)
	if bool(result["ok"]):
		campaign_menu.build(game.content, SaveGame.slots(game.content, game.save_path.get_base_dir()), game.save_path)
		campaign_menu.message.text = game.text("ui.saves.imported").replace("{name}", result["name"]).replace("{slot}", result["slot"])
		if result.get("recovered", "") != "":
			campaign_menu.message.text += "\n" + game.text("ui.saves.recovered")
	else:
		campaign_menu.message.text = game.text("ui.saves." + String(result["reason"]))


func _continue_campaign(path: String) -> void:
	var result := game.continue_slot(path)
	if not result["ok"]:
		campaign_menu.message.text = game.text("ui.saves." + String(result["reason"]))
		return
	settings.active_slot = path.get_file().get_basename()
	settings.save(settings_path)
	context.clear()
	_mourning = false
	_leave_dungeon()
	_leave_guild()
	place = Place.NONE
	open(null)
	_sync()
	settings.apply(player)
	_maybe_show_offline()


func _open_map() -> void:
	if _exploring() and place == Place.DUNGEON and layout != null:
		floor_map.bind(layout, game.campaign.run, player.global_position, player.rotation.y)
		overlay(floor_map)


func _focus_room() -> void:
	if _room_hint or _room_focus != null:
		_refresh_prompt()
		_focused_ghost_id = -1
	_room_focus = null
	_room_hint = false
	if place != Place.DUNGEON or game.campaign.run == null:
		return
	var nearest := INF
	for marker in markers:
		if marker.deliberate and marker.nearby and marker.available:
			if marker.kind == "shop" and player.global_position.distance_to(Kit.cell_to_world(RoomSigns.service_cell(layout, layout.room_of_node(marker.index)))) > 2.8:
				continue
			var distance := player.global_position.distance_to(marker.global_position)
			if distance < nearest:
				nearest = distance
				_room_focus = marker
	if _room_focus != null:
		_focused_ghost_id = 0
		prompts.show_prompt(game.text("room.engage").replace("{room}", RoomPresentation.describe(game.campaign.run, _room_focus.index)))
	else:
		# A doorway warning is readable outside the automatic encounter volume.
		for sign in _signs:
			if player.global_position.distance_to((sign as Node3D).global_position) < 5.0:
				var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position, (sign as Node3D).global_position)
				ray.collision_mask = DungeonBuilder.LAYER_WORLD
				if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					continue
				prompts.show_prompt(RoomPresentation.describe(game.campaign.run, int(sign.get_meta("node_index"))))
				_room_hint = true
				return


func _refresh_teaching() -> void:
	if teaching == null or settings == null or game == null or game.campaign == null:
		return
	teaching.hide()
	if panel != null:
		return
	var id := ""
	if director != null:
		id = "combat"
	elif place == Place.DUNGEON and game.campaign.run != null and game.campaign.run.floor == 1:
		id = "rooms"
	elif place == Place.GUILD and game.campaign.onboarding.first_death_seen:
		id = "ghost"
	if id != "" and not settings.dismissed_lessons.has(id):
		var compact := id == "combat" and hud.ui.size.y < 300
		teaching.position = Vector2(hud.ui.size.x - 80, 62) if compact else Vector2(8, 76)
		teaching.present(game.content, id, compact)


func _dismiss_lesson(id: String) -> void:
	if not settings.dismissed_lessons.has(id):
		settings.dismissed_lessons.append(id)
		settings.save(settings_path)
	teaching.hide()


func _show_recap() -> void:
	if _recap_result.is_empty():
		return
	recap.build(game.campaign, _recap_result)
	_recap_result = {}
	overlay(recap)
