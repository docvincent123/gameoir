class_name AnimationManager
extends RefCounted

const PRESS := 0.135
const REFILL := 0.33

var change: Dictionary = {}
var stamp_id := ""
var stamp_center := Vector2.ZERO
var refill_center := Vector2.ZERO
var palette: Array = [0]
var slab_style := ThemeCatalog.STUDIO_START
var cut_effect := 0
var elapsed := 1.0
var raised := false
var glowing := false
var active := false

func start(result: Dictionary, id: String, center: Vector2, colors: Array, style: int, effect: int) -> void:
	change = result
	stamp_id = id
	stamp_center = center
	palette = colors
	slab_style = style
	cut_effect = effect
	elapsed = 0.0
	raised = false
	glowing = false
	active = true

func step(delta: float) -> void:
	if active:
		elapsed += delta
		if elapsed >= duration():
			active = false

func duration() -> float:
	if not change.refilled.is_empty():
		return 0.76
	return 0.52

func displace(streak: int, reduced: bool) -> Vector2:
	if not active or reduced or not glowing or streak < 3:
		return Vector2.ZERO
	var age := elapsed - REFILL
	return Vector2(sin(age * 113.0), cos(age * 121.0) * 0.45) * maxf(0.0, 1.0 - age * 4.1) * 5.0
