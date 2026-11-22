@tool
class_name PlayerMovement
extends Movement2D

@export_category("Movement")
@export var speed: float = 1945.0
@export var acceleration: float = 1945.0
@export var friction: float = 1800.0

@export_category("Energy")
@export var max_energy: float = 100.0
@export var energy_regen_rate: float = 10.0
@export var energy_regen_delay: float = 1.0
@export var energy_exhausted_regen_delay: float = 1.5
@export_range(0.1, 1.0, 0.05) var exhausted_speed_multiplier: float = 0.1

@export_category("Dash & Bounce")
@export var dash_energy_cost: float = 20.0
@export var dash_cooldown: float = 0.2
@export var dash_duration: float = 0.16
@export var dash_speed_multiplier: float = 2.5
@export_range(1.0, 2.0, 0.05) var dash_bounce_factor: float = 1.1
@export var dash_final_bounce_factor: float = 1.02
@export var dash_bounce_acceleration_multiplier: float = 1.12
@export var bounce_factor: float = 1.0
@export var bounce_lockout: float = 0.06

@export_group("Bounce Speed")
@export var min_bounce_speed: float = 0.0
@export var max_bounce_speed: float = 4200.0
@export var max_bounce_acceleration: float = 2800.0
@export var bounce_boost_decay: float = 2000.0
@export var bounce_attack_window: float = 0.75

@onready var dash_timer: Timer = $DashTimer

var actor: Player

var is_dashing: bool = false

var energy_regen_wait_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var _bounce_lock_timer: float = 0.0

func setup(player: Player) -> void:
	actor = player

func update_before_physics(delta: float) -> void:
	update_timers(delta)
	decay_bounce_boost(delta)

func update_timers(delta: float) -> void:
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	_bounce_lock_timer = maxf(_bounce_lock_timer - delta, 0.0)
	actor.combat._bounce_attack_timer = maxf(actor.combat._bounce_attack_timer - delta, 0.0)
	actor.combat.parry_cooldown_timer = maxf(actor.combat.parry_cooldown_timer - delta, 0.0)
	actor.combat._invulnerability_timer = maxf(actor.combat._invulnerability_timer - delta, 0.0)

	
	if not actor.is_transitioning:
		actor.combat.is_invulnerable = actor.combat._invulnerability_timer > 0.0

func decay_bounce_boost(delta: float) -> void:
	var target_speed: float = actor.get_current_move_speed()
	if speed > target_speed:
		speed = move_toward(
			speed,
			target_speed,
			delta * bounce_boost_decay
		)
	elif speed < target_speed:
		speed = target_speed

	if acceleration > actor.base_acceleration:
		acceleration = move_toward(
			acceleration,
			actor.base_acceleration,
			delta * bounce_boost_decay
		)

func input_move(delta: float) -> void:
	if _bounce_lock_timer > 0.0:
		return


	var input_direction := Input.get_vector(
		"player_left", "player_right", "player_up", "player_down"
	)
	var target_speed: float = actor.get_current_move_speed()

	if input_direction != Vector2.ZERO:
		actor.velocity = actor.velocity.move_toward(
			input_direction * target_speed,
			acceleration * delta
		)
		if actor.visual._locked_animation.is_empty() and not is_dashing:
			actor._update_facing_direction(input_direction)
	else:
		actor.velocity = actor.velocity.move_toward(
			Vector2.ZERO,
			friction * delta
		)

	actor.visual._update_movement_animation()

func handle_bounce(pre_collision_velocity: Vector2) -> void:
	if actor.get_slide_collision_count() == 0:
		return

	var reflected_velocity := pre_collision_velocity
	var did_bounce := false

	for collision_index in actor.get_slide_collision_count():
		var collision: KinematicCollision2D = actor.get_slide_collision(collision_index)
		var normal: Vector2 = collision.get_normal()

		
		if reflected_velocity.dot(normal) < -30.0:
			reflected_velocity = reflected_velocity.bounce(normal)
			did_bounce = true

	if not did_bounce:
		return

	actor.resource.energize(5.0)
	_bounce_lock_timer = bounce_lockout
	actor.combat._bounce_attack_timer = bounce_attack_window
	actor.combat._dash_hit_enemies.clear()

	var incoming_speed := pre_collision_velocity.length()
	var rebound_multiplier: float = dash_bounce_factor if is_dashing else bounce_factor
	var rebound_speed := maxf(incoming_speed * rebound_multiplier, min_bounce_speed)
	rebound_speed = minf(rebound_speed, max_bounce_speed)

	if is_dashing:
		rebound_speed = maxf(
			rebound_speed,
			actor.normal_speed * dash_speed_multiplier
		)
		rebound_speed = minf(rebound_speed, max_bounce_speed)
		acceleration = minf(
			maxf(acceleration, actor.base_acceleration)
				* dash_bounce_acceleration_multiplier,
			max_bounce_acceleration
		)
	else:
		acceleration = actor.base_acceleration

	speed = rebound_speed
	actor.velocity = reflected_velocity.normalized() * rebound_speed
	actor._update_facing_direction(actor.velocity.normalized())
	actor.visual._update_movement_animation()

	
	var impact_ratio := clampf(
		incoming_speed / maxf(actor.normal_speed * dash_speed_multiplier, 1.0),
		0.0,
		1.0
	)
	var shake_strength := lerpf(
		actor.wall_hit_shake_min,
		actor.wall_hit_shake_max,
		impact_ratio
	)
	actor.visual.camera_shake(shake_strength, actor.wall_hit_shake_duration)
	AudioManager.play_sfx("ting", 1.2 if is_dashing else 0.9, 0.0)

func can_dash() -> bool:
	return (
		not actor.is_dead
		and not actor.is_transitioning
		and not actor.get_tree().paused
		and dash_cooldown_timer <= 0.0
		and actor.energy >= dash_energy_cost
		and not actor.combat.is_attacking
		and actor.visual._locked_animation.is_empty()
	)

func perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_dash():
		return

	if actor.combat.is_shield_active:
		actor.combat.deactivate_shield()

	dash_cooldown_timer = dash_cooldown
	actor.energy = maxf(actor.energy - dash_energy_cost, 0.0)
	if actor.energy <= 0.0:
		actor.is_exhausted = true
		energy_regen_wait_timer = energy_exhausted_regen_delay
	else:
		energy_regen_wait_timer = energy_regen_delay
	actor._emit_energy_changed()

	is_dashing = true
	actor.combat.is_invulnerable = true
	actor.combat._invulnerability_timer = maxf(
		actor.combat._invulnerability_timer,
		actor.combat.dash_invulnerability_duration
	)

	
	actor.combat._dash_hit_enemies.clear()
	dash_timer.start(dash_duration)

	speed = actor.normal_speed * dash_speed_multiplier

	var dash_direction := direction
	if dash_direction == Vector2.ZERO:
		dash_direction = Input.get_vector(
			"player_left", "player_right", "player_up", "player_down"
		)
	if dash_direction == Vector2.ZERO:
		dash_direction = actor._get_facing_direction_vector()
	else:
		dash_direction = dash_direction.normalized()
		actor._update_facing_direction(dash_direction)

	
	actor.velocity = dash_direction * speed
	actor.visual.flash_white(0.12)

func finish_dash() -> void:
	dash_timer.stop()
	is_dashing = false
	speed = actor.get_current_move_speed()
	acceleration = actor.base_acceleration

	# if actor._locked_animation.begins_with("charge_"):
	# 	actor._locked_animation = ""
	actor.visual._update_movement_animation()

func _on_dash_timer_timeout() -> void:
	finish_dash()
