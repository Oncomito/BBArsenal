extends Node

signal player_died

func take_damage(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(amount)

func get_player_damage(base_damage: float = 20.0) -> float:
	return base_damage

func get_enemy_scaling_hp(base_hp: float = 20.0) -> float:
	return base_hp
