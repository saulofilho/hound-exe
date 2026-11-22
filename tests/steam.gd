extends SceneTree
## Critérios da Steam e do Steam Deck que dão para automatizar: idiomas, botões
## na tela, qualquer controle, jogar e sair só com controle, opções, pausa
## automática, fim, texto legível e artes da loja.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/steam.gd

const PATH := "user://test_steam.json"
const ASSETS := {
	"header_capsule_920x430": Vector2i(920, 430), "small_capsule_462x174": Vector2i(462, 174),
	"main_capsule_1232x706": Vector2i(1232, 706), "vertical_capsule_748x896": Vector2i(748, 896),
	"library_capsule_600x900": Vector2i(600, 900), "library_header_920x430": Vector2i(920, 430),
	"library_hero_3840x1240": Vector2i(3840, 1240),
}
const DECK := Vector2i(1280, 800)

var G: Node
var O: Node
var T: GDScript
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	O = root.get_node("Options")
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	print("%-52s %-7s %s" % [what, "ok" if ok else "FALHOU", detail])
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _pad(button: JoyButton, device := 1) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device  # de propósito, o segundo controle
		ev.button_index = button
		ev.pressed = down
		_send(ev)
		await _frames(3)


func _key(key: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = down
		_send(ev)
		await _frames(3)


func _stick(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 1
	ev.axis = axis
	ev.axis_value = value
	_send(ev)


func _focus_text() -> String:
	var node := root.gui_get_focus_owner()
	return node.text if node is Button else ""


func _clean() -> void:
	var base := PATH.get_basename()
	for p in [PATH, PATH + ".bak", PATH + ".tmp", base + ".options.json", base + ".settings.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _run() -> void:
	await process_frame
	T = load("res://scripts/texts.gd")
	_clean()
	_texts()
	_files()
	await _controller()
	await _options()
	await _interruptions()
	await _ending()
	_clean()
	print("STEAM ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)


func _texts() -> void:
	var font := ThemeDB.fallback_font
	var incomplete := []
	var missing := {}
	var wide := []
	for key in T.DATA:
		var pair: Array = T.DATA[key]
		if pair.size() != 2 or pair[0] == "" or pair[1] == "":
			incomplete.append(key)
			continue
		for text in pair:
			for c in text:
				if c.unicode_at(0) >= 32 and not font.has_char(c.unicode_at(0)):
					missing[c] = key
			var limit := 376.0
			if key.begins_with("menu_") or key.begins_with("ctrl_") or key.begins_with("act_"):
				limit = 212.0
			elif key.begins_with("icon_"):
				limit = 51.0
			elif key in ["pause_saved", "pause_no_save", "ending_text"]:
				limit = 254.0
			elif key == "credits_text":
				limit = 274.0
			elif key.begins_with("title_keys"):
				limit = 320.0
			for line in text.split("\n"):
				if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > limit:
					wide.append([key, line])
	_check("todo texto em portugues e ingles", incomplete.is_empty(), str(incomplete))
	_check("fonte cobre os dois idiomas", missing.is_empty(), str(missing))
	_check("os dois idiomas cabem na tela", wide.is_empty(), str(wide))

	var keys := RegEx.create_from_string("A/D|W/S|WASD|Shift|Espaço|Space|Esc\\b|Tab\\b|Enter|mouse|clique|click|\\bK\\b|\\bJ\\b|\\bR\\b")
	var leaks := []
	var unpaired := []
	for key in T.DATA:
		for text in T.DATA[key]:
			if keys.search(text) == null:
				continue
			if key.ends_with("_pad"):
				leaks.append(key)
			elif not T.DATA.has(key + "_pad"):
				unpaired.append(key)
	_check("texto de controle nao cita tecla", leaks.is_empty(), str(leaks))
	_check("texto com tecla tem versao de controle", unpaired.is_empty(), str(unpaired))

	var unknown := []
	var used := RegEx.create_from_string("Options\\.t\\(\"([a-z_]+)\"\\)")
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			for m in used.search_all(FileAccess.get_file_as_string("res://scripts/" + file)):
				if not T.DATA.has(m.get_string(1)):
					unknown.append(m.get_string(1))
	for room in load("res://scripts/rooms.gd").DATA:
		if not T.DATA.has("room_" + room):
			unknown.append("room_" + room)
	_check("toda chave usada existe", unknown.is_empty(), str(unknown))

	var scale := mini(DECK.x / 384, DECK.y / 216)
	_check("Deck: menor letra >= 12 px (minimo 9)", 5 * scale >= 12, "%d px em escala %dx" % [5 * scale, scale])


func _files() -> void:
	for name in ASSETS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://steam/assets/%s.png" % name))
		_check("arte: " + name, img != null and img.get_size() == ASSETS[name])
	var logo := Image.load_from_file(ProjectSettings.globalize_path("res://steam/assets/library_logo_1280.png"))
	_check("logo: 1280 de largura e fundo transparente", logo.get_width() == 1280 and logo.get_pixel(0, 0).a == 0.0)

	var shots := 0
	var dir := "res://steam/screenshots"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".png"):
				var img := Image.load_from_file(ProjectSettings.globalize_path(dir + "/" + file))
				if img.get_size() == Vector2i(1920, 1080):
					shots += 1
	_check("pelo menos 5 capturas 1920x1080", shots >= 5, str(shots))


func _controller() -> void:
	G.save_path = PATH
	change_scene_to_file("res://title.tscn")
	await _frames(6)
	await _pad(JOY_BUTTON_A)  # novo jogo
	await _frames(8)
	var s = current_scene
	_check("segundo controle comeca o jogo", s.name == "Main")
	_check("controle em uso: dica mostra botoes", O.pad and "LT" in s.hud.hint and not "Shift" in s.hud.hint, s.hud.hint)
	var x0: float = s.player.global_position.x
	_stick(JOY_AXIS_LEFT_X, 1.0)
	await _frames(20)
	_stick(JOY_AXIS_LEFT_X, 0.0)
	_check("segundo controle anda", s.player.global_position.x > x0 + 10.0)
	_stick(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(8)
	_check("segundo controle fareja", s.sniffing)
	_stick(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(5)
	await _pad(JOY_BUTTON_BACK)
	_check("View abre o Explorer", s._map_view.visible)
	await _pad(JOY_BUTTON_BACK)

	var bindings := []
	for action in ["left", "right", "up", "down", "jump", "shoot", "dash", "sniff", "map", "pause", "aim_left", "aim_right", "aim_up", "aim_down"]:
		var ok := false
		for ev in InputMap.action_get_events(action):
			if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) and ev.device == -1:
				ok = true
		if not ok:
			bindings.append(action)
	_check("toda acao num botao, em qualquer controle", bindings.is_empty(), str(bindings))

	s.player.hp = 1
	s.player._iframes = 0.0
	s.player.take_damage(1, s.player.global_position + Vector2(8, 0))
	await _frames(5)
	_check("tela azul mostra botao, nao tecla", "Menu" in s.banner.text, s.banner.text.get_slice("\n", 3))
	await _pad(JOY_BUTTON_START)
	await _frames(8)
	_check("Menu tira da tela azul", current_scene.player.hp == current_scene.player.MAX_HP)
	await _key(KEY_J)
	_check("tecla volta as dicas de teclado", not O.pad and "Shift" in current_scene.hud.hint)
	var move := InputEventMouseMotion.new()
	await _pad(JOY_BUTTON_X)
	_send(move)
	await _frames(3)
	_check("mexer o mouse nao troca as dicas (Deck)", O.pad)


func _options() -> void:
	await _pad(JOY_BUTTON_START)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("controle chega nas opcoes", "MÚSICA" in _focus_text(), _focus_text())
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	await _frames(3)
	_check("idioma muda na hora, foco na linha", O.language == "en" and "LANGUAGE" in _focus_text(), _focus_text())
	_check("HUD acompanha o idioma", "jump" in current_scene.hud.hint)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("tela cheia liga e desliga", not O.fullscreen and "OFF" in _focus_text())
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("tremor de tela desliga", not O.shake)
	current_scene.pause_menu.close()
	await _frames(4)
	current_scene.add_shake(8.0)
	await _frames(1)
	_check("sem tremor a camera nao balanca", current_scene.camera.offset == Vector2.ZERO)

	change_scene_to_file("res://title.tscn")
	await _frames(8)
	_check("opcoes sobrevivem a reabrir", O.language == "en" and not O.fullscreen and not O.shake)
	_check("titulo em ingles", _focus_text() == "CONTINUE", _focus_text())
	var f := FileAccess.open(PATH.get_basename() + ".options.json", FileAccess.WRITE)
	f.store_string('{"language":"xx","fullscreen":"sim","shake":7}')
	f.close()
	O.load_options()
	_check("opcoes ruins usam o padrao", O.language == "pt" and O.fullscreen and O.shake)
	current_scene.show_main()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	for i in 6:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("controle chega nos creditos", current_scene.page == 3)
	await _pad(JOY_BUTTON_B)
	await _pad(JOY_BUTTON_B)
	_check("B volta ate o titulo", current_scene.page == 0)


func _interruptions() -> void:
	G.new_game()
	G.enter("c_drive")
	await _frames(8)
	O.interrupted.emit()
	await _frames(2)
	_check("perder foco ou controle pausa", paused)
	current_scene.pause_menu.close()
	await _frames(4)


func _ending() -> void:
	G.new_game()
	G.abilities.dash = true
	G.boss_return = {"room": "trash", "pos": Vector2(720, 168)}
	G.enter("ghost")
	await _frames(8)
	O.show_ending = true
	current_scene.boss.hit(999, Vector2.RIGHT)
	await _frames(5)
	current_scene.player.global_position = current_scene.exit_pos
	await _frames(12)
	var menu = current_scene.pause_menu
	_check("sair do chefe mostra o fim", paused and menu.page == 2)
	await _pad(JOY_BUTTON_A)
	await _frames(4)
	_check("da para continuar explorando", not paused and G.room == "trash")
	G.respawn()
	await _frames(8)
	_check("o fim aparece uma vez so", not paused)
	O.show_ending = false
