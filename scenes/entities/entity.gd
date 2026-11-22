@tool
class_name Entity2D
extends CharacterBody2D

signal to_die

const HIT_EFFECT_SCENE := GameManager.HIT_EFFECT_SCENE

@export var max_health: float = 100.0
@export var controllable: bool = false

@export_category("Components")
@export var movement: Movement2D:
	set(value):
		movement = value
		update_configuration_warnings()

@export var visual: Visual2D:
	set(value):
		visual = value
		update_configuration_warnings()

@export var combat: Combat2D:
	set(value):
		combat = value
		update_configuration_warnings()

@export var resource: Resource2D:
	set(value):
		resource = value
		update_configuration_warnings()

@export_category("Camera")
@export var has_camera: bool = false:
	set(value):
		has_camera = value
		update_configuration_warnings()

@export var camera: Camera2D:
	set(value):
		camera = value
		update_configuration_warnings()

@onready var health: float = max_health

var hitbox: Hitbox2D
var hurtbox: Hurtbox2D
var bodybox: Bodybox2D
var sprite: AnimatedSprite2D
var is_dead: bool = false


func _ready() -> void:
	assert(is_instance_valid(movement), "Entity requires a Movement2D node or a subclass of it.")
	assert(is_instance_valid(visual), "Entity requires a Visual2D node or a subclass of it.")
	assert(is_instance_valid(combat), "Entity requires a Combat2D node or a subclass of it.")
	assert(is_instance_valid(resource), "Entity requires a Resource2D node or a subclass of it.")

	if has_camera:
		assert(is_instance_valid(camera), "Entity has 'has_camera' enabled, but no Camera2D is assigned.")

	sprite = visual.sprite
	hitbox = combat.hitbox
	hurtbox = resource.hurtbox
	bodybox = movement.bodybox

func _get_child_by_type(parent: Node, type) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, type):
			return child
	return null


func take_damage(amount: float) -> void:
	if not apply_damage(amount):
		return
	if health <= 0.0:
		die()


func apply_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false
	health = maxf(health - amount, 0.0)
	return true


func apply_healing(amount: float) -> bool:
	if is_dead or amount <= 0.0:
		return false
	health = minf(health + amount, max_health)
	return true


func die() -> void:
	is_dead = true
	to_die.emit()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not is_instance_valid(movement):
		warnings.append("Missing required component: Movement2D.")
	if not is_instance_valid(visual):
		warnings.append("Missing required component: Visual2D.")
	if not is_instance_valid(combat):
		warnings.append("Missing required component: Combat2D.")
	if not is_instance_valid(resource):
		warnings.append("Missing required component: Resource2D.")

	if has_camera and not is_instance_valid(camera):
		warnings.append("Camera2D is not assigned. Assign a Camera2D or uncheck 'Has Camera'.")

	return warnings
