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


class MovementController:
	var actor: Variant

	func _init(owner: Variant) -> void:
		actor = owner

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
			actor.combat_controller.steer_dash_chain()
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
			actor.resources_controller.deactivate_shield()

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

class CombatController:
	var actor: Variant

	func _init(owner: Variant) -> void:
		actor = owner

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
			actor.movement_controller.finish_dash()
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
				actor.movement_controller.finish_dash()
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

class ResourceController:
	var actor: Variant

	func _init(owner: Variant) -> void:
		actor = owner

	func update_energy_regeneration(delta: float) -> void:
		if actor.is_shield_active:
			return
		if actor.energy_regen_wait_timer > 0.0:
			actor.energy_regen_wait_timer = maxf(actor.energy_regen_wait_timer - delta, 0.0)
			return
		if actor.energy < actor.max_energy:
			actor.energy = minf(
				actor.energy + actor.energy_regen_rate * delta,
				actor.max_energy
			)
			if actor.is_exhausted and actor.energy > 0.0:
				actor.is_exhausted = false
			actor._emit_energy_changed()

	func update_shield(delta: float) -> void:
		if not actor.is_shield_active:
			return
		if actor.is_dashing or actor.is_dead or actor.is_transitioning:
			deactivate_shield()
			return

		actor.energy = maxf(actor.energy - actor.shield_drain_rate * delta, 0.0)
		actor._emit_energy_changed()
		if actor.energy <= 0.0:
			mark_exhausted()
			deactivate_shield()

	func toggle_shield() -> void:
		if (
			actor.is_dead
			or actor.is_transitioning
			or actor.get_tree().paused
			or actor.is_dashing
		):
			return

		if actor.is_shield_active:
			deactivate_shield()
		elif actor.energy > 0.0 and not actor.is_exhausted:
			activate_shield()

	func activate_shield() -> void:
		actor.is_shield_active = true
		if is_instance_valid(actor.shield):
			actor.shield.activate()

	func deactivate_shield() -> void:
		actor.is_shield_active = false
		if is_instance_valid(actor.shield):
			actor.shield.deactivate()

	func mark_exhausted() -> void:
		actor.is_exhausted = true
		actor.energy_regen_wait_timer = actor.energy_exhausted_regen_delay

	func take_damage(amount: float) -> void:
		if actor.is_dead or amount <= 0.0 or actor.is_invulnerable:
			return

		if actor.is_shield_active:
			var energy_absorbed: float = amount * actor.shield_damage_energy_multiplier
			actor.energy = maxf(actor.energy - energy_absorbed, 0.0)
			actor._emit_energy_changed()
			actor.camera_shake(8.0, 0.15)
			if AudioManager:
				AudioManager.play_sfx("blast", 2.0, -4.0)
			if actor.energy <= 0.0:
				mark_exhausted()
				deactivate_shield()
			return

		
		if actor.is_attacking:
			actor.combat_controller.successful_parry(actor.global_position)
			return

		actor.health = clampf(actor.health - amount, 0.0, actor.max_health)
		actor.health_changed.emit(actor.health, actor.max_health)
		actor.camera_shake(actor.damage_shake_intensity, actor.damage_shake_duration)
		if actor.health <= 0.0:
			actor.die()

	func heal(amount: float) -> void:
		if actor.is_dead or amount <= 0.0:
			return
		actor.health = clampf(actor.health + amount, 0.0, actor.max_health)
		actor.health_changed.emit(actor.health, actor.max_health)

	func energize(amount: float) -> void:
		if actor.is_dead:
			return

		
		var energy_change := -amount if actor.is_shield_active and amount > 0.0 else amount
		actor.energy = clampf(actor.energy + energy_change, 0.0, actor.max_energy)
		actor._emit_energy_changed()

		if actor.is_shield_active and actor.energy <= 0.0:
			mark_exhausted()
			deactivate_shield()

class VisualController:
	const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

	var actor: Variant

	func _init(owner: Variant) -> void:
		actor = owner

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


var movement_controller
var combat_controller
var resources_controller
var visual_controller


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var dash_timer: Timer = %DashTimer
@onready var parry_timer: Timer = %ParryTimer
@onready var hitbox: Area2D = $Hitbox
@onready var shield: PlayerShield = $Shield


func _ready() -> void:
	movement_controller = MovementController.new(self)
	combat_controller = CombatController.new(self)
	resources_controller = ResourceController.new(self)
	visual_controller = VisualController.new(self)

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

	visual_controller.setup_flash_shader()
	health_changed.emit(health, max_health)
	_emit_energy_changed()

func _process(delta: float) -> void:
	visual_controller.update_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_transitioning:
		return

	movement_controller.update_before_physics(delta)
	resources_controller.update_shield(delta)
	resources_controller.update_energy_regeneration(delta)
	movement_controller.input_move(delta)

	
	var pre_collision_velocity := velocity
	move_and_slide()
	movement_controller.handle_bounce(pre_collision_velocity)

	var current_speed := velocity.length()
	var minimum_damage_speed := normal_speed * speed_damage_min_speed_ratio
	if is_dashing or current_speed >= minimum_damage_speed:
		combat_controller.handle_speed_damage(current_speed)
	else:
		_dash_hit_enemies.clear()

	if is_attacking:
		combat_controller.check_parry()


func can_dash() -> bool:
	return movement_controller.can_dash()

func perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	movement_controller.perform_dash(direction)

func _perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	perform_dash(direction)

func can_parry() -> bool:
	return combat_controller.can_parry()

func perform_parry() -> void:
	combat_controller.perform_parry()

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
	resources_controller.toggle_shield()

func _toggle_shield() -> void:
	toggle_shield()

func _activate_shield() -> void:
	resources_controller.activate_shield()

func _deactivate_shield() -> void:
	resources_controller.deactivate_shield()

func take_damage(amount: float) -> void:
	resources_controller.take_damage(amount)

func heal(amount: float) -> void:
	resources_controller.heal(amount)

func energize(amount: float) -> void:
	resources_controller.energize(amount)

func die() -> void:
	if is_dead:
		return
	if is_shield_active:
		resources_controller.deactivate_shield()
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
	movement_controller.handle_bounce(pre_collision_velocity)

func _handle_speed_damage(current_speed: float) -> void:
	combat_controller.handle_speed_damage(current_speed)

func _check_parry() -> void:
	combat_controller.check_parry()

func _handle_energy_regen(delta: float) -> void:
	resources_controller.update_energy_regeneration(delta)

func _handle_shield(delta: float) -> void:
	resources_controller.update_shield(delta)

func _on_dash_hit(hit_position: Vector2) -> void:
	_spawn_hit_effect(hit_position, Vector2(2.5, 2.5), "arcane")
	AudioManager.play_sfx("blast", 1.6, -4.0)
	camera_shake(10.0, 0.15)

func _on_successful_parry(world_position: Vector2) -> void:
	combat_controller.successful_parry(world_position)

func _spawn_hit_effect(
	world_position: Vector2,
	effect_scale: Vector2,
	animation_name: String
) -> void:
	visual_controller.spawn_hit_effect(world_position, effect_scale, animation_name)

func _setup_flash_shader() -> void:
	visual_controller.setup_flash_shader()

func flash_white(duration: float = 0.1) -> void:
	visual_controller.flash_white(duration)

func camera_shake(intensity: float, duration: float = 0.2) -> void:
	visual_controller.camera_shake(intensity, duration)

func _update_camera_shake(delta: float) -> void:
	visual_controller.update_camera_shake(delta)

func _input_move(delta: float) -> void:
	movement_controller.input_move(delta)

func _decay_bounce_boost(delta: float) -> void:
	movement_controller.decay_bounce_boost(delta)

func _update_timers(delta: float) -> void:
	movement_controller.update_timers(delta)


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
	movement_controller.on_dash_timer_timeout()

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
	resources_controller.deactivate_shield()
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
