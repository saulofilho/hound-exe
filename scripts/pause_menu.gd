class_name PauseMenu
extends CanvasLayer
## Pausa (Esc / Menu), opções e o aviso de fim. Cada Stage cria a sua.

enum Page { MAIN, OPTIONS, ENDING }

var menu: GameMenu
var stage: Stage
var page: Page = Page.MAIN
var _closing := false
var _frame: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	GameMenu.setup_input()

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.size = Art.SCREEN
	add_child(shade)

	_frame = Control.new()
	_frame.size = Art.SCREEN
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_window)
	add_child(_frame)
	Options.changed.connect(_frame.queue_redraw)

	menu = GameMenu.new()
	add_child(menu)
	menu.options_top = 34.0


func _draw_window() -> void:
	var headings := ["pause_heading", "options_heading", "ending_heading"]
	var top_y := 3.0 if page == Page.OPTIONS else 22.0
	Art.window(_frame, Rect2(62, top_y, 260, 206.0 - top_y), Options.t(headings[page]))
	if page == Page.OPTIONS:
		return
	var key := "ending_text"
	if page == Page.MAIN:
		key = "pause_no_save" if Game.save_path == "" else "pause_saved"
	var lines := Options.t(key).split("\n")
	var top := 70.0 if page == Page.ENDING else 46.0
	var ink := Art.WHITE if page == Page.ENDING else Art.MID
	for i in lines.size():
		Art.text_centered(_frame, 192, top + i * Art.LINE_H, lines[i], ink)
	if page == Page.ENDING:
		Art.text_centered(_frame, 192, 49, ending_summary(), Art.ACCENT)


func ending_summary() -> String:
	var stats := Game.stats
	return Options.t("ending_stats") % [RunStats.clock(stats.finish_time()), stats.deaths, Game.secret_count(), Rooms.secret_total()]


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if page == Page.OPTIONS and not event.is_action_pressed("pause"):
				if menu.go_back():
					return
				_show_main()  # B no submenu volta um nível
			else:
				close()
	elif stage.overlay_open():
		return
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if stage.hero_dead():
			Game.respawn()  # na tela azul, Menu/Esc faz o mesmo que R
		else:
			open()


func open() -> void:
	_show()
	Sound.play("pause")
	_show_main()


func open_ending() -> void:
	_show()
	_set_page(Page.ENDING, 116)
	menu.show_options([
		[Options.t("menu_explore"), close],
		[Options.t("menu_title"), Game.to_title],
		[Options.t("menu_quit_game"), Game.quit],
	])


func _show() -> void:
	visible = true
	_closing = false
	get_tree().paused = true


func _set_page(which: Page, menu_top: float) -> void:
	page = which
	menu.position = Vector2((Art.SCREEN.x - GameMenu.WIDTH) / 2.0, menu_top)
	_frame.queue_redraw()


func _show_main() -> void:
	_set_page(Page.MAIN, 92)
	menu.show_options([
		[Options.t("menu_continue"), close],
		[Options.t("menu_restore"), Game.give_up],
		[Options.t("menu_options"), _show_game_options],
		[Options.t("menu_title"), Game.to_title],
		[Options.t("menu_quit_game"), Game.quit],
	])


func _show_game_options() -> void:
	_set_page(Page.OPTIONS, 34)
	menu.show_game_options(_show_main)


func close() -> void:
	if _closing:
		return
	_closing = true
	menu.clear()  # nenhum botão escondido pode ficar com o foco
	# espera passar o quadro do botão, senão B (voltar) vira dash e A vira pulo
	await get_tree().physics_frame
	await get_tree().physics_frame
	visible = false
	_closing = false
	get_tree().paused = false
