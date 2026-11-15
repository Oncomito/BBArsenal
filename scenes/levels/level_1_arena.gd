extends Node2D

const WASD_UI_SCENE := preload("res://scenes/ui/wasd_ui.tscn")
const DASH_UI_SCENE := preload("res://scenes/ui/dash_ui.tscn")
const PARRY_UI_SCENE := preload("res://scenes/ui/parry_ui.tscn")
const SHIELD_UI_SCENE := preload("res://scenes/ui/shield_ui.tscn")
const OH_NO_UI_SCENE := preload("res://scenes/ui/oh_no.tscn")
const TO_THE_LEVELS_UI_SCENE := preload("res://scenes/ui/to_the_levelsss.tscn")

@export var max_floor_in_scene: int = 10
@export var next_level_scene: PackedScene = preload("res://scenes/levels/level_2_crossroads.tscn")
@export var trapdoor_local_center: Vector2 = Vector2.ZERO
@export var trapdoor_trigger_size: Vector2 = Vector2(480.0, 480.0)

var _is_trapdoor_open: bool = false
var _is_entering_trapdoor: bool = false
var _tutorial_waiting_enemies: bool = false

@onready var trap_door: TileMapLayer = get_node_or_null("TrapDoor")
@onready var spawner: Node2D = get_node_or_null("Spawner")
@onready var player: CharacterBody2D = get_node_or_null("Ordering/Player")
@onready var trap_door_zone: Area2D = get_node_or_null("TrapDoorZone")

func _ready() -> void:
	if AudioManager:
		AudioManager.play_music("gameplay")
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_setup_trapdoor_zone()

	if spawner:
		if "auto_start_on_ready" in spawner:
			spawner.auto_start_on_ready = false
		if spawner.has_method("prepare_wave"):
			spawner.prepare_wave()
		if spawner.has_signal("all_enemies_cleared") and not spawner.all_enemies_cleared.is_connected(_on_all_enemies_cleared):
			spawner.all_enemies_cleared.connect(_on_all_enemies_cleared)

	if GameManager:
		GameManager.max_arena_level = max_floor_in_scene
		if not GameManager.is_black_screen_active:
			GameManager.set_black_instant()

	var center_global := to_global(trapdoor_local_center)
	if is_instance_valid(player) and player.has_method("prepare_drop_in"):
		player.prepare_drop_in(center_global)

	var mode: String = GameManager.game_mode if GameManager else "levels"
	if mode == "tutorial":
		call_deferred("_start_tutorial")
	elif mode == "endless":
		call_deferred("_start_endless")
	else:
		var start_level: int = GameManager.current_level if GameManager else 1
		call_deferred("_start_floor", start_level)

func _setup_trapdoor_zone() -> void:
	if not is_instance_valid(trap_door_zone):
		trap_door_zone = Area2D.new()
		trap_door_zone.name = "TrapDoorZone"
		trap_door_zone.position = trapdoor_local_center

		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = trapdoor_trigger_size
		col.shape = shape
		trap_door_zone.add_child(col)
		add_child(trap_door_zone)

	trap_door_zone.monitoring = false
	trap_door_zone.monitorable = false
	if not trap_door_zone.body_entered.is_connected(_on_trap_door_zone_body_entered):
		trap_door_zone.body_entered.connect(_on_trap_door_zone_body_entered)

func _get_ui_parent() -> Node:
	if get_tree().current_scene:
		var ui_node := get_tree().current_scene.get_node_or_null("UI")
		if ui_node:
			return ui_node
	return self

func _reset_arena_state() -> void:
	_is_trapdoor_open = false
	_is_entering_trapdoor = false
	_tutorial_waiting_enemies = false

	if trap_door:
		trap_door.visible = true

	if trap_door_zone:
		trap_door_zone.set_deferred("monitoring", false)

	for proj in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(proj):
			proj.queue_free()

	if spawner and spawner.has_method("prepare_wave"):
		spawner.prepare_wave()

	var center_global := to_global(trapdoor_local_center)
	if is_instance_valid(player) and player.has_method("prepare_drop_in"):
		player.prepare_drop_in(center_global)

func _start_floor(level: int) -> void:
	_reset_arena_state()
	var center_global := to_global(trapdoor_local_center)

	if GameManager and GameManager.has_method("fade_from_black"):
		if not GameManager.is_black_screen_active:
			GameManager.set_black_instant()
		await GameManager.fade_from_black(0.3, 0.35)

	if not is_inside_tree():
		return

	if GameManager and GameManager.has_method("notify_level_started"):
		GameManager.notify_level_started()

	if is_instance_valid(player) and player.has_method("play_drop_in_animation"):
		await player.play_drop_in_animation(center_global)

	if not is_inside_tree():
		return

	if spawner and spawner.has_method("start_wave"):
		spawner.start_wave(level)

func _start_endless() -> void:
	_reset_arena_state()
	var center_global := to_global(trapdoor_local_center)

	if GameManager and GameManager.has_method("fade_from_black"):
		if not GameManager.is_black_screen_active:
			GameManager.set_black_instant()
		await GameManager.fade_from_black(0.3, 0.35)

	if not is_inside_tree():
		return

	if GameManager and GameManager.has_method("notify_level_started"):
		GameManager.notify_level_started()

	if is_instance_valid(player) and player.has_method("play_drop_in_animation"):
		await player.play_drop_in_animation(center_global)

	if not is_inside_tree():
		return

	if spawner and spawner.has_method("start_endless"):
		spawner.start_endless()

func _start_tutorial() -> void:
	_reset_arena_state()
	var center_global := to_global(trapdoor_local_center)

	if GameManager and GameManager.has_method("set_wave_enemies"):
		GameManager.set_wave_enemies(0)

	if GameManager and GameManager.has_method("fade_from_black"):
		if not GameManager.is_black_screen_active:
			GameManager.set_black_instant()
		await GameManager.fade_from_black(0.3, 0.35)

	if not is_inside_tree():
		return

	if is_instance_valid(player) and player.has_method("play_drop_in_animation"):
		await player.play_drop_in_animation(center_global)

	if not is_inside_tree():
		return

	var ui_parent := _get_ui_parent()

	var wasd_ui := WASD_UI_SCENE.instantiate() as Control
	ui_parent.add_child(wasd_ui)
	var moved_time := 0.0
	while is_inside_tree() and moved_time < 0.35:
		await get_tree().process_frame
		if Input.get_vector("player_left", "player_right", "player_up", "player_down") != Vector2.ZERO:
			moved_time += get_process_delta_time()
	if is_instance_valid(wasd_ui):
		wasd_ui.queue_free()

	if not is_inside_tree():
		return

	var dash_ui := DASH_UI_SCENE.instantiate() as Control
	ui_parent.add_child(dash_ui)
	while is_inside_tree():
		await get_tree().process_frame
		if is_instance_valid(player) and bool(player.get("is_dashing")):
			break
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(dash_ui):
		dash_ui.queue_free()

	if not is_inside_tree():
		return

	var parry_ui := PARRY_UI_SCENE.instantiate() as Control
	ui_parent.add_child(parry_ui)
	while is_inside_tree():
		await get_tree().process_frame
		if is_instance_valid(player) and bool(player.get("is_attacking")):
			break
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(parry_ui):
		parry_ui.queue_free()

	if not is_inside_tree():
		return

	var shield_ui := SHIELD_UI_SCENE.instantiate() as Control
	ui_parent.add_child(shield_ui)
	while is_inside_tree():
		await get_tree().process_frame
		if is_instance_valid(player) and bool(player.get("is_shield_active")):
			break
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(shield_ui):
		shield_ui.queue_free()

	if not is_inside_tree():
		return

	var oh_no_ui := OH_NO_UI_SCENE.instantiate() as Control
	ui_parent.add_child(oh_no_ui)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(oh_no_ui):
		oh_no_ui.queue_free()

	if not is_inside_tree():
		return

	_tutorial_waiting_enemies = true
	if spawner and spawner.has_method("start_wave"):
		spawner.start_wave(1, 3)

func _show_tutorial_complete_ui() -> void:
	var ui_parent := _get_ui_parent()
	var to_levels_ui := TO_THE_LEVELS_UI_SCENE.instantiate() as Control
	ui_parent.add_child(to_levels_ui)
	var start_btn := to_levels_ui.get_node_or_null("Start") as Button
	if start_btn:
		start_btn.grab_focus()
		start_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			if is_instance_valid(to_levels_ui):
				to_levels_ui.queue_free()
			if GameManager:
				GameManager.game_mode = "levels"
				GameManager.reset_run()
				await GameManager.fade_to_black(0.25)
			if is_inside_tree():
				await _start_floor(1)
		, CONNECT_ONE_SHOT)

func _on_all_enemies_cleared() -> void:
	if _tutorial_waiting_enemies:
		_tutorial_waiting_enemies = false
		_show_tutorial_complete_ui()
		return

	if GameManager and GameManager.game_mode != "levels":
		return

	if _is_trapdoor_open:
		return

	_is_trapdoor_open = true
	var current_lvl: int = GameManager.current_level if GameManager else 1
	if GameManager:
		GameManager.level_cleared.emit(current_lvl)

	if trap_door:
		trap_door.visible = false

	AudioManager.play_sfx("blast", 0.75, 2.0)
	if is_instance_valid(player) and player.has_method("camera_shake"):
		player.camera_shake(14.0, 0.3)

	if trap_door_zone:
		trap_door_zone.set_deferred("monitoring", true)
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree() or not _is_trapdoor_open or _is_entering_trapdoor:
			return
		if is_instance_valid(player) and trap_door_zone.overlaps_body(player):
			_enter_trapdoor(player)

func _on_trap_door_zone_body_entered(body: Node2D) -> void:
	if not _is_trapdoor_open or _is_entering_trapdoor:
		return
	if body.is_in_group("player"):
		_enter_trapdoor(body)

func _enter_trapdoor(player_node: Node2D) -> void:
	if _is_entering_trapdoor:
		return
	_is_entering_trapdoor = true

	if trap_door_zone:
		trap_door_zone.set_deferred("monitoring", false)

	for proj in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(proj):
			proj.queue_free()

	var center_global := to_global(trapdoor_local_center)
	if player_node.has_method("play_jump_into_trapdoor"):
		await player_node.play_jump_into_trapdoor(center_global)

	if not is_inside_tree():
		return

	if GameManager and GameManager.has_method("fade_to_black"):
		await GameManager.fade_to_black(0.25)

	if not is_inside_tree():
		return

	var next_level: int = GameManager.advance_level() if GameManager else 2

	if next_level <= max_floor_in_scene:
		await _start_floor(next_level)
	else:
		await _transition_to_next_scene()

func _transition_to_next_scene() -> void:
	if not next_level_scene:
		return

	var parent_node := get_parent()
	if parent_node and parent_node != get_tree().root:
		var saved_hp: float = float(player.get("health")) if is_instance_valid(player) and "health" in player else 100.0
		var next_instance := next_level_scene.instantiate()
		parent_node.add_child(next_instance)

		var new_player := next_instance.get_node_or_null("Player") as Node2D
		if not new_player:
			new_player = next_instance.get_node_or_null("Ordering/Player") as Node2D
		if new_player:
			if "health" in new_player:
				new_player.health = saved_hp
			if new_player.has_method("prepare_drop_in"):
				new_player.prepare_drop_in(new_player.global_position)

		if GameManager and GameManager.has_method("fade_from_black"):
			await GameManager.fade_from_black(0.3, 0.35)

		if GameManager and GameManager.has_method("notify_level_started"):
			GameManager.notify_level_started()

		if is_instance_valid(new_player) and new_player.has_method("play_drop_in_animation"):
			new_player.call_deferred("play_drop_in_animation", new_player.global_position)

		queue_free()
	else:
		get_tree().change_scene_to_packed(next_level_scene)
		if GameManager and GameManager.has_method("fade_from_black"):
			GameManager.call_deferred("fade_from_black", 0.3, 0.35)
		if GameManager and GameManager.has_method("notify_level_started"):
			GameManager.call_deferred("notify_level_started")
