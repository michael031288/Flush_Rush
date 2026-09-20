extends CharacterBody2D

@export var speed: float = 70.0
@export var travel: float = 80.0

var _dir := 1.0
var _origin_y := 0.0
var _alive := true


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hazards")
	_origin_y = global_position.y
	$Hit.body_entered.connect(_on_hit)


func _physics_process(_delta: float) -> void:
	if not _alive:
		return
	velocity = Vector2(0, _dir * speed)
	move_and_slide()
	if abs(global_position.y - _origin_y) > travel or is_on_ceiling() or is_on_floor():
		_dir *= -1.0
		global_position.y = clamp(global_position.y, _origin_y - travel, _origin_y + travel)
	$Sprite.flip_v = _dir > 0.0


func _on_hit(body: Node) -> void:
	if body.has_method("hit_by_hazard"):
		body.hit_by_hazard(self)


func defeated() -> void:
	if not _alive:
		return
	_alive = false
	AudioManager.play("hit_boss")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
