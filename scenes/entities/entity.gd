class_name Entity
extends CharacterBody2D

@export var max_health: float = 100.0

var health: float = 100.0
var is_dead: bool = false

@onready var entity_hitbox: Hitbox2D = find_child("Hitbox", true, false) as Hitbox2D
@onready var entity_hurtbox: Hurtbox2D = find_child("Hurtbox", true, false) as Hurtbox2D
@onready var entity_bodybox: Bodybox2D = find_child("Bodybox", true, false) as Bodybox2D

func _ready() -> void:
	assert(is_instance_valid(entity_hitbox), "Entity requires a Hitbox2D node named Hitbox")
	assert(is_instance_valid(entity_hurtbox), "Entity requires a Hurtbox2D node named Hurtbox")
	assert(is_instance_valid(entity_bodybox), "Entity requires a Bodybox2D node named Bodybox")
	health = max_health


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