class_name GameMenu
extends VBoxContainer
## Lista de opções para teclado (setas/WS, Enter), controle e mouse.

const WIDTH := 220.0


var options_top := 34.0    # onde a lista de opções começa
var compact := false       # linhas baixas, para a tela de controles
var _listen_action := ""
var _listen_device := ""
var _listen_back := Callable()
var _parent_page := Callable()  # para onde B volta, num submenu


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
	ev.device = -1
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## `options` = [[texto, ao apertar, ao ajustar], ...]. O terceiro é opcional:
## recebe -1/1 (esquerda/direita) ou 0 (apertou) e devolve o texto novo.
## O foco começa em `focus`.
func show_options(options: Array, focus := 0, low := false) -> void:
	clear()
	compact = low
	add_theme_constant_override("separation", 1 if low else 3)
	size = Vector2.ZERO
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


## As opções, usadas no título e na pausa. `credits` só existe no título.
func show_game_options(back: Callable, credits := Callable(), focus := 0) -> void:
	var rows := []
	for item in [["Music", "opt_music"], ["Effects", "opt_effects"]]:
		var bus: String = item[0]
		var label: String = item[1]
		var adjust := func(step: int) -> String:
			Sound.change_volume(bus, step)
			return _volume_text(bus, label)
		rows.append([_volume_text(bus, label), null, adjust])

	var language := func(_step: int) -> String:
		Options.cycle_language()
		# tudo muda de idioma: refaz a lista com o foco na mesma linha
		show_game_options.call_deferred(back, credits, 2)
		return _choice_text("opt_language", Options.t("language_name"))
	rows.append([_choice_text("opt_language", Options.t("language_name")), null, language])

	var screen := func(_step: int) -> String:
		Options.toggle_fullscreen()
		return _switch_text("opt_fullscreen", Options.fullscreen)
	rows.append([_switch_text("opt_fullscreen", Options.fullscreen), null, screen])

	var shake := func(_step: int) -> String:
		Options.toggle_shake()
		return _switch_text("opt_shake", Options.shake)
	rows.append([_switch_text("opt_shake", Options.shake), null, shake])

	var controls := func() -> void:
		show_controls(show_game_options.bind(back, credits, 5))
	rows.append([Options.t("menu_controls"), controls])
	if credits.is_valid():
		rows.append([Options.t("menu_credits"), credits])
	rows.append([Options.t("menu_back"), back])
	show_options(rows, focus)
	position = Vector2(position.x, options_top)


## Uma linha por ação. `device` é "key" ou "pad".
func show_controls(back: Callable, device := "", focus := 0) -> void:
	if device == "":
		device = "pad" if Options.pad else "key"
	var rows := []
	var swap := func() -> void:
		show_controls.call_deferred(back, "pad" if device == "key" else "key", 0)
	rows.append([_choice_text("ctrl_device", Options.t("ctrl_" + device)), swap])
	for i in Controls.ACTIONS.size():
		var action: String = Controls.ACTIONS[i]
		var listen := func() -> void: _listen.call_deferred(action, device, back)
		rows.append(["%s:  %s" % [Options.t("act_" + action), Options.button_name(action, device)], listen])
	var reset := func() -> void:
		Options.reset_bindings(device)
		show_controls.call_deferred(back, device, Controls.ACTIONS.size() + 1)
	rows.append([Options.t("ctrl_reset"), reset])
	rows.append([Options.t("menu_back"), back])
	show_options(rows, focus, true)
	_parent_page = back
	position = Vector2(position.x, 22)


func _listen(action: String, device: String, back: Callable) -> void:
	_listen_action = action
	_listen_device = device
	_listen_back = back
	var button := get_child(Controls.ACTIONS.find(action) + 1) as Button
	button.text = Options.t("ctrl_press_" + device)


func _input(event: InputEvent) -> void:
	if _listen_action == "":
		return
	var cancel: bool = event.is_action_pressed("pause")
	var code := "" if cancel else Controls.code_from(event, _listen_device)
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()  # enquanto escuta, nada mais reage
	if not cancel and code == "":
		return
	var action := _listen_action
	var device := _listen_device
	var back := _listen_back
	_listen_action = ""
	if code != "":
		Options.rebind(device, action, code)
		Sound.play("ui_ok")
	show_controls.call_deferred(back, device, Controls.ACTIONS.find(action) + 1)


static func _volume_text(bus: String, label: String) -> String:
	return "<  %s %d%%  >" % [Options.t(label), Sound.volumes[bus]]


static func _choice_text(label: String, value: String) -> String:
	return "<  %s: %s  >" % [Options.t(label), value]


static func _switch_text(label: String, value: bool) -> String:
	return _choice_text(label, Options.t("on" if value else "off"))


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


## Volta um nível dentro do menu. false: já está no primeiro.
func go_back() -> bool:
	if not _parent_page.is_valid():
		return false
	_parent_page.call()
	return true


func clear() -> void:
	_listen_action = ""
	_parent_page = Callable()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(WIDTH, 13 if compact else 18)
	button.add_theme_font_size_override("font_size", Art.FONT_SIZE)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_paint(button, false)
	button.focus_entered.connect(_paint.bind(button, true))
	button.focus_exited.connect(_paint.bind(button, false))
	button.mouse_entered.connect(button.grab_focus)
	return button


## Selecionado = invertido (fundo branco, texto preto).
func _paint(button: Button, lit: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Art.WHITE if lit else Art.BLACK
	box.border_color = Art.WHITE
	box.set_border_width_all(1)
	# borda mais grossa embaixo e à direita: o botão em relevo do Windows 95
	box.border_width_bottom = 2
	box.border_width_right = 2
	box.anti_aliasing = false
	if compact:
		box.border_width_bottom = 1
		box.border_width_right = 1
		box.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, box)
	var ink := Art.BLACK if lit else Art.WHITE
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)
