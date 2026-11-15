extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/mecha.tscn")
@export var enemy_scenes: Array[PackedScene] = [
	preload("res://scenes/enemies/mecha.tscn")
]
@export var max_enemies: int = 8
@export var min_player_distance: float = 250.0

@onready var spawn_area: ReferenceRect = $ReferenceRect
@onready var timer: Timer = $Timer

func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	spawn_enemy()

func spawn_enemy() -> void:
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

	var enemy = chosen_scene.instantiate()

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

	enemy.global_position = spawn_pos

	var target_parent: Node = get_tree().current_scene
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		target_parent = self
	target_parent.call_deferred("add_child", enemy)
