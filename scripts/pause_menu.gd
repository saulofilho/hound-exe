class_name PauseMenu
extends CanvasLayer
## Pausa (Esc / Start). Cada Stage cria a sua.

var menu: GameMenu
var stage: Stage
var _closing := false
var _in_sound := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	GameMenu.setup_input()

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.88)
	shade.size = Vector2(384, 216)
	add_child(shade)

	var heading := Label.new()
	heading.text = "PROCESSO PAUSADO"
	heading.position = Vector2(0, 34)
	heading.size = Vector2(384, 20)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(heading)

	var note := Label.new()
	note.text = "O progresso é salvo sozinho. Ao voltar, o cão\naparece no último ponto de restauração." if Game.save_path != "" else "Salvamento desligado: sala aberta sem passar pelo título."
	note.position = Vector2(0, 60)
	note.size = Vector2(384, 24)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Stage.ACCENT)
	add_child(note)

	menu = GameMenu.new()
	menu.position = Vector2((384 - GameMenu.WIDTH) / 2.0, 92)
	add_child(menu)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if _in_sound and not event.is_action_pressed("pause"):
				_show_main()  # B no submenu volta um nível
			else:
				close()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if stage.hero_dead():
			Game.respawn()  # na tela azul, Start/Esc faz o mesmo que R
		else:
			open()


func open() -> void:
	visible = true
	_closing = false
	get_tree().paused = true
	Sound.play("pause")
	_show_main()


func _show_main() -> void:
	_in_sound = false
	menu.show_options([
		["CONTINUAR", close],
		["VOLTAR AO PONTO DE RESTAURAÇÃO", Game.respawn],
		["SOM", _show_sound],
		["TELA DE TÍTULO", Game.to_title],
		["SAIR DO JOGO", Game.quit],
	])


func _show_sound() -> void:
	_in_sound = true
	menu.show_sound_options(_show_main)


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
