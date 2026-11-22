class_name Controls
## Teclas e botões remapeáveis: padrões, aplicação no InputMap e nomes na tela.
##
## Um código é uma string: "k74" tecla física, "m1" botão do mouse, "b0" botão
## do controle, "a4+" eixo do controle e o sentido. Só dados, dá para salvar.

const ACTIONS := ["left", "right", "up", "down", "jump", "shoot", "dash", "sniff", "map"]
const DEADZONE := 0.4
const CAPTURE_AXIS := 0.6

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
}


static func defaults() -> Dictionary:
	return {
		"key": {
			"left": [_k(KEY_A), _k(KEY_LEFT)], "right": [_k(KEY_D), _k(KEY_RIGHT)],
			"up": [_k(KEY_W), _k(KEY_UP)], "down": [_k(KEY_S), _k(KEY_DOWN)],
			"jump": [_k(KEY_SPACE), _k(KEY_Z)], "shoot": [_k(KEY_J), _k(KEY_X), "m%d" % MOUSE_BUTTON_LEFT],
			"dash": [_k(KEY_K), _k(KEY_C)], "sniff": [_k(KEY_SHIFT), _k(KEY_L)], "map": [_k(KEY_TAB)],
		},
		"pad": {
			"left": [_a(JOY_AXIS_LEFT_X, -1), _b(JOY_BUTTON_DPAD_LEFT)],
			"right": [_a(JOY_AXIS_LEFT_X, 1), _b(JOY_BUTTON_DPAD_RIGHT)],
			"up": [_a(JOY_AXIS_LEFT_Y, -1), _b(JOY_BUTTON_DPAD_UP)],
			"down": [_a(JOY_AXIS_LEFT_Y, 1), _b(JOY_BUTTON_DPAD_DOWN)],
			"jump": [_b(JOY_BUTTON_A)],
			"shoot": [_b(JOY_BUTTON_X), _a(JOY_AXIS_TRIGGER_RIGHT, 1)],
			"dash": [_b(JOY_BUTTON_B)],
			"sniff": [_a(JOY_AXIS_TRIGGER_LEFT, 1)],
			"map": [_b(JOY_BUTTON_BACK)],
		},
	}


static func _k(key: Key) -> String:
	return "k%d" % key


static func _b(button: JoyButton) -> String:
	return "b%d" % button


static func _a(axis: JoyAxis, side: int) -> String:
	return "a%d%s" % [axis, "+" if side > 0 else "-"]


# ---- InputMap

static func apply(bindings: Dictionary) -> void:
	for action in ACTIONS:
		_reset(action)
		for code in bindings.key[action] + bindings.pad[action]:
			InputMap.action_add_event(action, event_for(code))
	# fixos: sempre dá para pausar, reiniciar e mirar
	_reset("pause")
	InputMap.action_add_event("pause", event_for(_k(KEY_ESCAPE)))
	InputMap.action_add_event("pause", event_for(_b(JOY_BUTTON_START)))
	_reset("restart")
	InputMap.action_add_event("restart", event_for(_k(KEY_R)))
	for item in [["aim_left", JOY_AXIS_RIGHT_X, -1], ["aim_right", JOY_AXIS_RIGHT_X, 1], ["aim_up", JOY_AXIS_RIGHT_Y, -1], ["aim_down", JOY_AXIS_RIGHT_Y, 1]]:
		_reset(item[0])
		InputMap.action_add_event(item[0], event_for(_a(item[1], item[2])))


static func _reset(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, DEADZONE)


static func event_for(code: String) -> InputEvent:
	var body := code.substr(1)
	match code[0]:
		"k":
			var key := InputEventKey.new()
			key.physical_keycode = int(body) as Key
			return key
		"m":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(body) as MouseButton
			return mouse
		"b":
			var button := InputEventJoypadButton.new()
			button.device = -1  # qualquer controle, não só o primeiro
			button.button_index = int(body) as JoyButton
			return button
		_:
			var axis := InputEventJoypadMotion.new()
			axis.device = -1
			axis.axis = int(body.left(-1)) as JoyAxis
			axis.axis_value = 1.0 if body.ends_with("+") else -1.0
			return axis


# ---- capturar e trocar

## O código de um evento, ou "" se não serve para `device` ("key" ou "pad").
static func code_from(event: InputEvent, device: String) -> String:
	if device == "key":
		if event is InputEventKey and event.pressed and not event.echo:
			var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if key in [KEY_ESCAPE, KEY_R, KEY_F11, KEY_META]:
				return ""  # pausa, reinício, tela cheia e sistema
			return _k(key)
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			return "m%d" % event.button_index
	else:
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index in [JOY_BUTTON_START, JOY_BUTTON_GUIDE]:
				return ""
			return _b(event.button_index)
		if event is InputEventJoypadMotion and absf(event.axis_value) >= CAPTURE_AXIS:
			if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
				return ""  # o analógico direito é a mira
			return _a(event.axis, 1 if event.axis_value > 0.0 else -1)
	return ""


## Põe `code` em `action`. Quem o usava herda o que sobrou, para nada ficar sem botão.
static func assign(bindings: Dictionary, device: String, action: String, code: String) -> void:
	var table: Dictionary = bindings[device]
	var old: Array = table[action].duplicate()
	for other in ACTIONS:
		if other == action or not code in table[other]:
			continue
		table[other].erase(code)
		if table[other].is_empty():
			table[other].append(old[0])
	table[action] = [code]


## Um arquivo de opções estragado não pode deixar ação sem botão.
static func validated(saved: Variant) -> Dictionary:
	var out := defaults()
	if not saved is Dictionary:
		return out
	var shape := {"key": RegEx.create_from_string("^(k[1-9][0-9]{0,8}|m[1-3])$"), "pad": RegEx.create_from_string("^(b([0-9]|1[0-9]|20)|a[0-5][+-])$")}
	for device in shape:
		var table: Variant = saved.get(device)
		if not table is Dictionary:
			continue
		var fresh := {}
		var used := {}
		for action in ACTIONS:
			var list: Variant = table.get(action)
			if not list is Array or list.is_empty() or list.size() > 3:
				break
			var good := true
			for code in list:
				if not code is String or used.has(code) or shape[device].search(code) == null:
					good = false
					break
				used[code] = true
			if not good:
				break
			fresh[action] = list.duplicate()
		if fresh.size() == ACTIONS.size():
			out[device] = fresh
	return out


# ---- nomes

static func label(code: String, language: String) -> String:
	var pt := language == "pt"
	var body := code.substr(1)
	match code[0]:
		"k":
			var physical := int(body) as Key
			var key := physical
			if DisplayServer.get_name() != "headless":
				# mostra a letra do teclado da pessoa (AZERTY, por exemplo)
				var local := DisplayServer.keyboard_get_keycode_from_physical(physical)
				if local != 0:
					key = local
			match key:
				KEY_SPACE: return "Espaço" if pt else "Space"
				KEY_LEFT: return "Esquerda" if pt else "Left"
				KEY_RIGHT: return "Direita" if pt else "Right"
				KEY_UP: return "Cima" if pt else "Up"
				KEY_DOWN: return "Baixo" if pt else "Down"
			var word := OS.get_keycode_string(key)
			for c in word:
				if c.unicode_at(0) > 126:
					word = OS.get_keycode_string(physical)  # a fonte não tem esse alfabeto
					break
			return word if word.length() <= 12 and word != "" else "#%d" % key
		"m":
			var names := ["Clique", "Clique dir.", "Clique meio"] if pt else ["Click", "R-click", "M-click"]
			return names[clampi(int(body) - 1, 0, 2)]
		"b":
			var button := int(body)
			if PAD_NAMES.has(button):
				return PAD_NAMES[button]
			match button:
				JOY_BUTTON_DPAD_UP: return "D-cima" if pt else "D-up"
				JOY_BUTTON_DPAD_DOWN: return "D-baixo" if pt else "D-down"
				JOY_BUTTON_DPAD_LEFT: return "D-esq." if pt else "D-left"
				JOY_BUTTON_DPAD_RIGHT: return "D-dir." if pt else "D-right"
			return "B%d" % button
		_:
			var axis := int(body.left(-1))
			var plus := body.ends_with("+")
			if axis == JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			if axis == JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			if axis == JOY_AXIS_LEFT_X:
				if pt:
					return "L-dir." if plus else "L-esq."
				return "L-right" if plus else "L-left"
			if axis == JOY_AXIS_LEFT_Y:
				if pt:
					return "L-baixo" if plus else "L-cima"
				return "L-down" if plus else "L-up"
			return "E%d" % axis
