class_name PremiumArt
extends RefCounted

const EMBLEM := preload("res://assets/ui/premium/emblem.svg")
const FACTORY := preload("res://assets/ui/premium/factory.svg")
const SCORE := preload("res://assets/ui/premium/score.svg")
const FRAME := preload("res://assets/ui/premium/frame.svg")
const TRAY := preload("res://assets/ui/premium/tray.svg")
const TROPHY := preload("res://assets/ui/premium/trophy.svg")
const PAUSE := preload("res://assets/ui/premium/pause.svg")
const GLINT := preload("res://assets/ui/premium/glint.svg")
const CELL := preload("res://assets/ui/premium/cell_gloss.svg")
const CREAM := preload("res://assets/ui/premium/cream_button.svg")
const GREEN := preload("res://assets/ui/premium/green_button.svg")

var cream_button := StyleBoxTexture.new()
var green_button := StyleBoxTexture.new()

func _init() -> void:
	cream_button.texture = CREAM
	green_button.texture = GREEN
	for style in [cream_button, green_button]:
		style.set_texture_margin(SIDE_LEFT, 38)
		style.set_texture_margin(SIDE_RIGHT, 38)
		style.set_texture_margin(SIDE_TOP, 34)
		style.set_texture_margin(SIDE_BOTTOM, 34)

func button(canvas: CanvasItem, area: Rect2, primary: bool) -> void:
	canvas.draw_style_box(green_button if primary else cream_button, area)

static func sparkle(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	canvas.draw_texture_rect(GLINT, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, Color(1, 1, 1, alpha))
