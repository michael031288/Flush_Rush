extends CharacterBody2D

enum State { INTRO, CHARGE, SPLASH, VULN, DEAD }

signal died

@export var arena_left: float = 0.0
@export var arena_right: float = 0.0
@export var swim_y: float = 0.0

var state: int = State.INTRO
var hits_left := 3
var _timer := 0.0
var _charge_dir := 1.0
var _invuln := 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	$Hit.body_entered.connect(_on_hit)
	_timer = 1.4


func _physics_process(delta: float) -> void:
	_invuln = max(0.0, _invuln - delta)
	_timer -= delta
	match state:
		State.INTRO:
			velocity = Vector2(0, sin(Time.get_ticks_msec() * 0.004) * 20.0)
			if _timer <= 0.0:
				_begin_charge()
		State.CHARGE:
			velocity = Vector2(_charge_dir * 220.0, 0)
			if global_position.x < arena_left:
				global_position.x = arena_left
				_charge_dir = 1.0
			elif global_position.x > arena_right:
				global_position.x = arena_right
				_charge_dir = -1.0
			if _timer <= 0.0:
				_begin_splash()
		State.SPLASH:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_begin_vuln()
		State.VULN:
			velocity = Vector2(0, sin(Time.get_ticks_msec() * 0.008) * 12.0)
			modulate = Color(1.4, 1.4, 1.4) if int(Time.get_ticks_msec() / 120) % 2 == 0 else Color.WHITE
			if _timer <= 0.0:
				modulate = Color.WHITE
				_begin_charge()
		State.DEAD:
			velocity = Vector2(0, 40)
	$Sprite.flip_h = _charge_dir < 0.0
	move_and_slide()
	if state != State.DEAD:
		global_position.y = lerp(global_position.y, swim_y, 0.08)


func _begin_charge() -> void:
	state = State.CHARGE
	_timer = 2.4
	modulate = Color.WHITE
	_charge_dir = -1.0 if _charge_dir > 0.0 else 1.0


func _begin_splash() -> void:
	state = State.SPLASH
	_timer = 1.3
	AudioManager.play("splash")
	var origin := global_position + Vector2(0, -10)
	for i in range(5):
		var blob = preload("res://scenes/objects/SlimeProjectile.tscn").instantiate()
		blob.global_position = origin
		blob.velocity = Vector2(lerpf(-180, 180, i / 4.0), randf_range(-280, -180))
		get_parent().add_child(blob)


func _begin_vuln() -> void:
	state = State.VULN
	_timer = 4.2
	_spawn_boxes()


func _spawn_boxes() -> void:
	for offset in [Vector2(-70, -90), Vector2(70, -90)]:
		var box = preload("res://scenes/objects/MysteryBox.tscn").instantiate()
		box.global_position = global_position + offset
		get_parent().add_child(box)


func _on_hit(body: Node) -> void:
	if body.has_method("hit_by_hazard"):
		body.hit_by_hazard(self)


func take_hit() -> void:
	if state == State.DEAD or _invuln > 0.0:
		return
	if state != State.VULN and GameManager.power != GameManager.Power.INVINCIBLE:
		return
	hits_left -= 1
	_invuln = 0.8
	AudioManager.play("hit_boss")
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2, 0.4, 0.4), 0.08)
	tw.tween_property(self, "modulate", Color.WHITE, 0.2)
	if hits_left <= 0:
		_die()
	else:
		_begin_charge()


func _die() -> void:
	state = State.DEAD
	GameManager.gator_down = true
	AudioManager.play("victory")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		died.emit()
		queue_free()
	)
