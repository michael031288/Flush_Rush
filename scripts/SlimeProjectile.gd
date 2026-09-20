extends Area2D

var velocity := Vector2.ZERO


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	velocity.y += 420.0 * delta
	position += velocity * delta
	rotation += delta * 4.0
	if position.y > 2000.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body.has_method("hit_by_hazard"):
		body.hit_by_hazard(self)
		queue_free()
