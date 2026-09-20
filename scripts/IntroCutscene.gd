extends Control

var slides: Array = []
var index := -1
var locked := false

@onready var art: TextureRect = $Art
@onready var caption: Label = $Caption
@onready var prompt: Label = $Prompt
@onready var title: Label = $Title
@onready var portrait: TextureRect = $Portrait


func _ready() -> void:
	AudioManager.play_song("bgm_sewer", -10.0)
	slides = [
		{
			"tex": preload("res://assets/ui/intro_1.png"),
			"text": "Strawberry the bunny chased a sparkly butterfly around the bathroom..."
		},
		{
			"tex": preload("res://assets/ui/intro_2.png"),
			"text": "Whoosh! She slipped, spun, and got flushed down the toilet!"
		},
		{
			"tex": preload("res://assets/ui/intro_3.png"),
			"text": "A rusty pipe dumped her into the spooky sewer. Time to get home!"
		},
	]
	_show_title()


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if locked or not is_inside_tree():
		return
	if event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		_advance()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func _show_title() -> void:
	index = -1
	art.texture = preload("res://assets/ui/intro_1.png")
	art.modulate = Color(0.55, 0.55, 0.7)
	title.visible = true
	portrait.visible = true
	caption.text = "A chubby bunny. A mysterious sewer. Three carrots of courage."
	prompt.text = "Press Space / Click to start"


func _advance() -> void:
	index += 1
	title.visible = false
	portrait.visible = false
	if index >= slides.size():
		GameManager.reset_run()
		get_tree().change_scene_to_file("res://scenes/levels/Level1.tscn")
		return
	locked = true
	var slide: Dictionary = slides[index]
	var tw := create_tween()
	tw.tween_property(art, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		art.texture = slide["tex"]
		art.modulate = Color.WHITE
		caption.text = slide["text"]
		prompt.text = "Press Space / Click"
	)
	tw.tween_property(art, "modulate:a", 1.0, 0.22)
	tw.tween_callback(func() -> void: locked = false)
