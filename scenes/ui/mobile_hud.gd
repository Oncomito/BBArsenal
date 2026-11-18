extends CharacterBody2D

@export var speed: float = 220.0
@onready var joystick: VirtualJoystick = $VirtualJoystick

func _physics_process(_delta: float):
	var dir = joystick.output if joystick.is_pressed else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed
	move_and_slide()   
