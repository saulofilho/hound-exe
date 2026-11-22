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


## `options` = [[texto, Callable], ...]. O foco começa em `focus`.
func show_options(options: Array, focus := 0) -> void:
	clear()
	var buttons: Array[Button] = []
	for option in options:
		var button := _make_button(option[0])
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
