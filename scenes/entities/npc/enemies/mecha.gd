@tool
class_name Mecha
extends NPC

@export var stop_distance: float = 220.0
@export var projectile_kind: String = "fireball"
@export var projectile_element: String = "fire"
@export var projectile_speed: float = 950.0

var _cooldown_elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	
	if Engine.is_editor_hint():
		return

	is_boss = false
	speed = 180.0
	health_bar = $Stats/Health
	cooldown_bar = $Stats/Cooldown
	attack_cooldown = 2.0
	attack_range = 1000.0
	damage = 5.0

	_sync_bars()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_hit_flash(delta)
	_cooldown_elapsed = minf(_cooldown_elapsed + delta, attack_cooldown)
	_sync_bars()

	var distance := _update_enemy_movement(speed, stop_distance)
	if distance < 0.0:
		return

	if distance <= attack_range and _cooldown_elapsed >= attack_cooldown:
		_cooldown_elapsed = 0.0
		_sync_bars()
		_shoot_at_player()


func _shoot_at_player() -> void:
	if not is_instance_valid(player):
		return

	var muzzle := global_position + Vector2(0.0, -170)
	var dir := muzzle.direction_to(player.global_position)

	ProjectileManager.spawn_projectile(projectile_kind, {
		"spawn_point": muzzle,
		"direction": dir,
		"speed": projectile_speed,
		"damage": damage,
		"element": projectile_element,
		"parent": get_tree().current_scene,
		"scale": Vector2(5.0, 5.0)
	})

	AudioManager.play_sfx("fireball", randf_range(0.95, 1.05))


## Applies incoming damage, updates the overhead health bar, and destroys on 0 HP.
func take_damage(amount: float) -> void:
	if not apply_damage(amount):
		return

	_sync_bars()
	_flash_on_hit(Color(2.5, 2.5, 2.5, 1.0), 0.1)

	if health <= 0.0:
		_die()


func _sync_bars() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maxf(max_health, 1.0)
		health_bar.value = clampf(health, 0.0, health_bar.max_value)
	if is_instance_valid(cooldown_bar):
		cooldown_bar.max_value = maxf(attack_cooldown, 0.01)
		cooldown_bar.value = clampf(_cooldown_elapsed, 0.0, cooldown_bar.max_value)


func _update_hit_flash(delta: float) -> void:
	super._update_hit_flash(delta)
