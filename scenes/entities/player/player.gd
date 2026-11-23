@tool
@icon("res://assets/_project/node/player.svg")
class_name Player
extends Entity2D

# INFO: So, yeah, I actually changed the structure to be Object-Oriented Programming.
# Why? Because with OOP, all functions can be localized to specific uses.
# For example, func input_move is now localized inside MovementController because its uses are only to do player movement.
# You can say, it is like compartments for building, which makes the functions much more distinguishable.

# All global variable exist after the classes definition.

# WARN: This is not finished. I will probably refactor this again.

signal health_changed(current_health: float, max_health: float)
signal energy_changed(current_energy: float, max_energy: float)
signal player_died
signal dash_count_changed(current_count: int, max_count: int)

@export_category("Camera Shake")
@export_range(0.0, 5.0, 0.1) var shake_multiplier: float = 1.0
@export var wall_hit_shake_min: float = 10.0
@export var wall_hit_shake_max: float = 28.0
@export var wall_hit_shake_duration: float = 0.15
@export var damage_shake_intensity: float = 48.0
@export var damage_shake_duration: float = 0.28

@onready var normal_speed: float = movement.speed
@onready var base_acceleration: float = movement.acceleration
@onready var energy: float = movement.max_energy

var is_exhausted: bool = false

var facing_direction: String = "down"
var is_transitioning: bool = false

var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var flash_material: ShaderMaterial

func _ready() -> void:
	super._ready()

	controllable = true

	movement.setup(self)
	combat.setup(self)
	resource.setup(self)
	visual.setup(self)

	if Engine.is_editor_hint():
		return

	add_to_group("player")
	GameManager.player_heal.connect(resource.heal)
	GameManager.player_energize.connect(resource.energize)

	if has_node("Shield") and is_instance_valid(combat.shield):
		combat.shield.setup(self)

	normal_speed = movement.speed
	base_acceleration = movement.acceleration
	energy = movement.max_energy
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
	var minimum_damage_speed: float = normal_speed * combat.speed_damage_min_speed_ratio
	if current_speed >= minimum_damage_speed:
		combat.handle_speed_damage(current_speed)
	elif combat._bounce_attack_timer <= 0.0:
		combat._dash_hit_enemies.clear()
		combat.bounce_combo = 0

	if combat.is_attacking:
		combat.check_parry()


func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning or is_dead or get_tree().paused:
		return

	if event.is_action_pressed("player_dash") and movement.can_dash():
		get_viewport().set_input_as_handled()
		movement.perform_dash()
	elif event.is_action_pressed("player_shield") and not movement.is_dashing:
		get_viewport().set_input_as_handled()
		combat.toggle_shield()
	elif event.is_action_pressed("player_parry") and combat.can_parry():
		get_viewport().set_input_as_handled()
		combat.perform_parry()

func die() -> void:
	if is_dead:
		return
	if combat.is_shield_active:
		resource.deactivate_shield()
	is_dead = true
	velocity = Vector2.ZERO
	player_died.emit()


func get_current_move_speed() -> float:
	if movement.is_dashing:
		return normal_speed * movement.dash_speed_multiplier
	if is_exhausted or energy <= 0.0:
		return normal_speed * combat.exhausted_speed_multiplier
	return normal_speed

func get_max_dash_count() -> int:
	return int(ceil(movement.max_energy / maxf(movement.dash_energy_cost, 1.0)))

func _emit_energy_changed() -> void:
	energy_changed.emit(energy, movement.max_energy)
	dash_count_changed.emit(get_dash_count(), get_max_dash_count())

func get_dash_count() -> int:
	if movement.dash_energy_cost <= 0.0 or energy <= 0.0:
		return 0
	return int(ceil(energy / movement.dash_energy_cost))

func get_dash_recharge_ratio() -> float:
	if movement.max_energy <= 0.0:
		return 1.0
	return clampf(energy / movement.max_energy, 0.0, 1.0)

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

func _begin_transition_state() -> void:
	combat.deactivate_shield()
	is_transitioning = true
	combat.is_invulnerable = true
	combat._invulnerability_timer = 0.0
	movement.is_dashing = false
	combat.is_attacking = false
	visual._locked_animation = ""
	velocity = Vector2.ZERO
	movement.dash_timer.stop()
	combat.parry_timer.stop()

func prepare_drop_in(target_global_position: Vector2) -> void:
	_begin_transition_state()
	global_position = target_global_position
	camera.reset_smoothing()
	facing_direction = "down"
	visual._play_animation("idle_down")

	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(3.6, 4.5)
	sprite.position = Vector2(1.0, -2000.0)

func play_drop_in_animation(target_global_position: Vector2) -> void:
	prepare_drop_in(target_global_position)

	var drop_tween := create_tween()
	drop_tween.tween_property(
		sprite,
		"position",
		Vector2(1.0, -60.0),
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop_tween.finished
	if not is_inside_tree():
		return

	AudioManager.play_sfx("blast", 1.15, -2.0)
	visual.camera_shake(18.0, 0.25)
	visual.spawn_hit_effect(global_position, Vector2(5.0, 5.0), "holy")

	sprite.scale = Vector2(4.7, 3.3)
	var bounce_tween := create_tween().set_parallel(true)
	bounce_tween.tween_property(
		sprite,
		"scale",
		Vector2(3.8, 4.2),
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(
		sprite,
		"position",
		Vector2(1.0, -240.0),
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await bounce_tween.finished
	if not is_inside_tree():
		return

	var settle_tween := create_tween().set_parallel(true)
	settle_tween.tween_property(
		sprite,
		"scale",
		Vector2(4.0, 4.0),
		0.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	settle_tween.tween_property(
		sprite,
		"position",
		Vector2(1.0, -60.0),
		0.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await settle_tween.finished

	is_transitioning = false
	combat.is_invulnerable = false

func play_jump_into_trapdoor(trapdoor_global_position: Vector2) -> void:
	_begin_transition_state()
	facing_direction = "down"
	visual._play_animation("idle_down")
	AudioManager.play_sfx("ting", 1.35, 0.0)

	var jump_up := create_tween().set_parallel(true)
	jump_up.tween_property(
		self,
		"global_position",
		trapdoor_global_position,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_up.tween_property(
		sprite,
		"position",
		Vector2(1.0, -210.0),
		0.26
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_up.tween_property(
		sprite,
		"scale",
		Vector2(4.4, 4.4),
		0.26
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await jump_up.finished
	if not is_inside_tree():
		return

	var fall_in := create_tween().set_parallel(true)
	fall_in.tween_property(
		sprite,
		"position",
		Vector2(1.0, 30.0),
		0.30
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_in.tween_property(
		sprite,
		"scale",
		Vector2.ZERO,
		0.30
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fall_in.tween_property(
		sprite,
		"modulate:a",
		0.0,
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall_in.finished
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.2).timeout
