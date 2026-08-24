class_name OfflineSummary
extends PanelContainer
## "While you were away" (spec §5.8). Shown once on load when the ghosts
## earned something worth reporting. A capped return always shows, because
## the cap is the reason to buy Night Watch and hiding it reads as a bug.

signal dismissed()

const MIN_SECONDS := 60
const MIN_SOUL := 1.0

var _title: Label
var _away: Label
var _earned: Label
var _capped: Label
var _button: Button


func _init() -> void:
	_build()


## Worth interrupting the player for? A blink is not; a capped night is,
## even if the ladder was empty and earned nothing.
static func should_show(offline: Dictionary) -> bool:
	if bool(offline.get("capped", false)):
		return true
	var counted := int(offline.get("counted", 0))
	var soul := float(offline.get("soul", 0.0))
	return counted >= MIN_SECONDS and soul >= MIN_SOUL


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	_title = UiTheme.title("")
	box.add_child(_title)
	_away = UiTheme.small("")
	box.add_child(_away)
	_earned = UiTheme.number("0")
	box.add_child(_earned)
	_capped = UiTheme.small("", Palette.PREPARED)
	_capped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_capped)

	_button = Button.new()
	_button.pressed.connect(func() -> void: dismissed.emit())
	box.add_child(_button)


func bind(content: Content, offline: Dictionary) -> void:
	var counted := int(offline.get("counted", 0))
	var capped := bool(offline.get("capped", false))
	_title.text = content.text("ui.offline.title")
	# The time that actually paid, not the time away -- otherwise a capped
	# return claims credit for hours it did not earn.
	_away.text = content.text("ui.offline.away").replace("{duration}", Num.duration(counted))
	_earned.text = Num.short(float(offline.get("soul", 0.0)))
	_capped.text = content.text("ui.offline.capped")
	_capped.visible = capped
	_button.text = content.text("ui.offline.dismiss")
