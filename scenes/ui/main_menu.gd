extends Control

const main_scene: String = "res://scenes/main/main.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = false
	
	
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(main_scene)
func _on_settings_pressed() -> void:
	print("Open settings menu here")
func _on_exit_pressed() -> void:
	get_tree().quit()
