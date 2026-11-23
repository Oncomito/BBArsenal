@tool
class_name PlayerCombat
extends Combat2D

@export_category("Energy & Dash")
@export var dash_damage: float = 35.0
@export var parry_cooldown: float = 0.75
@export_range(0.0, 1.0, 0.05) var speed_damage_min_speed_ratio: float = 0.5
@export var dash_invulnerability_duration: float = 0.25
@export var parry_invulnerability_duration: float = 0.2
@export var dash_hit_radius: float = 200.0
@export var parry_radius: float = 140.0
@export var ricochet_search_radius: float = 650.0
@export var knockback_force: float = 1100.0

var bounce_combo: int = 0

@export_category("Hit Detection")
@export var player_hit_center_offset: Vector2 = Vector2(0.0, -75.0)
@export var enemy_hit_center_offset: Vector2 = Vector2(0.0, -115.0)

@onready var parry_timer: Timer = $ParryTimer

@export_category("Shield")
@export var shield_drain_rate: float = 10.0
@export var shield_damage_energy_multiplier: float = 1.2
@export var shield: PlayerShield:
	set(value):
		shield = value
		update_configuration_warnings()

var actor: Player

var is_invulnerable: bool = false
var is_attacking: bool = false
var is_shield_active: bool = false
var _dash_hit_enemies: Array = []

var parry_cooldown_timer: float = 0.0
var _invulnerability_timer: float = 0.0
var _bounce_attack_timer: float = 0.0

func setup(player: Player) -> void:
	actor = player

func handle_speed_damage(current_speed: float) -> void:
	if current_speed <= 0.0:
		return

	var reference_speed := maxf(
		actor.normal_speed * actor.movement.dash_speed_multiplier,
		1.0
	)
	var damage: float = dash_damage * current_speed / reference_speed
	var player_center: Vector2 = actor.global_position + player_hit_center_offset

	for enemy in actor.get_tree().get_nodes_in_group("enemy"):
		if not _is_valid_enemy(enemy) or _dash_hit_enemies.has(enemy):
			continue

		var enemy_center: Vector2 = enemy.global_position + enemy_hit_center_offset
		if player_center.distance_to(enemy_center) > dash_hit_radius:
			continue

		
		var hit_enemy_position: Vector2 = enemy.global_position
		var incoming_direction: Vector2 = actor.velocity.normalized()

		
		_dash_hit_enemies.append(enemy)
		bounce_combo += 1
		var combo_multiplier: float = 1.0 + (bounce_combo - 1) * 0.25
		enemy.take_damage(damage * combo_multiplier)
		if enemy.has_method("apply_knockback"):
			var push_dir: Vector2 = (enemy.global_position - actor.global_position).normalized()
			enemy.apply_knockback(push_dir * knockback_force)
		actor.resource.energize(8.0)
		_on_dash_hit(hit_enemy_position)

func _on_dash_hit(hit_position: Vector2) -> void:
	var pitch := minf(1.2 + bounce_combo * 0.15, 2.4)
	actor.visual.spawn_hit_effect(hit_position, Vector2(2.8, 2.8), "arcane")
	AudioManager.play_sfx("blast", pitch, -2.0)
	actor.visual.camera_shake(14.0 + bounce_combo * 2.0, 0.18)
	actor.visual.hitstop(0.05, 0.045)
	
func _find_next_ricochet_target(exclude_enemy: Node2D) -> Node2D:
	var best_target: Node2D = null
	var closest_dist: float = ricochet_search_radius
	for enemy in actor.get_tree().get_nodes_in_group("enemy"):
		if enemy == exclude_enemy or not _is_valid_enemy(enemy):
			continue
		var dist := actor.global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			best_target = enemy
	return best_target

func bounce_to_next_enemy(
	hit_enemy: Node2D,
	hit_enemy_position: Vector2,
	incoming_direction: Vector2
) -> void:
	var bounce_dir: Vector2
	var next_target := _find_next_ricochet_target(hit_enemy)
	if is_instance_valid(next_target):
		bounce_dir = (next_target.global_position - actor.global_position).normalized()
	else:
		bounce_dir = (actor.global_position - hit_enemy_position).normalized()
		if bounce_dir == Vector2.ZERO:
			bounce_dir = -incoming_direction
	var rebound_speed := minf(
		maxf(actor.velocity.length(), actor.normal_speed * actor.movement.dash_speed_multiplier)
			* actor.movement.dash_final_bounce_factor,
		actor.movement.max_bounce_speed
	)
	actor.velocity = bounce_dir * rebound_speed
	actor.movement.speed = rebound_speed
	actor.movement._bounce_lock_timer = 0.14 
	_bounce_attack_timer = actor.movement.bounce_attack_window
	
	_dash_hit_enemies = [hit_enemy]
	actor._update_facing_direction(bounce_dir)
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
		and not is_attacking
		and not is_shield_active
		and not actor.movement.is_dashing
		and actor.visual._locked_animation.is_empty()
		and parry_cooldown_timer <= 0.0
	)

func perform_parry() -> void:
	if not can_parry():
		return

	is_attacking = true
	is_invulnerable = true
	_invulnerability_timer = maxf(
		_invulnerability_timer,
		parry_invulnerability_duration
	)
	parry_cooldown_timer = parry_cooldown
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

		if actor.global_position.distance_to(projectile.global_position) <= parry_radius:
			projectile.parry(actor)
			actor._update_facing_direction_to_object(projectile.global_position)
			AudioManager.play_sfx("ting", 2.0, -8.0)
			successful_parry(projectile.global_position)
			return

func successful_parry(world_position: Vector2) -> void:
	actor.visual.spawn_hit_effect(world_position, Vector2(3.0, 3.0), "holy")
	actor.visual.camera_shake(14.0, 0.2)
	AudioManager.play_sfx("ting", 1.8, 3.0)
	actor.resource.energize(10.0)

func toggle_shield() -> void:
	if (
		actor.is_dead
		or actor.is_transitioning
		or actor.get_tree().paused
		or actor.movement.is_dashing
	):
		return

	if is_shield_active:
		deactivate_shield()
	elif actor.energy > 0.0 and not actor.is_exhausted:
		activate_shield()

func activate_shield() -> void:
	is_shield_active = true
	if is_instance_valid(shield):
		shield.activate()

func deactivate_shield() -> void:
	is_shield_active = false
	if is_instance_valid(shield):
		shield.deactivate()

func _on_parry_timer_timeout() -> void:
	is_attacking = false
	actor.visual._update_movement_animation()
