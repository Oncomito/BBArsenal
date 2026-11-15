extends Node

const PROJECTILE_SCENES: Dictionary = {
	"bolt": preload("res://scenes/projectiles/bolt.tscn"),
	"disc": preload("res://scenes/projectiles/disc.tscn"),
	"fireball": preload("res://scenes/projectiles/fireball.tscn"),
	"glob": preload("res://scenes/projectiles/glob.tscn"),
	"helix": preload("res://scenes/projectiles/helix.tscn"),
	"orb": preload("res://scenes/projectiles/orb.tscn"),
	"rocket": preload("res://scenes/projectiles/rocket.tscn"),
	"shard": preload("res://scenes/projectiles/shard.tscn"),
	"spinner": preload("res://scenes/projectiles/spinner.tscn"),
	"tracer": preload("res://scenes/projectiles/tracer.tscn"),
	"wave": preload("res://scenes/projectiles/wave.tscn"),
}

const LASER_SCENE := preload("res://scenes/projectiles/laser.tscn")

func spawn_projectile(kind: String, options: Dictionary = {}) -> Node2D:
	var scene := PROJECTILE_SCENES.get(kind) as PackedScene
	if scene == null:
		push_error("ProjectileManager: unknown projectile type '%s'." % kind)
		return null

	var projectile := scene.instantiate() as Node2D
	if projectile == null:
		push_error("ProjectileManager: projectile '%s' is not a Node2D." % kind)
		return null

	_configure_projectile(projectile, options)
	return _add_to_parent(projectile, options)

func spawn_laser(options: Dictionary = {}) -> Node2D:
	var laser := LASER_SCENE.instantiate() as Node2D
	if laser == null:
		push_error("ProjectileManager: laser scene is not a Node2D.")
		return null

	_configure_projectile(laser, options)
	return _add_to_parent(laser, options)

func _configure_projectile(projectile: Node2D, options: Dictionary) -> void:
	if options.has("spawn_point"):
		projectile.global_position = options["spawn_point"] as Vector2

	if options.has("direction"):
		var direction := options["direction"] as Vector2
		if not direction.is_zero_approx() and "direction" in projectile:
			projectile.set("direction", direction.normalized())
	elif options.has("target"):
		var target_position: Variant = _target_position(options["target"])
		if target_position != null and "direction" in projectile:
			var direction := projectile.global_position.direction_to(target_position)
			if not direction.is_zero_approx():
				projectile.set("direction", direction)

	if options.has("speed") and "speed" in projectile:
		projectile.set("speed", float(options["speed"]))
	if options.has("damage") and "damage" in projectile:
		projectile.set("damage", float(options["damage"]))
	if options.has("lifetime") and "lifetime" in projectile:
		projectile.set("lifetime", float(options["lifetime"]))
	if options.has("duration") and "duration" in projectile:
		projectile.set("duration", float(options["duration"]))
	if options.has("element") and "element" in projectile:
		projectile.set("element", str(options["element"]))
	if options.has("scale"):
		projectile.scale = options["scale"] as Vector2

func _target_position(target: Variant) -> Variant:
	if target is Vector2:
		return target
	if target is Node2D and is_instance_valid(target):
		return target.global_position
	return null

func _add_to_parent(projectile: Node2D, options: Dictionary) -> Node2D:
	var parent := options.get("parent", get_tree().current_scene) as Node
	if parent == null:
		push_error("ProjectileManager: no valid parent or current scene to spawn projectile.")
		projectile.queue_free()
		return null

	parent.call_deferred("add_child", projectile)
	return projectile
