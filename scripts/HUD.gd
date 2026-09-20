extends CanvasLayer

@onready var hearts: HBoxContainer = $Root/Hearts
@onready var power_label: Label = $Root/PowerLabel
@onready var hint: Label = $Root/Hint
@onready var pause_panel: ColorRect = $Root/Pause
@onready var boss_label: Label = $Root/BossBanner

var carrot_tex: Texture2D
var empty_tex: Texture2D


func _ready() -> void:
	carrot_tex = preload("res://assets/sprites/carrot.png")
	GameManager.health_changed.connect(_on_health)
	GameManager.powerup_changed.connect(_on_power)
	_on_health(GameManager.health, GameManager.MAX_HEALTH)
	_on_power(GameManager.power, GameManager.power_time)
	pause_panel.visible = false
	boss_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused
		pause_panel.visible = get_tree().paused
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var x := player.global_position.x
	if GameManager.gator_down:
		hint.text = "Climb the glowing ladder — go home!"
	elif x < 420.0:
		hint.text = "WASD / Arrows move   •   Space jump   •   Swim in the water!"
	elif x < 1100.0:
		hint.text = "Leap onto pipes!  Smash ? boxes for power-ups."
	elif x < 1900.0:
		hint.text = "Watch the bats... keep hopping!"
	elif x < 2500.0:
		hint.text = "Eels patrol the tunnels. Swim around them!"
	else:
		hint.text = "The Sewer King! Grab a power-up, then dash into him while he rests."


func show_boss_banner() -> void:
	boss_label.visible = true
	boss_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(boss_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.2)
	tw.tween_property(boss_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: boss_label.visible = false)


func _on_health(current: int, maximum: int) -> void:
	for child in hearts.get_children():
		child.queue_free()
	for i in range(maximum):
		var tex := TextureRect.new()
		tex.texture = carrot_tex
		tex.custom_minimum_size = Vector2(22, 28)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.modulate = Color.WHITE if i < current else Color(0.25, 0.25, 0.3, 0.7)
		hearts.add_child(tex)


func _on_power(kind: int, remaining: float) -> void:
	if kind == GameManager.Power.NONE:
		power_label.text = ""
		return
	power_label.text = "%s  %0.0fs" % [GameManager.power_label(), ceil(remaining)]
