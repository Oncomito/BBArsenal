extends Control

@onready var levels_label: Label = get_node_or_null("Levels")

var _banner_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if levels_label:
		levels_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false

	if GameManager and GameManager.has_signal("level_started") and not GameManager.level_started.is_connected(_on_level_started):
		GameManager.level_started.connect(_on_level_started)

func _on_level_started(banner_text: String) -> void:
	show_level_banner(banner_text)

func show_level_banner(banner_text: String) -> void:
	if levels_label:
		levels_label.text = banner_text

	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()

	visible = true
	modulate.a = 0.0

	_banner_tween = create_tween()
	_banner_tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.1)
	_banner_tween.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(func() -> void:
		visible = false
	)
