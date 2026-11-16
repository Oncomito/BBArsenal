extends Control

const main_menu_scene: String = "res://scenes/levels/main_menu.tscn"

@onready var restart_button: Button = $VBoxContainer/Restart

var player: Node = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_player()

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_bind_player()

func _bind_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_signal("player_died"):
		if not player.player_died.is_connected(show_game_over):
			player.player_died.connect(show_game_over)

func show_game_over() -> void:
	var pause_menu := get_parent().get_node_or_null("PauseMenu") as Control
	AudioManager.fade_out(2.5)
	if pause_menu:
		pause_menu.visible = false
	visible = true
	get_tree().paused = true
	if restart_button:
		restart_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("kb_enter") or event.is_action_pressed("joystick_accept") or event.is_action_pressed("ui_accept"):
		if not get_viewport().gui_get_focus_owner():
			get_viewport().set_input_as_handled()
			_on_restart_pressed()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("joystick_cancel") or event.is_action_pressed("kb_cancel"):
		get_viewport().set_input_as_handled()
		_on_main_menu_pressed()

func _on_restart_pressed() -> void:
	AudioManager.play_sfx("click")
	visible = false
	Gamemanager.restart_game()

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	print("settings button pressed")

func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx("click")
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
