class_name Stage
extends Node2D
## Base das telas jogáveis (corredor lateral e sala de cima):
## controles, câmera com tremor, hitstop, HUD, avisos e reinício.

const TILE := 16
const ACCENT := Color(0.18, 0.71, 0.66)  # teal da área de trabalho (cor do faro)

var camera: Camera2D
var hud: Label
var banner: Label
var toast: Label
var _toast_t := 0.0
var sniffing := false
var _shake := 0.0


func _ready() -> void:
	_setup_input()
	RenderingServer.set_default_clear_color(Color.BLACK)
	Engine.time_scale = 1.0
	camera = Camera2D.new()
	add_child(camera)
	_build_level()
	_build_hud(help_text())


# ---- para as subclasses

func _build_level() -> void:
	pass


func help_text() -> String:
	return ""


func stage_process(_delta: float) -> void:
	pass


## Parede sólida de `width` blocos a partir da célula (cx, cy).
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


# ---- efeitos

func base_time_scale() -> float:
	return 0.5 if sniffing else 1.0


func set_sniffing(on: bool) -> void:
	if on == sniffing:
		return
	sniffing = on
	Engine.time_scale = base_time_scale()
	queue_redraw()


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Congela o jogo por um instante para dar peso ao impacto.
func hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = base_time_scale()


## Mensagem curta no rodapé (sala nova, item pego, ponto de restauração).
func show_toast(text: String, seconds := 2.0) -> void:
	toast.text = text
	_toast_t = seconds
	toast.visible = true


func show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		Game.respawn()  # volta ao último ponto de restauração
		set_process(false)
		return
	stage_process(delta)
	var real := delta / maxf(Engine.time_scale, 0.05)
	_toast_t = maxf(_toast_t - real, 0.0)
	toast.visible = _toast_t > 0.0
	# o tremor ignora a câmera lenta, para não ficar "mole" durante o faro
	_shake = move_toward(_shake, 0.0, delta / maxf(Engine.time_scale, 0.05) * 30.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


func _build_hud(help: String) -> void:
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
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(0, 150)
	toast.size = Vector2(384, 40)
	toast.add_theme_font_size_override("font_size", 10)
	toast.add_theme_color_override("font_color", ACCENT)
	toast.visible = false
	layer.add_child(toast)
	var hint := Label.new()
	hint.text = help
	hint.position = Vector2(6, 200)
	hint.add_theme_font_size_override("font_size", 8)
	hint.modulate = Color(1, 1, 1, 0.6)
	layer.add_child(hint)


# ---- controles

func _setup_input() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_Z], "shoot": [KEY_J, KEY_X],
		"dash": [KEY_K, KEY_C], "sniff": [KEY_SHIFT, KEY_L], "restart": [KEY_R], "map": [KEY_TAB],
	}
	var pad_buttons := {"jump": JOY_BUTTON_A, "shoot": JOY_BUTTON_X, "dash": JOY_BUTTON_B, "restart": JOY_BUTTON_START, "map": JOY_BUTTON_BACK}
	var pad_axes := {
		"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
		"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
		"sniff": [JOY_AXIS_TRIGGER_LEFT, 1.0], "shoot": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"aim_left": [JOY_AXIS_RIGHT_X, -1.0], "aim_right": [JOY_AXIS_RIGHT_X, 1.0],
		"aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	var actions := keys.keys()
	for a in pad_axes:
		if not a in actions:
			actions.append(a)
	for action in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.4)
		for k in keys.get(action, []):
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
	if InputMap.has_action("shoot") and not _has_mouse(InputMap.action_get_events("shoot")):
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mb)


func _has_mouse(events: Array) -> bool:
	for e in events:
		if e is InputEventMouseButton:
			return true
	return false
