class_name TestFixtures
extends RefCounted
## Builders for engine tests. Uses the real slice content so tests exercise
## the same data the game ships.

static var _content: Content


static func content() -> Content:
	if _content == null:
		_content = Content.load_from("res://data")
	return _content


static func bare_state(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1) -> FightState:
	var s := FightState.new()
	s.content = content()
	s.rng = Rng.new(seed)
	s.floor = floor
	s.hero_hp = 70
	s.hero_max_hp = 70
	s.energy = 3
	s.max_energy = 3
	s.draw_per_turn = 5
	for enemy_id in enemy_ids:
		var def: EnemyDef = content().enemies[String(enemy_id)]
		var e := EnemyState.new()
		e.def_id = String(enemy_id)
		e.max_hp = Scaling.enemy_hp(def.hp, floor, content().balance)
		e.hp = e.max_hp
		s.enemies.append(e)
	return s


static func give_hand(s: FightState, card_ids: Array, upgraded: bool = false) -> void:
	s.hand.clear()
	for id in card_ids:
		s.hand.append(s.new_card(String(id), upgraded))


static func fill_draw(s: FightState, card_ids: Array) -> void:
	s.draw_pile.clear()
	for id in card_ids:
		s.draw_pile.append(s.new_card(String(id)))


static func events_of(s: FightState, type: String) -> Array:
	var out: Array = []
	for ev in s.events:
		if ev["type"] == type:
			out.append(ev)
	return out


static func hero(hero_name: String = "Tester") -> Hero:
	return Hero.create(content(), "sexton", hero_name)


static func new_run(entry_floor: int = 1, run_seed: int = 1, watch_unlocked: bool = true, h: Hero = null) -> RunState:
	var the_hero := h if h != null else hero()
	return RunEngine.start_run(content(), the_hero, entry_floor, run_seed, watch_unlocked)


static func autofight(run: RunState) -> void:
	var ap := Autopilot.new()
	var guard := 0
	while run.phase == "fight" and guard < 200:
		guard += 1
		for action in ap.choose_turn(run.fight):
			if run.phase != "fight":
				break
			RunEngine.apply(run, action)


static func set_nodes(run: RunState, nodes: Array) -> void:
	run.nodes = nodes
	run.node_index = 0
	run.resolved = []
	run.phase = "node"


static func run_events_of(run: RunState, type: String) -> Array:
	var out: Array = []
	for ev in run.events:
		if ev["type"] == type:
			out.append(ev)
	return out


static func campaign(campaign_seed: int = 1, now: int = 1000) -> Campaign:
	var c := CampaignEngine.new_campaign(content(), campaign_seed, now)
	c.sim_fights = 4
	return c


static func die_on_floor(c: Campaign, floor: int, now: int) -> Dictionary:
	var run := CampaignEngine.start_run(c, 1, now)
	run.floor = floor
	run.hero.hp = 1
	set_nodes(run, [{"kind": "fight", "enemies": ["shambler", "shambler", "shambler"]}])
	RunEngine.apply(run, {"kind": "enter"})
	autofight(run)
	return CampaignEngine.finish_run(c, now)


static func end_at_exit(c: Campaign, floor: int, choice: String, now: int) -> Dictionary:
	var run := CampaignEngine.start_run(c, 1, now)
	run.floor = floor
	run.watch_unlocked = true
	set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": choice})
	return CampaignEngine.finish_run(c, now)


static func campaign_events_of(c: Campaign, type: String) -> Array:
	var out: Array = []
	for ev in c.events:
		if ev["type"] == type:
			out.append(ev)
	return out
