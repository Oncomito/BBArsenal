extends Control

@onready var music_slider: HSlider = $Center/Panel/Content/MusicRow/MusicSlider
@onready var music_value: Label = $Center/Panel/Content/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Center/Panel/Content/SfxRow/SfxSlider
@onready var sfx_value: Label = $Center/Panel/Content/SfxRow/SfxValue

var return_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.focus_mode = Control.FOCUS_ALL
	sfx_slider.focus_mode = Control.FOCUS_ALL
	var back_button: Button = $Center/Panel/Content/Back
	music_slider.focus_neighbor_bottom = music_slider.get_path_to(sfx_slider)
	sfx_slider.focus_neighbor_top = sfx_slider.get_path_to(music_slider)
	sfx_slider.focus_neighbor_bottom = sfx_slider.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(sfx_slider)
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume
	_update_value_labels()
	music_slider.grab_focus()

func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	_update_value_labels()

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_update_value_labels()

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