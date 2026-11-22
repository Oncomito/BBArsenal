extends Area2D

const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

@export var speed: float = 420.0
@export var damage: float = 5.0
@export var lifetime: float = 1.8
@export_enum("arcane", "crimson", "electric", "fire", "holy", "ice", "plasma", "rose", "shadow", "toxic") var element: String = "fire"

var direction: Vector2 = Vector2.RIGHT
var _exploded: bool = false
var is_parried: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("projectile")
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(element):
			animated_sprite.play(element)
		else:
			animated_sprite.play()
	rotation = direction.angle()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	rotation = direction.angle()
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
		return

	if not is_parried:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			var player_combat := player.get("combat") as Node
			var is_shield_active: bool = (
				is_instance_valid(player_combat)
				and bool(player_combat.get("is_shield_active"))
			)
			var shield_node := (
				player_combat.get("shield") as Node2D
				if is_instance_valid(player_combat)
				else null
			)
			var shield_pos := shield_node.global_position if shield_node else player.global_position
			if is_shield_active and (dist < 70.0 or global_position.distance_to(shield_pos) < 70.0):
				if shield_node and shield_node.has_method("bounce_projectile"):
					shield_node.call("bounce_projectile", self)
				else:
					parry(player)
				return

			var is_attacking: bool = (
				is_instance_valid(player_combat)
				and bool(player_combat.get("is_attacking"))
			)
			if is_attacking and dist < 110.0:
				var to_proj := global_position - player.global_position
				var facing_left: bool = false
				if player.has_node("AnimatedSprite2D"):
					facing_left = player.get_node("AnimatedSprite2D").flip_h
				var facing_dir := Vector2.LEFT if facing_left else Vector2.RIGHT

				if to_proj.normalized().dot(facing_dir) > -0.3 or dist < 65.0:
					parry(player)
					return

	else:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				if global_position.distance_to(enemy.global_position) < 45.0:
					_hit_enemy(enemy)
					return

func _on_body_entered(body: Node2D) -> void:
	if _exploded:
		return
	if not is_parried:
		if body.is_in_group("player"):
			return
		elif body is TileMapLayer or body is StaticBody2D:
			_explode()
	else:
		if body.is_in_group("player"):
			return
		if body.has_method("take_damage"):
			_hit_enemy(body)
		elif body is TileMapLayer or body is StaticBody2D:
			_explode()

func _on_area_entered(area: Area2D) -> void:
	if _exploded:
		return
	if not is_parried:
		if area.is_in_group("player_shield") and area.get("is_active"):
			if area.has_method("bounce_projectile"):
				area.call("bounce_projectile", self)
			else:
				parry(area.get("player_ref"))
			return
		if area.name == "Hurtbox" or area.is_in_group("player_hurtbox"):
			var player := _find_player_for_area(area)
			if is_instance_valid(player) and player.is_in_group("player"):
				if _is_player_attacking(player):
					parry(player)
				else:
					Gamemanager.take_damage(damage)
					_explode()
			return
		if area.name == "Hitbox" or area.is_in_group("player_hitbox"):
			var player := _find_player_for_area(area)
			if is_instance_valid(player) and _is_player_attacking(player):
				parry(player)
				return
	else:
		var target := area.get_parent()
		if is_instance_valid(target) and not target.is_in_group("player") and target.has_method("take_damage"):
			_hit_enemy(target)

func _find_player_for_area(area: Area2D) -> Node2D:
	var ancestor := area.get_parent()
	while is_instance_valid(ancestor):
		if ancestor.is_in_group("player"):
			return ancestor as Node2D
		ancestor = ancestor.get_parent()
	return null

func _is_player_attacking(player: Node) -> bool:
	if not is_instance_valid(player):
		return false
	var player_combat := player.get("combat") as Node
	return is_instance_valid(player_combat) and bool(player_combat.get("is_attacking"))

func _hit_enemy(target: Node) -> void:
	if _exploded:
		return
	var parry_damage: int = int(Gamemanager.get_player_damage(20) * 1.75)
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(parry_damage)
	_explode()

func parry(player: Node2D) -> void:
	if is_parried or _exploded:
		return
	is_parried = true

	var nearest_enemy: Node2D = null
	var min_dist: float = 999999.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			var d := global_position.distance_to(enemy.global_position)
			if d < min_dist:
				min_dist = d
				nearest_enemy = enemy

	if nearest_enemy:
		direction = global_position.direction_to(nearest_enemy.global_position)
	else:
		direction = - direction

	speed *= 1.6
	lifetime = 2.5
	rotation = direction.angle()

	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var spark := HIT_EFFECT_SCENE.instantiate()
		spark.global_position = global_position
		spark.scale = scale * 2.0
		spark.animation_name = "holy" if element != "holy" else "arcane"
		get_tree().current_scene.call_deferred("add_child", spark)

	if AudioManager:
		AudioManager.play_sfx("blast", 2.2)

	if is_instance_valid(player):
		var player_visual := player.get("visual") as Node
		if is_instance_valid(player_visual) and player_visual.has_method("camera_shake"):
			player_visual.call("camera_shake", 7.0, 0.15)

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)
	hide()

	AudioManager.play_sfx("blast")
	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = global_position
		hit.scale = scale * 2.0
		hit.animation_name = element
		get_tree().current_scene.call_deferred("add_child", hit)
	queue_free()
