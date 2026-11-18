extends Control

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")

@onready var health_bar: ProgressBar = $health
@onready var energy_bar: ProgressBar = $energy
@onready var pause_button: Button = $Button
@onready var levels_label: Label = get_node_or_null("levels")
@onready var enemy_label: Label = get_node_or_null("EnemyCounter")

var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_update_labels()

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_bind_player()
		return

	if "health" in player and "max_health" in player:
		health_bar.max_value = player.max_health
		health_bar.value = player.health

	if "energy" in player and "max_energy" in player:
		energy_bar.max_value = player.max_energy
		energy_bar.value = player.energy

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
	if health_bar:
		health_bar.max_value = max_health_val
		health_bar.value = current_health

func _on_player_energy_changed(current_energy: float, max_energy_val: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_energy_val
		energy_bar.value = current_energy

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

	if GameManager.game_mode == "endless":
		if levels_label:
			levels_label.text = "pts %d" % GameManager.score
		if enemy_label:
			enemy_label.text = "enemy %d / endless" % GameManager.enemies_killed
	elif GameManager.game_mode == "tutorial":
		if levels_label:
			levels_label.text = "tutorial"
		if enemy_label:
			enemy_label.text = "enemy %d / %d" % [GameManager.enemies_killed, GameManager.total_enemies]
	else:
		if levels_label:
			levels_label.text = "lvl %s" % GameManager.get_level_code()
		if enemy_label:
			enemy_label.text = "enemy %d/%d" % [GameManager.enemies_killed, GameManager.total_enemies]
