class_name Player

extends CharacterBody2D

const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

signal health_changed(current_health: float, max_health: float)
signal energy_changed(current_energy: float, max_energy: float)
signal player_died
signal dash_count_changed(current_count: int, max_count: int)

@export_group("Movement")
@export var speed: float = 1945.0
@export var acceleration: float = 1945.0
@export var friction: float = 1800.0
@export var dash_speed_multiplier: float = 2.0
@export_range(1.0, 2.0, 0.05) var dash_bounce_factor: float = 1.1
@export var dash_bounce_acceleration_multiplier: float = 1.12
@export var bounce_factor: float = 1.1
@export var min_bounce_speed: float = 100.0
@export var bounce_lockout: float = 0.06
var _bounce_lock_timer: float = 0.0

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Energy & Dash")
@export var max_energy: float = 100.0
@export var dash_energy_cost: float = 20.0
@export var dash_cooldown: float = 0.2
@export var energy_regen_rate: float = 10.0
@export var energy_regen_delay: float = 1.0
@export var energy_exhausted_regen_delay: float = 1.5
@export_range(0.1, 1.0, 0.05) var exhausted_speed_multiplier: float = 0.1
@export var dash_damage: float = 35.0
@export var parry_cooldown: float = 0.75
@export_range(0.0, 1.0, 0.05) var speed_damage_min_speed_ratio: float = 0.5
@export var dash_invulnerability_duration: float = 0.25
@export var parry_invulnerability_duration: float = 0.2

@export_group("Shield")
@export var shield_drain_rate: float = 10.0

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
var is_exhausted: bool = false
var is_dead: bool = false
var is_dashing: bool = false
var facing_direction: String = "down"
var is_invulnerable: bool = false
var is_attacking: bool = false
var is_shield_active: bool = false
var is_transitioning: bool = false
var _dash_hit_enemies: Array = []
var _locked_animation: String = ""

var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0

var flash_material: ShaderMaterial

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var dash_timer: Timer = %DashTimer
@onready var parry_timer: Timer = %ParryTimer
@onready var hitbox: Area2D = $Hitbox
@onready var shield: PlayerShield = $Shield

func _ready() -> void:
	add_to_group("player")
	GameManager.player_heal.connect(heal)
	GameManager.player_energize.connect(energize)
	if has_node("Shield"):
		shield.setup(self)
	normal_speed = speed
	base_acceleration = acceleration
	health = max_health
	energy = max_energy
	is_exhausted = false
	is_dead = false
	_setup_flash_shader()
	health_changed.emit(health, max_health)
	_emit_energy_changed()

func _setup_flash_shader() -> void:
	var shader := load("res://shaders/white_flash.gdshader") as Shader
	if shader:
		flash_material = ShaderMaterial.new()
		flash_material.shader = shader
		animated_sprite.material = flash_material

func flash_white(duration: float = 0.1) -> void:
	if flash_material:
		flash_material.set_shader_parameter("flash", true)
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(flash_material):
				flash_material.set_shader_parameter("flash", false)
		)

func _process(delta: float) -> void:
	_update_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_transitioning:
		return

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	if parry_cooldown_timer > 0.0:
		parry_cooldown_timer = maxf(parry_cooldown_timer - delta, 0.0)
	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)
	if not is_transitioning:
		is_invulnerable = _invulnerability_timer > 0.0
	if _bounce_lock_timer > 0.0:
		_bounce_lock_timer = maxf(_bounce_lock_timer - delta, 0.0)

	_decay_bounce_boost(delta)
	_handle_shield(delta)
	_handle_energy_regen(delta)
	_input_move(delta)

	var pre_collision_velocity := velocity
	move_and_slide()
	_handle_bounce(pre_collision_velocity)

	var current_speed := velocity.length()
	var minimum_damage_speed := normal_speed * speed_damage_min_speed_ratio
	if is_dashing or current_speed >= minimum_damage_speed:
		_handle_speed_damage(current_speed)
	else:
		_dash_hit_enemies.clear()

	if is_attacking:
		_check_parry()

func _decay_bounce_boost(delta: float) -> void:
	var target_speed := _get_current_move_speed()
	if speed > target_speed:
		speed = move_toward(speed, target_speed, delta * 2000.0)
	elif speed < target_speed:
		speed = target_speed

	if acceleration > base_acceleration:
		acceleration = move_toward(acceleration, base_acceleration, delta * 2000.0)


func _handle_speed_damage(current_speed: float) -> void:
	if current_speed <= 0.0:
		return
	var reference_speed := maxf(normal_speed * dash_speed_multiplier, 1.0)
	var damage := dash_damage * current_speed / reference_speed
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not _dash_hit_enemies.has(enemy):
			var enemy_position = enemy.global_position + Vector2(0.0, -115)
			var my_center_position = global_position + Vector2(0.0, -75)
			if my_center_position.distance_to(enemy_position) < 200:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
					energize(5.0)
					_dash_hit_enemies.append(enemy)
					_on_dash_hit(enemy.global_position)

func _on_dash_hit(hit_pos: Vector2) -> void:
	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = hit_pos
		hit.scale = Vector2(2.5, 2.5)
		hit.animation_name = "arcane"
		get_tree().current_scene.call_deferred("add_child", hit)
	AudioManager.play_sfx("blast", 1.6, -4.0)
	camera_shake(10.0, 0.15)

func _handle_bounce(pre_collision_velocity: Vector2) -> void:
	if get_slide_collision_count() == 0:
		return

	var bounced_velocity := pre_collision_velocity
	var did_bounce := false

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()

		if bounced_velocity.dot(normal) < -30.0:
			bounced_velocity = bounced_velocity.bounce(normal)
			did_bounce = true

	if did_bounce:
		energize(ceilf(dash_energy_cost / 4))
		_bounce_lock_timer = bounce_lockout
		if is_dashing:
			speed = minf(maxf(speed, normal_speed * dash_speed_multiplier) * dash_bounce_factor, 4200.0)
			acceleration = minf(maxf(acceleration, base_acceleration) * dash_bounce_acceleration_multiplier, 2800.0)
			velocity = bounced_velocity.normalized() * speed
		else:
			speed = _get_current_move_speed()
			acceleration = base_acceleration
			var normal_bounce_speed := minf(pre_collision_velocity.length(), speed)
			velocity = bounced_velocity.normalized() * normal_bounce_speed
		_update_facing_direction(velocity.normalized())
		_update_movement_animation()

		camera_shake(10.0 if is_dashing else 4.0, wall_hit_shake_duration)
		AudioManager.play_sfx("ting", 1.2 if is_dashing else 0.9, 0.0)

func camera_shake(intensity: float, duration: float = 0.2) -> void:
	var scaled_intensity := intensity * shake_multiplier
	if scaled_intensity <= 0.0 or duration <= 0.0:
		return
	if scaled_intensity >= _shake_intensity or _shake_timer <= 0.0:
		_shake_intensity = scaled_intensity
		_shake_duration = duration
		_shake_timer = duration

func _update_camera_shake(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if _shake_timer > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		var progress := _shake_timer / _shake_duration if _shake_duration > 0.0 else 0.0
		var current_strength := _shake_intensity * progress
		camera.offset = Vector2(
			randf_range(-current_strength, current_strength),
			randf_range(-current_strength, current_strength)
		)
	else:
		camera.offset = Vector2.ZERO
		_shake_intensity = 0.0

func _handle_energy_regen(delta: float) -> void:
	if is_shield_active:
		return

	if energy_regen_wait_timer > 0.0:
		energy_regen_wait_timer = maxf(energy_regen_wait_timer - delta, 0.0)
		return

	if energy < max_energy:
		energy = minf(energy + energy_regen_rate * delta, max_energy)
		if is_exhausted and energy > 0.0:
			is_exhausted = false
		_emit_energy_changed()

func _handle_shield(delta: float) -> void:
	if not is_shield_active:
		return

	if is_dashing or is_dead or is_transitioning:
		_deactivate_shield()
		return

	energy = maxf(energy - shield_drain_rate * delta, 0.0)
	_emit_energy_changed()

	if energy <= 0.0:
		is_exhausted = true
		energy_regen_wait_timer = energy_exhausted_regen_delay
		_deactivate_shield()

func toggle_shield() -> void:
	if is_dead or is_transitioning or get_tree().paused or is_dashing:
		return
	if is_shield_active:
		_deactivate_shield()
	elif energy > 0.0 and not is_exhausted:
		_activate_shield()

func _toggle_shield() -> void:
	toggle_shield()

func _activate_shield() -> void:
	is_shield_active = true
	if is_instance_valid(shield):
		shield.activate()

func _deactivate_shield() -> void:
	is_shield_active = false
	if is_instance_valid(shield):
		shield.deactivate()

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

func can_parry() -> bool:
	return (
		not is_dead
		and not is_transitioning
		and not get_tree().paused
		and not is_attacking
		and not is_shield_active
		and not is_dashing
		and _locked_animation.is_empty()
		and parry_cooldown_timer <= 0.0
	)

func perform_parry() -> void:
	if not can_parry():
		return
	is_attacking = true
	is_invulnerable = true
	_invulnerability_timer = maxf(_invulnerability_timer, parry_invulnerability_duration)
	parry_cooldown_timer = parry_cooldown
	parry_timer.start(0.1)
	_check_parry()
	_play_locked_animation("parry_" + facing_direction)

func _perform_parry() -> void:
	perform_parry()

func _check_parry() -> void:
	for proj in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(proj) and proj.has_method("parry") and not proj.get("is_parried"):
			if global_position.distance_to(proj.global_position) <= 140.0:
				proj.parry(self)
				_update_facing_direction_to_object((proj as Node2D).global_position)
				AudioManager.play_sfx("ting", 2.0, -8.0)
				_on_successful_parry(proj.global_position)
				return

func _on_successful_parry(pos: Vector2) -> void:
	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = pos
		hit.scale = Vector2(3.0, 3.0)
		hit.animation_name = "holy"
		get_tree().current_scene.call_deferred("add_child", hit)

	camera_shake(14.0, 0.2)
	AudioManager.play_sfx("ting", 1.8, 3.0)
	energize(10)

func _input_move(delta: float) -> void:
	if _bounce_lock_timer > 0.0:
		return

	var input_direction := Input.get_vector("player_left", "player_right", "player_up", "player_down")
	var target_max_speed := _get_current_move_speed()

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * target_max_speed, acceleration * delta)
		if _locked_animation.is_empty() and not is_dashing:
			_update_facing_direction(input_direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_update_movement_animation()

func can_dash() -> bool:
	return (
		not is_dead
		and not is_transitioning
		and not get_tree().paused
		and dash_cooldown_timer <= 0.0
		and energy >= dash_energy_cost
		and not is_attacking
		and _locked_animation.is_empty()
	)

func perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	if not can_dash():
		return

	if is_shield_active:
		_deactivate_shield()

	dash_cooldown_timer = dash_cooldown
	energy = maxf(energy - dash_energy_cost, 0.0)

	if energy <= 0.0:
		is_exhausted = true
		energy_regen_wait_timer = energy_exhausted_regen_delay
	else:
		energy_regen_wait_timer = energy_regen_delay

	_emit_energy_changed()

	is_dashing = true
	is_invulnerable = true
	_invulnerability_timer = maxf(_invulnerability_timer, dash_invulnerability_duration)
	_dash_hit_enemies.clear()
	dash_timer.start(0.16)
	speed = normal_speed * dash_speed_multiplier

	var dash_dir := direction
	if dash_dir == Vector2.ZERO:
		dash_dir = Input.get_vector("player_left", "player_right", "player_up", "player_down")
	if dash_dir == Vector2.ZERO:
		dash_dir = _get_facing_direction_vector()
	else:
		_update_facing_direction(dash_dir)

	velocity = dash_dir * speed
	flash_white(0.12)
	_play_locked_animation("charge_" + facing_direction)

func _perform_dash(direction: Vector2 = Vector2.ZERO) -> void:
	perform_dash(direction)

func _get_current_move_speed() -> float:
	if is_dashing:
		return normal_speed * dash_speed_multiplier
	if is_exhausted or energy <= 0.0:
		return normal_speed * exhausted_speed_multiplier
	return normal_speed

func take_damage(amount: float) -> void:
	if is_invulnerable:
		return
	if is_shield_active:
		var energy_absorbed := amount * 1.2
		energy = maxf(energy - energy_absorbed, 0.0)
		_emit_energy_changed()
		camera_shake(8.0, 0.15)
		if AudioManager:
			AudioManager.play_sfx("blast", 2.0, -4.0)
		if energy <= 0.0:
			is_exhausted = true
			energy_regen_wait_timer = energy_exhausted_regen_delay
			_deactivate_shield()
		return
	if is_attacking:
		_on_successful_parry(global_position)
		return
	if is_dead or amount <= 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	camera_shake(damage_shake_intensity, damage_shake_duration)
	if health <= 0.0:
		die()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)

func energize(amount: float) -> void:
	if is_dead:
		return
	var energy_change := -amount if is_shield_active and amount > 0.0 else amount
	energy = clampf(energy + energy_change, 0.0, max_energy)
	_emit_energy_changed()
	if is_shield_active and energy <= 0.0:
		is_exhausted = true
		energy_regen_wait_timer = energy_exhausted_regen_delay
		_deactivate_shield()

func die() -> void:
	if is_dead:
		return
	if is_shield_active:
		_deactivate_shield()
	is_dead = true
	velocity = Vector2.ZERO
	player_died.emit()

func _update_facing_direction(dir: Vector2) -> void:
	if absf(dir.x) >= absf(dir.y):
		facing_direction = "right" if dir.x > 0.0 else "left"
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"

func _update_facing_direction_to_object(object: Vector2) -> void:
	_update_facing_direction(object - global_position)

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

func _on_dash_timer_timeout() -> void:
	is_dashing = false
	speed = _get_current_move_speed()
	acceleration = base_acceleration
	if _locked_animation.begins_with("charge_"):
		_locked_animation = ""
	_update_movement_animation()

func _update_movement_animation() -> void:
	if is_dead or is_transitioning:
		return
	var input_direction := Input.get_vector("player_left", "player_right", "player_up", "player_down")
	if is_dashing:
		_play_animation("run_" + facing_direction)
	elif not is_attacking:
		if input_direction != Vector2.ZERO:
			_play_animation("run_" + facing_direction)
		else:
			_play_animation("idle_" + facing_direction)

func _play_animation(anim_name: String) -> void:
	if not _locked_animation.is_empty():
		return
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _play_locked_animation(anim_name: String) -> void:
	_locked_animation = anim_name
	animated_sprite.play(anim_name)

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

func _on_parry_timer_timeout() -> void:
	is_attacking = false
	_update_movement_animation()

func _begin_transition_state() -> void:
	_deactivate_shield()
	is_transitioning = true
	is_invulnerable = true
	_invulnerability_timer = 0.0
	is_dashing = false
	is_attacking = false
	_locked_animation = ""
	velocity = Vector2.ZERO
	if dash_timer:
		dash_timer.stop()
	if parry_timer:
		parry_timer.stop()

func prepare_drop_in(target_global_pos: Vector2) -> void:
	_begin_transition_state()

	global_position = target_global_pos
	if camera:
		camera.reset_smoothing()
	facing_direction = "down"
	_play_animation("idle_down")

	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		animated_sprite.scale = Vector2(3.6, 4.5)
		animated_sprite.position = Vector2(1.0, -2000.0)

func play_drop_in_animation(target_global_pos: Vector2) -> void:
	prepare_drop_in(target_global_pos)

	if animated_sprite:
		var drop_tween := create_tween()
		drop_tween.tween_property(animated_sprite, "position", Vector2(1.0, -60.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await drop_tween.finished

		if not is_inside_tree():
			return

		AudioManager.play_sfx("blast", 1.15, -2.0)
		camera_shake(18.0, 0.25)

		if HIT_EFFECT_SCENE and get_tree().current_scene:
			var hit := HIT_EFFECT_SCENE.instantiate()
			hit.global_position = global_position
			hit.scale = Vector2(5.0, 5.0)
			hit.animation_name = "holy"
			get_tree().current_scene.call_deferred("add_child", hit)

		animated_sprite.scale = Vector2(4.7, 3.3)
		var bounce_tween := create_tween().set_parallel(true)
		bounce_tween.tween_property(animated_sprite, "scale", Vector2(3.8, 4.2), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(animated_sprite, "position", Vector2(1.0, -240.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await bounce_tween.finished

		if not is_inside_tree():
			return

		var settle_tween := create_tween().set_parallel(true)
		settle_tween.tween_property(animated_sprite, "scale", Vector2(4.0, 4.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		settle_tween.tween_property(animated_sprite, "position", Vector2(1.0, -60.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await settle_tween.finished

	is_transitioning = false
	is_invulnerable = false

func play_jump_into_trapdoor(trapdoor_global_pos: Vector2) -> void:
	_begin_transition_state()

	facing_direction = "down"
	_play_animation("idle_down")
	AudioManager.play_sfx("ting", 1.35, 0.0)

	if animated_sprite:
		var jump_up := create_tween().set_parallel(true)
		jump_up.tween_property(self, "global_position", trapdoor_global_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump_up.tween_property(animated_sprite, "position", Vector2(1.0, -210.0), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump_up.tween_property(animated_sprite, "scale", Vector2(4.4, 4.4), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await jump_up.finished

		if not is_inside_tree():
			return

		var fall_in := create_tween().set_parallel(true)
		fall_in.tween_property(animated_sprite, "position", Vector2(1.0, 30.0), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_in.tween_property(animated_sprite, "scale", Vector2(0.0, 0.0), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		fall_in.tween_property(animated_sprite, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fall_in.finished

		if not is_inside_tree():
			return

		await get_tree().create_timer(0.2).timeout


func _on_animated_sprite_2d_animation_finished() -> void:
	if _locked_animation.is_empty() or animated_sprite.animation != _locked_animation:
		return

	_locked_animation = ""

	if is_dead or is_transitioning or is_attacking:
		return

	_update_movement_animation()
