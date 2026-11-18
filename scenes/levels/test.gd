extends Node2D


# Called when the node enters the scene tree for the first time.
# With "Emulate Mouse from Touch" enabled, this will trigger on touch
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Touch or Click detected at:", event.position)   
