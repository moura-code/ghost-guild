class_name PaletteLayer
extends CanvasLayer
## Sits over the entire game and snaps every rendered pixel to the palette.
##
## The one piece that makes the whole thing pixel art rather than a game with
## pixel art in it. Everything else -- the sprites, the fonts, the 640x360
## viewport -- gets each element onto the grid individually; this gets the
## whole frame onto one palette at once, including the things that would
## otherwise never comply: the crypt shader's gradients, anti-aliased circles
## in the props, particle alpha fades, and the greys a font renders its own
## edges with.
##
## Deliberately the last thing added to the scene, on a high layer, so it is
## over the run view, the epitaph and the offline modal alike.

const SHADER_PATH := "res://game/theme/palette_snap.gdshader"
## Above every CanvasLayer the game creates. Godot draws layers in order and
## this one has to be last or it snaps a frame that is missing whatever drew
## after it.
const LAYER := 128

var _rect: ColorRect


func _init() -> void:
	layer = LAYER
	_build()


func _build() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# It samples the screen rather than tinting it, so its own colour is
	# irrelevant -- but it must not eat input from the game underneath.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		# A missing shader must degrade to "no palette snap", never to a
		# black rectangle over the whole game.
		_rect.color = Color(0, 0, 0, 0)
		add_child(_rect)
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	_rect.material = material
	add_child(_rect)


## Whether the snap is actually running. Tests assert this rather than
## assert on pixels: if the shader fails to load the game still plays, and
## the failure has to be visible somewhere other than by eye.
func is_active() -> bool:
	return _rect != null and _rect.material is ShaderMaterial \
		and (_rect.material as ShaderMaterial).shader != null
