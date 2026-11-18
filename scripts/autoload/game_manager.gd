extends Node

signal player_heal(amount: float)
signal player_energize(amoung: float)
signal level_changed(new_level: int)
signal level_started(level_code: String)
signal level_cleared(level: int)
signal stats_changed
signal virtual_gamepad_changed(enabled: bool)

var game_mode: String = "levels"
var current_level: int = 1
var current_stage: int = 1
var current_sublevel: int = 0
var max_arena_level: int = 10
var enemies_killed: int = 0
var total_enemies: int = 0
var score: int = 0
var exp: float = 0.0
var virtual_gamepad_enabled: bool = true

const BASE_RESOLUTION := Vector2i(1920, 1080)
const MAX_WINDOWED_RATIO := 0.9
const GAME_SETTINGS_PATH := "user://game_settings.cfg"

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null
var is_black_screen_active: bool = false

var device_os: String = ""
var fullscreen_resolution: Vector2i = BASE_RESOLUTION
var windowed_resolution: Vector2i = Vector2i(1728, 972)
var _last_window_mode: int = -1
var _is_desktop_display: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_game_settings()
	if name == "GameManager":
		_setup_fade_overlay()
		detect_device()

func _process(_delta: float) -> void:
	if name != "GameManager" or not _is_desktop_display:
		return
	var current_mode := DisplayServer.window_get_mode()
	if current_mode != _last_window_mode:
		_last_window_mode = current_mode
		_apply_display_resolution(current_mode)
	elif current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		var screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen)
		var max_size := Vector2i(
			int(floor(float(screen_size.x) * MAX_WINDOWED_RATIO)),
			int(floor(float(screen_size.y) * MAX_WINDOWED_RATIO))
		)
		var win_size := DisplayServer.window_get_size()
		if win_size.x > max_size.x or win_size.y > max_size.y:
			_apply_display_resolution(current_mode)

func _unhandled_input(event: InputEvent) -> void:
	if name != "GameManager" or not _is_desktop_display:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func detect_device() -> void:
	device_os = OS.get_name()
	print(device_os)

	if DisplayServer.get_name() == "headless":
		_is_desktop_display = false
		return

	if OS.has_feature("web") or device_os == "Web":
		_is_desktop_display = false
		return

	if OS.has_feature("mobile") or device_os in ["Android", "iOS"]:
		_is_desktop_display = false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	_is_desktop_display = true
	_update_screen_resolutions()
	_last_window_mode = DisplayServer.window_get_mode()
	_apply_display_resolution(_last_window_mode)

func _update_screen_resolutions() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	if screen_size.x <= 0 or screen_size.y <= 0:
		return

	fullscreen_resolution = screen_size

	var max_width := int(floor(float(screen_size.x) * MAX_WINDOWED_RATIO))
	var max_height := int(floor(float(screen_size.y) * MAX_WINDOWED_RATIO))
	var aspect := float(BASE_RESOLUTION.x) / float(BASE_RESOLUTION.y)

	var win_width := max_width
	var win_height := int(floor(float(win_width) / aspect))
	if win_height > max_height:
		win_height = max_height
		win_width = int(floor(float(win_height) * aspect))

	win_width = min(win_width, max_width)
	win_height = min(win_height, max_height)
	windowed_resolution = Vector2i(max(win_width, 640), max(win_height, 360))

func _apply_display_resolution(mode: int) -> void:
	if not _is_desktop_display:
		return
	_update_screen_resolutions()
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var screen_pos := DisplayServer.screen_get_position(screen)

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_size(fullscreen_resolution)
	elif mode == DisplayServer.WINDOW_MODE_WINDOWED:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(windowed_resolution)
		var usable_rect := DisplayServer.screen_get_usable_rect(screen)
		var centered_pos: Vector2i
		if usable_rect.size.x > 0 and usable_rect.size.y > 0:
			centered_pos = usable_rect.position + (usable_rect.size - windowed_resolution) / 2
			centered_pos.y = max(centered_pos.y, usable_rect.position.y + 24)
		else:
			centered_pos = screen_pos + (screen_size - windowed_resolution) / 2
		DisplayServer.window_set_position(centered_pos)

func toggle_fullscreen() -> void:
	if not _is_desktop_display:
		return
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_last_window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		_apply_display_resolution(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_last_window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		_apply_display_resolution(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _setup_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "TransitionLayer"
	_fade_layer.layer = 100
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "BlackOverlay"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)

func set_black_instant() -> void:
	if not _fade_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	is_black_screen_active = true
	_fade_rect.visible = true
	_fade_rect.modulate.a = 1.0

func fade_to_black(duration: float = 0.25) -> void:
	if not _fade_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	is_black_screen_active = true
	_fade_rect.visible = true
	if duration <= 0.0:
		_fade_rect.modulate.a = 1.0
		return
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_tween.finished

func fade_from_black(duration: float = 0.3, hold_time: float = 0.35) -> void:
	if not _fade_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.visible = true
	_fade_rect.modulate.a = 1.0
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time, true, false, true).timeout
	if duration > 0.0:
		_fade_tween = create_tween()
		_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade_tween.tween_property(_fade_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await _fade_tween.finished
	else:
		_fade_rect.modulate.a = 0.0
	_fade_rect.visible = false
	is_black_screen_active = false

func reset_run() -> void:
	current_level = 1
	current_stage = 1
	current_sublevel = 0
	enemies_killed = 0
	total_enemies = 0
	score = 0
	exp = 0.0
	level_changed.emit(current_level)
	stats_changed.emit()

func set_wave_enemies(total: int) -> void:
	enemies_killed = 0
	total_enemies = max(total, 0)
	stats_changed.emit()

func register_enemy_kill(points: int = 10) -> void:
	enemies_killed += 1
	score += points
	stats_changed.emit()

func advance_level() -> int:
	current_level += 1
	current_sublevel += 1
	if current_sublevel >= max_arena_level:
		current_stage += 1
		current_sublevel = 0

	player_heal.emit(50.0)
	player_energize.emit(100.0)
	level_changed.emit(current_level)
	stats_changed.emit()
	return current_level

func advance_stage() -> void:
	current_stage += 1
	current_sublevel = 0
	level_changed.emit(current_level)
	stats_changed.emit()

func get_level_code() -> String:
	return "%d.%d" % [current_stage, current_sublevel]

func notify_level_started() -> void:
	level_changed.emit(current_level)
	stats_changed.emit()
	if game_mode == "endless":
		level_started.emit("Endless")
	elif game_mode == "tutorial":
		level_started.emit("Tutorial")
	else:
		level_started.emit("Level " + get_level_code())

func add_exp(amount: float) -> void:
	exp += amount

func take_damage(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(amount)

func get_player_damage(base_damage: float = 20.0) -> float:
	return base_damage

func get_enemy_scaling_hp(base_hp: float = 20.0) -> float:
	return base_hp * (1.0 + float(max(current_level - 1, 0)) * 0.1)

func restart_game() -> void:
	get_tree().paused = false
	reset_run()
	await fade_to_black(0.2)

	AudioManager.play_music("gameplay")
	AudioManager.fade_in(0.5)

	get_tree().reload_current_scene()

func set_virtual_gamepad_enabled(enabled: bool) -> void:
	virtual_gamepad_enabled = enabled
	_save_game_settings()
	virtual_gamepad_changed.emit(virtual_gamepad_enabled)

func _load_game_settings() -> void:
	var config := ConfigFile.new()
	if config.load(GAME_SETTINGS_PATH) != OK:
		return
	virtual_gamepad_enabled = bool(config.get_value("controls", "virtual_gamepad_enabled", virtual_gamepad_enabled))

func _save_game_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "virtual_gamepad_enabled", virtual_gamepad_enabled)
	var error := config.save(GAME_SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save game settings: %s" % error_string(error))
