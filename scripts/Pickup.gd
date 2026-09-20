extends Area2D

@export var kind: String = "carrot"
@export var pop_on_spawn: bool = true

var _time := 0.0
var _velocity := Vector2.ZERO
var _popping := true
var _got := false


func _ready() -> void:
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)
	_velocity = Vector2(randf_range(-50.0, 50.0), randf_range(-140.0, -90.0))
	if not pop_on_spawn:
		_popping = false
		_velocity = Vector2.ZERO
	var sprite: Sprite2D = $Sprite
	match kind:
		"carrot":
			sprite.texture = preload("res://assets/sprites/carrot.png")
		"speed":
			sprite.texture = preload("res://assets/sprites/power_speed.png")
		"invincible":
			sprite.texture = preload("res://assets/sprites/power_star.png")
		"invisible":
			sprite.texture = preload("res://assets/sprites/power_ghost.png")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).from(Vector2(0.4, 0.4))


func _physics_process(delta: float) -> void:
	_time += delta
	if _popping:
		_velocity.y += 420.0 * delta
		position += _velocity * delta
		if _velocity.y > 0.0 and _time > 0.28:
			_popping = false
			_velocity = Vector2.ZERO
	else:
		$Sprite.position.y = sin(_time * 4.0) * 3.0


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()


func _on_area(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().is_in_group("player"):
		_collect()


func _collect() -> void:
	if _got:
		return
	_got = true
	match kind:
		"carrot":
			GameManager.heal(1)
			GameManager.score_carrots += 1
			AudioManager.play("collect")
		"speed":
			GameManager.grant_power(GameManager.Power.SPEED)
			AudioManager.play("collect")
		"invincible":
			GameManager.grant_power(GameManager.Power.INVINCIBLE)
			AudioManager.play("collect")
		"invisible":
			GameManager.grant_power(GameManager.Power.INVISIBLE)
			AudioManager.play("collect")
	queue_free()
