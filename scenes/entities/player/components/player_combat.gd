@tool
class_name PlayerCombat
extends Combat2D

var actor: Player
@onready var parry_timer: Timer = $ParryTimer

@export var ricochet_search_radius: float = 650.0
@export var knockback_force: float = 1100.0
@export var shield: PlayerShield:
	set(value):
		shield = value
		update_configuration_warnings()
var bounce_combo: int = 0

func setup(_owner: Player) -> void:
	actor = _owner

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
		bounce_combo += 1
		var combo_multiplier: float = 1.0 + (bounce_combo - 1) * 0.25
		enemy.take_damage(damage * combo_multiplier)
		if enemy.has_method("apply_knockback"):
			var push_direction: Vector2 = (enemy.global_position - actor.global_position).normalized()
			enemy.apply_knockback(push_direction * knockback_force)
		actor.energize(8.0)
		_on_dash_hit(hit_enemy_position)

		if actor.is_dashing or actor._bounce_attack_timer > 0.0:
			bounce_to_next_enemy(enemy, hit_enemy_position, incoming_direction)
			return

func _on_dash_hit(hit_position: Vector2) -> void:
	var pitch := minf(1.2 + bounce_combo * 0.15, 2.4)
	actor.visual.spawn_hit_effect(hit_position, Vector2(2.8, 2.8), "arcane")
	AudioManager.play_sfx("blast", pitch, -2.0)
	actor.camera_shake(14.0 + bounce_combo * 2.0, 0.18)
	actor.visual.hitstop(0.05, 0.045)

func _find_next_ricochet_target(exclude_enemy: Node2D) -> Node2D:
	var best_target: Node2D = null
	var closest_distance: float = ricochet_search_radius
	for enemy in actor.get_tree().get_nodes_in_group("enemy"):
		if (
			enemy == exclude_enemy
			or actor._dash_hit_enemies.has(enemy)
			or not _is_valid_enemy(enemy)
		):
			continue
		var distance: float = actor.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			best_target = enemy
	return best_target

func bounce_to_next_enemy(
	hit_enemy: Node2D,
	hit_enemy_position: Vector2,
	incoming_direction: Vector2
) -> void:
	var bounce_direction: Vector2
	var next_target := _find_next_ricochet_target(hit_enemy)
	if is_instance_valid(next_target):
		bounce_direction = (next_target.global_position - actor.global_position).normalized()
	else:
		bounce_direction = (actor.global_position - hit_enemy_position).normalized()
		if bounce_direction == Vector2.ZERO:
			bounce_direction = -incoming_direction
		if bounce_direction == Vector2.ZERO:
			bounce_direction = Vector2.UP

	var rebound_speed := minf(
		maxf(actor.velocity.length(), actor.normal_speed * actor.dash_speed_multiplier)
			* actor.dash_final_bounce_factor,
		actor.max_bounce_speed
	)
	actor.movement.finish_dash()
	actor.velocity = bounce_direction * rebound_speed
	actor.speed = rebound_speed
	actor.movement.lock_bounce_input(0.14)
	actor._bounce_attack_timer = actor.bounce_attack_window
	actor._update_facing_direction(bounce_direction)

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
		and actor.visual._locked_animation.is_empty()
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
	parry_timer.start(0.22)
	check_parry()
	actor.visual._play_locked_animation("parry_" + actor.facing_direction)

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

func _on_parry_timer_timeout() -> void:
	actor.is_attacking = false
	actor.visual._update_movement_animation()