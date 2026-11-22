@tool
class_name PlayerResource
extends Resource2D


var actor: Player

func setup(player: Player) -> void:
	actor = player

func update_energy_regeneration(delta: float) -> void:
	if actor.combat.is_shield_active:
		return
	if actor.movement.energy_regen_wait_timer > 0.0:
		actor.movement.energy_regen_wait_timer = maxf(actor.movement.energy_regen_wait_timer - delta, 0.0)
		return
	if actor.energy < actor.movement.max_energy:
		actor.energy = minf(
			actor.energy + actor.movement.energy_regen_rate * delta,
			actor.movement.max_energy
		)
		if actor.is_exhausted and actor.energy > 0.0:
			actor.is_exhausted = false
		actor._emit_energy_changed()

func update_shield(delta: float) -> void:
	if not actor.combat.is_shield_active:
		return
	if actor.movement.is_dashing or actor.is_dead or actor.is_transitioning:
		actor.combat.deactivate_shield()
		return

	actor.energy = maxf(actor.energy - actor.combat.shield_drain_rate * delta, 0.0)
	actor._emit_energy_changed()
	if actor.energy <= 0.0:
		mark_exhausted()
		actor.combat.deactivate_shield()

func mark_exhausted() -> void:
	actor.is_exhausted = true
	actor.movement.energy_regen_wait_timer = actor.movement.energy_exhausted_regen_delay

func take_damage(amount: float) -> void:
	if actor.is_dead or amount <= 0.0 or actor.combat.is_invulnerable:
		return

	if actor.combat.is_shield_active:
		var energy_absorbed: float = amount * actor.combat.shield_damage_energy_multiplier
		actor.energy = maxf(actor.energy - energy_absorbed, 0.0)
		actor._emit_energy_changed()
		actor.visual.camera_shake(8.0, 0.15)
		if AudioManager:
			AudioManager.play_sfx("blast", 2.0, -4.0)
		if actor.energy <= 0.0:
			mark_exhausted()
			actor.combat.deactivate_shield()
		return

	
	if actor.combat.is_attacking:
		actor.combat.successful_parry(actor.global_position)
		return

	actor.apply_damage(amount)
	actor.health_changed.emit(actor.health, actor.max_health)
	actor.visual.camera_shake(actor.damage_shake_intensity, actor.damage_shake_duration)
	if actor.health <= 0.0:
		actor.die()

func heal(amount: float) -> void:
	if actor.is_dead or amount <= 0.0:
		return
	actor.apply_healing(amount)
	actor.health_changed.emit(actor.health, actor.max_health)

func energize(amount: float) -> void:
	if actor.is_dead:
		return

	var energy_change := -amount if actor.combat.is_shield_active and amount > 0.0 else amount
	actor.energy = clampf(actor.energy + energy_change, 0.0, actor.movement.max_energy)
	actor._emit_energy_changed()

	if actor.combat.is_shield_active and actor.energy <= 0.0:
		mark_exhausted()
		actor.combat.deactivate_shield()
