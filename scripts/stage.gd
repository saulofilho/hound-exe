class_name Stage
extends Node2D
## Base das telas jogáveis (corredor lateral e sala de cima):
## controles, câmera com tremor, hitstop, HUD, avisos e reinício.

const TILE := 16
const RESTART_HOLD := 0.8      # segundos segurando R
const ACCENT := Art.ACCENT

var camera: Camera2D
var hud: Hud
var banner: DialogBox
var toast: DialogBox
var _toast_t := 0.0
var sniffing := false
var _shake := 0.0
var pause_menu: PauseMenu
var _restart_held := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	Engine.time_scale = 1.0
	Sound.muffled = false
	camera = Camera2D.new()
	add_child(camera)
	_build_level()
	_build_hud(help_text())
	pause_menu = PauseMenu.new()
	pause_menu.stage = self
	add_child(pause_menu)
	Game.save_failed.connect(_on_save_failed)
	Options.changed.connect(refresh_text)
	Options.interrupted.connect(_on_interrupted)


# ---- para as subclasses

func _build_level() -> void:
	pass


func help_text() -> String:
	return ""


func stage_process(_delta: float) -> void:
	pass


func hero_dead() -> bool:
	return false


## Alguma janela por cima do jogo que cuida do próprio Esc (o Explorer).
func overlay_open() -> bool:
	return false


func refresh_text() -> void:
	hud.hint = help_text()


func _on_interrupted() -> void:
	if not pause_menu.visible and not hero_dead() and not overlay_open():
		pause_menu.open()


func _on_save_failed() -> void:
	show_toast(Options.t("save_failed"), 5.0)


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
	if on:
		Sound.play("sniff")
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
	banner.fill = color
	banner.visible = true


func _process(delta: float) -> void:
	if _wants_restart(delta):
		Game.respawn()  # volta ao último ponto de restauração
		set_process(false)
		return
	stage_process(delta)
	Sound.muffled = sniffing or hero_dead()
	var real := delta / maxf(Engine.time_scale, 0.05)
	_toast_t = maxf(_toast_t - real, 0.0)
	toast.visible = _toast_t > 0.0
	# o tremor ignora a câmera lenta, para não ficar "mole" durante o faro
	_shake = move_toward(_shake, 0.0, delta / maxf(Engine.time_scale, 0.05) * 30.0)
	var jolt := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	camera.offset = jolt if Options.shake else Vector2.ZERO


## Na tela azul basta um toque; vivo, é preciso segurar.
func _wants_restart(delta: float) -> bool:
	var pressed := Input.is_action_just_pressed("restart")
	if hero_dead():
		return pressed
	if pressed:
		show_toast(Options.t("hold_restart"), RESTART_HOLD + 0.6)
	if Input.is_action_pressed("restart"):
		_restart_held += delta / maxf(Engine.time_scale, 0.05)
	else:
		_restart_held = 0.0
	hud.restart_hold = _restart_held / RESTART_HOLD
	return _restart_held >= RESTART_HOLD


func _build_hud(help: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.hint = help
	layer.add_child(hud)
	toast = DialogBox.new()
	toast.top = 22.0
	toast.visible = false
	layer.add_child(toast)
	banner = DialogBox.new()
	banner.titled = true
	banner.visible = false
	layer.add_child(banner)
