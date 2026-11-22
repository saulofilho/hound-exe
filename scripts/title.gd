extends Control
## Tela de título: continuar, novo jogo (com confirmação), opções, créditos e sair.
## É quem liga o salvamento em disco e carrega as opções.

enum Page { MAIN, CONFIRM, OPTIONS, CREDITS }

const ICONS := [[0, "icon_docs"], [3, "icon_downloads"], [4, "icon_trash"]]

var menu: GameMenu
var message: Label
var page: Page = Page.MAIN
var _starting := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	Engine.time_scale = 1.0
	GameMenu.setup_input()
	size = Art.SCREEN
	if Game.save_path == "":  # os testes definem um caminho próprio antes
		Game.save_path = SaveFile.PATH
	get_tree().auto_accept_quit = false
	Options.load_options()
	Sound.load_settings()
	Sound.muffled = false
	Sound.music("title")

	message = _label("", Vector2(0, 98))
	menu = GameMenu.new()
	add_child(menu)
	menu.options_top = 24.0
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


func _set_page(which: Page, menu_top: float) -> void:
	page = which
	menu.position = Vector2((Art.SCREEN.x - GameMenu.WIDTH) / 2.0, menu_top)
	message.visible = page == Page.MAIN or page == Page.CONFIRM


func show_main() -> void:
	_set_page(Page.MAIN, 114)
	var saved := SaveFile.read(Game.save_path)
	var options := []
	if not saved.is_empty():
		var where: String = saved.restore if saved.restore != "" else Game.START_ROOM
		message.text = Options.t("title_saved") + Options.t("room_" + where)
		if "boss_desktop" in saved.taken:
			message.text += Options.t("title_clean")
		options.append([Options.t("menu_continue"), _continue])
	elif SaveFile.exists(Game.save_path):
		message.text = Options.t("title_bad_save")
	else:
		message.text = ""
	options.append([Options.t("menu_new"), _ask_new_game])
	options.append([Options.t("menu_options"), _show_game_options])
	options.append([Options.t("menu_quit"), Game.quit])
	menu.show_options(options)


func _show_game_options() -> void:
	_set_page(Page.OPTIONS, 24)
	menu.show_game_options(show_main, _show_credits)


func _show_credits() -> void:
	_set_page(Page.CREDITS, 170)
	menu.show_options([[Options.t("menu_back"), _show_game_options]])


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
	_set_page(Page.CONFIRM, 114)
	message.text = Options.t("title_replace")
	# o foco começa na opção que não perde nada
	menu.show_options([[Options.t("menu_cancel"), show_main], [Options.t("menu_erase"), _start_new]])


func _start_new() -> void:
	if _starting:
		return
	_starting = true
	Game.new_game()
	Game.enter(Game.START_ROOM)


func _input(event: InputEvent) -> void:
	if page != Page.MAIN and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if page == Page.OPTIONS and menu.go_back():
			return
		if page == Page.CREDITS:
			_show_game_options()
		else:
			show_main()


func _draw() -> void:
	var icons := Art.texture("icons")
	for i in ICONS.size():
		for x in [4.0, 344.0]:
			var at := Vector2(x + 6, 12 + i * 58)
			Art.frame(self, icons, ICONS[i][0], at, Vector2(24, 24), Art.MID if x < 100 else Art.DIM)
		Art.text_centered(self, 25.5, 38 + i * 58, Options.t(ICONS[i][1]), Art.MID)

	var frame := Rect2(52, 3, 280, 194)
	match page:
		Page.OPTIONS:
			Art.window(self, frame, Options.t("options_heading"))
		Page.CREDITS:
			Art.window(self, frame, Options.t("credits_heading"))
			var lines := (Options.t("credits_text") % Options.version()).split("\n")
			for i in lines.size():
				Art.text_centered(self, 192, 28 + i * Art.LINE_H, lines[i], Art.WHITE if i == 0 else Art.MID)
		_:
			Art.window(self, frame, "C:\\hound.exe")
			Art.text_centered(self, 192, 18, "HOUND.EXE", Art.WHITE, 3)
			_draw_chase()

	var x := Art.taskbar(self)
	Art.text(self, Vector2(x, Art.SCREEN.y - Art.BAR_H + 3), Options.t("title_keys"), Art.MID)


## O cão farejando um rastro até um bug.
func _draw_chase() -> void:
	var step := Time.get_ticks_msec() / 160
	draw_set_transform(Vector2(112, 62), 0.0, Vector2(2, 2))
	Art.frame(self, Art.texture("hound"), 9 + step % 2, Vector2.ZERO, Vector2(24, 16))
	draw_set_transform(Vector2(234, 62), 0.0, Vector2(2, 2))
	Art.frame(self, Art.texture("walker"), step % 4, Vector2.ZERO, Vector2(16, 16))
	draw_set_transform(Vector2.ZERO)
	for i in 8:
		if (i - step) % 3 != 0:
			draw_rect(Rect2(164 + i * 8, 89, 3, 3), Art.ACCENT)
