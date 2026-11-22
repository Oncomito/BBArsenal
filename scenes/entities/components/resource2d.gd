@tool
@icon("res://assets/_project/node/resource.svg")
class_name Resource2D
extends Node2D

@export var hurtbox: Hurtbox2D:
	set(value):
		hurtbox = value
		update_configuration_warnings()

func _ready() -> void:
	assert(is_instance_valid(hurtbox), "Entity requires a Hurtbox2D node or as subclass of it.")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not is_instance_valid(hurtbox):
		warnings.append("Missing required component: Hurtbox2D.")

	return warnings
	
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return