class_name StaminaBar
extends Control

@export var player: CharacterBody2D

@export_group("Layout")
@export var segment_width: float = 70.0
@export var segment_height: float = 16.0
@export var segment_spacing: float = 8.0
@export var border_thickness: float = 2.0

@export_group("Colors")
@export var bg_color: Color = Color(0.04, 0.06, 0.1, 0.85)
@export var border_empty_color: Color = Color(0.18, 0.25, 0.35, 0.7)
@export var border_charging_color: Color = Color(0.0, 0.6, 0.85, 0.9)
@export var border_full_color: Color = Color(0.0, 0.95, 1.0, 1.0)

@export var fill_charging_color: Color = Color(0.0, 0.65, 0.88, 0.9)
@export var fill_full_color: Color = Color(0.0, 0.88, 1.0, 1.0)
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.45)

var current_stamina: float = 3.0
var max_stamina: float = 3.0

func _ready() -> void:
	custom_minimum_size = Vector2(
		3.0 * segment_width + 2.0 * segment_spacing,
		segment_height
	)
	_find_player()

func _find_player() -> void:
	if is_instance_valid(player):
		return
	var p: Node = get_parent()
	while p != null and not (p is CharacterBody2D):
		p = p.get_parent()
	if p is CharacterBody2D:
		player = p
	elif owner is CharacterBody2D:
		player = owner
	else:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()

	if is_instance_valid(player) and "stamina" in player:
		current_stamina = player.stamina
		if "max_stamina" in player:
			max_stamina = player.max_stamina
	queue_redraw()

func _draw() -> void:
	var total_segments := int(max_stamina)
	if total_segments <= 0:
		total_segments = 3

	for i in range(total_segments):
		var seg_pos := Vector2(i * (segment_width + segment_spacing), 0.0)
		var seg_rect := Rect2(seg_pos, Vector2(segment_width, segment_height))

		var fill := clampf(current_stamina - float(i), 0.0, 1.0)
		var is_full := fill >= 1.0

		# 1. Background
		draw_rect(seg_rect, bg_color, true)

		# 2. Fill bar (progress within this segment)
		if fill > 0.0:
			var inner_width := (segment_width - border_thickness * 2.0) * fill
			var fill_rect := Rect2(
				seg_pos + Vector2(border_thickness, border_thickness),
				Vector2(inner_width, segment_height - border_thickness * 2.0)
			)
			var cur_fill_col := fill_full_color if is_full else fill_charging_color
			draw_rect(fill_rect, cur_fill_col, true)

			# Top gloss highlight
			if fill_rect.size.x > 2.0:
				var gloss_rect := Rect2(fill_rect.position, Vector2(fill_rect.size.x, 2.0))
				draw_rect(gloss_rect, highlight_color, true)

		# 3. Outer border outline
		var cur_border_col := border_full_color if is_full else (border_charging_color if fill > 0.0 else border_empty_color)
		draw_rect(seg_rect, cur_border_col, false, border_thickness)
