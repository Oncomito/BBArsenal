@icon("res://assets/_project/node/combat.svg")
class_name PlayerCombat
extends Node2D

var actor: Player

func setup(player: Player) -> void:
	actor = player

func handle_speed_damage(current_speed: float) -> void:
	if current_speed <= 0.0:
		return

	var reference_speed := maxf(
		actor.normal_speed * actor.dash_speed_multiplier,
		1.0
	)
	var damage: float = actor.dash_damage * current_speed / reference_speed
	var player_center: Vector2 = actor.global_position + actor.player_hit_center_offset

	for enemy in actor.get_tree().get_nodes_in_group("enemy"):
		if not _is_valid_enemy(enemy) or actor._dash_hit_enemies.has(enemy):
			continue

		var enemy_center: Vector2 = enemy.global_position + actor.enemy_hit_center_offset
		if player_center.distance_to(enemy_center) > actor.dash_hit_radius:
			continue

		
		var hit_enemy_position: Vector2 = enemy.global_position
		var incoming_direction: Vector2 = actor.velocity.normalized()

		
		actor._dash_hit_enemies.append(enemy)
		enemy.take_damage(damage)
		actor.energize(5.0)
		actor._on_dash_hit(hit_enemy_position)

		if actor.is_dashing:
			bounce_to_next_enemy(hit_enemy_position, incoming_direction)
			
			
			return

func bounce_to_next_enemy(
	hit_enemy_position: Vector2,
	incoming_direction: Vector2
) -> void:
	var next_enemy := find_nearest_enemy_in_dash_cone(
		actor.global_position,
		hit_enemy_position,
		incoming_direction,
		actor.dash_chain_max_angle
	)

	if next_enemy == null:
		var away_direction: Vector2 = (actor.global_position - hit_enemy_position).normalized()
		if away_direction == Vector2.ZERO:
			away_direction = - incoming_direction
		if away_direction == Vector2.ZERO:
			away_direction = Vector2.UP

		var final_speed := minf(
			maxf(actor.velocity.length(), actor.normal_speed * actor.dash_speed_multiplier)
				* actor.dash_final_bounce_factor,
			actor.dash_chain_max_speed
		)
		actor.velocity = away_direction * final_speed
		actor._update_facing_direction(away_direction)
		actor.camera_shake(18.0, 0.22)
		actor.movement.finish_dash()
		return

	actor._dash_chain_active = true
	actor._dash_chain_target = next_enemy

	var direction_to_target: Vector2 = (next_enemy.global_position - actor.global_position).normalized()
	if direction_to_target == Vector2.ZERO:
		direction_to_target = incoming_direction
	if direction_to_target == Vector2.ZERO:
		direction_to_target = Vector2.UP

	var chain_speed := minf(
		maxf(actor.velocity.length(), actor.normal_speed * actor.dash_speed_multiplier)
			* actor.dash_enemy_bounce_factor,
		actor.dash_chain_max_speed
	)
	actor.velocity = direction_to_target * chain_speed
	actor.speed = chain_speed
	actor._update_facing_direction(direction_to_target)

	
	actor._invulnerability_timer = maxf(
		actor._invulnerability_timer,
		actor.dash_chain_invulnerability_duration
	)
	actor.is_invulnerable = true

	
	var distance: float = actor.global_position.distance_to(next_enemy.global_position)
	var travel_time: float = distance / maxf(chain_speed, 1.0) + actor.dash_chain_time_padding
	actor.dash_timer.start(clampf(
		travel_time,
		actor.dash_chain_min_segment_time,
		actor.dash_chain_max_segment_time
	))

	actor.camera_shake(14.0, 0.16)
	AudioManager.play_sfx("ting", 1.8, 1.0)

func steer_dash_chain() -> void:
	if not _is_valid_enemy(actor._dash_chain_target):
		var forward_direction: Vector2 = actor.velocity.normalized()
		if forward_direction == Vector2.ZERO:
			forward_direction = actor._get_facing_direction_vector()

		actor._dash_chain_target = find_nearest_enemy_in_dash_cone(
			actor.global_position,
			actor.global_position,
			forward_direction,
			actor.dash_chain_max_angle
		)
		if actor._dash_chain_target == null:
			actor.movement.finish_dash()
			return

	var direction: Vector2 = (actor._dash_chain_target.global_position - actor.global_position).normalized()
	if direction == Vector2.ZERO:
		return

	
	var current_speed: float = maxf(
		actor.velocity.length(),
		actor.normal_speed * actor.dash_speed_multiplier
	)
	actor.velocity = direction * current_speed
	actor._update_facing_direction(direction)

func find_nearest_enemy_in_dash_cone(
	distance_origin: Vector2,
	cone_origin: Vector2,
	forward_direction: Vector2,
	max_angle_degrees: float
) -> Node2D:
	var forward := forward_direction.normalized()
	if forward == Vector2.ZERO:
		return null

	var allowed_angle := deg_to_rad(clampf(max_angle_degrees, 0.0, 180.0))
	var minimum_dot := cos(allowed_angle)
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	for candidate in actor.get_tree().get_nodes_in_group("enemy"):
		if not _is_valid_enemy(candidate) or actor._dash_hit_enemies.has(candidate):
			continue

		var candidate_direction: Vector2 = candidate.global_position - cone_origin
		if candidate_direction.is_zero_approx():
			continue
		candidate_direction = candidate_direction.normalized()

		
		if forward.dot(candidate_direction) < minimum_dot:
			continue

		var distance: float = distance_origin.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = candidate

	return nearest_enemy

func _is_valid_enemy(candidate: Variant) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate is Node2D
		and candidate.is_inside_tree()
		and not candidate.is_queued_for_deletion()
		and candidate.has_method("take_damage")
	)

func can_parry() -> bool:
	return (
		not actor.is_dead
		and not actor.is_transitioning
		and not actor.get_tree().paused
		and not actor.is_attacking
		and not actor.is_shield_active
		and not actor.is_dashing
		and actor._locked_animation.is_empty()
		and actor.parry_cooldown_timer <= 0.0
	)

func perform_parry() -> void:
	if not can_parry():
		return

	actor.is_attacking = true
	actor.is_invulnerable = true
	actor._invulnerability_timer = maxf(
		actor._invulnerability_timer,
		actor.parry_invulnerability_duration
	)
	actor.parry_cooldown_timer = actor.parry_cooldown
	actor.parry_timer.start(0.1)
	check_parry()
	actor._play_locked_animation("parry_" + actor.facing_direction)

func check_parry() -> void:
	for projectile in actor.get_tree().get_nodes_in_group("projectile"):
		if (
			not is_instance_valid(projectile)
			or not projectile.has_method("parry")
			or projectile.get("is_parried")
		):
			continue

		if actor.global_position.distance_to(projectile.global_position) <= actor.parry_radius:
			projectile.parry(actor)
			actor._update_facing_direction_to_object(projectile.global_position)
			AudioManager.play_sfx("ting", 2.0, -8.0)
			successful_parry(projectile.global_position)
			return

func successful_parry(world_position: Vector2) -> void:
	actor._spawn_hit_effect(world_position, Vector2(3.0, 3.0), "holy")
	actor.camera_shake(14.0, 0.2)
	AudioManager.play_sfx("ting", 1.8, 3.0)
	actor.energize(10.0)