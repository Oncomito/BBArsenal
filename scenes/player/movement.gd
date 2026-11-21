class_name PlayerMovement
extends Node

var actor: Player

func setup(player: Player) -> void:
	actor = player

func update_before_physics(delta: float) -> void:
	update_timers(delta)
	decay_bounce_boost(delta)

func update_timers(delta: float) -> void:
	actor.dash_cooldown_timer = maxf(actor.dash_cooldown_timer - delta, 0.0)
	actor.parry_cooldown_timer = maxf(actor.parry_cooldown_timer - delta, 0.0)
	actor._invulnerability_timer = maxf(actor._invulnerability_timer - delta, 0.0)
	actor._bounce_lock_timer = maxf(actor._bounce_lock_timer - delta, 0.0)

	
	if not actor.is_transitioning:
		actor.is_invulnerable = actor._invulnerability_timer > 0.0

func decay_bounce_boost(delta: float) -> void:
	var target_speed: float = actor._get_current_move_speed()
	if actor.speed > target_speed:
		actor.speed = move_toward(
			actor.speed,
			target_speed,
			delta * actor.bounce_boost_decay
		)
	elif actor.speed < target_speed:
		actor.speed = target_speed

	if actor.acceleration > actor.base_acceleration:
		actor.acceleration = move_toward(
			actor.acceleration,
			actor.base_acceleration,
			delta * actor.bounce_boost_decay
		)

func input_move(delta: float) -> void:
	if actor._bounce_lock_timer > 0.0:
		return

	
	if actor._dash_chain_active:
		actor.combat.steer_dash_chain()
		return

	var input_direction := Input.get_vector(
		"player_left", "player_right", "player_up", "player_down"
	)
	var target_speed: float = actor._get_current_move_speed()

	if input_direction != Vector2.ZERO:
		actor.velocity = actor.velocity.move_toward(
			input_direction * target_speed,
			actor.acceleration * delta
		)
		if actor._locked_animation.is_empty() and not actor.is_dashing:
			actor._update_facing_direction(input_direction)
	else:
		actor.velocity = actor.velocity.move_toward(
			Vector2.ZERO,
			actor.friction * delta
		)

	actor._update_movement_animation()

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

	actor.energize(5.0)
	actor._bounce_lock_timer = actor.bounce_lockout

	var incoming_speed := pre_collision_velocity.length()
	var rebound_multiplier: float = actor.dash_bounce_factor if actor.is_dashing else actor.bounce_factor
	var rebound_speed := maxf(incoming_speed * rebound_multiplier, actor.min_bounce_speed)
	rebound_speed = minf(rebound_speed, actor.max_bounce_speed)

	if actor.is_dashing:
		rebound_speed = maxf(
			rebound_speed,
			actor.normal_speed * actor.dash_speed_multiplier
		)
		rebound_speed = minf(rebound_speed, actor.max_bounce_speed)
		actor.acceleration = minf(
			maxf(actor.acceleration, actor.base_acceleration)
				* actor.dash_bounce_acceleration_multiplier,
			actor.max_bounce_acceleration
		)
	else:
		actor.acceleration = actor.base_acceleration

	actor.speed = rebound_speed
	actor.velocity = reflected_velocity.normalized() * rebound_speed
	actor._update_facing_direction(actor.velocity.normalized())
	actor._update_movement_animation()

	
	var impact_ratio := clampf(
		incoming_speed / maxf(actor.normal_speed * actor.dash_speed_multiplier, 1.0),
		0.0,
		1.0
	)
	var shake_strength := lerpf(
		actor.wall_hit_shake_min,
		actor.wall_hit_shake_max,
		impact_ratio
	)
	actor.camera_shake(shake_strength, actor.wall_hit_shake_duration)
	AudioManager.play_sfx("ting", 1.2 if actor.is_dashing else 0.9, 0.0)

func can_dash() -> bool:
	return (
		not actor.is_dead
		and not actor.is_transitioning
		and not actor.get_tree().paused
		and actor.dash_cooldown_timer <= 0.0
		and actor.energy >= actor.dash_energy_cost
		and not actor.is_attacking
		and actor._locked_animation.is_empty()
	)

func perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_dash():
		return

	if actor.is_shield_active:
		actor.resource.deactivate_shield()

	actor.dash_cooldown_timer = actor.dash_cooldown
	actor.energy = maxf(actor.energy - actor.dash_energy_cost, 0.0)
	if actor.energy <= 0.0:
		actor.is_exhausted = true
		actor.energy_regen_wait_timer = actor.energy_exhausted_regen_delay
	else:
		actor.energy_regen_wait_timer = actor.energy_regen_delay
	actor._emit_energy_changed()

	actor.is_dashing = true
	actor.is_invulnerable = true
	actor._invulnerability_timer = maxf(
		actor._invulnerability_timer,
		actor.dash_invulnerability_duration
	)

	
	actor._dash_hit_enemies.clear()
	actor._dash_chain_active = false
	actor._dash_chain_target = null
	actor.dash_timer.start(actor.dash_duration)

	actor.speed = actor.normal_speed * actor.dash_speed_multiplier

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

	
	actor.velocity = dash_direction * actor.speed
	actor.flash_white(0.12)
	actor._play_locked_animation("charge_" + actor.facing_direction)

func finish_dash() -> void:
	actor.dash_timer.stop()
	actor.is_dashing = false
	actor.speed = actor._get_current_move_speed()
	actor.acceleration = actor.base_acceleration
	actor._dash_chain_active = false
	actor._dash_chain_target = null

	if actor._locked_animation.begins_with("charge_"):
		actor._locked_animation = ""
	actor._update_movement_animation()

func on_dash_timer_timeout() -> void:
	finish_dash()