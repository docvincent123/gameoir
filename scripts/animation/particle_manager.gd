class_name ParticleManager
extends RefCounted

const LIMIT := 124

class Particle:
	var life := 0.0
	var full_life := 1.0
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var radius := 0.0
	var gravity := 590.0
	var skin := 0
	var color := Color.WHITE
	var sprite := -1

var particles: Array[Particle] = []
var cursor := 0

func _init() -> void:
	for i in LIMIT:
		particles.append(Particle.new())

func burst(at: Vector2, count: int, skin: int, tint: Color, sparks := false, force := 1.0,
		sprite := -1) -> void:
	for i in count:
		var particle := particles[cursor]
		cursor = (cursor + 1) % LIMIT
		particle.full_life = randf_range(0.35, 0.79) * (1.45 if sparks else 1.0)
		particle.life = particle.full_life
		particle.position = at + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.velocity = Vector2.from_angle(randf_range(-PI * 0.99, -0.03)) * randf_range(90, 390) * force
		particle.radius = randf_range(6, 19) * force
		particle.gravity = 210.0 if sparks else 590.0
		particle.skin = skin
		particle.color = tint
		particle.sprite = ClayArt.Effect.GLINT if sparks and sprite < 0 else sprite

func tick(delta: float) -> bool:
	var was_active := false
	for particle in particles:
		if particle.life <= 0.0:
			continue
		was_active = true
		particle.life -= delta
		particle.position += particle.velocity * delta
		particle.velocity.y += particle.gravity * delta
	return was_active

func render(canvas: CanvasItem, art: ClayArt) -> void:
	for particle in particles:
		if particle.life <= 0.0:
			continue
		var ratio := particle.life / particle.full_life
		var fade := smoothstep(0.0, 0.4, ratio)
		var radius := particle.radius * lerpf(0.4, 1.0, fade)
		var color := Color(particle.color, fade)
		if particle.sprite >= 0:
			art.effect(canvas, particle.sprite, particle.position, radius * 2.6, color)
		else:
			art.cell(canvas, Rect2(particle.position - Vector2.ONE * radius, Vector2.ONE * radius * 2), particle.skin, ClayArt.CRUMB, color)

func clear() -> void:
	for particle in particles:
		particle.life = 0.0
