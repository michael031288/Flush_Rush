extends Node2D

const T := 32
const MAP_W := 108
const MAP_H := 18

@onready var tiles: TileMapLayer = $TileMapLayer
@onready var entities: Node2D = $Entities
@onready var decor: Node2D = $Decor

var _exit_visuals: Array[CanvasItem] = []
var _exit_area: Area2D
var _hud: CanvasLayer


func _ready() -> void:
	randomize()
	_build_tileset()
	_paint_backdrop()
	_build_world()
	_spawn_player()
	_hud = preload("res://scenes/ui/HUD.tscn").instantiate()
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud)
	AudioManager.play_song("bgm_sewer", -8.0)
	if "--shot" in OS.get_cmdline_user_args():
		_capture_shot()


func _capture_shot() -> void:
	await get_tree().create_timer(0.45).timeout
	var img := get_viewport().get_texture().get_image()
	var path := "user://flush_rush_shot.png"
	img.save_png(path)
	print("Saved screenshot to ", OS.get_user_data_dir())


func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = preload("res://assets/sprites/tileset.png")
	src.texture_region_size = Vector2i(T, T)
	for y in range(4):
		for x in range(8):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	tiles.tile_set = ts
	tiles.z_index = -2


func _atlas(i: int) -> Vector2i:
	return Vector2i(i % 8, int(i / 8.0))


func cell(x: int, y: int, atlas: int) -> void:
	if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
		return
	tiles.set_cell(Vector2i(x, y), 0, _atlas(atlas))


func fill(x: int, y: int, w: int, h: int, atlas: int, collide: bool = false) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			cell(xx, yy, atlas)
	if collide:
		_solid(x, y, w, h)


func _solid(x: int, y: int, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2((x + w * 0.5) * T, (y + h * 0.5) * T)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w * T, h * T)
	cs.shape = rect
	body.add_child(cs)
	entities.add_child(body)


func _paint_backdrop() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			var atlas := 6
			if (x * 3 + y * 5) % 13 == 0:
				atlas = 15
			elif (x + y * 2) % 19 == 0:
				atlas = 5
			cell(x, y, atlas)
	var bg := Sprite2D.new()
	bg.texture = preload("res://assets/sprites/bg_sewer.png")
	bg.centered = false
	bg.z_index = -8
	bg.modulate = Color(0.42, 0.38, 0.58)
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.region_enabled = true
	bg.region_rect = Rect2(0, 0, MAP_W * T, MAP_H * T)
	add_child(bg)
	move_child(bg, 0)


func _build_world() -> void:
	# Outer shell
	fill(0, 0, MAP_W, 1, 0, true)
	fill(0, MAP_H - 1, MAP_W, 1, 0, true)
	fill(0, 1, 1, MAP_H - 2, 0, true)
	fill(MAP_W - 1, 1, 1, MAP_H - 2, 0, true)

	_section_start()
	_section_pipes()
	_section_cave()
	_section_eels()
	_section_boss()


func _section_start() -> void:
	fill(1, 16, 18, 1, 5, true)
	_water(1, 9, 18, 7)
	_platform(2, 7, 5, 4)
	_platform(10, 7, 5, 4)
	_spawn_pickup(Vector2(12 * T + 16, 7 * T - 18), "carrot")
	_spawn_box(Vector2(16 * T, 6 * T))
	_prop(14, 1, Vector2(2.5 * T, 5.5 * T), Vector2(1.8, 1.8))
	_prop(3, 0, Vector2(1.6 * T, 3.2 * T), Vector2(1.2, 2.4))
	_mushroom(Vector2(8 * T, 16 * T))
	_mushroom(Vector2(15 * T, 16 * T))


func _section_pipes() -> void:
	fill(19, 16, 24, 1, 1, true)
	_water(19, 12, 24, 4)
	_platform(20, 9, 4, 4)
	_platform(26, 7, 4, 2)
	_platform(32, 9, 5, 4)
	_platform(38, 6, 4, 4)
	_spawn_box(Vector2(22 * T, 8 * T))
	_spawn_pickup(Vector2(34 * T, 9 * T - 18), "carrot")
	_slime(Vector2(27 * T + 16, 7 * T - 14))
	_slime(Vector2(39 * T, 6 * T - 14))
	_mushroom(Vector2(24 * T, 16 * T))
	fill(30, 1, 1, 4, 3, true)


func _section_cave() -> void:
	fill(43, 12, 20, 5, 0, true)
	fill(43, 12, 20, 1, 5, false)
	_platform(48, 8, 4, 4)
	_platform(55, 6, 4, 4)
	_bat(Vector2(47 * T, 4 * T), 90)
	_bat(Vector2(56 * T, 3 * T + 16), 110)
	_spawn_pickup(Vector2(49 * T + 16, 8 * T - 18), "carrot")
	_spawn_box(Vector2(57 * T, 5 * T))
	_checkpoint(Vector2(61 * T, 12 * T - 8))
	_mushroom(Vector2(51 * T, 12 * T))
	fill(52, 1, 2, 2, 8, false)


func _section_eels() -> void:
	fill(63, 16, 18, 1, 1, true)
	fill(63, 1, 18, 3, 15, true)
	_water(63, 8, 18, 8)
	_platform(66, 7, 3, 4)
	_platform(73, 6, 4, 4)
	_eel(Vector2(70 * T, 12 * T), 70)
	_eel(Vector2(76 * T, 11 * T), 80)
	_spawn_pickup(Vector2(67 * T + 16, 7 * T - 18), "carrot")
	_spawn_box(Vector2(75 * T, 5 * T))
	_slime(Vector2(74 * T, 6 * T - 14))


func _section_boss() -> void:
	fill(81, 16, 26, 1, 0, true)
	_water(82, 10, 23, 6)
	_platform(81, 6, 6, 2)
	_platform(81, 9, 5, 4)
	_platform(99, 6, 7, 2)
	_platform(100, 9, 6, 4)
	_platform(90, 8, 3, 4)

	var gator = preload("res://scenes/characters/BossGator.tscn").instantiate()
	gator.global_position = Vector2(93 * T, 13 * T)
	gator.arena_left = 84 * T
	gator.arena_right = 102 * T
	gator.swim_y = 13 * T
	gator.died.connect(_on_boss_dead)
	entities.add_child(gator)

	var trigger := Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.position = Vector2(82 * T, 8 * T)
	var tshape := CollisionShape2D.new()
	var trect := RectangleShape2D.new()
	trect.size = Vector2(3 * T, 10 * T)
	tshape.shape = trect
	trigger.add_child(tshape)
	trigger.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player") and _hud and _hud.has_method("show_boss_banner"):
			_hud.show_boss_banner()
			trigger.queue_free()
	)
	entities.add_child(trigger)

	# Hidden home ladder
	for y in range(1, 6):
		cell(103, y, 9)
		var rung := Sprite2D.new()
		rung.texture = preload("res://assets/sprites/tileset.png")
		rung.region_enabled = true
		rung.region_rect = Rect2(1 * T, 1 * T, T, T)
		rung.position = Vector2(103 * T + 16, y * T + 16)
		rung.visible = false
		decor.add_child(rung)
		_exit_visuals.append(rung)
	var hole := Sprite2D.new()
	hole.texture = preload("res://assets/sprites/tileset.png")
	hole.region_enabled = true
	hole.region_rect = Rect2(4 * T, 1 * T, T, T)
	hole.position = Vector2(103 * T + 16, 1 * T + 16)
	hole.visible = false
	decor.add_child(hole)
	_exit_visuals.append(hole)

	_exit_area = Area2D.new()
	_exit_area.collision_layer = 8
	_exit_area.collision_mask = 0
	_exit_area.monitoring = false
	_exit_area.monitorable = true
	_exit_area.add_to_group("exit")
	_exit_area.position = Vector2(103 * T + 16, 4 * T)
	var es := CollisionShape2D.new()
	var er := RectangleShape2D.new()
	er.size = Vector2(24, 5 * T)
	es.shape = er
	_exit_area.add_child(es)
	entities.add_child(_exit_area)


func _on_boss_dead() -> void:
	for vis in _exit_visuals:
		vis.visible = true
		vis.modulate = Color(1.4, 1.3, 0.6)
	_exit_area.monitoring = true
	_exit_area.monitorable = true
	if _hud:
		_hud.hint.text = "Climb the glowing ladder — go home!"


func _water(x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			cell(xx, yy, 11)
	var water = preload("res://scenes/objects/WaterZone.tscn").instantiate()
	entities.add_child(water)
	water.setup(Rect2(x * T, y * T, w * T, h * T))
	water.add_to_group("water")
	water.collision_layer = 16
	water.collision_mask = 0
	water.z_index = 8


func _platform(x: int, y: int, w: int, atlas: int) -> void:
	fill(x, y, w, 1, atlas, true)


func _spawn_player() -> void:
	var player = preload("res://scenes/characters/Strawberry.tscn").instantiate()
	player.global_position = Vector2(4 * T, 7 * T - 22)
	entities.add_child(player)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.enabled = true
	cam.make_current()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * T
	cam.limit_bottom = MAP_H * T
	cam.limit_smoothed = true
	GameManager.set_checkpoint(player.global_position)


func _spawn_pickup(pos: Vector2, kind: String) -> void:
	var p = preload("res://scenes/objects/Pickup.tscn").instantiate()
	p.kind = kind
	p.pop_on_spawn = false
	p.global_position = pos
	entities.add_child(p)


func _spawn_box(pos: Vector2) -> void:
	var b = preload("res://scenes/objects/MysteryBox.tscn").instantiate()
	b.global_position = pos
	entities.add_child(b)


func _slime(pos: Vector2) -> void:
	var s = preload("res://scenes/characters/Slime.tscn").instantiate()
	s.global_position = pos
	entities.add_child(s)


func _eel(pos: Vector2, travel: float) -> void:
	var e = preload("res://scenes/characters/Eel.tscn").instantiate()
	e.global_position = pos
	e.travel = travel
	entities.add_child(e)


func _bat(pos: Vector2, travel: float) -> void:
	var b = preload("res://scenes/characters/Bat.tscn").instantiate()
	b.global_position = pos
	b.travel = travel
	entities.add_child(b)


func _checkpoint(pos: Vector2) -> void:
	var c = preload("res://scenes/objects/Checkpoint.tscn").instantiate()
	c.global_position = pos
	entities.add_child(c)


func _mushroom(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/tileset.png")
	s.region_enabled = true
	s.region_rect = Rect2(0, T, T, T)
	s.position = pos + Vector2(16, -8)
	s.z_index = -1
	decor.add_child(s)


func _prop(atlas: int, _unused: int, pos: Vector2, scl: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/tileset.png")
	s.region_enabled = true
	s.region_rect = Rect2((atlas % 8) * T, int(atlas / 8.0) * T, T, T)
	s.position = pos
	s.scale = scl
	s.z_index = -1
	decor.add_child(s)
