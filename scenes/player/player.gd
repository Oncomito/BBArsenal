class_name Player
extends CharacterBody2D

# INFO: So, yeah, I actually changed the structure to be Object-Oriented Programming.
# Why? Because with OOP, all functions can be localized to specific uses.
# For example, func input_move is now localized inside MovementController because its uses are only to do player movement.
# You can say, it is like compartments for building, which makes the functions much more distinguishable.

# All global variable exist after the classes definition.

# WARN: This is not finished. I will probably refactor this again.

const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

signal health_changed(current_health: float, max_health: float)
signal energy_changed(current_energy: float, max_energy: float)
signal player_died
signal dash_count_changed(current_count: int, max_count: int)

@onready var movement: PlayerMovement = $Movement
@onready var visual: PlayerVisual = $Visual
@onready var combat: PlayerCombat = $Combat
@onready var resource: PlayerResource = $Resource

@export_group("Movement")
@export var speed: float = 1945.0
@export var acceleration: float = 1945.0
@export var friction: float = 1800.0
@export var dash_speed_multiplier: float = 2.5
@export_range(1.0, 2.0, 0.05) var dash_bounce_factor: float = 1.1
@export var dash_bounce_acceleration_multiplier: float = 1.12
@export var bounce_factor: float = 1.0
@export var min_bounce_speed: float = 0.0
@export var bounce_lockout: float = 0.06
@export var max_bounce_speed: float = 4200.0
@export var max_bounce_acceleration: float = 2800.0
@export var bounce_boost_decay: float = 2000.0

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Energy & Dash")
@export var max_energy: float = 100.0
@export var dash_energy_cost: float = 20.0
@export var dash_cooldown: float = 0.2
@export var dash_duration: float = 0.16
@export var energy_regen_rate: float = 10.0
@export var energy_regen_delay: float = 1.0
@export var energy_exhausted_regen_delay: float = 1.5
@export_range(0.1, 1.0, 0.05) var exhausted_speed_multiplier: float = 0.1
@export var dash_damage: float = 35.0
@export var parry_cooldown: float = 0.75
@export_range(0.0, 1.0, 0.05) var speed_damage_min_speed_ratio: float = 0.5
@export var dash_invulnerability_duration: float = 0.25
@export var dash_chain_invulnerability_duration: float = 0.15
@export var parry_invulnerability_duration: float = 0.2


@export var dash_enemy_bounce_factor: float = 1.0
@export var dash_final_bounce_factor: float = 1.02
@export var dash_chain_max_speed: float = 4200.0
@export var dash_chain_min_segment_time: float = 0.25
@export var dash_chain_max_segment_time: float = 4.0
@export var dash_chain_time_padding: float = 0.18


@export_range(0.0, 180.0, 1.0) var dash_chain_max_angle: float = 75.0
@export var dash_hit_radius: float = 200.0
@export var parry_radius: float = 140.0

@export_group("Shield")
@export var shield_drain_rate: float = 10.0
@export var shield_damage_energy_multiplier: float = 1.2

@export_group("Hit Detection")
@export var player_hit_center_offset: Vector2 = Vector2(0.0, -75.0)
@export var enemy_hit_center_offset: Vector2 = Vector2(0.0, -115.0)

@export_group("Camera Shake")
@export_range(0.0, 5.0, 0.1) var shake_multiplier: float = 1.0
@export var wall_hit_shake_min: float = 10.0
@export var wall_hit_shake_max: float = 28.0
@export var wall_hit_shake_duration: float = 0.15
@export var damage_shake_intensity: float = 48.0
@export var damage_shake_duration: float = 0.28


var normal_speed: float = speed
var base_acceleration: float = acceleration
var health: float = 100.0
var energy: float = 100.0
var energy_regen_wait_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var parry_cooldown_timer: float = 0.0
var _invulnerability_timer: float = 0.0
var _bounce_lock_timer: float = 0.0

var is_exhausted: bool = false
var is_dead: bool = false
var is_dashing: bool = false
var facing_direction: String = "down"
var is_invulnerable: bool = false
var is_attacking: bool = false
var is_shield_active: bool = false
var is_transitioning: bool = false


var _dash_hit_enemies: Array = []
var _dash_chain_active: bool = false
var _dash_chain_target: Node2D = null
var _locked_animation: String = ""

var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var flash_material: ShaderMaterial


@onready var animated_sprite: AnimatedSprite2D = %Sprite
@onready var camera: Camera2D = %Camera
@onready var dash_timer: Timer = %DashTimer
@onready var parry_timer: Timer = %ParryTimer
@onready var hitbox: Area2D = %Hitbox
@onready var shield: PlayerShield = %Shield


func _ready() -> void:
	movement.setup(self)
	combat.setup(self)
	resource.setup(self)
	visual.setup(self)

	add_to_group("player")
	GameManager.player_heal.connect(heal)
	GameManager.player_energize.connect(energize)

	if has_node("Shield") and is_instance_valid(shield):
		shield.setup(self)

	normal_speed = speed
	base_acceleration = acceleration
	health = max_health
	energy = max_energy
	is_exhausted = false
	is_dead = false

	visual.setup_flash_shader()
	health_changed.emit(health, max_health)
	_emit_energy_changed()

func _process(delta: float) -> void:
	visual.update_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_transitioning:
		return

	movement.update_before_physics(delta)
	resource.update_shield(delta)
	resource.update_energy_regeneration(delta)
	movement.input_move(delta)

	
	var pre_collision_velocity := velocity
	move_and_slide()
	movement.handle_bounce(pre_collision_velocity)

	var current_speed := velocity.length()
	var minimum_damage_speed := normal_speed * speed_damage_min_speed_ratio
	if is_dashing or current_speed >= minimum_damage_speed:
		combat.handle_speed_damage(current_speed)
	else:
		_dash_hit_enemies.clear()

	if is_attacking:
		combat.check_parry()


func can_dash() -> bool:
	return movement.can_dash()

func perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	movement.perform_dash(direction)

func _perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	perform_dash(direction)

func can_parry() -> bool:
	return combat.can_parry()

func perform_parry() -> void:
	combat.perform_parry()

func _perform_parry() -> void:
	perform_parry()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning or is_dead or get_tree().paused:
		return

	if event.is_action_pressed("player_dash") and can_dash():
		get_viewport().set_input_as_handled()
		perform_dash()
	elif event.is_action_pressed("player_shield") and not is_dashing:
		get_viewport().set_input_as_handled()
		toggle_shield()
	elif event.is_action_pressed("player_parry") and can_parry():
		get_viewport().set_input_as_handled()
		perform_parry()


func toggle_shield() -> void:
	resource.toggle_shield()

func _toggle_shield() -> void:
	toggle_shield()

func _activate_shield() -> void:
	resource.activate_shield()

func _deactivate_shield() -> void:
	resource.deactivate_shield()

func take_damage(amount: float) -> void:
	resource.take_damage(amount)

func heal(amount: float) -> void:
	resource.heal(amount)

func energize(amount: float) -> void:
	resource.energize(amount)

func die() -> void:
	if is_dead:
		return
	if is_shield_active:
		resource.deactivate_shield()
	is_dead = true
	velocity = Vector2.ZERO
	player_died.emit()


func _get_current_move_speed() -> float:
	if is_dashing:
		return normal_speed * dash_speed_multiplier
	if is_exhausted or energy <= 0.0:
		return normal_speed * exhausted_speed_multiplier
	return normal_speed

func get_max_dash_count() -> int:
	return int(ceil(max_energy / maxf(dash_energy_cost, 1.0)))

func _emit_energy_changed() -> void:
	energy_changed.emit(energy, max_energy)
	dash_count_changed.emit(get_dash_count(), get_max_dash_count())

func get_dash_count() -> int:
	if dash_energy_cost <= 0.0 or energy <= 0.0:
		return 0
	return int(ceil(energy / dash_energy_cost))

func get_dash_recharge_ratio() -> float:
	if max_energy <= 0.0:
		return 1.0
	return clampf(energy / max_energy, 0.0, 1.0)

func _update_facing_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) >= absf(direction.y):
		facing_direction = "right" if direction.x > 0.0 else "left"
	else:
		facing_direction = "down" if direction.y > 0.0 else "up"

func _update_facing_direction_to_object(world_position: Vector2) -> void:
	_update_facing_direction(world_position - global_position)

func _get_facing_direction_vector() -> Vector2:
	match facing_direction:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN


func _handle_bounce(pre_collision_velocity: Vector2) -> void:
	movement.handle_bounce(pre_collision_velocity)

func _handle_speed_damage(current_speed: float) -> void:
	combat.handle_speed_damage(current_speed)

func _check_parry() -> void:
	combat.check_parry()

func _handle_energy_regen(delta: float) -> void:
	resource.update_energy_regeneration(delta)

func _handle_shield(delta: float) -> void:
	resource.update_shield(delta)

func _on_dash_hit(hit_position: Vector2) -> void:
	_spawn_hit_effect(hit_position, Vector2(2.5, 2.5), "arcane")
	AudioManager.play_sfx("blast", 1.6, -4.0)
	camera_shake(10.0, 0.15)

func _on_successful_parry(world_position: Vector2) -> void:
	combat.successful_parry(world_position)

func _spawn_hit_effect(
	world_position: Vector2,
	effect_scale: Vector2,
	animation_name: String
) -> void:
	visual.spawn_hit_effect(world_position, effect_scale, animation_name)

func _setup_flash_shader() -> void:
	visual.setup_flash_shader()

func flash_white(duration: float = 0.1) -> void:
	visual.flash_white(duration)

func camera_shake(intensity: float, duration: float = 0.2) -> void:
	visual.camera_shake(intensity, duration)

func _update_camera_shake(delta: float) -> void:
	visual.update_camera_shake(delta)

func _input_move(delta: float) -> void:
	movement.input_move(delta)

func _decay_bounce_boost(delta: float) -> void:
	movement.decay_bounce_boost(delta)

func _update_timers(delta: float) -> void:
	movement.update_timers(delta)


func _update_movement_animation() -> void:
	if is_dead or is_transitioning:
		return

	var input_direction := Input.get_vector(
		"player_left", "player_right", "player_up", "player_down"
	)
	if is_dashing:
		_play_animation("run_" + facing_direction)
	elif not is_attacking:
		if input_direction != Vector2.ZERO:
			_play_animation("run_" + facing_direction)
		else:
			_play_animation("idle_" + facing_direction)

func _play_animation(animation_name: String) -> void:
	if not _locked_animation.is_empty():
		return
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func _play_locked_animation(animation_name: String) -> void:
	_locked_animation = animation_name
	animated_sprite.play(animation_name)

func _on_dash_timer_timeout() -> void:
	movement.on_dash_timer_timeout()

func _on_parry_timer_timeout() -> void:
	is_attacking = false
	_update_movement_animation()

func _on_animated_sprite_2d_animation_finished() -> void:
	if _locked_animation.is_empty() or animated_sprite.animation != _locked_animation:
		return

	_locked_animation = ""
	if is_dead or is_transitioning or is_attacking:
		return
	_update_movement_animation()


func _begin_transition_state() -> void:
	resource.deactivate_shield()
	is_transitioning = true
	is_invulnerable = true
	_invulnerability_timer = 0.0
	is_dashing = false
	is_attacking = false
	_dash_chain_active = false
	_dash_chain_target = null
	_locked_animation = ""
	velocity = Vector2.ZERO
	dash_timer.stop()
	parry_timer.stop()

func prepare_drop_in(target_global_position: Vector2) -> void:
	_begin_transition_state()
	global_position = target_global_position
	camera.reset_smoothing()
	facing_direction = "down"
	_play_animation("idle_down")

	animated_sprite.visible = true
	animated_sprite.modulate = Color.WHITE
	animated_sprite.scale = Vector2(3.6, 4.5)
	animated_sprite.position = Vector2(1.0, -2000.0)

func play_drop_in_animation(target_global_position: Vector2) -> void:
	prepare_drop_in(target_global_position)

	var drop_tween := create_tween()
	drop_tween.tween_property(
		animated_sprite,
		"position",
		Vector2(1.0, -60.0),
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop_tween.finished
	if not is_inside_tree():
		return

	AudioManager.play_sfx("blast", 1.15, -2.0)
	camera_shake(18.0, 0.25)
	_spawn_hit_effect(global_position, Vector2(5.0, 5.0), "holy")

	animated_sprite.scale = Vector2(4.7, 3.3)
	var bounce_tween := create_tween().set_parallel(true)
	bounce_tween.tween_property(
		animated_sprite,
		"scale",
		Vector2(3.8, 4.2),
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(
		animated_sprite,
		"position",
		Vector2(1.0, -240.0),
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await bounce_tween.finished
	if not is_inside_tree():
		return

	var settle_tween := create_tween().set_parallel(true)
	settle_tween.tween_property(
		animated_sprite,
		"scale",
		Vector2(4.0, 4.0),
		0.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	settle_tween.tween_property(
		animated_sprite,
		"position",
		Vector2(1.0, -60.0),
		0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await settle_tween.finished

	is_transitioning = false
	is_invulnerable = false

func play_jump_into_trapdoor(trapdoor_global_position: Vector2) -> void:
	_begin_transition_state()
	facing_direction = "down"
	_play_animation("idle_down")
	AudioManager.play_sfx("ting", 1.35, 0.0)

	var jump_up := create_tween().set_parallel(true)
	jump_up.tween_property(
		self,
		"global_position",
		trapdoor_global_position,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_up.tween_property(
		animated_sprite,
		"position",
		Vector2(1.0, -210.0),
		0.26
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_up.tween_property(
		animated_sprite,
		"scale",
		Vector2(4.4, 4.4),
		0.26
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await jump_up.finished
	if not is_inside_tree():
		return

	var fall_in := create_tween().set_parallel(true)
	fall_in.tween_property(
		animated_sprite,
		"position",
		Vector2(1.0, 30.0),
		0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_in.tween_property(
		animated_sprite,
		"scale",
		Vector2.ZERO,
		0.30
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fall_in.tween_property(
		animated_sprite,
		"modulate:a",
		0.0,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall_in.finished
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.2).timeout
