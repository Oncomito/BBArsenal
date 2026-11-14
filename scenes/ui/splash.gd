extends Node

func _ready() -> void:
	await RenderingServer.frame_post_draw
	
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://assets/images/splash_screen.png")

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
