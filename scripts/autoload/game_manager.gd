extends Node

signal player_heal(amount: float)
signal player_energize(amoung: float)
signal level_changed(new_level: int)
signal level_started(level_code: String)
signal level_cleared(level: int)
signal stats_changed

var game_mode: String = "levels"
var current_level: int = 1
var current_stage: int = 1
var current_sublevel: int = 0
var max_arena_level: int = 10
var enemies_killed: int = 0
var total_enemies: int = 0
var score: int = 0
var exp: float = 0.0

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null
var is_black_screen_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if name == "GameManager":
		_setup_fade_overlay()

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