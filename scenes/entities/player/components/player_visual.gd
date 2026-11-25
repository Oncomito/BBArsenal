@tool
class_name PlayerVisual
extends Visual2D

var actor: Player
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _locked_animation: String = ""

func setup(_owner: Player) -> void:
	actor = _owner

func setup_flash_shader() -> void:
	var shader := load("res://shaders/white_flash.gdshader") as Shader
	if shader:
		actor.flash_material = ShaderMaterial.new()
		actor.flash_material.shader = shader
		actor.sprite.material = actor.flash_material

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

	if scaled_intensity >= _shake_intensity or _shake_timer <= 0.0:
		_shake_intensity = scaled_intensity
		_shake_duration = duration
		_shake_timer = duration

func update_camera_shake(delta: float) -> void:
	if not is_instance_valid(actor.camera):
		return

	if _shake_timer > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		var progress: float = _shake_timer / _shake_duration if _shake_duration > 0.0 else 0.0
		var strength: float = _shake_intensity * progress
		actor.camera.offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
	else:
		actor.camera.offset = Vector2.ZERO
		_shake_intensity = 0.0

func spawn_hit_effect(
	world_position: Vector2,
	effect_scale: Vector2,
	animation_name: String
) -> void:
	var current_scene: Node2D = actor.get_tree().current_scene
	if current_scene == null:
		return

	var hit := actor.HIT_EFFECT_SCENE.instantiate()
	hit.global_position = world_position
	hit.scale = effect_scale
	hit.animation_name = animation_name
	current_scene.call_deferred("add_child", hit)

func hitstop(time_scale: float = 0.05, duration: float = 0.05) -> void:
	Engine.time_scale = time_scale
	await actor.get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _play_animation(animation_name: String) -> void:
	if not _locked_animation.is_empty():
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)

func _play_locked_animation(animation_name: String) -> void:
	_locked_animation = animation_name
	sprite.play(animation_name)

func _update_movement_animation() -> void:
	if actor.is_dead or actor.is_transitioning:
		return

	var input_direction := Input.get_vector(
		"player_left", "player_right", "player_up", "player_down"
	)
	if actor.is_dashing:
		_play_animation("run_" + actor.facing_direction)
	elif not actor.is_attacking:
		if input_direction != Vector2.ZERO:
			_play_animation("run_" + actor.facing_direction)
		else:
			_play_animation("idle_" + actor.facing_direction)

func _on_animated_sprite_2d_animation_finished() -> void:
	if _locked_animation.is_empty() or sprite.animation != _locked_animation:
		return

	_locked_animation = ""
	if actor.is_dead or actor.is_transitioning or actor.is_attacking:
		return
	_update_movement_animation()
