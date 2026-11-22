class_name GameMenu
extends VBoxContainer
## Lista de opções para teclado (setas/WS, Enter), controle e mouse.
## Visual provisório, até o refinamento.

const WIDTH := 220.0


func _init() -> void:
	add_theme_constant_override("separation", 3)


## Aceitar/voltar/navegar no controle e W/S, além do padrão do Godot.
static func setup_input() -> void:
	_bind_key("ui_up", KEY_W)
	_bind_key("ui_down", KEY_S)
	_bind_key("ui_left", KEY_A)
	_bind_key("ui_right", KEY_D)
	_bind_pad("ui_left", JOY_BUTTON_DPAD_LEFT)
	_bind_pad("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_bind_pad("ui_accept", JOY_BUTTON_A)
	_bind_pad("ui_cancel", JOY_BUTTON_B)
	_bind_pad("ui_up", JOY_BUTTON_DPAD_UP)
	_bind_pad("ui_down", JOY_BUTTON_DPAD_DOWN)


static func _bind_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


static func _bind_pad(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## `options` = [[texto, ao apertar, ao ajustar], ...]. O terceiro é opcional:
## recebe -1/1 (esquerda/direita) ou 0 (apertou) e devolve o texto novo.
## O foco começa em `focus`.
func show_options(options: Array, focus := 0) -> void:
	clear()
	var buttons: Array[Button] = []
	for option in options:
		var button := _make_button(option[0])
		button.pressed.connect(Sound.play.bind("ui_ok", 1.0, 0.0))
		if option.size() > 2:
			_make_adjustable(button, option[2])
		else:
			button.pressed.connect(option[1])
		add_child(button)
		buttons.append(button)
	# o foco dá a volta do último para o primeiro
	for i in buttons.size():
		var above := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var below := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(above)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(below)
	if not buttons.is_empty():
		buttons[focus].grab_focus()
	# só depois do foco inicial, que não deve fazer barulho
	for button in buttons:
		button.focus_entered.connect(Sound.play.bind("ui_move", 1.0, 0.0))


## As duas linhas de volume e o VOLTAR, usadas no título e na pausa.
func show_sound_options(back: Callable) -> void:
	var rows := []
	for item in [["Music", "MÚSICA"], ["Effects", "EFEITOS"]]:
		var bus: String = item[0]
		var label: String = item[1]
		var adjust := func(step: int) -> String:
			Sound.change_volume(bus, step)
			return _volume_text(bus, label)
		rows.append([_volume_text(bus, label), null, adjust])
	rows.append(["VOLTAR", back])
	show_options(rows)


static func _volume_text(bus: String, label: String) -> String:
	return "<  %s %d%%  >" % [label, Sound.volumes[bus]]


func _make_adjustable(button: Button, adjust: Callable) -> void:
	button.pressed.connect(func() -> void: button.text = adjust.call(0))
	button.gui_input.connect(func(event: InputEvent) -> void:
		var step := 0
		if event.is_action_pressed("ui_left"):
			step = -1
		elif event.is_action_pressed("ui_right"):
			step = 1
		if step != 0:
			button.text = adjust.call(step)
			Sound.play("ui_move")
			button.accept_event())


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(WIDTH, 18)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_paint(button, false)
	button.focus_entered.connect(_paint.bind(button, true))
	button.focus_exited.connect(_paint.bind(button, false))
	button.mouse_entered.connect(button.grab_focus)
	return button


## Selecionado = invertido (fundo branco, texto preto).
func _paint(button: Button, lit: bool) -> void:
	var box := _box(Color.WHITE if lit else Color.BLACK)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, box)
	var ink := Color.BLACK if lit else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)


func _box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color.WHITE
	box.set_border_width_all(1)
	return box
