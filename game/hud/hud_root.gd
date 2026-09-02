class_name HudRoot
extends CanvasLayer
## The 2D layer over the live 3D room: cards, panels, numbers, prompts.
##
## Everything you read in this game is drawn here rather than in the world.
## The spec argues it for cards -- "a card rendered in perspective is a card
## you cannot read" (§3.2) -- and the argument is about text and choice, not
## about cards, so a shop list and an exit decision live here too.
##
## One scale for the whole layer. Every kept widget was authored against the
## old 640x360 viewport (CardView.CARD_SIZE is 82x159, UiTheme's font sizes
## match), and the 3D world now renders at the window's real resolution. So
## `ui` is a 640x360 space scaled up to fill the window, and its children go on
## using the coordinates they already use.

const REFERENCE := Vector2(640.0, 360.0)

## The space panels lay out in. Add children here, never to the layer.
var ui: Control
var panel: Control
## Darkens the room behind whatever panel is open.
var dim: ColorRect
## What this layer last asked the pointer to do. Recorded because
## Input.set_mouse_mode does not stick under --headless -- there is no window
## to capture a cursor into, so it reads back VISIBLE whatever it was told --
## and the intent is the part worth asserting anyway.
var pointer_free: bool = false


## Fractional, not integer: the pixel-art direction needed whole numbers so a
## texel stayed square, and it died with PaletteLayer. A 1600x900 window should
## fill rather than letterbox. Never below 1.0 -- a window smaller than the
## reference should clip, not shrink the text past reading.
static func scale_for(viewport: Vector2) -> float:
	return maxf(1.0, minf(viewport.x / REFERENCE.x, viewport.y / REFERENCE.y))


func _init() -> void:
	# Behind everything, and added first so it stays there. A panel over a lit
	# 3D room competes with the room for every pixel; bone-white text on bright
	# ochre stone is legible in spite of the background rather than because of
	# it.
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.05, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	ui = Control.new()
	ui.name = "Ui"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The game's own theme, on the node every panel is a descendant of.
	#
	# It was built and never applied: `UiTheme.build()` existed for two
	# milestones and was constructed only by tests, so the HUD drew in Godot's
	# default face and every carved StoneBox in it -- buttons, panels,
	# scrollbars -- was dead code. The screens that looked carved were the ones
	# whose authors had overridden the stylebox by hand.
	ui.theme = UiTheme.build()
	add_child(ui)


func _ready() -> void:
	var viewport := get_viewport()
	if viewport != null:
		fit(viewport.get_visible_rect().size)
		if not viewport.size_changed.is_connected(_on_resized):
			viewport.size_changed.connect(_on_resized)


const DIM_ALPHA := 0.72
const DIM_SECONDS := 0.12


func fit(viewport: Vector2) -> void:
	var k := scale_for(viewport)
	ui.scale = Vector2(k, k)
	ui.position = Vector2.ZERO
	ui.size = viewport / k
	if dim != null:
		dim.position = Vector2.ZERO
		dim.size = viewport


## Fades the room down behind a panel and back up when it closes.
func set_dim(on: bool) -> void:
	if dim == null:
		return
	var to := DIM_ALPHA if on else 0.0
	if not is_inside_tree():
		dim.color.a = to
		return
	var tween := create_tween()
	tween.tween_property(dim, "color:a", to, DIM_SECONDS)


func has_panel() -> bool:
	return panel != null and is_instance_valid(panel)


## One panel at a time, and the previous one goes immediately rather than on
## the next frame -- two shop lists overlapping for a frame is the kind of
## thing nobody notices until a screenshot.
func show_panel(next: Control) -> void:
	clear_panel()
	panel = next
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(next)
	set_pointer(true)


func clear_panel() -> void:
	if has_panel():
		panel.get_parent().remove_child(panel)
		panel.queue_free()
	panel = null


## True while something on this layer needs clicking. The player's look and
## walk are the other half of this and are switched by whoever calls it, so
## that "the mouse is free" and "the body is frozen" can never disagree.
func set_pointer(on: bool) -> void:
	pointer_free = on
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED)


func _on_resized() -> void:
	var viewport := get_viewport()
	if viewport != null:
		fit(viewport.get_visible_rect().size)
