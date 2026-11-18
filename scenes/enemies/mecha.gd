extends CharacterBody2D
## Standard ranged Mecha enemy with one shooting attack and HUD stat bars.

const HIT_EFFECT_SCENE: PackedScene = preload("res://scenes/projectiles/hit.tscn")

@export var speed: float = 180.0
@export var max_health: float = 180.0
@export var damage: float = 5.0
@export var shoot_cooldown: float = 2.0
@export var shoot_range: float = 1000.0
@export var stop_distance: float = 220.0
@export var projectile_kind: String = "fireball"
@export var projectile_element: String = "fire"
@export var projectile_speed: float = 950.0

var health: float = 180.0
var player: Node2D = null
var _cooldown_elapsed: float = 0.0
var _flash_timer: float = 0.0
var _is_dead: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $Stats/Health
@onready var cooldown_bar: ProgressBar = $Stats/Cooldown


func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(animated_sprite):
		animated_sprite.play("walk")
	_sync_bars()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_hit_flash(delta)
	_cooldown_elapsed = minf(_cooldown_elapsed + delta, shoot_cooldown)
	_sync_bars()

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if is_instance_valid(animated_sprite) and absf(to_player.x) > 10.0:
		animated_sprite.flip_h = to_player.x < 0.0

	if distance > stop_distance:
		velocity = to_player.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if distance <= shoot_range and _cooldown_elapsed >= shoot_cooldown:
		_cooldown_elapsed = 0.0
		_sync_bars()
		_shoot_at_player()


func _shoot_at_player() -> void:
	if not is_instance_valid(player):
		return

	var muzzle: Vector2 = global_position + Vector2(0.0, -115.0)
	var dir: Vector2 = (player.global_position - muzzle).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	ProjectileManager.spawn_projectile(projectile_kind, {
		"spawn_point": muzzle,
		"direction": dir,
		"target": player,
		"speed": projectile_speed,
		"damage": damage,
		"element": projectile_element,
		"parent": get_parent(),
	})
	AudioManager.play_sfx("fireball", randf_range(0.95, 1.05))


## Applies incoming damage, updates the overhead health bar, and destroys on 0 HP.
func take_damage(amount: float) -> void:
	if _is_dead:
		return

	health = maxf(health - amount, 0.0)
	_sync_bars()

	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		_flash_timer = 0.1

	if health <= 0.0:
		_die()


func _sync_bars() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maxf(max_health, 1.0)
		health_bar.value = clampf(health, 0.0, health_bar.max_value)
	if is_instance_valid(cooldown_bar):
		cooldown_bar.max_value = maxf(shoot_cooldown, 0.01)
		cooldown_bar.value = clampf(_cooldown_elapsed, 0.0, cooldown_bar.max_value)


func _update_hit_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0 and is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color.WHITE


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true

	GameManager.register_enemy_kill(10)
	AudioManager.play_sfx("explode", 2.0)

	if HIT_EFFECT_SCENE != null and get_parent() != null:
		var effect := HIT_EFFECT_SCENE.instantiate()
		effect.global_position = global_position + Vector2(0.0, -115.0)
		effect.scale = Vector2(10.0, 10.0)
		if "animation_name" in effect:
			effect.animation_name = "fire"
		get_parent().add_child(effect)

	queue_free()
