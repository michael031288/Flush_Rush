extends Node

signal health_changed(current: int, maximum: int)
signal powerup_changed(kind: int, remaining: float)
signal checkpoint_changed(where: Vector2)
signal boss_defeated

const MAX_HEALTH := 3

enum Power { NONE, SPEED, INVINCIBLE, INVISIBLE }

var health: int = MAX_HEALTH
var checkpoint: Vector2 = Vector2(96, 192)
var power: int = Power.NONE
var power_time: float = 0.0
var score_carrots: int = 0
var gator_down: bool = false


func _process(delta: float) -> void:
	if power == Power.NONE:
		return
	power_time = max(0.0, power_time - delta)
	powerup_changed.emit(power, power_time)
	if power_time <= 0.0:
		clear_power()


func reset_run() -> void:
	health = MAX_HEALTH
	power = Power.NONE
	power_time = 0.0
	score_carrots = 0
	gator_down = false
	checkpoint = Vector2(96, 192)
	health_changed.emit(health, MAX_HEALTH)
	powerup_changed.emit(power, 0.0)


func set_checkpoint(where: Vector2) -> void:
	checkpoint = where
	checkpoint_changed.emit(where)


func heal(amount: int = 1) -> void:
	health = min(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)


func grant_power(kind: int) -> void:
	power = kind
	match kind:
		Power.SPEED:
			power_time = 8.0
		Power.INVINCIBLE, Power.INVISIBLE:
			power_time = 10.0
		_:
			power_time = 0.0
	powerup_changed.emit(power, power_time)


func clear_power() -> void:
	power = Power.NONE
	power_time = 0.0
	powerup_changed.emit(power, 0.0)


func has_power() -> bool:
	return power != Power.NONE


func power_label() -> String:
	match power:
		Power.SPEED:
			return "Speed Boost"
		Power.INVINCIBLE:
			return "Invincible!"
		Power.INVISIBLE:
			return "Invisible"
		_:
			return ""
