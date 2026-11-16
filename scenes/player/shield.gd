extends Area2D
class_name PlayerShield

signal projectile_bounced(projectile: Node2D)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_active: bool = false
var player_ref: CharacterBody2D = null

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	is_active = false
	visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if animated_sprite:
		animated_sprite.stop()

func setup(player: CharacterBody2D) -> void:
	player_ref = player

func activate() -> void:
	if is_active:
		return
	is_active = true
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("shield_spawn"):
			animated_sprite.play("shield_spawn")
		elif animated_sprite.sprite_frames.has_animation("shield_active"):
			animated_sprite.play("shield_active")
		elif animated_sprite.sprite_frames.has_animation("active"):
			animated_sprite.play("active")
		else:
			animated_sprite.play()

func deactivate() -> void:
	if not is_active and not visible:
		return
	is_active = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("shield_hide"):
		animated_sprite.play("shield_hide")
	else:
		visible = false
		if animated_sprite:
			animated_sprite.stop()

func _on_animation_finished() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	match animated_sprite.animation:
		&"shield_spawn", &"bounce":
			if is_active:
				if animated_sprite.sprite_frames.has_animation("shield_active"):
					animated_sprite.play("shield_active")
				elif animated_sprite.sprite_frames.has_animation("active"):
					animated_sprite.play("active")
		&"shield_hide":
			if not is_active:
				visible = false
				animated_sprite.stop()

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	
	if area.is_in_group("projectile") and area.has_method("parry") and not area.get("is_parried"):
		bounce_projectile(area)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("projectile") and body.has_method("parry") and not body.get("is_parried"):
		bounce_projectile(body)


func bounce_projectile(proj: Node2D) -> void:
	if not is_active or not is_instance_valid(proj) or not proj.has_method("parry") or proj.get("is_parried"):
		return
	GameManager.player_energize.emit(-proj.damage)
	proj.parry(player_ref)
	projectile_bounced.emit(proj)
