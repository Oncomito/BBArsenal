extends Control

const main_scene: String = "res://scenes/main/main.tscn"

@onready var start_button: Button = $VBoxContainer/Start

var _is_starting: bool = false

func _ready() -> void:
	get_tree().paused = false
	if start_button:
		start_button.grab_focus()

func _on_start_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	AudioManager.play_sfx("click")
	if GameManager:
		if GameManager.has_method("reset_run"):
			GameManager.reset_run()
		if GameManager.has_method("fade_to_black"):
			await GameManager.fade_to_black(0.25)
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
