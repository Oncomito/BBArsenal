extends Enemy
## Boss Mecha enemy cycling through multi-type ProjectileManager barrage patterns.

signal health_changed(current_health: float, max_health: float)
signal boss_defeated

@export var boss_title: String = "MECHA OVERLORD"
@export var stop_distance: float = 320.0


var _cooldown_timer: float = 1.0
var _pattern_index: int = 0


func _ready() -> void:
	super._ready()
	is_boss = true
	speed = 135.0
	health_bar = $Stats/Health
	attack_cooldown = 2.2
	attack_range = 1500.0

	if is_instance_valid(health_bar) and health_bar.get_parent() is CanvasItem:
		(health_bar.get_parent() as CanvasItem).visible = false
	_sync_health_bar()

	health_changed.emit(health, max_health)
	
	GameManager.register_boss(self)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_hit_flash(delta)
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	var distance := _update_enemy_movement(speed, stop_distance)
	if distance < 0.0:
		return

	if distance <= attack_range and _cooldown_timer <= 0.0:
		_fire_next_pattern()
		_cooldown_timer = attack_cooldown


func _fire_next_pattern() -> void:
	if not is_instance_valid(player):
		return

	var origin: Vector2 = global_position + Vector2(0.0, -165.0)
	var base_dir: Vector2 = (player.global_position - origin).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT

	match _pattern_index:
		0:
			_attack_radial_nova(origin, base_dir)
		1:
			_attack_rocket_salvo(origin, base_dir)
		2:
			_attack_wave_fan(origin, base_dir)
		3:
			_attack_laser_overload(origin, base_dir)

	_pattern_index = (_pattern_index + 1) % 4


func _attack_radial_nova(origin: Vector2, base_dir: Vector2) -> void:
	var count: int = 12
	var base_angle: float = base_dir.angle()
	for i in range(count):
		var angle: float = base_angle + (TAU * float(i) / float(count))
		var is_orb: bool = (i % 2) == 0
		var kind: String = "orb" if is_orb else "shard"
		var spd: float = 650.0 if is_orb else 860.0
		_spawn_shot(kind, origin, Vector2.from_angle(angle), "plasma", spd, 10.0, 3.8)
	AudioManager.play_sfx("blast", 0.85)


func _attack_rocket_salvo(origin: Vector2, base_dir: Vector2) -> void:
	for offset in [-0.36, -0.12, 0.12, 0.36]:
		_spawn_shot("rocket", origin, base_dir.rotated(offset), "fire", 620.0, 14.0, 4.0)
	for offset in [-0.18, 0.0, 0.18]:
		_spawn_shot("tracer", origin, base_dir.rotated(offset), "electric", 1150.0, 8.0, 3.0)
	AudioManager.play_sfx("fireball", 0.75)


func _attack_wave_fan(origin: Vector2, base_dir: Vector2) -> void:
	for step in range(-2, 3):
		var dir: Vector2 = base_dir.rotated(float(step) * 0.22)
		var is_wave: bool = (abs(step) % 2) == 0
		var kind: String = "wave" if is_wave else "disc"
		var elem: String = "crimson" if is_wave else "arcane"
		var spd: float = 780.0 if is_wave else 840.0
		_spawn_shot(kind, origin, dir, elem, spd, 11.5, 3.0)
	for side in [-0.5, 0.5]:
		_spawn_shot("helix", origin, base_dir.rotated(side), "arcane", 700.0, 12.0, 4.0)
	AudioManager.play_sfx("fireball", 1.1)


func _attack_laser_overload(origin: Vector2, base_dir: Vector2) -> void:
	ProjectileManager.spawn_laser({
		"spawn_point": origin,
		"direction": base_dir,
		"target": player,
		"damage": 22.0,
		"duration": 0.9,
		"element": "electric",
		"scale": Vector2(1.6, 1.6),
		"parent": get_parent(),
	})
	for offset in [0.45, -0.45, 2.35, -2.35]:
		_spawn_shot("spinner", origin, base_dir.rotated(offset), "electric", 540.0, 11.0, 4.0)
	AudioManager.play_sfx("blast", 1.2)


func _spawn_shot(
	kind: String,
	origin: Vector2,
	dir: Vector2,
	element: String,
	spd: float,
	dmg: float,
	proj_scale: float
) -> void:
	ProjectileManager.spawn_projectile(kind, {
		"spawn_point": origin,
		"direction": dir,
		"target": player,
		"speed": spd,
		"damage": dmg,
		"element": element,
		"scale": Vector2.ONE * proj_scale,
		"parent": get_parent(),
	})


## Applies incoming damage, updates the boss health bar, and destroys on 0 HP.
func take_damage(amount: float) -> void:
	if not apply_damage(amount):
		return

	_sync_health_bar()
	health_changed.emit(health, max_health)
	if GameManager and GameManager.has_method("update_boss_health"):
		GameManager.update_boss_health(health, max_health, boss_title)

	_flash_on_hit(Color(2.2, 2.2, 2.2, 1.0), 0.08)

	if health <= 0.0:
		_die()


func _sync_health_bar() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maxf(max_health, 1.0)
		health_bar.value = clampf(health, 0.0, health_bar.max_value)

func _die() -> void:
	super._die()
	boss_defeated.emit()