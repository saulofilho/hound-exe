extends Control
## Tela de título: continuar, novo jogo (com confirmação) e sair.
## É quem liga o salvamento em disco.

const ACCENT := Color(0.18, 0.71, 0.66)

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

	_label("HOUND.EXE", Vector2(0, 20), 34, Color.WHITE)
	message = _label("", Vector2(0, 98), 9, ACCENT)
	menu = GameMenu.new()
	menu.position = Vector2((384 - GameMenu.WIDTH) / 2.0, 114)
	add_child(menu)
	_label("setas ou W/S escolhem · Enter ou A confirma", Vector2(0, 198), 8, Color(1, 1, 1, 0.5))
	show_main()


func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(384, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


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
	# o cão provisório, 3×, farejando um rastro até um bug
	draw_set_transform(Vector2(140, 76), 0.0, Vector2(3, 3))
	for r in [Rect2(-6, -1, 10, 6), Rect2(3, -2, 5, 6), Rect2(7, 0, 2, 3), Rect2(3, -4, 2, 2), Rect2(-8, -2, 2, 1), Rect2(-5, 5, 1, 3), Rect2(-2, 5, 1, 3), Rect2(1, 5, 1, 3), Rect2(3, 5, 1, 3)]:
		draw_rect(r, Color.WHITE)
	draw_rect(Rect2(5, 0, 1, 1), Color.BLACK)
	draw_set_transform(Vector2.ZERO)
	for x in range(178, 238, 10):
		draw_rect(Rect2(x, 91, 4, 3), ACCENT)
	draw_rect(Rect2(244, 82, 16, 12), Enemy.BUG_COLOR)
	draw_rect(Rect2(247, 78, 10, 4), Enemy.BUG_COLOR)
	for x in [245, 251, 257]:
		draw_rect(Rect2(x, 94, 2, 5), Enemy.BUG_COLOR)
