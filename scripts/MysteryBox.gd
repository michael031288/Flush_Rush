extends Area2D

const KINDS := ["speed", "invincible", "invisible"]

var _opened := false


func _ready() -> void:
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		open()


func _on_area(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().is_in_group("player"):
		open()


func open() -> void:
	if _opened:
		return
	_opened = true
	AudioManager.play("box")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 0.7), 0.08)
	tw.tween_property(self, "scale", Vector2(0.2, 1.4), 0.1)
	tw.tween_callback(_spawn)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


func _spawn() -> void:
	var pickup := preload("res://scenes/objects/Pickup.tscn").instantiate()
	pickup.kind = KINDS[randi() % KINDS.size()]
	pickup.global_position = global_position + Vector2(0, -12)
	get_parent().add_child(pickup)
