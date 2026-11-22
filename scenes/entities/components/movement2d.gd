@tool
@icon("res://assets/_project/node/movement.svg")
class_name Movement2D
extends Node2D

@export var bodybox: Bodybox2D:
	set(value):
		bodybox = value
		update_configuration_warnings()

func _ready() -> void:
	assert(is_instance_valid(bodybox), "Entity requires a Bodybox2D node or as subclass of it.")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not is_instance_valid(bodybox):
		warnings.append("Missing required component: Bodybox2D.")

	return warnings

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return