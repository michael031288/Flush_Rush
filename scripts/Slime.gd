extends Area2D

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("enemies")
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	$Sprite.position.y = sin(Time.get_ticks_msec() * 0.006 + global_position.x) * 2.0


func _on_body(body: Node) -> void:
	if body.has_method("hit_by_hazard"):
		body.hit_by_hazard(self)


func defeated() -> void:
	AudioManager.play("hit_boss")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
