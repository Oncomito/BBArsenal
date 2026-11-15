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
	deactivate()

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
			var on_spawn_finished: Callable
			on_spawn_finished = func():
				if animated_sprite.animation_finished.is_connected(on_spawn_finished):
					animated_sprite.animation_finished.disconnect(on_spawn_finished)
				if is_active and animated_sprite.sprite_frames.has_animation("shield_active"):
					animated_sprite.play("shield_active")
			animated_sprite.animation_finished.connect(on_spawn_finished)
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
		var on_hide_finished: Callable
		on_hide_finished = func():
			if animated_sprite.animation_finished.is_connected(on_hide_finished):
				animated_sprite.animation_finished.disconnect(on_hide_finished)
			if not is_active:
				visible = false
				animated_sprite.stop()
		animated_sprite.animation_finished.connect(on_hide_finished)
	else:
		visible = false
		if animated_sprite:
			animated_sprite.stop()

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	
	if area.is_in_group("projectile") and area.has_method("parry") and not area.get("is_parried"):
		_bounce_projectile(area)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("projectile") and body.has_method("parry") and not body.get("is_parried"):
		_bounce_projectile(body)

func _bounce_projectile(proj: Node2D) -> void:
	proj.parry(player_ref)
	projectile_bounced.emit(proj)
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bounce"):
		animated_sprite.play("bounce")
		var callable: Callable
		callable = func():
			if animated_sprite.animation_finished.is_connected(callable):
				animated_sprite.animation_finished.disconnect(callable)
			if is_active:
				if animated_sprite.sprite_frames.has_animation("shield_active"):
					animated_sprite.play("shield_active")
				elif animated_sprite.sprite_frames.has_animation("active"):
					animated_sprite.play("active")
		animated_sprite.animation_finished.connect(callable)
