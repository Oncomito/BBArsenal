extends CharacterBody2D

@export var speed: float = 1250.0
@export var acceleration: float = 2000.0
@export var friction: float = 1800.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing_direction: String = "down"

func _physics_process(delta: float) -> void:
	_input_move(delta)
	move_and_slide()

func _input_move(delta: float) -> void:
	var input_direction := Input.get_vector("left", "right", "up", "down")

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

func _play_animation(anim_name: String) -> void:
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
