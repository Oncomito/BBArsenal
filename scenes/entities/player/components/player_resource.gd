@tool
class_name PlayerResource
extends Resource2D

var actor: Player

func setup(_owner: Player) -> void:
	actor = _owner

func update_energy_regeneration(delta: float) -> void:
	if actor.is_shield_active:
		return
	if actor.energy_regen_wait_timer > 0.0:
		actor.energy_regen_wait_timer = maxf(actor.energy_regen_wait_timer - delta, 0.0)
		return
	if actor.energy < actor.max_energy:
		actor.energy = minf(
			actor.energy + actor.energy_regen_rate * delta,
			actor.max_energy
		)
		if actor.is_exhausted and actor.energy > 0.0:
			actor.is_exhausted = false
		actor._emit_energy_changed()

func update_shield(delta: float) -> void:
	if not actor.is_shield_active:
		return
	if actor.is_dashing or actor.is_dead or actor.is_transitioning:
		deactivate_shield()
		return

	actor.energy = maxf(actor.energy - actor.shield_drain_rate * delta, 0.0)
	actor._emit_energy_changed()
	if actor.energy <= 0.0:
		mark_exhausted()
		deactivate_shield()

func toggle_shield() -> void:
	if (
		actor.is_dead
		or actor.is_transitioning
		or actor.get_tree().paused
		or actor.is_dashing
	):
		return

	if actor.is_shield_active:
		deactivate_shield()
	elif actor.energy > 0.0 and not actor.is_exhausted:
		activate_shield()

func activate_shield() -> void:
	actor.is_shield_active = true
	if is_instance_valid(actor.combat.shield):
		actor.combat.shield.activate()

func deactivate_shield() -> void:
	actor.is_shield_active = false
	if is_instance_valid(actor.combat.shield):
		actor.combat.shield.deactivate()

func mark_exhausted() -> void:
	actor.is_exhausted = true
	actor.energy_regen_wait_timer = actor.energy_exhausted_regen_delay

func take_damage(amount: float) -> void:
	if actor.is_dead or amount <= 0.0 or actor.is_invulnerable:
		return

	if actor.is_shield_active:
		var energy_absorbed: float = amount * actor.shield_damage_energy_multiplier
		actor.energy = maxf(actor.energy - energy_absorbed, 0.0)
		actor._emit_energy_changed()
		actor.camera_shake(8.0, 0.15)
		if AudioManager:
			AudioManager.play_sfx("blast", 2.0, -4.0)
		if actor.energy <= 0.0:
			mark_exhausted()
			deactivate_shield()
		return

	
	if actor.is_attacking:
		actor.combat.successful_parry(actor.global_position)
		return

	actor.health = clampf(actor.health - amount, 0.0, actor.max_health)
	actor.health_changed.emit(actor.health, actor.max_health)
	actor.camera_shake(actor.damage_shake_intensity, actor.damage_shake_duration)
	if actor.health <= 0.0:
		actor.die()

func heal(amount: float) -> void:
	if actor.is_dead or amount <= 0.0:
		return
	actor.health = clampf(actor.health + amount, 0.0, actor.max_health)
	actor.health_changed.emit(actor.health, actor.max_health)

func energize(amount: float) -> void:
	if actor.is_dead:
		return

	
	var energy_change := -amount if actor.is_shield_active and amount > 0.0 else amount
	actor.energy = clampf(actor.energy + energy_change, 0.0, actor.max_energy)
	actor._emit_energy_changed()

	if actor.is_shield_active and actor.energy <= 0.0:
		mark_exhausted()
		deactivate_shield()