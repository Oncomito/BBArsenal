extends Control

@onready var music_slider: HSlider = $Center/Panel/Content/MusicRow/MusicSlider
@onready var music_value: Label = $Center/Panel/Content/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Center/Panel/Content/SfxRow/SfxSlider
@onready var sfx_value: Label = $Center/Panel/Content/SfxRow/SfxValue
@onready var hud_button: Button = $Center/Panel/Content/HudRow/HudButton
@onready var gamepad_toggle: Button = $Center/Panel/Content/GamepadRow/GamepadToggle

var return_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.focus_mode = Control.FOCUS_ALL
	sfx_slider.focus_mode = Control.FOCUS_ALL
	hud_button.focus_mode = Control.FOCUS_ALL
	gamepad_toggle.focus_mode = Control.FOCUS_ALL
	var back_button: Button = $Center/Panel/Content/Back
	music_slider.focus_neighbor_bottom = music_slider.get_path_to(sfx_slider)
	sfx_slider.focus_neighbor_top = sfx_slider.get_path_to(music_slider)
	sfx_slider.focus_neighbor_bottom = sfx_slider.get_path_to(hud_button)
	hud_button.focus_neighbor_top = hud_button.get_path_to(sfx_slider)
	hud_button.focus_neighbor_bottom = hud_button.get_path_to(gamepad_toggle)
	gamepad_toggle.focus_neighbor_top = gamepad_toggle.get_path_to(hud_button)
	gamepad_toggle.focus_neighbor_bottom = gamepad_toggle.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(gamepad_toggle)
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume
	_update_value_labels()
	_update_hud_button_visual()
	var virtual_gamepad := GameManager.virtual_gamepad_enabled if GameManager else false
	gamepad_toggle.set_pressed_no_signal(virtual_gamepad)
	_update_gamepad_toggle_visual(virtual_gamepad)
	music_slider.grab_focus()

func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	_update_value_labels()

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_update_value_labels()

func _on_hud_button_pressed() -> void:
	AudioManager.play_sfx("click")
	if GameManager:
		GameManager.toggle_hud_layout()
	_update_hud_button_visual()

func _update_hud_button_visual() -> void:
	if not is_instance_valid(hud_button):
		return
	var current_layout := GameManager.hud_layout if GameManager else GameManager.HUD_LAYOUT.TOP
	hud_button.text = "BOTTOM LEFT" if current_layout == GameManager.HUD_LAYOUT.BOTTOM else "TOP BAR"
	var text_color := Color(0.55, 1.0, 0.92, 1.0)
	hud_button.add_theme_color_override("font_color", text_color)
	hud_button.add_theme_color_override("font_pressed_color", text_color)
	hud_button.add_theme_color_override("font_hover_color", text_color)
	hud_button.add_theme_color_override("font_focus_color", text_color)

func _on_gamepad_toggle_toggled(toggled_on: bool) -> void:
	AudioManager.play_sfx("click")
	if GameManager:
		GameManager.set_virtual_gamepad_enabled(toggled_on)
	_update_gamepad_toggle_visual(toggled_on)

func _update_gamepad_toggle_visual(enabled: bool) -> void:
	if not is_instance_valid(gamepad_toggle):
		return
	gamepad_toggle.text = "ON" if enabled else "OFF"
	var text_color := Color(0.55, 1.0, 0.92, 1.0) if enabled else Color(0.7, 0.76, 0.78, 0.85)
	gamepad_toggle.add_theme_color_override("font_color", text_color)
	gamepad_toggle.add_theme_color_override("font_pressed_color", text_color)
	gamepad_toggle.add_theme_color_override("font_hover_color", text_color)
	gamepad_toggle.add_theme_color_override("font_hover_pressed_color", text_color)
	gamepad_toggle.add_theme_color_override("font_focus_color", text_color)

func _update_value_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)

func _on_back_pressed() -> void:
	_close()

func set_return_focus(control: Control) -> void:
	return_focus = control

func _close() -> void:
	queue_free()
	if is_instance_valid(return_focus):
		return_focus.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("kb_cancel") or event.is_action_pressed("joystick_cancel"):
		get_viewport().set_input_as_handled()
		_close()
