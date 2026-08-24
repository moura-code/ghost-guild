class_name FightScreen
extends VBoxContainer
## The fight (spec §9): enemies across the top with their telegraphed
## intents, the hero's vitals in the middle, the hand along the bottom.
##
## Targeting is two clicks: pick a card, then pick an enemy. Cards that
## target the hero resolve on the first click. Playability comes from
## CombatEngine.legal_actions, so the screen can never offer a move the
## engine would refuse.

signal fight_ended()

var game: GameRoot
var run: RunState
var selected_index: int = -1

var _enemy_row: HBoxContainer
var _hand_row: HBoxContainer
var _vitals: Label
var _piles: Label
var _prompt: Label
var _end_turn: Button
var _enemy_views: Array[EnemyView] = []
var _card_views: Array[CardView] = []
var _playable: Dictionary = {}
var _animator: FightAnimator
var _shake_tween: Tween


func _init() -> void:
	add_theme_constant_override("separation", 10)


func bind(g: GameRoot, p_run: RunState) -> void:
	game = g
	run = p_run
	if _enemy_row == null:
		_build()
	_animator.bind(g.content)
	refresh()


func _build() -> void:
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 10)
	add_child(_enemy_row)

	_vitals = UiTheme.number("", Palette.BONE)
	add_child(_vitals)

	_piles = UiTheme.small("", Palette.BONE_FAINT)
	add_child(_piles)

	_prompt = UiTheme.body("", Palette.SOUL)
	add_child(_prompt)

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	_hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_hand_row)

	_end_turn = Button.new()
	_end_turn.pressed.connect(_on_end_turn)
	add_child(_end_turn)

	# Overlay: it draws above the fight and never eats a click.
	_animator = FightAnimator.new()
	_animator.shake_requested.connect(_shake)
	add_child(_animator)


func refresh() -> void:
	if game == null or run == null or run.fight == null:
		return
	var fight := run.fight
	_recompute_playable(fight)
	_refresh_enemies(fight)
	_refresh_vitals(fight)
	_refresh_hand(fight)
	_end_turn.text = game.text("ui.fight.end_turn")
	_end_turn.disabled = fight.is_over()
	_refresh_prompt(fight)


## The engine is the authority on what can be played; the screen only
## mirrors it. Keys are hand indices, values are whether that card needs
## an enemy chosen.
func _recompute_playable(fight: FightState) -> void:
	_playable.clear()
	for action in CombatEngine.legal_actions(fight):
		if String(action.get("kind", "")) != "play":
			continue
		var index := int(action["hand_index"])
		var needs_target := int(action.get("target", -1)) >= 0
		_playable[index] = bool(_playable.get(index, false)) or needs_target


## Views are pooled, never churned: the hand changes size every time a card
## is played, and creating a node per refresh leaks hundreds of orphans
## across a single run. Spare slots are hidden, not freed.
func _refresh_enemies(fight: FightState) -> void:
	while _enemy_views.size() < fight.enemies.size():
		var view := EnemyView.new()
		view.pressed.connect(_on_enemy_pressed)
		_enemy_row.add_child(view)
		_enemy_views.append(view)
	var targeting := selected_index >= 0 and bool(_playable.get(selected_index, false))
	for i in _enemy_views.size():
		var used := i < fight.enemies.size()
		_enemy_views[i].visible = used
		if used:
			_enemy_views[i].bind(fight, i, targeting and fight.enemies[i].alive)


func _refresh_vitals(fight: FightState) -> void:
	var bits := PackedStringArray()
	bits.append("%s %d/%d" % [game.text("ui.hp"), fight.hero_hp, fight.hero_max_hp])
	if fight.hero_block > 0:
		bits.append("%s %d" % [game.text("ui.fight.block"), fight.hero_block])
	bits.append("%s %d/%d" % [game.text("ui.fight.energy"), fight.energy, fight.max_energy])
	bits.append(game.text("ui.fight.turn").replace("{turn}", str(fight.turn)))
	_vitals.text = "   ".join(bits)

	var piles := PackedStringArray()
	piles.append("%s %d" % [game.text("ui.fight.draw"), fight.draw_pile.size()])
	piles.append("%s %d" % [game.text("ui.fight.discard"), fight.discard_pile.size()])
	var statuses := EnemyView.status_text(game.content, fight.statuses)
	if statuses != "":
		piles.append(statuses)
	_piles.text = "   ".join(piles)


func _refresh_hand(fight: FightState) -> void:
	while _card_views.size() < fight.hand.size():
		var view := CardView.new()
		view.pressed.connect(_on_card_pressed)
		_hand_row.add_child(view)
		_card_views.append(view)
	for i in _card_views.size():
		var used := i < fight.hand.size()
		_card_views[i].visible = used
		if used:
			_card_views[i].bind(game.content, fight.hand[i], i, _playable.has(i))
			_card_views[i].set_selected(i == selected_index)


func _refresh_prompt(fight: FightState) -> void:
	if selected_index >= 0 and bool(_playable.get(selected_index, false)) and not fight.is_over():
		_prompt.text = game.text("ui.fight.pick_target")
	else:
		_prompt.text = ""


## First click selects; a second click on the same card deselects. A card
## that targets only the hero resolves immediately — making the player pick
## themselves as a target would be noise.
func _on_card_pressed(hand_index: int) -> void:
	if run == null or run.fight == null or run.fight.is_over():
		return
	if not _playable.has(hand_index):
		return
	if selected_index == hand_index:
		selected_index = -1
		refresh()
		return
	if bool(_playable[hand_index]):
		selected_index = hand_index
		refresh()
		return
	_play(hand_index, -1)


func _on_enemy_pressed(enemy_index: int) -> void:
	if selected_index < 0 or run == null or run.fight == null:
		return
	if not run.fight.enemies[enemy_index].alive:
		return
	_play(selected_index, enemy_index)


func _play(hand_index: int, target: int) -> void:
	selected_index = -1
	# Fly the card before the refresh rebinds that slot to a different card.
	if hand_index < _card_views.size():
		_card_views[hand_index].fly_out(_discard_corner())
	var events := game.run_action({"kind": "play", "hand_index": hand_index, "target": target})
	_animate(events)
	_after_action()


func _on_end_turn() -> void:
	if run == null or run.fight == null or run.fight.is_over():
		return
	selected_index = -1
	var events := game.run_action({"kind": "end_turn"})
	_animate(events)
	_after_action()


## Bottom-right, where the discard count sits.
func _discard_corner() -> Vector2:
	return global_position + Vector2(size.x - 40.0, size.y - 24.0)


## Where a number should appear for each thing the events can name.
func anchors() -> Dictionary:
	var out := {"hero": _vitals.position + Vector2(0.0, -8.0)}
	for i in _enemy_views.size():
		if _enemy_views[i].visible:
			out[i] = _enemy_views[i].position + _enemy_views[i].size * Vector2(0.5, 0.0)
	return out


func _animate(events: Array) -> void:
	if events.is_empty():
		return
	_animator.play(events, anchors())
	_react(events)


## The floating numbers say what happened; these make the thing it happened
## to acknowledge it. Driven off the same event stream.
func _react(events: Array) -> void:
	for event in events:
		if not event.has("index"):
			continue
		var index := int(event["index"])
		if index < 0 or index >= _enemy_views.size():
			continue
		match String(event.get("type", "")):
			"damage":
				if int(event.get("amount", 0)) > 0:
					_enemy_views[index].react_hit(int(event["amount"]))
			"enemy_died":
				_enemy_views[index].react_death()


## Tweening a container child's position is fragile -- the parent re-sorts on
## resize and can cut the shake short -- but the tween always resolves back to
## zero, so the worst case is a shake that ends early. Cosmetic, not a bug.
func _shake(strength: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var origin := Vector2.ZERO
	_shake_tween = create_tween()
	for i in 4:
		var away := Vector2(strength * (1.0 if i % 2 == 0 else -1.0), 0.0) * (1.0 - float(i) / 4.0)
		_shake_tween.tween_property(self, "position", origin + away, 0.045)
	_shake_tween.tween_property(self, "position", origin, 0.045)


## The engine moves the run out of the fight phase itself when the fight
## resolves; the screen just reports it upward so the router can swap.
func _after_action() -> void:
	if run.phase != "fight":
		fight_ended.emit()
		return
	refresh()
