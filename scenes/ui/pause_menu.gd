extends Control

const main_menu_scene: String = "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not get_tree().paused:
			toggle_pause()
		else:
			_on_main_menu_pressed()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if not get_tree().paused:
			return
		toggle_pause()

func _on_continue_pressed() -> void:
	toggle_pause()
	
func _on_settings_pressed() -> void:
	print("settings button pressed")
	
func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
