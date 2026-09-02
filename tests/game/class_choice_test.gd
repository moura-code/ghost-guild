extends GdUnitTestSuite
## Choosing who goes down (spec §3.4).
##
## The gate is a hero who has never descended. Every death hands you a fresh
## one, so every death is a class choice -- and nobody swaps class halfway
## through a campaign to dodge a matchup, because by then the hero has a deck
## that was built rather than dealt.

const TMP := "user://test_saves/class_choice_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 2
	return g


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _screen(g: GameRoot) -> HeroScreen:
	var s: HeroScreen = auto_free(HeroScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func _claim_the_deep(g: GameRoot) -> void:
	var walker := Hero.create(g.content, "sexton", "Deepwalker", {}, 1)
	g.campaign.ladder.add(Ghost.from_expedition(walker, 14, 0))


# -------------------------------------------------------------- the engine

func test_a_new_hero_keeps_the_class_that_just_died() -> void:
	var g := _game()
	_claim_the_deep(g)
	CampaignEngine.new_hero(g.campaign, 1000, "hexer")
	assert_str(g.campaign.hero.class_id).is_equal("hexer")
	CampaignEngine.new_hero(g.campaign, 1000)
	assert_str(g.campaign.hero.class_id).override_failure_message(
		"dying cost the player their class").is_equal("hexer")


func test_a_locked_class_is_refused_rather_than_honoured() -> void:
	# The one place this could be exploited is a hand-edited save.
	var g := _game()
	CampaignEngine.new_hero(g.campaign, 1000, "hexer")
	assert_str(g.campaign.hero.class_id).is_equal(Classes.starting(g.content))


func test_the_new_hero_carries_that_class_deck_and_relic() -> void:
	var g := _game()
	_claim_the_deep(g)
	CampaignEngine.new_hero(g.campaign, 1000, "hexer")
	var hexer: ClassDef = g.content.classes["hexer"]
	assert_int(g.campaign.hero.deck.size()).is_equal(hexer.starting_deck.size())
	assert_array(g.campaign.hero.relics).contains([hexer.relic])
	assert_int(g.campaign.hero.max_hp).is_less(g.content.classes["sexton"].base_hp)


# ---------------------------------------------------------------- the wire

func test_choosing_a_class_goes_through_the_one_channel() -> void:
	var g := _game()
	_claim_the_deep(g)
	var seen := [0]
	g.hero_changed.connect(func() -> void: seen[0] += 1)
	assert_bool(bool(g.choose_class("hexer")["ok"])).is_true()
	assert_str(g.campaign.hero.class_id).is_equal("hexer")
	assert_int(seen[0]).is_greater(0)
	var back := SaveGame.load_campaign(g.content, TMP)
	assert_str(back.hero.class_id).override_failure_message(
		"the choice was not saved").is_equal("hexer")


func test_a_hero_who_has_already_descended_is_committed() -> void:
	var g := _game()
	_claim_the_deep(g)
	g.campaign.hero.runs = 1
	var r := g.choose_class("hexer")
	assert_bool(bool(r["ok"])).is_false()
	assert_str(String(r["reason"])).is_equal("committed")
	assert_str(g.campaign.hero.class_id).is_equal(Classes.starting(g.content))


func test_a_locked_class_cannot_be_chosen() -> void:
	var g := _game()
	var r := g.choose_class("hexer")
	assert_bool(bool(r["ok"])).is_false()
	assert_str(String(r["reason"])).is_equal("locked")


func test_choosing_the_class_you_already_are_changes_nothing() -> void:
	var g := _game()
	var before := g.campaign.hero.id
	assert_bool(bool(g.choose_class(Classes.starting(g.content))["ok"])).is_false()
	assert_int(g.campaign.hero.id).is_equal(before)


# --------------------------------------------------------------- the screen

func test_the_sheet_offers_every_class_including_the_locked_ones() -> void:
	# A class you cannot pick yet, with the reason beside it, is the whole
	# point of an unlock. Hiding it hides the reward.
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_int(s.class_rows.size()).is_equal(g.content.classes.size())
	assert_bool((s.class_rows["hexer"] as Button).disabled).is_true()
	assert_str((s.class_rows["hexer"] as Button).tooltip_text) \
		.contains(g.text("biome.fungal_deep.name"))


func test_claiming_the_deep_opens_the_hexer_on_the_sheet() -> void:
	var g := _game()
	var s := _screen(g)
	_claim_the_deep(g)
	s.refresh()
	await await_idle_frame()
	assert_bool((s.class_rows["hexer"] as Button).disabled).is_false()


func test_pressing_it_changes_who_you_are() -> void:
	var g := _game()
	var s := _screen(g)
	_claim_the_deep(g)
	s.refresh()
	(s.class_rows["hexer"] as Button).pressed.emit()
	await await_idle_frame()
	assert_str(g.campaign.hero.class_id).is_equal("hexer")
	assert_str(s._class.text).is_equal(g.text("class.hexer.name"))


func test_the_choice_closes_once_the_hero_has_descended() -> void:
	var g := _game()
	var s := _screen(g)
	_claim_the_deep(g)
	g.campaign.hero.runs = 1
	s.refresh()
	await await_idle_frame()
	for id in s.class_rows:
		assert_bool((s.class_rows[id] as Button).disabled).override_failure_message(
			"%s is still offered to a hero who has already gone down" % id).is_true()
