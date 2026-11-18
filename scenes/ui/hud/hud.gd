extends Control

const PAUSE_MENU_SCENE := preload("res://scenes/ui/menus/pause_menu.tscn")

@export var layout_id: String = "top_bar"

@onready var health_bar: ProgressBar = get_node_or_null("%health") if get_node_or_null("%health") != null else get_node_or_null("health")
@onready var top_energy_bar: ProgressBar = get_node_or_null("energy")
@onready var panel_energy_bar: ProgressBar = get_node_or_null("Panel/energy")
@onready var pause_button: Button = get_node_or_null("Button")
@onready var normal_levels_group: Control = get_node_or_null("NormalLevels")
@onready var boss_fight_group: Control = get_node_or_null("BossFight")
@onready var levels_label: Label = get_node_or_null("NormalLevels/levels") if get_node_or_null("NormalLevels/levels") != null else get_node_or_null("levels")
@onready var boss_levels_label: Label = get_node_or_null("BossFight/levels")
@onready var enemy_label: Label = get_node_or_null("NormalLevels/EnemyCounter") if get_node_or_null("NormalLevels/EnemyCounter") != null else get_node_or_null("EnemyCounter")
@onready var boss_bar: ProgressBar = get_node_or_null("BossFight/Boss")
@onready var boss_hp_label: Label = get_node_or_null("BossFight/BossHp")

var player: Node = null
var boss: Node = null
var _is_swapping: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager:
		if not GameManager.hud_layout_changed.is_connected(_on_hud_layout_changed):
			GameManager.hud_layout_changed.connect(_on_hud_layout_changed)
		if _check_layout_match():
			return
	_bind_player()
	if pause_button:
		pause_button.focus_mode = Control.FOCUS_NONE
		if not pause_button.pressed.is_connected(_on_pause_button_pressed):
			pause_button.pressed.connect(_on_pause_button_pressed)
	if GameManager:
		if not GameManager.level_changed.is_connected(_on_level_changed):
			GameManager.level_changed.connect(_on_level_changed)
		if not GameManager.stats_changed.is_connected(_update_labels):
			GameManager.stats_changed.connect(_update_labels)
		if GameManager.has_signal("boss_spawned") and not GameManager.boss_spawned.is_connected(_on_boss_spawned):
			GameManager.boss_spawned.connect(_on_boss_spawned)
		if GameManager.has_signal("boss_health_changed") and not GameManager.boss_health_changed.is_connected(_on_boss_health_changed):
			GameManager.boss_health_changed.connect(_on_boss_health_changed)
		if GameManager.has_signal("boss_defeated") and not GameManager.boss_defeated.is_connected(_on_boss_defeated):
			GameManager.boss_defeated.connect(_on_boss_defeated)
	_bind_boss()
	_update_labels()

func _on_hud_layout_changed(_new_layout: String) -> void:
	if _is_swapping or is_queued_for_deletion():
		return
	_check_layout_match()

func _check_layout_match() -> bool:
	if _is_swapping or not GameManager or GameManager.hud_layout == layout_id:
		return false
	_is_swapping = true
	call_deferred("_swap_to_hud_layout")
	return true

func _swap_to_hud_layout() -> void:
	if not is_inside_tree() or not GameManager or GameManager.hud_layout == layout_id:
		_is_swapping = false
		return
	var parent := get_parent()
	if not parent:
		_is_swapping = false
		return
	var scene_res := load(GameManager.get_hud_scene_path()) as PackedScene
	if not scene_res:
		_is_swapping = false
		return
	var new_hud := scene_res.instantiate()
	var idx := get_index()
	parent.add_child(new_hud)
	parent.move_child(new_hud, idx)
	queue_free()

func _process(_delta: float) -> void:
	if _is_swapping:
		return
	if not is_instance_valid(boss):
		_bind_boss()
	if not is_instance_valid(player):
		_bind_player()
		return

	if "health" in player and "max_health" in player and is_instance_valid(health_bar):
		health_bar.max_value = player.max_health
		health_bar.value = player.health

	if "energy" in player and "max_energy" in player:
		_apply_energy_value(player.energy, player.max_energy)


func _bind_boss() -> void:
	var found: Node = null
	if GameManager and "active_boss" in GameManager and is_instance_valid(GameManager.active_boss):
		found = GameManager.active_boss
	else:
		found = get_tree().get_first_node_in_group("boss")

	if not is_instance_valid(found) or found.is_queued_for_deletion():
		boss = null
		_refresh_boss_mode_visibility()
		return

	_attach_boss(found)


func _attach_boss(boss_node: Node) -> void:
	if not is_instance_valid(boss_node) or boss_node.is_queued_for_deletion():
		boss = null
		_refresh_boss_mode_visibility()
		return

	boss = boss_node
	if boss.has_signal("health_changed") and not boss.health_changed.is_connected(_on_direct_boss_health_changed):
		boss.health_changed.connect(_on_direct_boss_health_changed)
	if boss.has_signal("boss_defeated") and not boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.connect(_on_boss_defeated)

	_refresh_boss_mode_visibility()
	var cur_hp: float = float(boss.get("health")) if "health" in boss else 0.0
	var max_hp: float = float(boss.get("max_health")) if "max_health" in boss else 100.0
	var title: String = str(boss.get("boss_title")) if "boss_title" in boss else "BOSS"
	_apply_boss_health(cur_hp, max_hp, title)


func _refresh_boss_mode_visibility() -> void:
	var is_boss_mode: bool = GameManager != null and GameManager.game_mode == "boss"
	var has_boss: bool = is_instance_valid(boss) and not boss.is_queued_for_deletion()
	var show_boss_ui: bool = has_boss or is_boss_mode
	if is_instance_valid(boss_fight_group):
		boss_fight_group.visible = show_boss_ui
	if is_instance_valid(normal_levels_group):
		normal_levels_group.visible = not show_boss_ui


func _on_boss_spawned(boss_node: Node) -> void:
	_attach_boss(boss_node)


func _on_direct_boss_health_changed(current_health: float, max_health_val: float) -> void:
	var title: String = str(boss.get("boss_title")) if is_instance_valid(boss) and "boss_title" in boss else "BOSS"
	_apply_boss_health(current_health, max_health_val, title)


func _on_boss_health_changed(current_health: float, max_health_val: float, boss_name: String) -> void:
	_refresh_boss_mode_visibility()
	_apply_boss_health(current_health, max_health_val, boss_name)


func _on_boss_defeated() -> void:
	boss = null
	_refresh_boss_mode_visibility()
	if GameManager and GameManager.game_mode == "boss":
		var max_hp: float = boss_bar.max_value if is_instance_valid(boss_bar) else 1200.0
		_apply_boss_health(0.0, max_hp, "BOSS DEFEATED")


func _apply_boss_health(current_health: float, max_health_val: float, boss_name: String) -> void:
	if is_instance_valid(boss_bar):
		boss_bar.max_value = maxf(max_health_val, 1.0)
		boss_bar.value = clampf(current_health, 0.0, boss_bar.max_value)
	if is_instance_valid(boss_hp_label):
		boss_hp_label.text = "%s  %d / %d" % [boss_name, int(ceilf(current_health)), int(roundf(max_health_val))]

func _bind_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("energy_changed") and not player.energy_changed.is_connected(_on_player_energy_changed):
		player.energy_changed.connect(_on_player_energy_changed)

	if "health" in player and "max_health" in player:
		_on_player_health_changed(player.health, player.max_health)
	if "energy" in player and "max_energy" in player:
		_on_player_energy_changed(player.energy, player.max_energy)

func _on_player_health_changed(current_health: float, max_health_val: float) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health_val
		health_bar.value = current_health

func _on_player_energy_changed(current_energy: float, max_energy_val: float) -> void:
	_apply_energy_value(current_energy, max_energy_val)

func _apply_energy_value(current_energy: float, max_energy_val: float) -> void:
	if is_instance_valid(top_energy_bar):
		top_energy_bar.max_value = max_energy_val
		top_energy_bar.value = current_energy
	if is_instance_valid(panel_energy_bar):
		panel_energy_bar.max_value = max_energy_val
		panel_energy_bar.value = current_energy

func _on_pause_button_pressed() -> void:
	var pause_menu: Node = null
	if get_parent():
		pause_menu = get_parent().get_node_or_null("PauseMenu")
	if not pause_menu and get_tree().current_scene:
		pause_menu = get_tree().current_scene.find_child("PauseMenu", true, false)
	if not pause_menu and PAUSE_MENU_SCENE and get_parent():
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		get_parent().add_child(pause_menu)
	if pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()

func _on_level_changed(_new_level: int) -> void:
	_update_labels()

func _update_labels() -> void:
	if not GameManager:
		return

	var level_text := ""
	var enemy_text := ""
	if GameManager.game_mode == "endless":
		level_text = "pts %d" % GameManager.score
		enemy_text = "enemy %d / endless" % GameManager.enemies_killed
	elif GameManager.game_mode == "tutorial":
		level_text = "tutorial"
		enemy_text = "enemy %d / %d" % [GameManager.enemies_killed, GameManager.total_enemies]
	elif GameManager.game_mode == "boss":
		level_text = "BOSS"
		enemy_text = "boss %d / %d" % [GameManager.enemies_killed, GameManager.total_enemies]
	else:
		level_text = "lvl %s" % GameManager.get_level_code()
		enemy_text = "enemy %d/%d" % [GameManager.enemies_killed, GameManager.total_enemies]

	if is_instance_valid(levels_label):
		levels_label.text = level_text
	if is_instance_valid(boss_levels_label):
		boss_levels_label.text = level_text
	if is_instance_valid(enemy_label):
		enemy_label.text = enemy_text
