extends CharacterBody2D

@export var speed: float = 90.0
@export var travel: float = 96.0

var _dir := 1.0
var _origin_x := 0.0
var _alive := true
var _flap := 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hazards")
	_origin_x = global_position.x
	$Hit.body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_flap += delta
	velocity = Vector2(_dir * speed, sin(_flap * 6.0) * 18.0)
	move_and_slide()
	if abs(global_position.x - _origin_x) > travel or is_on_wall():
		_dir *= -1.0
		global_position.x = clamp(global_position.x, _origin_x - travel, _origin_x + travel)
	$Sprite.flip_h = _dir < 0.0
	$Sprite.rotation = sin(_flap * 12.0) * 0.15


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
