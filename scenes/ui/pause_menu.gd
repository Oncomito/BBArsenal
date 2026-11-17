extends Control

const main_menu_scene: String = "res://scenes/levels/main_menu.tscn"
const SETTINGS_SCENE := preload("res://scenes/ui/settings.tscn")

@onready var continue_button: Button = $VBoxContainer/Continue

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _is_game_over_active() -> bool:
	var game_over := get_parent().get_node_or_null("GameOver") as Control
	return game_over != null and game_over.visible

func toggle_pause() -> void:
	if _is_game_over_active():
		return
	AudioManager.play_sfx("click")
	if AudioManager.is_playing():
		AudioManager.pause_music()
	else:
		AudioManager.resume_music()
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused
	if visible and continue_button:
		continue_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over_active():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("joystick_start"):
		get_viewport().set_input_as_handled()
		toggle_pause()
	elif visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("joystick_cancel") or event.is_action_pressed("kb_cancel")):
		get_viewport().set_input_as_handled()
		toggle_pause()
	elif visible and event.is_action_pressed("ui_accept") and not get_viewport().gui_get_focus_owner():
		get_viewport().set_input_as_handled()
		toggle_pause()

func _on_continue_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	if not get_node_or_null("Settings"):
		var settings := SETTINGS_SCENE.instantiate()
		settings.call("set_return_focus", $VBoxContainer/Settings)
		add_child(settings)

func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx("click")
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
