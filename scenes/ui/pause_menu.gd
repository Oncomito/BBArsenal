extends Control

const main_menu_scene: String = "res://scenes/ui/main_menu.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle_pause() -> void:
	var is_paused: bool = not get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused

func _unhandled_input(event: InputEvent) -> void:
	# Uses the "esc" action already configured in your project.godot
	if event.is_action_pressed("esc"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	toggle_pause()
	
func _on_settings_pressed() -> void:
	print("settings button pressed")
	
func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
