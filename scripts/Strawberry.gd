extends CharacterBody2D

const SPEED := 150.0
const SWIM_SPEED := 135.0
const JUMP_VELOCITY := -360.0
const SURFACE_JUMP := -420.0
const GRAVITY := 980.0
const WATER_GRAVITY := 90.0

@onready var sprite: Sprite2D = $Sprite
@onready var sensor: Area2D = $Sensor
@onready var camera: Camera2D = $Camera2D
@onready var trail: CPUParticles2D = $Trail
@onready var bubbles: CPUParticles2D = $Bubbles

var tex_idle: Texture2D
var tex_swim: Texture2D
var tex_jump: Texture2D
var rainbow_mat: ShaderMaterial

var in_water := false
var near_surface := false
var current_water: Area2D
var invuln := 0.0
var coyote := 0.0
var jump_buf := 0.0
var dying := false
var facing := 1.0
var _was_in_water := false


func _ready() -> void:
	add_to_group("player")
	tex_idle = preload("res://assets/sprites/strawberry.png")
	tex_swim = preload("res://assets/sprites/strawberry_swim.png")
	tex_jump = preload("res://assets/sprites/strawberry_jump.png")
	rainbow_mat = ShaderMaterial.new()
	rainbow_mat.shader = preload("res://shaders/rainbow.gdshader")
	sensor.area_entered.connect(_on_area_entered)
	sensor.area_exited.connect(_on_area_exited)
	sensor.body_entered.connect(_on_sensor_body)
	GameManager.set_checkpoint(global_position)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	_setup_particles()


func _setup_particles() -> void:
	trail.amount = 20
	trail.lifetime = 0.4
	trail.emitting = false
	trail.direction = Vector2(-1, 0)
	trail.spread = 28.0
	trail.gravity = Vector2(0, 30)
	trail.initial_velocity_min = 18.0
	trail.initial_velocity_max = 48.0
	trail.scale_amount_min = 1.6
	trail.scale_amount_max = 3.2
	trail.color = Color(1.0, 0.72, 0.88, 0.75)
	bubbles.amount = 10
	bubbles.lifetime = 0.85
	bubbles.emitting = false
	bubbles.direction = Vector2(0, -1)
	bubbles.spread = 40.0
	bubbles.gravity = Vector2(0, -40)
	bubbles.initial_velocity_min = 12.0
	bubbles.initial_velocity_max = 28.0
	bubbles.color = Color(0.65, 0.92, 1.0, 0.5)


func _physics_process(delta: float) -> void:
	if dying:
		return

	_refresh_water_state()
	invuln = max(0.0, invuln - delta)
	_update_sensor_mask()

	var boost := 1.8 if GameManager.power == GameManager.Power.SPEED else 1.0
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("jump"):
		jump_buf = 0.14
	else:
		jump_buf -= delta

	if is_on_floor():
		coyote = 0.16
	else:
		coyote -= delta

	if in_water:
		_swim(delta, move, boost)
	else:
		_land(delta, move, boost)

	if move.x != 0.0:
		facing = sign(move.x)

	move_and_slide()
	_update_visuals(delta)

	if _was_in_water != in_water:
		AudioManager.play("splash")
	_was_in_water = in_water


func _swim(delta: float, move: Vector2, boost: float) -> void:
	var target := move * SWIM_SPEED * boost
	if move == Vector2.ZERO:
		target.y = -22.0
	velocity = velocity.lerp(target, 1.0 - exp(-8.0 * delta))
	velocity.y += WATER_GRAVITY * delta * 0.25
	velocity *= 0.992
	if jump_buf > 0.0 and near_surface:
		velocity.y = SURFACE_JUMP * (0.7 + 0.3 * boost)
		jump_buf = 0.0
		in_water = false
		AudioManager.play("jump")


func _land(delta: float, move: Vector2, boost: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var x_speed := SPEED * boost
	velocity.x = move.x * x_speed
	if jump_buf > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY * (0.72 + 0.28 * boost)
		jump_buf = 0.0
		coyote = 0.0
		AudioManager.play("jump")


func _refresh_water_state() -> void:
	in_water = false
	near_surface = false
	current_water = null
	for area in sensor.get_overlapping_areas():
		if area.is_in_group("water") and area.has_method("surface_y"):
			in_water = true
			current_water = area
			var top: float = area.surface_y()
			near_surface = global_position.y <= top + 20.0
			if global_position.y < top - 4.0:
				in_water = false
			break


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hazards") or area.is_in_group("enemies"):
		hit_by_hazard(area)
	elif area.is_in_group("exit"):
		_win()


func _on_area_exited(_area: Area2D) -> void:
	pass


func _on_sensor_body(body: Node) -> void:
	if body.is_in_group("hazards") or body.is_in_group("enemies"):
		hit_by_hazard(body)


func hit_by_hazard(source: Node) -> void:
	if dying:
		return
	if GameManager.power == GameManager.Power.INVISIBLE:
		return
	if GameManager.power == GameManager.Power.INVINCIBLE:
		_defeat_source(source)
		return
	if GameManager.power == GameManager.Power.SPEED and source.is_in_group("boss"):
		if source.has_method("take_hit"):
			source.take_hit()
		return
	if source.is_in_group("boss") and source.has_method("take_hit"):
		if source.state == 3:
			source.take_hit()
			return
	if invuln > 0.0:
		return
	if GameManager.has_power():
		GameManager.clear_power()
		invuln = 1.5
		AudioManager.play("hurt")
		_knock(source)
		return
	GameManager.health -= 1
	GameManager.health_changed.emit(GameManager.health, GameManager.MAX_HEALTH)
	AudioManager.play("hurt")
	invuln = 1.5
	_knock(source)
	if GameManager.health <= 0:
		_die()


func _defeat_source(source: Node) -> void:
	if source.has_method("take_hit"):
		source.take_hit()
	elif source.has_method("defeated"):
		source.defeated()
	elif source.get_parent() and source.get_parent().has_method("defeated"):
		source.get_parent().defeated()


func _knock(source: Node) -> void:
	var dir := 1.0
	if source is Node2D:
		dir = sign(global_position.x - source.global_position.x)
		if dir == 0.0:
			dir = -facing
	velocity = Vector2(dir * 160.0, -180.0)


func _die() -> void:
	dying = true
	velocity = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position", GameManager.checkpoint, 1.15).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_respawn)


func _respawn() -> void:
	GameManager.health = GameManager.MAX_HEALTH
	GameManager.health_changed.emit(GameManager.health, GameManager.MAX_HEALTH)
	GameManager.clear_power()
	invuln = 1.2
	dying = false
	velocity = Vector2.ZERO


func _win() -> void:
	if GameManager.gator_down:
		AudioManager.play("victory")
		get_tree().change_scene_to_file("res://scenes/ui/VictoryScreen.tscn")


func _update_sensor_mask() -> void:
	# enemies 4 + pickups 8 + water 16 + hazards 32 + checkpoints 64 + extras
	if GameManager.power == GameManager.Power.INVISIBLE:
		sensor.collision_mask = 8 + 16 + 64
	else:
		sensor.collision_mask = 4 + 8 + 16 + 32 + 64


func _update_visuals(_delta: float) -> void:
	if in_water:
		sprite.texture = tex_swim
	elif not is_on_floor() and not in_water:
		sprite.texture = tex_jump
	else:
		sprite.texture = tex_idle

	sprite.flip_h = facing < 0.0
	var bob := sin(Time.get_ticks_msec() * 0.008) * (3.0 if in_water else 1.4)
	if is_on_floor() or in_water:
		sprite.position.y = bob
	else:
		sprite.position.y = 0.0

	if GameManager.power == GameManager.Power.INVINCIBLE:
		sprite.material = rainbow_mat
	else:
		sprite.material = null

	var alpha := 1.0
	if GameManager.power == GameManager.Power.INVISIBLE:
		alpha = 0.35
	if invuln > 0.0 and GameManager.power != GameManager.Power.INVINCIBLE:
		alpha *= 0.3 if int(invuln * 18.0) % 2 == 0 else 1.0
	sprite.modulate.a = alpha

	trail.emitting = GameManager.power == GameManager.Power.SPEED
	bubbles.emitting = in_water
