class_name FightDirector
extends Node3D
## Stages a fight where the player is standing: bodies in the room, the hand
## on the HUD, and the turn flow between them. Replaces `fight_screen.gd`.
##
## The camera does not cut away. Spec §8 says "the camera locks to it", and in
## a first-person game that means your own body is frozen and your own head
## turns -- you are still looking through your own eyes, which is the entire
## point of the pivot. A cutaway would put the fight back on a stage you watch
## instead of in a room you are in.
##
## Nothing here writes to RunState. Every action goes through
## GameRoot.run_action, which is the only channel (spec §4).

signal fight_finished()

## How far in front of the room's centre the front rank stands.
const DEPTH := 1.6
const SPACING := 1.35
## Outer enemies stand a little further back, so a line of three reads as a
## group rather than a wall.
const BACK_STEP := 0.45
const TURN_SECONDS := 0.35
const SHAKE_SECONDS := 0.22

var game: GameRoot
var hud: HudRoot
var player: Player
var hand: HandView
var animator: FightAnimator3D
var vitals: HeroPanel
var bodies: Array[EnemyBody] = []
var tags: Array[EnemyTag] = []
## Hand index -> whether that card needs an enemy chosen. Mirrors the engine.
var playable: Dictionary = {}

## Everything this director puts on the HUD lives under one node, so it can
## all be taken down together. The widgets are children of the HUD, not of the
## director, so freeing the director does not free them -- and a second fight
## would otherwise deal a second hand next to the first one, forever.
var _hud_layer: Control
var _end_turn: Button
var _banner: TurnBanner
var _finished: bool = false
var _shake: Tween


## Where each enemy stands, given the centre of the room and the direction the
## player is looking. Pure, so the arrangement can be checked without staging
## anything.
static func stage_points(count: int, at: Vector3, facing: Vector3) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var fwd := Vector3(facing.x, 0.0, facing.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0.0, 0.0, -1.0)
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	for i in count:
		var offset := float(i) - float(count - 1) * 0.5
		out.append(at + right * (offset * SPACING) + fwd * (DEPTH + absf(offset) * BACK_STEP))
	return out


func begin(g: GameRoot, h: HudRoot, p: Player, at: Vector3) -> void:
	game = g
	hud = h
	player = p
	_finished = false

	var facing := Vector3(at.x - p.global_position.x, 0.0, at.z - p.global_position.z)
	if facing.length_squared() < 0.0001:
		facing = -p.global_transform.basis.z
	_stage(at, facing)
	_face(at)

	# Frozen and pointing at the fight: the cards need the cursor, and a body
	# that can still walk away mid-fight is a body that will.
	player.frozen = true
	player.look_enabled = false
	_build_hud()
	hud.set_pointer(true)
	refresh()


func fight() -> FightState:
	if game == null or game.campaign == null or game.campaign.run == null:
		return null
	return game.campaign.run.fight


func living_bodies() -> Array:
	var out: Array = []
	for b in bodies:
		if not b.dying:
			out.append(b)
	return out


func body_of(index: int) -> EnemyBody:
	for b in bodies:
		if b.index == index:
			return b
	return null


## Camera ray at a screen point -> the enemy index under it, or -1.
func target_under(screen: Vector2) -> int:
	if player == null or player.camera == null:
		return -1
	var space := get_world_3d().direct_space_state
	var from := player.camera.project_ray_origin(screen)
	var to := from + player.camera.project_ray_normal(screen) * 40.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = EnemyBody.LAYER_ENEMY
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -1
	var body := hit["collider"] as EnemyBody
	return body.index if body != null and not body.dying else -1


func needs_target(hand_index: int) -> bool:
	# One living enemy means there is nothing to choose, and asking the player
	# to click it is friction, not depth. Most fights are one enemy.
	if living_bodies().size() <= 1:
		return false
	return bool(playable.get(hand_index, false))


## Where a number should appear for each thing the events can name, in screen
## space. Re-asked by the animator every beat, because a body that recoiled
## has moved.
func anchors() -> Dictionary:
	var out: Dictionary = {}
	var camera := player.camera if player != null else null
	var screen := hud.ui.size if hud != null else Vector2(640.0, 360.0)
	out["hero"] = Vector2(screen.x * 0.5, screen.y * 0.72)
	for b in bodies:
		out[b.index] = _to_screen(camera, b.head_point(), screen)
	return out


func play_card(hand_index: int, target: int) -> void:
	var f := fight()
	if f == null or f.is_over() or not playable.has(hand_index):
		return
	hand.select(-1)
	if hand_index < hand.views.size():
		hand.views[hand_index].fly_out(_discard_corner())
	_sound("card_play")
	animator.play(game.run_action({"kind": "play", "hand_index": hand_index, "target": target}))
	_after_action()


func end_turn() -> void:
	var f := fight()
	if f == null or f.is_over():
		return
	hand.select(-1)
	_banner.announce(game.text("ui.fight.enemy_turn"), false)
	animator.play(game.run_action({"kind": "end_turn"}))
	_after_action()


## Idempotent: called after every action and again when the animator settles,
## so whichever notices first, the fight ends exactly once.
func check_over() -> void:
	if _finished:
		return
	if game.campaign.run != null and game.campaign.run.phase == "fight":
		return
	_finished = true
	player.frozen = false
	player.look_enabled = true
	hud.set_pointer(false)
	hand.clear()
	for t in tags:
		(t as EnemyTag).visible = false
	fight_finished.emit()


func refresh() -> void:
	var f := fight()
	if f == null:
		return
	_recompute_playable(f)
	vitals.bind(game.content, f)
	hand.show_hand(f, playable)
	for t in tags:
		var tag: EnemyTag = t
		if tag.index < f.enemies.size():
			tag.bind(game.content, f, tag.index)
	for b in bodies:
		var alive := b.index < f.enemies.size() and f.enemies[b.index].alive
		if not alive and not b.dying:
			b.die()
	_end_turn.disabled = f.is_over()


## The engine is the authority on what can be played; this only mirrors it.
func _recompute_playable(f: FightState) -> void:
	playable.clear()
	for action in CombatEngine.legal_actions(f):
		if String(action.get("kind", "")) != "play":
			continue
		var index := int(action["hand_index"])
		var wants_enemy := int(action.get("target", -1)) >= 0
		playable[index] = bool(playable.get(index, false)) or wants_enemy


func _stage(at: Vector3, facing: Vector3) -> void:
	var f := fight()
	if f == null:
		return
	var points := stage_points(f.enemies.size(), at, facing)
	for i in f.enemies.size():
		var def: EnemyDef = game.content.enemies[f.enemies[i].def_id]
		var body := EnemyBody.create(def, i)
		add_child(body)
		body.global_position = points[i]
		body.look_at_from_position(points[i], Vector3(at.x, points[i].y, at.z) - facing * 4.0, Vector3.UP)
		bodies.append(body)


## Turns the player to face the group. Tweened rather than snapped: the head
## whipping round is the difference between "a fight started" and "the screen
## changed".
func _face(at: Vector3) -> void:
	var to := Vector3(at.x, player.global_position.y, at.z)
	var yaw := player.global_position.direction_to(to)
	if yaw.length_squared() < 0.0001:
		return
	var target := atan2(-yaw.x, -yaw.z)
	if not is_inside_tree():
		player.rotation.y = target
		return
	var turn := create_tween()
	turn.tween_property(player, "rotation:y", target, TURN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_hud() -> void:
	_hud_layer = Control.new()
	_hud_layer.name = "FightHud"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.ui.add_child(_hud_layer)

	animator = FightAnimator3D.new()
	animator.bind(game.content, game.sfx)
	animator.anchors_supplier = anchors
	animator.body_supplier = func(i: int) -> Node3D: return body_of(i)
	animator.shake_requested.connect(_on_shake)
	animator.finished.connect(check_over)
	_hud_layer.add_child(animator)

	hand = HandView.new()
	hand.bind(game.content)
	hand.card_pressed.connect(_on_card_pressed)
	_hud_layer.add_child(hand)

	vitals = HeroPanel.new()
	vitals.position = Vector2(8.0, hud.ui.size.y - HeroPanel.PANEL_SIZE.y - 8.0)
	_hud_layer.add_child(vitals)

	_end_turn = Button.new()
	_end_turn.text = game.text("ui.fight.end_turn")
	_end_turn.position = Vector2(hud.ui.size.x - 70.0, hud.ui.size.y - 30.0)
	_end_turn.pressed.connect(end_turn)
	_hud_layer.add_child(_end_turn)

	_banner = TurnBanner.new()
	_hud_layer.add_child(_banner)

	# One tag per enemy, above the hand so a card never covers the number you
	# are deciding against.
	for b in bodies:
		var tag := EnemyTag.create((b as EnemyBody).index)
		_hud_layer.add_child(tag)
		tags.append(tag)


func _on_card_pressed(hand_index: int) -> void:
	var f := fight()
	if f == null or f.is_over() or not playable.has(hand_index):
		return
	if hand.selected == hand_index:
		hand.select(-1)
		return
	if needs_target(hand_index):
		hand.select(hand_index)
		return
	# One living enemy, or a card that only touches the hero: resolve now.
	var only := living_bodies()
	play_card(hand_index, int((only[0] as EnemyBody).index) if only.size() == 1 and bool(playable[hand_index]) else -1)


func _unhandled_input(event: InputEvent) -> void:
	if _finished or hand == null or hand.selected < 0:
		return
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var target := target_under(click.position)
	if target >= 0:
		play_card(hand.selected, target)


func _after_action() -> void:
	if game.campaign.run == null or game.campaign.run.phase != "fight":
		# The animator is still playing the blow that ended it; check_over runs
		# again when it settles, and it is idempotent.
		check_over()
		return
	refresh()


## The tags follow the bodies every frame: a recoiling enemy that leaves its
## health bar behind reads as a bug before it reads as a hit.
func _process(_delta: float) -> void:
	if _finished or hud == null:
		return
	var anchor := anchors()
	for t in tags:
		var tag: EnemyTag = t
		var body := body_of(tag.index)
		if body == null or body.dying:
			tag.visible = false
			continue
		tag.place(anchor.get(tag.index, Vector2.ZERO))


func _on_shake(strength: float) -> void:
	if player == null or player.head == null or strength <= 0.0:
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	var rest := Vector3(0.0, Player.EYE, 0.0)
	var kick := rest + Vector3(0.0, -strength * 0.006, 0.0)
	_shake = create_tween()
	_shake.tween_property(player.head, "position", kick, SHAKE_SECONDS * 0.3)
	_shake.tween_property(player.head, "position", rest, SHAKE_SECONDS * 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _to_screen(camera: Camera3D, at: Vector3, screen: Vector2) -> Vector2:
	if camera == null or not camera.is_inside_tree() or camera.is_position_behind(at):
		return screen * 0.5
	# The camera unprojects into the real viewport; the HUD is a scaled space
	# over it, so the point has to be brought back into the HUD's coordinates.
	var k := HudRoot.scale_for(camera.get_viewport().get_visible_rect().size)
	return camera.unproject_position(at) / k


func _discard_corner() -> Vector2:
	return Vector2(hud.ui.size.x - 40.0, hud.ui.size.y - 24.0)


func _sound(id: String) -> void:
	if game != null and game.sfx != null:
		game.sfx.play(id)


## The hand, the vitals, the end-turn button and the tags are children of the
## HUD rather than of this node, so they do not go when it does. They have to
## be taken down explicitly or every fight leaves its interface on screen.
func _exit_tree() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
		_hud_layer = null
