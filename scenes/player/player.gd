extends CharacterBody2D

signal dash_count_changed(current_count: int, max_count: int)

@export var speed: float = 1945.0
@export var acceleration: float = 1945.0
@export var friction: float = 1800.0
@export var dash_speed_multiplier: float = 1.5
@export var max_dash_count: int = 3
@export var dash_recharge_time: float = 5.0

var normal_speed: float = speed
var current_dash_count: int = max_dash_count
var dash_recharge_timer: float = 0.0
var facing_direction: String = "down"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_timer: Timer = %DashTimer

func _ready() -> void:
	add_to_group("player")
	normal_speed = speed
	current_dash_count = max_dash_count

func _physics_process(delta: float) -> void:
	_handle_dash_recharge(delta)
	_input_move(delta)
	move_and_slide()

func _handle_dash_recharge(delta: float) -> void:
	if current_dash_count < max_dash_count:
		dash_recharge_timer += delta
		if dash_recharge_timer >= dash_recharge_time:
			dash_recharge_timer -= dash_recharge_time
			current_dash_count += 1
			dash_count_changed.emit(current_dash_count, max_dash_count)
	else:
		dash_recharge_timer = 0.0

func _input_move(delta: float) -> void:
	var input_direction := Input.get_vector("player_left", "player_right", "player_up", "player_down")

	if Input.is_action_just_pressed("player_dash") and current_dash_count > 0:
		current_dash_count -= 1
		dash_count_changed.emit(current_dash_count, max_dash_count)
		dash_timer.start()
		speed = normal_speed * dash_speed_multiplier
		var dash_dir := input_direction
		if dash_dir == Vector2.ZERO:
			dash_dir = _get_facing_direction_vector()
		velocity += dash_dir * speed

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * speed, acceleration * delta)
		_update_facing_direction(input_direction)
		_play_animation("run_" + facing_direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_play_animation("idle_" + facing_direction)

func _update_facing_direction(dir: Vector2) -> void:
	if absf(dir.x) >= absf(dir.y):
		facing_direction = "right" if dir.x > 0.0 else "left"
	else:
		facing_direction = "down" if dir.y > 0.0 else "up"

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
	speed = normal_speed

func _play_animation(anim_name: String) -> void:
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func get_dash_count() -> int:
	return current_dash_count

func get_dash_recharge_ratio() -> float:
	if current_dash_count >= max_dash_count:
		return 1.0
	return clampf(dash_recharge_timer / dash_recharge_time, 0.0, 1.0)
