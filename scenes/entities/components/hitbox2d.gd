@icon("res://assets/_project/node/intersection.svg")
class_name Hitbox2D
extends Area2D

signal hit(hurtbox: Hurtbox2D)

@export var max_targets: int = -1
@export var damage: float = 1.0

var _hit_hurtboxes: Array[Hurtbox2D] = []

func _init() -> void:
	monitoring = true
	monitorable = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _reset() -> void:
	_hit_hurtboxes.clear()

func _on_area_entered(area: Area2D) -> void:
	if not area is Hurtbox2D:
		return

	var hurtbox := area as Hurtbox2D

	if max_targets > 0 and _hit_hurtboxes.size() >= max_targets:
		return

	if hurtbox in _hit_hurtboxes or hurtbox.is_invincible:
		return

	_hit_hurtboxes.append(hurtbox)
	hurtbox.take_hit(self)
	hit.emit(hurtbox)
