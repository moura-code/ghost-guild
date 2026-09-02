extends GdUnitTestSuite


func test_slice_content_is_valid() -> void:
	var c := Content.load_from("res://data")
	var errors := ContentValidator.validate(c)
	assert_array(errors).is_empty()


func test_slice_content_volume() -> void:
	var c := Content.load_from("res://data")
	assert_int(c.cards.size()).is_equal(30)
	assert_int(c.enemies.size()).is_equal(10)
	assert_int(c.relics.size()).is_equal(6)
	assert_int(c.classes.size()).is_equal(1)
	assert_int(c.biomes.size()).is_equal(1)
	assert_int(c.events.size()).is_equal(3)
	# The M1 slice shipped ten upgrade nodes (spec §7). M2 is growing toward
	# the forty at launch, so this is a floor rather than an equality: it
	# still catches a data file that failed to load, which is what it was
	# actually guarding.
	assert_int(c.upgrades.size()).is_greater_equal(10)
	# Twelve priority rules (spec §7), all in the Descent-era content.
	assert_int(c.rules.size()).is_equal(12)
	var sexton: ClassDef = c.classes["sexton"]
	assert_array(sexton.starting_deck).has_size(10)
	var elites := 0
	var bosses := 0
	for id in c.enemies:
		var e: EnemyDef = c.enemies[id]
		if e.kind == "elite":
			elites += 1
		elif e.kind == "boss":
			bosses += 1
	assert_int(elites).is_equal(1)
	assert_int(bosses).is_equal(1)


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


func test_every_card_belongs_to_a_known_pool() -> void:
	var c := Content.load_from("res://data")
	for id in c.cards:
		var card: CardDef = c.cards[id]
		assert_bool(card.pool == "sexton" or card.pool == "catacombs").override_failure_message("card %s has pool %s" % [id, card.pool]).is_true()


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
			c.rules, c.upgrades]:
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
