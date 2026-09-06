class_name WalletBar
extends HBoxContainer
## Soul, income and reach, above every idle screen.
##
## This used to live inside LadderScreen, which meant the Guild and the
## Séance -- the only two screens in the game where Soul is *spent* -- never
## showed how much of it you had. You could tell an upgrade was unaffordable
## only by noticing its button was grey. A shop with the wallet in another
## room is the kind of thing that reads as unfinished, so the readout moved
## up to the shell and every tab gets it.
##
## Runs at 10 Hz off `soul_changed` and touches nothing but its own labels:
## the tower and the upgrade rows are static between mutations and must not
## be rebuilt by a ticking number.

const SEPARATION := 28

var game: GameRoot

var _soul: Label
var _rate: Label
var _reach: Label
var _shown_soul: float = 0.0
var _last_shown_soul: int = -1
var _soul_tween: Tween


func _init() -> void:
	add_theme_constant_override("separation", SEPARATION)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(g: GameRoot) -> void:
	game = g
	if _soul == null:
		_build()
	if not g.soul_changed.is_connected(_on_soul_changed):
		g.soul_changed.connect(_on_soul_changed)
	if not g.ladder_changed.is_connected(refresh):
		g.ladder_changed.connect(refresh)
	refresh()


func _build() -> void:
	_soul = UiTheme.number("0")
	_rate = UiTheme.number("0/h", Palette.BONE)
	_reach = UiTheme.number("1", Palette.BONE)
	add_child(_stat_block(_soul, game.text("ui.soul"), game.text("ui.tip.soul"), "soul"))
	add_child(_stat_block(_rate, game.text("ui.per_hour"), game.text("ui.tip.per_hour"), "ghost"))
	add_child(_stat_block(_reach, game.text("ui.reach"), game.text("ui.tip.reach"), "descend"))


static func _stat_block(value: Label, caption: String, tip: String, icon: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = tip
	box.add_child(Icons.make_rect(Icons.ui(icon), 12.0, Palette.SOUL if icon == "soul" else Palette.EDGE_LIGHT))
	box.add_child(value)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 4)
	foot.add_child(UiTheme.small(caption))
	foot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(foot)
	return box


func refresh() -> void:
	if game == null or game.campaign == null:
		return
	_reach.text = str(CampaignEngine.reach(game.campaign))
	_on_soul_changed(game.displayed_soul(), game.campaign.rate_per_hour)


## The 10 Hz path: numbers only, never a rebind.
func _on_soul_changed(soul: float, rate_per_hour: float) -> void:
	_rate.text = Num.rate(rate_per_hour)
	_count_to(soul)
	_punch_soul(int(soul))


## The counter runs up to its new value instead of jumping. On an idle
## screen the number climbing IS the feedback -- a value that snaps reads
## as a field being overwritten.
func _count_to(soul: float) -> void:
	if not is_inside_tree() or absf(soul - _shown_soul) < 0.01:
		_shown_soul = soul
		_soul.text = Num.short(soul)
		return
	# A big jump (a run banked, an upgrade bought) is worth watching; the
	# 10 Hz trickle is not, so it lands almost immediately.
	var leap := absf(soul - _shown_soul) > maxf(8.0, _shown_soul * 0.05)
	if _soul_tween != null and _soul_tween.is_valid():
		_soul_tween.kill()
	_soul_tween = create_tween()
	_soul_tween.tween_method(_set_shown_soul, _shown_soul, soul, 0.55 if leap else 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown_soul(value: float) -> void:
	_shown_soul = value
	_soul.text = Num.short(value)


## A small kick whenever the whole number climbs -- what makes the counter
## feel like earnings rather than a readout.
func _punch_soul(whole: int) -> void:
	if whole == _last_shown_soul:
		return
	var first := _last_shown_soul < 0
	_last_shown_soul = whole
	if first or not is_inside_tree():
		return
	_soul.pivot_offset = _soul.size * Vector2(0.0, 0.5)
	_soul.scale = Vector2(1.12, 1.12)
	var tween := create_tween()
	tween.tween_property(_soul, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
