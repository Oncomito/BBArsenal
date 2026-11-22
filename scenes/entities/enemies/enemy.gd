class_name Enemy
extends Entity

var player: Node2D = null
var _flash_timer: float = 0.0
@export var is_boss: bool = false
@export var speed: float = 100.0
@export var health_bar: ProgressBar
@export var cooldown_bar: ProgressBar
@export var attack_cooldown: float = 2.0
@export var attack_range: float = 1000.0
@export var damage: float = 5.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	super._ready()
	player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(animated_sprite):
		animated_sprite.play("walk")


func _update_enemy_movement(move_speed: float, stop_distance: float) -> float:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return -1.0

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if is_instance_valid(animated_sprite) and absf(to_player.x) > 10.0:
		animated_sprite.flip_h = to_player.x < 0.0

	if distance > stop_distance:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	return distance


func _flash_on_hit(color: Color, duration: float) -> void:
	if not is_instance_valid(animated_sprite):
		return
	animated_sprite.modulate = color
	_flash_timer = duration


func _update_hit_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0 and is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color.WHITE

func _die() -> void:
	if is_dead:
		return
	is_dead = true

	if is_boss:
		GameManager.unregister_boss(self)
		GameManager.register_enemy_kill(100)
		AudioManager.play_sfx("explode", 2.0)
	else:
		GameManager.register_enemy_kill(10)
		AudioManager.play_sfx("explode", 0.75)

	if GameManager.HIT_EFFECT_SCENE != null and get_parent() != null:
		var effect := GameManager.HIT_EFFECT_SCENE.instantiate()
		effect.global_position = global_position + Vector2(0.0, -115.0)
		effect.scale = Vector2(10.0, 10.0)
		if "animation_name" in effect:
			effect.animation_name = "fire"
		get_parent().add_child(effect)

	queue_free()
