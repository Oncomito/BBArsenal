extends CharacterBody2D

@export_group("Roaming")
@export var walk_speed: float = 500.0
@export var acceleration: float = 1500.0
@export var friction: float = 1500.0
@export var roam_radius: float = 1200.0
@export var min_walk_time: float = 1.0
@export var max_walk_time: float = 3.0
@export var min_idle_time: float = 0.4
@export var max_idle_time: float = 1.8
@export_range(0.0, 1.0, 0.05) var skip_idle_chance: float = 0.2

@export_group("Dash")
@export var dash_enabled: bool = true
@export var dash_speed_multiplier: float = 2.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 2.0
@export_range(0.0, 1.0, 0.05) var dash_chance: float = 0.3

@export_group("Bounce")
@export var bounce_lockout: float = 0.06
@export var dash_bounce_factor: float = 1.1
@export var max_dash_speed: float = 2400.0

enum State {IDLE, WALK}

var state: State = State.IDLE
var facing_direction: String = "down"

var _home: Vector2
var _wander_dir: Vector2 = Vector2.ZERO
var _state_time_left: float = 0.0
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _bounce_lock_timer: float = 0.0
var _dash_speed: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("npc")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	randomize()
	_home = global_position
	_enter_idle()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_state(delta)
	_apply_movement(delta)

	var pre_collision_velocity := velocity
	move_and_slide()
	_handle_bounce(pre_collision_velocity)

	_update_animation()

func _tick_timers(delta: float) -> void:
	_state_time_left -= delta
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_bounce_lock_timer = maxf(_bounce_lock_timer - delta, 0.0)
	if _dash_time_left > 0.0:
		_dash_time_left -= delta

func _update_state(_delta: float) -> void:
	if _state_time_left > 0.0:
		return
	if state == State.WALK:
		if randf() < skip_idle_chance:
			_enter_walk()
		else:
			_enter_idle()
	else:
		_enter_walk()


func _enter_idle() -> void:
	state = State.IDLE
	_state_time_left = randf_range(min_idle_time, max_idle_time)


func _enter_walk() -> void:
	state = State.WALK
	_state_time_left = randf_range(min_walk_time, max_walk_time)
	_wander_dir = _pick_direction()
	_update_facing_direction(_wander_dir)

	if dash_enabled and _dash_cooldown_left <= 0.0 and randf() < dash_chance:
		_start_dash()


func _pick_direction() -> Vector2:
	var dir := Vector2.from_angle(randf_range(0.0, TAU))
	# Too far from home? Head back, with a bit of randomness so it doesn't look robotic.
	if roam_radius > 0.0 and global_position.distance_to(_home) > roam_radius:
		var to_home := global_position.direction_to(_home)
		dir = to_home.rotated(randf_range(-0.6, 0.6))
	return dir


func _start_dash() -> void:
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_dash_speed = walk_speed * dash_speed_multiplier
	velocity = _wander_dir * _dash_speed
	if _has_anim("charge_" + facing_direction):
		animated_sprite.play("charge_" + facing_direction)


func _is_dashing() -> bool:
	return _dash_time_left > 0.0

func _apply_movement(delta: float) -> void:
	if _bounce_lock_timer > 0.0:
		return

	if state == State.WALK:
		var target_speed := _dash_speed if _is_dashing() else walk_speed
		velocity = velocity.move_toward(_wander_dir * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _handle_bounce(pre_collision_velocity: Vector2) -> void:
	if get_slide_collision_count() == 0:
		return

	var bounced_velocity := pre_collision_velocity
	var did_bounce := false

	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if bounced_velocity.dot(normal) < -30.0:
			bounced_velocity = bounced_velocity.bounce(normal)
			did_bounce = true

	if not did_bounce:
		return

	_bounce_lock_timer = bounce_lockout

	if _is_dashing():
		_dash_speed = minf(_dash_speed * dash_bounce_factor, max_dash_speed)
		velocity = bounced_velocity.normalized() * _dash_speed
	else:
		var bounce_speed := minf(pre_collision_velocity.length(), walk_speed)
		velocity = bounced_velocity.normalized() * bounce_speed

	# Keep walking in the bounced direction so the NPC doesn't push back into the wall
	if velocity != Vector2.ZERO:
		_wander_dir = velocity.normalized()
		_update_facing_direction(_wander_dir)

func _update_animation() -> void:
	if _is_dashing():
		if not _has_anim("charge_" + facing_direction):
			_play_animation("run_" + facing_direction)
		return

	if velocity.length() > 20.0:
		_update_facing_direction(velocity.normalized())
		_play_animation("run_" + facing_direction)
	else:
		_play_animation("idle_" + facing_direction)


func _play_animation(anim_name: String) -> void:
	if animated_sprite.animation != anim_name and _has_anim(anim_name):
		animated_sprite.play(anim_name)


func _has_anim(anim_name: String) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(anim_name)


func _update_facing_direction(dir: Vector2) -> void:
	if absf(dir.x) >= absf(dir.y):
		facing_direction = "right" if dir.x > 0.0 else "left"
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"