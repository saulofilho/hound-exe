extends Node
## Opções do jogador e qual entrada está em uso (autoload "Options").
##
## `live` = jogo de verdade, aberto pelo título com o save real. Só aí o jogo
## mexe na janela, pausa sozinho e mostra o fim: testes e capturas ficam
## determinísticos.

signal changed           # idioma ou tipo de entrada: redesenhar textos
signal interrupted       # perdeu o foco ou o controle: pausar

const DEFAULTS := {"language": "pt", "fullscreen": true, "shake": true}
const STICK_WAKE := 0.5

var language: String = DEFAULTS.language
var fullscreen: bool = DEFAULTS.fullscreen
var shake: bool = DEFAULTS.shake
var pad := false         # o controle foi a última entrada usada
var live := false
var show_ending := false
var bindings := {}       # teclas e botões, ver controls.gd


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bindings = Controls.defaults()
	Controls.apply(bindings)
	Input.joy_connection_changed.connect(_on_pad_connection)


func t(key: String) -> String:
	var text := Texts.lookup(key, language, pad)
	if not "{" in text:
		return text
	# {jump}, {sniff}...: o botão de verdade, depois de remapear
	for action in Controls.ACTIONS:
		var token := "{%s}" % action
		if token in text:
			text = text.replace(token, button_name(action, "pad" if pad else "key"))
	return text


func button_name(action: String, device: String) -> String:
	return Controls.label(bindings[device][action][0], language)


func rebind(device: String, action: String, code: String) -> void:
	Controls.assign(bindings, device, action, code)
	_bindings_changed()


func reset_bindings(device: String) -> void:
	bindings[device] = Controls.defaults()[device]
	_bindings_changed()


func _bindings_changed() -> void:
	Controls.apply(bindings)
	_write()
	changed.emit()


func version() -> String:
	return ProjectSettings.get_setting("application/config/version", "")


# ---- carregar e gravar (ao lado do save, fora da nuvem)

func path() -> String:
	return "" if Game.save_path == "" else Game.save_path.get_basename() + ".options.json"


func load_options() -> void:
	var first_time := not live
	live = Game.save_path == SaveFile.PATH
	language = _system_language() if live else DEFAULTS.language
	fullscreen = DEFAULTS.fullscreen
	shake = DEFAULTS.shake
	bindings = Controls.defaults()
	var file := path()
	if file != "" and FileAccess.file_exists(file):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(file)) == OK and json.data is Dictionary:
			var saved: Dictionary = json.data
			if saved.get("language") is String and saved.language in Texts.LANGUAGES:
				language = saved.language
			if saved.get("fullscreen") is bool:
				fullscreen = saved.fullscreen
			if saved.get("shake") is bool:
				shake = saved.shake
			bindings = Controls.validated(saved.get("bindings"))
	Controls.apply(bindings)
	if live:
		show_ending = true
		_apply_window()
		if first_time:
			# no Steam Deck o controle já vem ligado: a primeira tela já mostra botões
			_set_pad(not Input.get_connected_joypads().is_empty())
	changed.emit()


## `--language=english` ou `--language=brazilian` (opção de início da Steam) vence o sistema.
func _system_language() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--language="):
			return "pt" if arg.get_slice("=", 1) in ["brazilian", "portuguese", "pt"] else "en"
	return "pt" if OS.get_locale_language() == "pt" else "en"


func _write() -> void:
	var file := path()
	if file == "":
		return
	var out := FileAccess.open(file, FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify({"language": language, "fullscreen": fullscreen, "shake": shake, "bindings": bindings}))
		out.close()


# ---- mudanças

func cycle_language() -> void:
	var list := Texts.LANGUAGES
	language = list[(list.find(language) + 1) % list.size()]
	_write()
	changed.emit()


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_write()
	if live:
		_apply_window()
	changed.emit()


func toggle_shake() -> void:
	shake = not shake
	_write()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


# ---- entrada em uso

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			get_viewport().set_input_as_handled()
			toggle_fullscreen()
		_set_pad(false)
	elif event is InputEventMouseButton and event.pressed:
		_set_pad(false)  # só clique: mexer no mouse não troca (entrada mista no Deck)
	elif event is InputEventJoypadButton and event.pressed:
		_set_pad(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_WAKE:
		_set_pad(true)


func _set_pad(on: bool) -> void:
	if on == pad:
		return
	pad = on
	if live:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	changed.emit()


func _on_pad_connection(_device: int, connected: bool) -> void:
	if not connected and pad:
		if Input.get_connected_joypads().is_empty():
			_set_pad(false)
		if live:
			interrupted.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and live:
		interrupted.emit()
