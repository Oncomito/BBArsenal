extends Node2D

signal all_enemies_cleared

@export var enemy_scene: PackedScene = preload("res://scenes/entities/enemies/mecha/mecha.tscn")
@export var spawn_area: ReferenceRect
@export var enemy_scenes: Array[PackedScene] = [
	preload("res://scenes/entities/enemies/mecha/mecha.tscn")
]
@export var max_enemies: int = 2
@export var min_player_distance: float = 250.0
@export var base_enemies_per_level: int = 4
@export var enemies_increase_per_level: int = 2
@export var auto_start_on_ready: bool = true

var total_to_spawn: int = 4
var spawned_count: int = 0
var alive_enemies: int = 0
var wave_active: bool = false
var wave_cleared: bool = false
var is_endless: bool = false

@onready var timer: Timer = $Timer
@onready var layer: Node2D = self.get_parent()

func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	timer.stop()
	if auto_start_on_ready:
		var lvl: int = GameManager.current_level if GameManager else 1
		start_wave(lvl)

func prepare_wave() -> void:
	wave_active = false
	wave_cleared = false
	is_endless = false
	spawned_count = 0
	alive_enemies = 0
	if timer:
		timer.stop()

func start_wave(level: int = 1, custom_total: int = -1) -> void:
	is_endless = false
	if custom_total > 0:
		total_to_spawn = custom_total
	else:
		total_to_spawn = max(1, base_enemies_per_level + max(level - 1, 0) * enemies_increase_per_level)
	spawned_count = 0
	alive_enemies = 0
	wave_active = true
	wave_cleared = false
	if GameManager and GameManager.has_method("set_wave_enemies"):
		GameManager.set_wave_enemies(total_to_spawn)
	if timer:
		timer.start()
	call_deferred("spawn_enemy")

func start_endless() -> void:
	is_endless = true
	spawned_count = 0
	alive_enemies = 0
	wave_active = true
	wave_cleared = false
	if GameManager and GameManager.has_method("set_wave_enemies"):
		GameManager.set_wave_enemies(0)
	if timer:
		timer.start()
	call_deferred("spawn_enemy")

func _on_timer_timeout() -> void:
	if not wave_active or wave_cleared:
		timer.stop()
		return
	spawn_enemy()

func spawn_enemy() -> void:
	if not wave_active or wave_cleared:
		return
	if not is_endless and spawned_count >= total_to_spawn:
		timer.stop()
		_check_wave_cleared()
		return

	var pool: Array[PackedScene] = []
	if enemy_scenes.size() > 0:
		pool = enemy_scenes
	elif enemy_scene:
		pool.append(enemy_scene)

	if pool.is_empty():
		return

	var current_enemies := get_tree().get_nodes_in_group("enemy")
	if current_enemies.size() >= max_enemies:
		return

	var chosen_scene: PackedScene = pool.pick_random()
	if not chosen_scene:
		return

	var enemy := chosen_scene.instantiate() as Node2D
	if not enemy:
		return

	var rect_pos: Vector2 = spawn_area.global_position
	var rect_w: float = spawn_area.size.x * spawn_area.scale.x
	var rect_h: float = spawn_area.size.y * spawn_area.scale.y

	var min_x := minf(rect_pos.x, rect_pos.x + rect_w)
	var max_x := maxf(rect_pos.x, rect_pos.x + rect_w)
	var min_y := minf(rect_pos.y, rect_pos.y + rect_h)
	var max_y := maxf(rect_pos.y, rect_pos.y + rect_h)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var spawn_pos := Vector2.ZERO
	var attempts := 0
	while attempts < 10:
		attempts += 1
		spawn_pos = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if not is_instance_valid(player) or spawn_pos.distance_to(player.global_position) >= min_player_distance:
			break

	var level_root: Node = get_parent()
	var target_parent: Node = null
	if level_root and level_root.has_node("Ordering"):
		target_parent = level_root.get_node("Ordering")
	elif level_root:
		target_parent = level_root
	else:
		target_parent = get_tree().current_scene if get_tree().current_scene else self

	spawned_count += 1
	alive_enemies += 1
	if not is_endless and spawned_count >= total_to_spawn and timer:
		timer.stop()

	enemy.tree_exited.connect(_on_enemy_tree_exited, CONNECT_ONE_SHOT)

	if target_parent is Node2D:
		enemy.position = (target_parent as Node2D).to_local(spawn_pos)
	else:
		enemy.global_position = spawn_pos

	target_parent.call_deferred("add_child", enemy)

func _on_enemy_tree_exited() -> void:
	alive_enemies = max(alive_enemies - 1, 0)
	if not is_inside_tree():
		return
	call_deferred("_check_wave_cleared")

func _check_wave_cleared() -> void:
	if is_endless:
		return
	if not is_inside_tree() or not wave_active or wave_cleared:
		return
	if spawned_count < total_to_spawn:
		return

	var active_enemy_count := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			active_enemy_count += 1

	if alive_enemies <= 0 and active_enemy_count == 0:
		wave_active = false
		wave_cleared = true
		if timer:
			timer.stop()
		all_enemies_cleared.emit()
