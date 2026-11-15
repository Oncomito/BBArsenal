extends CharacterBody2D

const HIT_EFFECT_SCENE := preload("res://scenes/projectiles/hit.tscn")

@export var speed: float = 180.0
@export var max_health: float = 100.0
@export var damage: float = 15.0
@export var shoot_cooldown: float = 2.5
@export var shoot_range: float = 600.0
@export var stomp_cooldown: float = 3.5
@export var stomp_range: float = 160.0
@export var stomp_damage: float = 25.0
@export var stomp_radius: float = 180.0

var health: float
var player: Node2D = null
var shoot_timer: float = 1.0
var stomp_timer: float = 2.0
var is_stomping: bool = false
var is_stunned: bool = false

var hp_bar: ProgressBar

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_setup_hp_bar()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if is_stunned or is_stomping:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		var dir := global_position.direction_to(player.global_position)
		velocity = dir * speed
		if velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0

		# Stomp logic
		stomp_timer -= delta
		if stomp_timer <= 0.0 and dist <= stomp_range:
			_start_stomp()
			return

		# Shooting logic
		shoot_timer -= delta
		if shoot_timer <= 0.0 and dist <= shoot_range:
			_shoot_at_player()
			shoot_timer = shoot_cooldown
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _start_stomp() -> void:
	is_stomping = true
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
	AudioManager.play_sfx("fireball", 0.8, -2.0)

	get_tree().create_timer(0.45).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_execute_stomp()
	)

func _execute_stomp() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	is_stomping = false
	stomp_timer = stomp_cooldown

	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = global_position
		hit.scale = Vector2(3.5, 3.5)
		hit.animation_name = "fire"
		get_tree().current_scene.call_deferred("add_child", hit)

	AudioManager.play_sfx("blast", 1.1, 2.0)

	if is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= stomp_radius:
			if bool(player.get("is_attacking")):
				AudioManager.play_sfx("ting", 1.8, 4.0)
				take_damage(40.0)
				is_stunned = true
				if player.has_method("camera_shake"):
					player.camera_shake(16.0, 0.25)
				get_tree().create_timer(1.2).timeout.connect(func():
					if is_instance_valid(self):
						is_stunned = false
				)
			elif bool(player.get("is_invulnerable")):
				# Dodged via dash i-frame
				pass
			else:
				if player.has_method("take_damage"):
					player.take_damage(stomp_damage)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_stunned:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox") or area.name == "Hitbox":
		var attacker := area.get_parent()
		if is_instance_valid(attacker) and attacker.is_in_group("player"):
			var dmg: float = float(attacker.get("dash_damage")) if "dash_damage" in attacker else 25.0
			take_damage(dmg)

func _shoot_at_player() -> void:
	if not is_instance_valid(player):
		return
	ProjectileManager.spawn_projectile("fireball", {
		"spawn_point": global_position,
		"target": player,
		"damage": 10.0,
		"scale": Vector2(4, 4)
	})

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if hp_bar:
		hp_bar.value = health

	if animated_sprite:
		var orig_color: Color = animated_sprite.modulate
		animated_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		get_tree().create_timer(0.12).timeout.connect(func():
			if is_instance_valid(animated_sprite):
				animated_sprite.modulate = orig_color
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
	AudioManager.play_sfx("blast")
	if HIT_EFFECT_SCENE and get_tree().current_scene:
		var hit := HIT_EFFECT_SCENE.instantiate()
		hit.global_position = global_position
		hit.scale = Vector2(3.0, 3.0)
		hit.animation_name = "fire"
		get_tree().current_scene.call_deferred("add_child", hit)
	queue_free()
