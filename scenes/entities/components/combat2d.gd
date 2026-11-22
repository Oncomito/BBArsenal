@tool
@icon("res://assets/_project/node/combat.svg")
class_name Combat2D
extends Node2D

@export var hitbox: Hitbox2D:
	set(value):
		hitbox = value
		update_configuration_warnings()

func _ready() -> void:
	assert(is_instance_valid(hitbox), "Entity requires a Hitbox2D node or as subclass of it.")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if not is_instance_valid(hitbox):
		warnings.append("Missing required component: Hitbox2D.")

	return warnings

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return