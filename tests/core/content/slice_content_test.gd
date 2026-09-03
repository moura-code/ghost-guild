extends GdUnitTestSuite


func test_slice_content_is_valid() -> void:
	var c := Content.load_from("res://data")
	var errors := ContentValidator.validate(c)
	assert_array(errors).is_empty()


func test_slice_content_volume() -> void:
	var c := Content.load_from("res://data")
	# The slice was one biome's worth of everything (spec §7). M2 is growing
	# toward the launch volume -- ~100 cards, 30 enemies, 3 biomes -- so these
	# are floors rather than equalities: they still catch a data file that
	# failed to load, which is what they were actually guarding.
	assert_int(c.cards.size()).is_greater_equal(30)
	assert_int(c.enemies.size()).is_greater_equal(10)
	assert_int(c.relics.size()).is_greater_equal(6)
	assert_int(c.classes.size()).is_greater_equal(1)
	assert_int(c.biomes.size()).is_greater_equal(1)
	assert_int(c.events.size()).is_equal(3)
	# The M1 slice shipped ten upgrade nodes (spec §7). M2 is growing toward
	# the forty at launch, so this is a floor rather than an equality: it
	# still catches a data file that failed to load, which is what it was
	# actually guarding.
	assert_int(c.upgrades.size()).is_greater_equal(10)
	# Twelve priority rules (spec §7), all in the Descent-era content.
	assert_int(c.rules.size()).is_equal(12)
	# Every class opens with ten cards and its own relic (spec §3.4), whatever
	# else it is. A class with nine is a class that draws a different opening
	# hand to every other one.
	for id in c.classes:
		var klass: ClassDef = c.classes[id]
		assert_array(klass.starting_deck).override_failure_message(
			"%s does not open with ten cards" % id).has_size(10)
		assert_bool(c.relics.has(klass.relic)).override_failure_message(
			"%s's relic '%s' does not exist" % [id, klass.relic]).is_true()
		for card_id in klass.starting_deck:
			var card: CardDef = c.cards.get(card_id)
			assert_object(card).override_failure_message(
				"%s opens with '%s', which is not a card" % [id, card_id]).is_not_null()
			assert_str(card.pool).override_failure_message(
				"%s opens with %s, which is in the %s pool" % [id, card_id, card.pool]) 				.is_equal(klass.pool)
	var elites := 0
	var bosses := 0
	for id in c.enemies:
		var e: EnemyDef = c.enemies[id]
		if e.kind == "elite":
			elites += 1
		elif e.kind == "boss":
			bosses += 1
	# One of each per biome (spec §2: the last node of every tenth floor is
	# the biome boss), so these track the biome count rather than a constant.
	assert_int(elites).is_greater_equal(c.biomes.size())
	assert_int(bosses).is_equal(c.biomes.size())


func test_every_upgrade_group_the_spec_names_has_something_in_it() -> void:
	# A group with no nodes is a tab in the guild panel that opens on nothing.
	var c := Content.load_from("res://data")
	var groups: Dictionary = {}
	for id in c.upgrades:
		var def: UpgradeDef = c.upgrades[id]
		groups[def.group] = int(groups.get(def.group, 0)) + 1
	for group in ContentValidator.UPGRADE_GROUPS:
		if group == "seance":
			# Séance upgrades are M2 work that has not landed yet (spec §5.9).
			continue
		assert_int(int(groups.get(group, 0))) 			.override_failure_message("upgrade group '%s' is empty" % group).is_greater(0)


## A card whose pool nothing draws from is a card that cannot be found.
func test_every_card_belongs_to_a_pool_something_draws_from() -> void:
	var c := Content.load_from("res://data")
	var pools: Array[String] = []
	for id in c.classes:
		pools.append((c.classes[id] as ClassDef).pool)
	for id in c.biomes:
		pools.append((c.biomes[id] as BiomeDef).card_pool)
	for id in c.cards:
		var card: CardDef = c.cards[id]
		assert_bool(pools.has(card.pool)).override_failure_message(
			"card %s has pool %s, which nothing draws from" % [id, card.pool]).is_true()


## Every biome has an elite table and a boss (spec §2), or its tenth floor
## generates a node it cannot fill.
func test_every_biome_can_finish_itself() -> void:
	var c := Content.load_from("res://data")
	for id in c.biomes:
		var b: BiomeDef = c.biomes[id]
		assert_array(b.elites).override_failure_message("%s has no elites" % id).is_not_empty()
		assert_array(b.boss).override_failure_message("%s has no boss" % id).is_not_empty()
		assert_array(b.encounters).override_failure_message("%s has no encounters" % id).is_not_empty()
		assert_array(b.node_patterns).override_failure_message("%s has no patterns" % id).is_not_empty()


## Every string key the shipped content names resolves to a string.
##
## An unresolved key is not an error anywhere -- `Content.text` returns the key
## itself, so the game renders `ui.group.descent` in a heading and keeps
## running. That shipped once, in a section title, and was only caught by
## looking at a screenshot.
func test_every_key_the_content_names_resolves() -> void:
	var c := Content.load_from("res://data")
	var missing: Array[String] = []
	var check := func(key: String) -> void:
		if key != "" and not c.strings.has(key):
			missing.append(key)
	for table in [c.cards, c.enemies, c.relics, c.classes, c.biomes, c.events,
			c.rules, c.upgrades, c.mutations]:
		for id in table:
			var def: Variant = table[id]
			check.call(String(def.get("name_key")))
			if def.get("text_key") != null:
				check.call(String(def.get("text_key")))
	# Upgrade groups are named by the data and titled by the UI, so a new
	# group arrives with no heading and nothing complains.
	for id in c.upgrades:
		check.call("ui.group.%s" % (c.upgrades[id] as UpgradeDef).group)
	assert_array(missing).override_failure_message(
		"unresolved string keys: %s" % ", ".join(missing)).is_empty()
