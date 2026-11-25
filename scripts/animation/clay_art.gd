class_name ClayArt
extends RefCounted

const MATERIALS := preload("res://assets/clay/materials.png")
const STUDIO := preload("res://assets/clay/studio.png")
const CUTTERS := preload("res://assets/cutters/steel.png")
const REGION_FILE := "res://assets/cutters/regions.json"
const TILE := 128
const VARIANTS := 7
const PRESSED := VARIANTS
const CAVITY := VARIANTS + 1
const CRUMB := VARIANTS + 2
const FRAME := preload("res://assets/ui/workshop/board.png")
const GLYPH_ATLAS := preload("res://assets/ui/workshop/glyphs.png")
const GLYPHS := [&"home", &"restart", &"sound", &"music", &"haptics", &"globe", &"check", &"cutter"]
const SURFACES := {
	&"raised": preload("res://assets/ui/workshop/card.png"),
	&"recess": preload("res://assets/ui/workshop/tray.png"),
}
const ICON_ATLAS := preload("res://assets/ui/workshop/icons.png")
const ICONS := [&"play", &"calendar", &"collection", &"trophy", &"settings", &"pause", &"back", &"clock", &"shine"]

var regions: Dictionary
var styles: Dictionary = {}
var skin_styles: Dictionary = {}

func _init() -> void:
	regions = JSON.parse_string(FileAccess.get_file_as_string(REGION_FILE))

func cell(canvas: CanvasItem, area: Rect2, material: int, frame: int, tint := Color.WHITE) -> void:
	if frame == CAVITY:
		skin(canvas, area.grow(-4), &"recess", tint)
		return
	var studio := material >= ThemeCatalog.STUDIO_START
	var row := material - ThemeCatalog.STUDIO_START if studio else material
	var region := Rect2(frame * TILE, row * TILE, TILE, TILE)
	canvas.draw_texture_rect_region(STUDIO if studio else MATERIALS, area, region, tint, false, true)

func cutter(canvas: CanvasItem, id: String, center: Vector2, unit: float, tint := Color.WHITE) -> void:
	if not regions.has(id):
		return
	var info: Array = regions[id]
	var side: float = unit * float(info[2]) / float(info[4])
	var region := Rect2(info[0], info[1], info[2], info[3])
	canvas.draw_texture_rect_region(CUTTERS, Rect2(center - Vector2.ONE * side / 2, Vector2.ONE * side), region, tint, false, true)

func skin(canvas: CanvasItem, area: Rect2, kind: StringName, tint := Color.WHITE) -> void:
	var key := [kind, tint]
	var style: StyleBoxTexture = skin_styles.get(key)
	if style == null:
		style = StyleBoxTexture.new()
		style.texture = SURFACES[kind]
		style.modulate_color = tint
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 31.0 if kind == &"raised" else 28.0)
		skin_styles[key] = style
	canvas.draw_style_box(style, area)

func icon(canvas: CanvasItem, id: StringName, center: Vector2, side: float, tint := Color.WHITE) -> void:
	var area := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	if id == &"star":
		id = &"shine"
	var painted := ICONS.find(id)
	if painted >= 0:
		var region := Rect2(painted % 3 * 160, floori(painted / 3.0) * 160, 160, 160)
		canvas.draw_texture_rect_region(ICON_ATLAS, area, region, tint, false, true)
		return
	var index := GLYPHS.find(id)
	if index >= 0:
		var region := Rect2((index % 7) * TILE, floori(index / 7.0) * TILE, TILE, TILE)
		canvas.draw_texture_rect_region(GLYPH_ATLAS, area, region, tint, false, true)

func panel(canvas: CanvasItem, area: Rect2, color: Color, radius: int, border := Color.TRANSPARENT, border_size := 2) -> void:
	var key := [color, radius, border, border_size]
	var style: StyleBoxFlat = styles.get(key)
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.corner_detail = 10
		if border.a > 0:
			style.set_border_width_all(border_size)
			style.border_color = border
		if styles.size() > 172:
			styles.clear()
		styles[key] = style
	canvas.draw_style_box(style, area)

func sparkle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, tilt := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := float(i) * TAU / 8.0 + tilt
		points.append(center + Vector2.from_angle(angle) * (radius if i % 2 == 0 else radius * 0.23))
	canvas.draw_colored_polygon(points, color)
