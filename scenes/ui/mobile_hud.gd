extends Control

var player: Player = null

func _ready() -> void:
	_bind_player()

func _bind_player() -> Player:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	return player

func _on_dash_pressed() -> void:
	var current_player := _bind_player()
	if is_instance_valid(current_player):
		current_player.perform_dash()
