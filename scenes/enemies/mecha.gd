extends CharacterBody2D

@export var speed: float = 180.0
@export var max_health: float = 100.0
@export var damage: float = 15.0

var health: float
var player: Node2D = null

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

func _physics_process(_delta: float) -> void:
	if is_instance_valid(player):
		var dir := global_position.direction_to(player.global_position)
		velocity = dir * speed
		if velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif Gamemanager and Gamemanager.has_method("take_damage"):
			Gamemanager.take_damage(damage)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox") or area.name == "PlayerHitbox":
		var dmg: float = area.get("damage") if "damage" in area else 20.0
		take_damage(dmg)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	queue_free()
