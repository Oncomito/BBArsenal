@icon("res://assets/_project/node/exclude.svg")
class_name Hurtbox2D
extends Area2D

signal hurt(hitbox: Hitbox2D)

@export var is_invincible: bool = false

func take_hit(hitbox: Hitbox2D) -> void:
	if is_invincible: return

	hurt.emit(hitbox)