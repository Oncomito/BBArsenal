extends Control

const CHOOSE_GAMEPLAY_SCENE: String = "res://scenes/ui/select_level.tscn"
const SETTINGS_SCENE := preload("res://scenes/ui/settings.tscn")

@onready var start_button: Button = $VBoxContainer/Start

var _is_starting: bool = false

func _ready() -> void:
	get_tree().paused = false
	if not AudioManager.is_playing():
		AudioManager.play_music("menu")
		AudioManager.fade_in(0.5)
	if start_button:
		start_button.grab_focus()
	if GameManager.is_black_screen_active:
		GameManager.call_deferred("fade_from_black", 0.25, 0.1)

func _on_start_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	AudioManager.play_sfx("click")
	if GameManager and GameManager.has_method("fade_to_black"):
		await GameManager.fade_to_black(0.2)
	get_tree().change_scene_to_file(CHOOSE_GAMEPLAY_SCENE)

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("click")
	if not get_node_or_null("Settings"):
		var settings := SETTINGS_SCENE.instantiate()
		settings.call("set_return_focus", $VBoxContainer/Settings)
		add_child(settings)

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
