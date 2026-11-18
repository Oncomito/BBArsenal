extends Control

@onready var player = get_tree().get_nodes_in_group("player")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Inside your Button's pressed signal handler or script
func _on_dash_pressed():
	player[0]._perform_dashshssh()
