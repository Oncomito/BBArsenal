extends Node2D

const MAIN_MENU_SCENE: String = "res://scenes/levels/main_menu.tscn"

var _transitioning: bool = false

func _ready() -> void:
	if AudioManager:
		AudioManager.play_sfx("ting", 1.15, -4.0)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport and viewport.get_texture():
		var img: Image = viewport.get_texture().get_image()
		if img:
			img.save_png("res://assets/images/splash_screen.png")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_go_to_main_menu()

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	_go_to_main_menu()

func _go_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	if GameManager and GameManager.has_method("fade_to_black"):
		await GameManager.fade_to_black(0.2)
	if is_inside_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
