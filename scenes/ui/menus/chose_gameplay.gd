extends Control

const main_scene: String = "res://scenes/main/main.tscn"
const main_menu_scene: String = "res://scenes/ui/menus/main_menu.tscn"

@onready var tutorial_button: Button = $VBoxContainer/Start

var _is_busy: bool = false

func _ready() -> void:
	get_tree().paused = false
	if tutorial_button:
		tutorial_button.grab_focus()
	if GameManager and GameManager.is_black_screen_active and GameManager.has_method("fade_from_black"):
		GameManager.call_deferred("fade_from_black", 0.25, 0.1)

func _start_mode(mode: String) -> void:
	if _is_busy:
		return
	_is_busy = true
	AudioManager.play_sfx("click")
	AudioManager.fade_out(2.0)
	# AudioManager.play_music("gameplay")
	
	GameManager.game_mode = mode
	GameManager.reset_run()
	await GameManager.fade_to_black(0.25)
	
	get_tree().change_scene_to_file(main_scene)

func _on_start_pressed() -> void:
	_start_mode("tutorial")

func _on_settings_pressed() -> void:
	_start_mode("levels")

func _on_endless_pressed() -> void:
	_start_mode("endless")

func _on_boss_pressed() -> void:
	_start_mode("boss")

func _on_exit_pressed() -> void:
	if _is_busy:
		return
	_is_busy = true
	AudioManager.play_sfx("click")
	if GameManager and GameManager.has_method("fade_to_black"):
		await GameManager.fade_to_black(0.2)
	get_tree().change_scene_to_file(main_menu_scene)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("kb_cancel") or event.is_action_pressed("joystick_cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_exit_pressed()
