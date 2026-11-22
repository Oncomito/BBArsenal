extends Control

const READY_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const UNAVAILABLE_MODULATE := Color(0.55, 0.58, 0.65, 0.62)
const SHIELD_ACTIVE_MODULATE := Color(1.15, 1.25, 1.25, 1.0)

var player: Player = null
var _button_tweens: Dictionary = {}

@onready var dash_button: Button = $Dash
@onready var shield_button: Button = $Shield
@onready var parry_button: Button = $Parry

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager and not GameManager.virtual_gamepad_changed.is_connected(_on_virtual_gamepad_changed):
		GameManager.virtual_gamepad_changed.connect(_on_virtual_gamepad_changed)
	_update_visibility()
	_bind_player()
	for btn in [dash_button, shield_button, parry_button]:
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size * 0.5

func _on_virtual_gamepad_changed(_enabled: bool) -> void:
	_update_visibility()

func _update_visibility() -> void:
	var enabled := GameManager.virtual_gamepad_enabled if GameManager else true
	visible = enabled and not get_tree().paused

func _process(_delta: float) -> void:
	_update_visibility()
	if not visible:
		return

	var current_player := _bind_player()
	if not is_instance_valid(current_player):
		return

	if is_instance_valid(dash_button):
		dash_button.modulate = READY_MODULATE if current_player.movement.can_dash() else UNAVAILABLE_MODULATE

	if is_instance_valid(parry_button):
		parry_button.modulate = READY_MODULATE if current_player.combat.can_parry() else UNAVAILABLE_MODULATE

	if is_instance_valid(shield_button):
		if current_player.combat.is_shield_active:
			shield_button.modulate = SHIELD_ACTIVE_MODULATE
		elif current_player.energy > 0.0 and not current_player.is_exhausted and not current_player.movement.is_dashing and not current_player.is_dead:
			shield_button.modulate = READY_MODULATE
		else:
			shield_button.modulate = UNAVAILABLE_MODULATE

func _bind_player() -> Player:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	return player

func _play_button_bounce(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var existing_tween: Tween = _button_tweens.get(btn)
	if existing_tween and existing_tween.is_valid():
		existing_tween.kill()
	btn.scale = Vector2(0.88, 0.88)
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[btn] = tween

func _on_dash_pressed() -> void:
	_play_button_bounce(dash_button)
	var current_player := _bind_player()
	if is_instance_valid(current_player):
		current_player.movement.perform_dash()

func _on_shield_pressed() -> void:
	_play_button_bounce(shield_button)
	var current_player := _bind_player()
	if is_instance_valid(current_player):
		current_player.combat.toggle_shield()

func _on_parry_pressed() -> void:
	_play_button_bounce(parry_button)
	var current_player := _bind_player()
	if is_instance_valid(current_player):
		current_player.combat.perform_parry()
