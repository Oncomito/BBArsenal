extends CharacterBody2D

@export var speed: float = 1250.0
@export var acceleration: float = 2000.0
@export var friction: float = 1800.0

func _physics_process(delta: float) -> void:
	_input_move(delta)
	move_and_slide()
	
func _input_move(delta: float) -> void:
	var input_direction := Input.get_vector("left", "right", "up", "down")

	if input_direction != Vector2.ZERO:
		self.velocity = self.velocity.move_toward(input_direction * speed, acceleration * delta)
	else:
		velocity = self.velocity.move_toward(Vector2.ZERO, friction * delta)