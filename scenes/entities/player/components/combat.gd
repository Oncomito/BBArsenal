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
	var away_direction: Vector2 = (actor.global_position - hit_enemy_position).normalized()
	if away_direction == Vector2.ZERO:
		away_direction = - incoming_direction
	if away_direction == Vector2.ZERO:
		away_direction = Vector2.UP

	var rebound_speed := minf(
		maxf(actor.velocity.length(), actor.normal_speed * actor.dash_speed_multiplier)
			* actor.dash_final_bounce_factor,
		actor.max_bounce_speed
	)
	actor.velocity = away_direction * rebound_speed
	actor.speed = rebound_speed
	actor._bounce_attack_timer = actor.bounce_attack_window
	actor._dash_hit_enemies.clear()
	actor._update_facing_direction(away_direction)
	actor.camera_shake(18.0, 0.22)
	actor.movement.finish_dash()

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