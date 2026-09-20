extends Area2D

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $WaterVisual


func setup(world_rect: Rect2) -> void:
	position = world_rect.position + world_rect.size * 0.5
	var rect := RectangleShape2D.new()
	rect.size = world_rect.size
	_shape.shape = rect
	_visual.size = world_rect.size
	_visual.position = -world_rect.size * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	_visual.material = mat


func surface_y() -> float:
	var rect := _shape.shape as RectangleShape2D
	if rect == null:
		return global_position.y
	return global_position.y - rect.size.y * 0.5
