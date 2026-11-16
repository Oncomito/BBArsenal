extends CharacterBody2D

const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

@export var speed: float = 180.0
@export var max_health: float = 180.0
@export var damage: float = 15.0
@export var shoot_cooldown: float = 2.5
@export var shoot_range: float = 1200.0
@export var stomp_range: float = 200
@export var stomp_damage: float = 25.0
@export var burst_count: int = 3
@export var time_between_shots: float = 1 / float(burst_count)

var health: float
var player: CharacterBody2D = null
var shoot_timer: Timer = Timer.new()
var consecutive_shoot_timer: Timer = Timer.new()
var shots_remaining: int = 0
var is_preparing_stomp: bool = false
var is_stomping: bool = false
var is_stunned: bool = false
var warning_pulse: float = 0.0

var hp_bar: ProgressBar

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	player = get_tree().get_first_node_in_group("player")

	add_child(shoot_timer)
	add_child(consecutive_shoot_timer)

	shoot_timer.wait_time = shoot_cooldown
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_start_shoot_burst)

	consecutive_shoot_timer.wait_time = time_between_shots
	consecutive_shoot_timer.one_shot = true
	consecutive_shoot_timer.timeout.connect(_shoot_next_in_burst)

	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		if not hitbox.body_exited.is_connected(_on_hitbox_body_exited):
			hitbox.body_exited.connect(_on_hitbox_body_exited)

	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	_setup_hp_bar()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if is_stomping:
		warning_pulse += delta * 12.0
		queue_redraw()

	if is_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_stomping:
		if is_instance_valid(player):
			var dir := global_position.direction_to(player.global_position)
			velocity = dir * (speed * 0.3)
			animated_sprite.flip_h = velocity.x < 0
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		var dir := global_position.direction_to(player.global_position)
		velocity = dir * speed
		animated_sprite.flip_h = velocity.x < 0

		
		if dist <= shoot_range and shoot_timer.is_stopped() and consecutive_shoot_timer.is_stopped() and shots_remaining == 0:
			_start_shoot_burst()

		
		if dist <= stomp_range and not is_preparing_stomp and not is_stomping:
			_start_stomp_preparation()
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _draw() -> void:
	if is_stomping:
		var radius := stomp_range
		var indicator_pos := Vector2.ZERO

		
		var alpha := 0.2 + 0.15 * sin(warning_pulse)
		draw_circle(indicator_pos, radius, Color(1.0, 0.2, 0.1, alpha))
		draw_arc(indicator_pos, radius, 0, TAU, 48, Color(1.0, 0.1, 0.1, 0.85), 3.5, true)


func _start_shoot_burst() -> void:
	shots_remaining = burst_count
	_shoot_next_in_burst()


func _shoot_next_in_burst() -> void:
	if not is_instance_valid(player):
		shots_remaining = 0
		return

	_shoot_at_player()
	shots_remaining -= 1

	if shots_remaining > 0:
		consecutive_shoot_timer.start()
	else:
		shoot_timer.start()


func _start_stomp_preparation() -> void:
	if is_preparing_stomp or is_stomping:
		return
	is_preparing_stomp = true

	
	get_tree().create_timer(0.5).timeout.connect(
		func():
			if not is_instance_valid(self):
				return
			if not is_preparing_stomp:
				return
			
			
			var dist := global_position.distance_to(player.global_position) if is_instance_valid(player) else 9999.0
			if not player or dist > stomp_range or not hitbox.overlaps_body(player):
				is_preparing_stomp = false
				return

			_start_stomp_charge(),
	)


func _start_stomp_charge() -> void:
	is_preparing_stomp = false
	is_stomping = true
	warning_pulse = 0.0
	if animated_sprite:
		animated_sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
	AudioManager.play_sfx("fireball", 0.8, -2.0)

	var charge_duration := randf_range(2.0, 4.0)
	get_tree().create_timer(charge_duration).timeout.connect(
		func():
			if not is_instance_valid(self):
				return
			if not is_stomping:
				return
			
			_execute_stomp(),
	)


func _execute_stomp() -> void:
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	is_stomping = false
	queue_redraw()

	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = global_position
		hit.scale = Vector2(3.5, 3.5)
		hit.animation_name = "fire"
		get_tree().current_scene.call_deferred("add_child", hit)

	AudioManager.play_sfx("blast", 1.1, 2.0)

	if hitbox:
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				if bool(body.get("is_attacking")):
					AudioManager.play_sfx("ting", 1.8, 4.0)
					is_stunned = true
					if body.has_method("camera_shake"):
						body.camera_shake(16.0, 0.25)
					get_tree().create_timer(1.2).timeout.connect(
						func():
							if is_instance_valid(self):
								is_stunned = false,
					)
				elif bool(body.get("is_invulnerable")):
					pass
				else:
					if body.has_method("take_damage"):
						body.take_damage(stomp_damage)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_stunned:
		return
	if body.is_in_group("player") and not is_preparing_stomp and not is_stomping:
		_start_stomp_preparation()


func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and is_preparing_stomp:
		is_preparing_stomp = false


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox") or area.name == "Hitbox":
		var attacker := area.get_parent()
		if is_instance_valid(attacker) and attacker.is_in_group("player"):
			var dmg: float = float(attacker.get("dash_damage")) if "dash_damage" in attacker else 25.0
			take_damage(dmg)

func _shoot_at_player() -> void:
	if not is_instance_valid(player):
		return
	ProjectileManager.spawn_projectile(
		"fireball",
		{
			"spawn_point": global_position + Vector2(0.0, -192),
			"target": player,
			"damage": 10.0,
			"scale": Vector2(4, 4),
			"speed": 1000.0,
			"lifetime": 2.5
		},
	)

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if hp_bar:
		hp_bar.value = health

	if animated_sprite:
		var orig_color: Color = animated_sprite.modulate
		animated_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		get_tree().create_timer(0.12).timeout.connect(
			func():
				if is_instance_valid(animated_sprite):
					animated_sprite.modulate = orig_color,
		)

	if health <= 0.0:
		_die()


func _setup_hp_bar() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(50, 6)
	hp_bar.size = Vector2(50, 6)
	hp_bar.position = Vector2(-25, -42)
	hp_bar.max_value = max_health
	hp_bar.value = health

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	sb_bg.corner_radius_top_left = 2
	sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_left = 2
	sb_bg.corner_radius_bottom_right = 2

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.85, 0.2, 0.2, 0.95)
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_left = 2
	sb_fill.corner_radius_bottom_right = 2

	hp_bar.add_theme_stylebox_override("background", sb_bg)
	hp_bar.add_theme_stylebox_override("fill", sb_fill)
	add_child(hp_bar)
	hp_bar.visible = true


func _die() -> void:
	if GameManager and GameManager.has_method("register_enemy_kill"):
		GameManager.register_enemy_kill(10)
	AudioManager.play_sfx("explode", 2.0)
	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = global_position
		hit.scale = Vector2(10.0, 10.0)
		hit.animation_name = "fire"
		get_tree().current_scene.call_deferred("add_child", hit)
	queue_free()
