class_name PlayerVisual
extends Node2D


const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

var actor: Player

func setup(player: Player) -> void:
	actor = player

func setup_flash_shader() -> void:
	var shader := load("res://shaders/white_flash.gdshader") as Shader
	if shader:
		actor.flash_material = ShaderMaterial.new()
		actor.flash_material.shader = shader
		actor.animated_sprite.material = actor.flash_material

func flash_white(duration: float = 0.1) -> void:
	if actor.flash_material == null:
		return

	actor.flash_material.set_shader_parameter("flash", true)
	var material_ref: ShaderMaterial = actor.flash_material
	actor.get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(material_ref):
			material_ref.set_shader_parameter("flash", false)
	)

func camera_shake(intensity: float, duration: float = 0.2) -> void:
	var scaled_intensity: float = intensity * actor.shake_multiplier
	if scaled_intensity <= 0.0 or duration <= 0.0:
		return

	if scaled_intensity >= actor._shake_intensity or actor._shake_timer <= 0.0:
		actor._shake_intensity = scaled_intensity
		actor._shake_duration = duration
		actor._shake_timer = duration

func update_camera_shake(delta: float) -> void:
	if not is_instance_valid(actor.camera):
		return

	if actor._shake_timer > 0.0:
		actor._shake_timer = maxf(actor._shake_timer - delta, 0.0)
		var progress: float = actor._shake_timer / actor._shake_duration if actor._shake_duration > 0.0 else 0.0
		var strength: float = actor._shake_intensity * progress
		actor.camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
	else:
		actor.camera.offset = Vector2.ZERO
		actor._shake_intensity = 0.0

func spawn_hit_effect(
	world_position: Vector2,
	effect_scale: Vector2,
	animation_name: String
) -> void:
	var current_scene: Node2D = actor.get_tree().current_scene
	if current_scene == null:
		return

	var hit := HIT_EFFECT_SCENE.instantiate()
	hit.global_position = world_position
	hit.scale = effect_scale
	hit.animation_name = animation_name
	current_scene.call_deferred("add_child", hit)