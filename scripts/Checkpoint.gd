extends Area2D

var _lit := false


func _ready() -> void:
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		activate()


func _on_area(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().is_in_group("player"):
		activate()


func activate() -> void:
	GameManager.set_checkpoint(global_position + Vector2(0, -8))
	if _lit:
		return
	_lit = true
	AudioManager.play("collect")
	var glow: Sprite2D = $Glow
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.9, 0.6)
	tw.tween_property(glow, "modulate:a", 0.35, 0.6)
	$Label.visible = true
