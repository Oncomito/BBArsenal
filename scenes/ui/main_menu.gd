extends Control

const main_scene: String = "res://scenes/main/main.tscn"

func _ready() -> void:
	get_tree().paused = false
	
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(main_scene)

func _on_settings_pressed() -> void:
	print("Open settings menu here")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_exit_pressed()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_start_pressed()