class_name FightScreen
extends Control
## The fight (spec §9): "enemies across the top (icon, HP bar, intent), hero
## bottom-left (HP, Block, Energy, stats), hand along the bottom, piles in
## the corners."
##
## Anchored regions rather than a vertical stack, because the stack read as
## a settings dialog. The hand is fanned -- cards arc and tilt around a
## centre point and lift out of the fan on hover -- which is the single
## clearest signal that this is a card game and not a form.
##
## Targeting is two clicks: pick a card, then pick an enemy. Cards that
## target the hero resolve on the first click. Playability comes from
## CombatEngine.legal_actions, so the screen can never offer a move the
## engine would refuse.

signal fight_ended()

## How far each card tilts and drops per step out from the middle of the fan.
const FAN_ARC := 0.055
const FAN_SPREAD := 0.72
const FAN_LIFT := 26.0
const HAND_BOTTOM := 24.0

var game: GameRoot
var run: RunState
var selected_index: int = -1

var _enemy_row: HBoxContainer
var _hand: Control
var _hero: HeroPanel
var _prompt: Label
var _end_turn: Button
var _enemy_views: Array[EnemyView] = []
var _card_views: Array[CardView] = []
var _playable: Dictionary = {}
var _animator: FightAnimator
var _shake_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func bind(g: GameRoot, p_run: RunState) -> void:
	game = g
	run = p_run
	if _enemy_row == null:
		_build()
	_animator.bind(g.content)
	refresh()


func _build() -> void:
	# Enemies: centred across the top, where the player looks first.
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 18)
	_enemy_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_enemy_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_enemy_row.position = Vector2(0.0, 16.0)
	add_child(_enemy_row)

	# The hero, bottom-left, opposite what is trying to kill them.
	_hero = HeroPanel.new()
	_hero.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hero.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hero.position = Vector2(16.0, -HeroPanel.PANEL_SIZE.y - 16.0)
	add_child(_hero)

	_prompt = UiTheme.body("", Palette.SOUL)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	# The hand lays itself out: a container would space the cards evenly and
	# flat, and the fan is the point.
	_hand = Control.new()
	_hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)

	_end_turn = Button.new()
	_end_turn.custom_minimum_size = Vector2(128.0, 40.0)
	_end_turn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_turn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_end_turn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_end_turn.position = Vector2(-144.0, -56.0)
	_end_turn.pressed.connect(_on_end_turn)
	add_child(_end_turn)

	# Overlay: draws above the fight and never eats a click.
	_animator = FightAnimator.new()
	_animator.shake_requested.connect(_shake)
	add_child(_animator)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and run != null and run.fight != null:
		_fan(run.fight.hand.size())


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
	_hero.bind(game.content, fight)


func _refresh_hand(fight: FightState) -> void:
	while _card_views.size() < fight.hand.size():
		var view := CardView.new()
		view.pressed.connect(_on_card_pressed)
		_hand.add_child(view)
		_card_views.append(view)
	for i in _card_views.size():
		var used := i < fight.hand.size()
		_card_views[i].visible = used
		if used:
			_card_views[i].bind(game.content, fight.hand[i], i, _playable.has(i))
			_card_views[i].set_selected(i == selected_index)
	_fan(fight.hand.size())


## Arcs the hand around a centre point: each card tilts a little further
## from vertical and sits a little lower the further it is from the middle,
## which is what a hand of cards actually looks like.
func _fan(count: int) -> void:
	if count <= 0 or size.x <= 0.0:
		return
	var centre := size.x * 0.5
	var card := CardView.CARD_SIZE
	var step := minf(card.x * FAN_SPREAD, (size.x - 320.0) / maxf(1.0, float(count)))
	var base_y := size.y - card.y - HAND_BOTTOM
	for i in count:
		var offset := float(i) - float(count - 1) * 0.5
		var angle := offset * FAN_ARC
		var lift := absf(offset) * absf(offset) * FAN_LIFT * 0.5
		var at := Vector2(centre + offset * step - card.x * 0.5, base_y + lift)
		_card_views[i].place(at, angle)


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
	var out := {"hero": _hero.position + Vector2(_hero.size.x * 0.5, -8.0)}
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
