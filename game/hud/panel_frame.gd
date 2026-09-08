class_name PanelFrame
extends MarginContainer
## A bounded scroll surface. The panel instance and scroll survive tab changes.

var scroll: ScrollContainer
var screen: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 10)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Follow in local UI coordinates: the HUD's independent scale makes
	# viewport pixel distances unsuitable as scroll offsets.
	scroll.follow_focus = false
	add_child(scroll)


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	scroll.resized.connect(func() -> void: _on_focus_changed(get_viewport().gui_get_focus_owner()))


func _on_focus_changed(control: Control) -> void:
	_follow_focus.call_deferred(control)


func _follow_focus(control: Control) -> void:
	# A newly opened panel may still have its old (or zero) content height.
	# Wait for container layout before deciding whether scrolling is needed.
	await get_tree().process_frame
	if not is_instance_valid(control) or get_viewport().gui_get_focus_owner() != control \
		or not control.is_visible_in_tree() or not scroll.is_ancestor_of(control):
		return
	var local := scroll.get_global_transform().affine_inverse() * control.get_global_transform()
	var bounds := local * Rect2(Vector2.ZERO, control.size)
	if bounds.position.y < 0:
		scroll.scroll_vertical += floori(bounds.position.y)
	elif bounds.end.y > scroll.size.y:
		scroll.scroll_vertical += ceili(bounds.end.y - scroll.size.y)


func host(control: Control) -> void:
	screen = control
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(control)
