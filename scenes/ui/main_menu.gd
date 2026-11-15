extends Control

const main_scene: String = "res://scenes/main/main.tscn"

@onready var start_button: Button = $VBoxContainer/Start

func _ready() -> void:
	get_tree().paused = false
	if start_button:
		start_button.grab_focus()

func _on_start_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file(main_scene)

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	print("Open settings menu here")

func _on_exit_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("kb_cancel") or event.is_action_pressed("joystick_cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_exit_pressed()
	elif event.is_action_pressed("kb_enter") or event.is_action_pressed("joystick_accept") or event.is_action_pressed("ui_accept"):
		if not get_viewport().gui_get_focus_owner():
			get_viewport().set_input_as_handled()
			_on_start_pressed()
