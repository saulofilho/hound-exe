extends Node2D
## Protótipo da fase 0: corredor lateral cinza montado a partir de um mapa ASCII.
## Legenda: # parede · P cão · w inimigo que anda · t torreta · E fim do corredor

const TILE := 16
const MAP := [
	"########################################################################",
	"#......................................................................#",
	"#......................................................................#",
	"#......................................................................#",
	"#...........................................###........................#",
	"#......................................................................#",
	"#...................................t.....................####.........#",
	"#.................................#####................................#",
	"#.......#####.......................................####...............#",
	"#.........................####.........................................#",
	"#..P............w.........####............w.............w.........t...E#",
	"########################################################################",
	"########################################################################",
]
const WALL := Color(0.36, 0.36, 0.4)
const WALL_TOP := Color(0.62, 0.62, 0.66)

var player: Player
var camera: Camera2D
var hud: Label
var banner: Label
var exit_pos: Vector2
var _shake := 0.0
var _done := false


func _ready() -> void:
	_setup_input()
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_level()
	_build_hud()


# ------------------------------------------------------------------ nível

func is_solid(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size():
		return true
	var row: String = MAP[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return true
	return row[cell.x] == "#"


func is_solid_at(pos: Vector2) -> bool:
	return is_solid(Vector2i(floori(pos.x / TILE), floori(pos.y / TILE)))


func _build_level() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		var x := 0
		while x < row.length():
			if row[x] == "#":
				# junta paredes vizinhas da mesma linha num único corpo
				var start := x
				while x < row.length() and row[x] == "#":
					x += 1
				_add_wall(start, y, x - start)
				continue
			var at := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match row[x]:
				"P":
					player = Player.new()
					player.position = at
					add_child(player)
				"w":
					var w := Walker.new()
					w.position = at
					add_child(w)
				"t":
					var t := Turret.new()
					t.position = at
					add_child(t)
				"E":
					exit_pos = at
			x += 1

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP[0].length() * TILE
	camera.limit_bottom = MAP.size() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.global_position = player.global_position
	camera.reset_smoothing()


func _add_wall(cx: int, cy: int, width: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * TILE, TILE)
	shape.shape = rect
	body.position = Vector2((cx + width / 2.0) * TILE, cy * TILE + TILE / 2.0)
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(r, WALL)
			if not is_solid(Vector2i(x, y - 1)):
				draw_rect(Rect2(r.position, Vector2(TILE, 2)), WALL_TOP)
	if exit_pos != Vector2.ZERO:
		draw_rect(Rect2(exit_pos - Vector2(6, 8), Vector2(12, 16)), Color.WHITE, false, 1.0)
		draw_rect(Rect2(exit_pos - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)


# ------------------------------------------------------------------ hud e efeitos

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(6, 4)
	layer.add_child(hud)
	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.size = Vector2(384, 216)
	banner.visible = false
	layer.add_child(banner)
	var help := Label.new()
	help.text = "mover A/D · pular Espaço · atirar J (W mira p/ cima) · dash K · R reinicia"
	help.position = Vector2(6, 200)
	help.add_theme_font_size_override("font_size", 8)
	help.modulate = Color(1, 1, 1, 0.6)
	layer.add_child(help)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Congela o jogo por um instante para dar peso ao impacto.
func hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return
	if is_instance_valid(player):
		camera.global_position = player.global_position + Vector2(player.facing * 32, -16)
		var enemies := get_tree().get_nodes_in_group("enemy").size()
		hud.text = "VIDA %d/%d   BUGS %d" % [maxi(player.hp, 0), player.MAX_HP, enemies]
		if not _done and player.global_position.distance_to(exit_pos) < 12:
			_done = true
			show_banner("FIM DO CORREDOR\nsala de cima vem na próxima etapa\n\nR para jogar de novo", Color.WHITE)
	_shake = move_toward(_shake, 0.0, delta * 30.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


# ------------------------------------------------------------------ controles

func _setup_input() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_Z], "shoot": [KEY_J, KEY_X],
		"dash": [KEY_K, KEY_C], "restart": [KEY_R],
	}
	var pad_buttons := {"jump": JOY_BUTTON_A, "shoot": JOY_BUTTON_X, "dash": JOY_BUTTON_B, "restart": JOY_BUTTON_START}
	var pad_axes := {
		"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
		"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.4)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		if pad_buttons.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pad_buttons[action]
			InputMap.action_add_event(action, jb)
		if pad_axes.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = pad_axes[action][0]
			jm.axis_value = pad_axes[action][1]
			InputMap.action_add_event(action, jm)
