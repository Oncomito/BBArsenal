extends Node2D

const MAIN_MENU_SCENE: String = "res://scenes/ui/menus/main_menu.tscn"

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _transitioning: bool = false
var _screenshot_taken: bool = false

func _ready() -> void:
	if AudioManager:
		AudioManager.play_sfx("ting", 1.15, -4.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_go_to_main_menu()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if _transitioning or _screenshot_taken:
		return
	_screenshot_taken = true
	
	var anim: Animation = anim_player.get_animation(anim_name)
	if anim:
		anim_player.seek(anim.length, true)

	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
		
	var viewport := get_viewport()
	if viewport and viewport.get_texture():
		var img: Image = viewport.get_texture().get_image()
		if img:
			var err := img.save_png("res://assets/images/splash_screen.png")
			if err != OK:
				push_error("Failed to save screenshot: " + str(err))
				
	_go_to_main_menu()

func _go_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	if GameManager and GameManager.has_method("fade_to_black"):
		await GameManager.fade_to_black(0.2)
	if is_inside_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
