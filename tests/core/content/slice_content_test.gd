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
	assert_int(c.upgrades.size()).is_equal(10)
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


func test_every_card_belongs_to_a_known_pool() -> void:
	var c := Content.load_from("res://data")
	for id in c.cards:
		var card: CardDef = c.cards[id]
		assert_bool(card.pool == "sexton" or card.pool == "catacombs").override_failure_message("card %s has pool %s" % [id, card.pool]).is_true()
