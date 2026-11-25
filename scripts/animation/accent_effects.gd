class_name AccentEffects
extends Node2D

const FLARE := preload("res://assets/animations/refill_shine.png")
const SPARK := preload("res://assets/particles/spark.png")

var flash := AnimatedSprite2D.new()
var motion := AnimationPlayer.new()
var confetti: GPUParticles2D

func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 28.0)
	frames.set_animation_loop(&"default", false)
	for frame in 8:
		var region := AtlasTexture.new()
		region.atlas = FLARE
		region.region = Rect2(frame * 96, 0, 96, 96)
		region.filter_clip = true
		frames.add_frame(&"default", region)
	flash.name = "Glint"
	flash.sprite_frames = frames
	flash.hide()
	flash.animation_finished.connect(flash.hide)
	add_child(flash)

	var library := AnimationLibrary.new()
	var bloom := Animation.new()
	bloom.length = 0.29
	var track := bloom.add_track(Animation.TYPE_VALUE)
	bloom.track_set_path(track, NodePath("Glint:scale"))
	bloom.track_insert_key(track, 0.0, Vector2.ONE * 0.75)
	bloom.track_insert_key(track, 0.11, Vector2.ONE * 1.66)
	bloom.track_insert_key(track, 0.29, Vector2.ONE * 1.32)
	library.add_animation(&"bloom", bloom)
	motion.add_animation_library(&"", library)
	add_child(motion)

	if DisplayServer.get_name() != "headless":
		prepare_confetti()

func prepare_confetti() -> void:
	var emitter := GPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 28
	emitter.lifetime = 0.76
	emitter.explosiveness = 0.97
	emitter.local_coords = true
	emitter.texture = SPARK
	emitter.visibility_rect = Rect2(-950, -1100, 1900, 2200)
	var process := ParticleProcessMaterial.new()
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_DISABLE_Z, true)
	process.direction = Vector3.UP
	process.spread = 135.0
	process.initial_velocity_min = 175.0
	process.initial_velocity_max = 530.0
	process.gravity = Vector3(0, 680, 0)
	process.scale_min = 0.40
	process.scale_max = 1.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.57, 1.0])
	fade.colors = PackedColorArray([Color("#fff5af"), Color("#ffd05f"), Color(1.0, 0.56, 0.2, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	emitter.process_material = process
	add_child(emitter)
	confetti = emitter

func refill(at: Vector2) -> void:
	flash.position = at
	flash.show()
	flash.stop()
	flash.play()
	motion.stop()
	motion.play(&"bloom")

func celebrate(at: Vector2) -> void:
	if confetti != null:
		confetti.position = at
		confetti.restart()

func clear() -> void:
	flash.hide()
	motion.stop()
	if confetti != null:
		confetti.emitting = false
