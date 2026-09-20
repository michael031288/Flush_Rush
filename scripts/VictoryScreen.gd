extends Control

@onready var art: TextureRect = $Art
@onready var caption: Label = $Caption
@onready var prompt: Label = $Prompt
@onready var confetti: CPUParticles2D = $Confetti


func _ready() -> void:
	AudioManager.play_song("bgm_victory", -6.0)
	art.texture = preload("res://assets/ui/ending.png")
	caption.text = "Home at last! Strawberry's bunny family throws a meadow party."
	prompt.text = "Press Space to play again   •   Esc to quit"
	confetti.emitting = true
	var fireworks := $Fireworks
	fireworks.emitting = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER):
		GameManager.reset_run()
		get_tree().change_scene_to_file("res://scenes/ui/IntroCutscene.tscn")
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
