extends Control
## Tela de título: continuar, novo jogo (com confirmação) e sair.
## É quem liga o salvamento em disco.

const ICONS := [[0, "Documentos"], [3, "Downloads"], [4, "Lixeira"]]

var menu: GameMenu
var message: Label
var _in_submenu := false
var _starting := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	Engine.time_scale = 1.0
	GameMenu.setup_input()
	size = Vector2(384, 216)
	if Game.save_path == "":  # os testes definem um caminho próprio antes
		Game.save_path = SaveFile.PATH
	get_tree().auto_accept_quit = false
	Sound.load_settings()
	Sound.muffled = false
	Sound.music("title")

	message = _label("", Vector2(0, 98))
	menu = GameMenu.new()
	menu.position = Vector2((384 - GameMenu.WIDTH) / 2.0, 114)
	add_child(menu)
	show_main()


func _label(content: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = content
	label.position = at
	label.size = Vector2(Art.SCREEN.x, Art.LINE_H)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Art.ACCENT)
	add_child(label)
	return label


func _process(_delta: float) -> void:
	queue_redraw()  # o cão anima


func show_main() -> void:
	_in_submenu = false
	var saved := SaveFile.read(Game.save_path)
	var options := []
	if not saved.is_empty():
		var where: String = saved.restore if saved.restore != "" else Game.START_ROOM
		message.text = "Progresso salvo · volta em " + Rooms.DATA[where].name
		if "boss_desktop" in saved.taken:
			message.text += " · região limpa"
		options.append(["CONTINUAR", _continue])
	elif SaveFile.exists(Game.save_path):
		message.text = "O save não pôde ser lido."
	else:
		message.text = ""
	options.append(["NOVO JOGO", _ask_new_game])
	options.append(["SOM", _show_sound])
	options.append(["SAIR", Game.quit])
	menu.show_options(options)


func _show_sound() -> void:
	_in_submenu = true
	message.text = "Esquerda e direita ajustam o volume."
	menu.show_sound_options(show_main)


func _continue() -> void:
	if _starting:
		return
	if Game.load_game():
		_starting = true
		Game.respawn()
	else:
		show_main()


func _ask_new_game() -> void:
	if not SaveFile.exists(Game.save_path):
		_start_new()
		return
	_in_submenu = true
	message.text = "Começar de novo substitui o progresso salvo."
	# o foco começa na opção que não perde nada
	menu.show_options([["CANCELAR", show_main], ["APAGAR E COMEÇAR", _start_new]])


func _start_new() -> void:
	if _starting:
		return
	_starting = true
	Game.new_game()
	Game.enter(Game.START_ROOM)


func _input(event: InputEvent) -> void:
	if _in_submenu and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		show_main()


func _draw() -> void:
	var icons := Art.texture("icons")
	for i in ICONS.size():
		for x in [4.0, 344.0]:
			var at := Vector2(x + 6, 12 + i * 58)
			Art.frame(self, icons, ICONS[i][0], at, Vector2(24, 24), Art.MID if x < 100 else Art.DIM)
		Art.text_centered(self, 25.5, 38 + i * 58, ICONS[i][1], Art.MID)

	Art.window(self, Rect2(52, 3, 280, 194), "C:\\hound.exe")
	Art.text_centered(self, 192, 18, "HOUND.EXE", Art.WHITE, 3)

	# o cão farejando um rastro até um bug
	var step := Time.get_ticks_msec() / 160
	draw_set_transform(Vector2(112, 62), 0.0, Vector2(2, 2))
	Art.frame(self, Art.texture("hound"), 9 + step % 2, Vector2.ZERO, Vector2(24, 16))
	draw_set_transform(Vector2(234, 62), 0.0, Vector2(2, 2))
	Art.frame(self, Art.texture("walker"), step % 4, Vector2.ZERO, Vector2(16, 16))
	draw_set_transform(Vector2.ZERO)
	for i in 8:
		if (i - step) % 3 != 0:
			draw_rect(Rect2(164 + i * 8, 89, 3, 3), Art.ACCENT)

	var x := Art.taskbar(self)
	Art.text(self, Vector2(x, Art.SCREEN.y - Art.BAR_H + 3), "setas ou W/S escolhem · Enter ou A confirma", Art.MID)
