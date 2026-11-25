class_name ParticleManager
extends RefCounted

const LIMIT := 124

class Particle:
	var life := 0.0
	var full_life := 1.0
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var radius := 0.0
	var spin := 0.0
	var skin := 0
	var color := Color.WHITE
	var star := false

var particles: Array[Particle] = []
var cursor := 0

func _init() -> void:
	for i in LIMIT:
		particles.append(Particle.new())

func burst(at: Vector2, count: int, skin: int, tint: Color, sparks := false, force := 1.0) -> void:
	for i in count:
		var particle := particles[cursor]
		cursor = (cursor + 1) % LIMIT
		particle.full_life = randf_range(0.35, 0.79) * (1.45 if sparks else 1.0)
		particle.life = particle.full_life
		particle.position = at + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.velocity = Vector2.from_angle(randf_range(-PI * 0.99, -0.03)) * randf_range(90, 390) * force
		particle.radius = randf_range(6, 19) * force
		particle.spin = randf_range(-0.4, 0.4)
		particle.skin = skin
		particle.color = tint
		particle.star = sparks

func tick(delta: float) -> bool:
	var was_active := false
	for particle in particles:
		if particle.life <= 0.0:
			continue
		was_active = true
		particle.life -= delta
		particle.position += particle.velocity * delta
		particle.velocity.y += 590.0 * delta
	return was_active

func render(canvas: CanvasItem, art: ClayArt) -> void:
	for particle in particles:
		if particle.life <= 0.0:
			continue
		var ratio := particle.life / particle.full_life
		var fade := smoothstep(0.0, 0.4, ratio)
		var radius := particle.radius * lerpf(0.4, 1.0, fade)
		var color := Color(particle.color, fade)
		if particle.star:
			art.sparkle(canvas, particle.position, radius, color, (1.0 - ratio) * particle.spin)
		else:
			art.cell(canvas, Rect2(particle.position - Vector2.ONE * radius, Vector2.ONE * radius * 2), particle.skin, 5, color)

func clear() -> void:
	for particle in particles:
		particle.life = 0.0
