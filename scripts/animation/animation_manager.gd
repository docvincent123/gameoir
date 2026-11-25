class_name AnimationManager
extends RefCounted

const PRESS := 0.135
const REFILL := 0.33

var change: Dictionary = {}
var stamp_id := ""
var stamp_center := Vector2.ZERO
var refill_center := Vector2.ZERO
var palette: Array = [0]
var cut_effect := 0
var elapsed := 1.0
var raised := false
var glowing := false
var active := false

func start(result: Dictionary, id: String, center: Vector2, colors: Array, effect: int) -> void:
	change = result
	stamp_id = id
	stamp_center = center
	palette = colors
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

func cell_state(coordinate: Vector2i, occupied: bool, input: InputManager, preview: Dictionary) -> ClayCell.State:
	if input.touched_board and not preview.is_empty() and coordinate - input.anchor in preview.cells:
		return ClayCell.State.VALID_PREVIEW if input.valid else ClayCell.State.INVALID_PREVIEW
	if active:
		if coordinate in change.removed and elapsed < PRESS:
			return ClayCell.State.CUTTING
		if coordinate in change.refill:
			return ClayCell.State.REFILLING
	return ClayCell.State.FILLED if occupied else ClayCell.State.EMPTY
