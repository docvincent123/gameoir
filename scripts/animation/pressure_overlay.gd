class_name PressureOverlay
extends ColorRect

const SHADER = preload("res://assets/shaders/clay_pressure.gdshader")
var mask_image := Image.create(7, 7, false, Image.FORMAT_L8)
var mask_texture: ImageTexture
var effect := ShaderMaterial.new()
var previous: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.shader = SHADER
	mask_image.fill(Color.BLACK)
	mask_texture = ImageTexture.create_from_image(mask_image)
	effect.set_shader_parameter("footprint", mask_texture)
	material = effect
	hide()

func update_pressure(app) -> void:
	if app.view != "game" or app.overlay != "" or app.reduced or app.run == null:
		hide()
		return
	var cells: Array = []
	var strength := 0.0
	if app.animation.active and app.animation.elapsed < AnimationManager.PRESS:
		cells = app.animation.change.removed
		strength = smoothstep(0.0, AnimationManager.PRESS, app.animation.elapsed)
	elif app.input.valid:
		for offset: Vector2i in app.run.cutters.shape(app.input.slot).cells:
			cells.append(app.input.anchor + offset)
		strength = 0.24
	if cells.is_empty():
		hide()
		return
	if previous != cells:
		mask_image.fill(Color.BLACK)
		for tile: Vector2i in cells:
			if app.run.board.is_inside(tile):
				mask_image.set_pixel(tile.x, tile.y, Color.WHITE)
		mask_texture.update(mask_image)
		previous = cells.duplicate()
	position = app.view_origin + (app.GRID.position + app.animation.displace(app.run.streak, app.reduced)) * app.view_scale
	size = app.GRID.size * app.view_scale
	effect.set_shader_parameter("pressure", strength)
	show()
