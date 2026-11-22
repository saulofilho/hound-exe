extends SceneTree
## As regras da região (blocos, setor ruim, pista, quarentena, atalho, porta,
## Spam, backups) e o remapeamento, até pelo menu com teclado e controle.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/region.gd

const PATH := "user://test_region.json"
const DONE := 3
const WARN := 1
const DIVE := 2

var G: Node
var O: Node
var C: GDScript
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	O = root.get_node("Options")
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	print("%-58s %-7s %s" % [what, "ok" if ok else "FALHOU", detail])
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	await _frames(n)
	Input.action_release(action)
	await _frames(3)


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _key(key: Key, hold := 3) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = down
		_send(ev)
		await _frames(hold if down else 3)


func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		_send(ev)
		await _frames(3)


func _focused() -> String:
	var node := root.gui_get_focus_owner()
	return node.text if node is Button else ""


func _room(id: String, pos := Vector2.ZERO) -> Node:
	paused = false
	G.enter(id, pos)
	await _frames(8)
	return current_scene


func _clean() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp", PATH.get_basename() + ".options.json", PATH.get_basename() + ".settings.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _run() -> void:
	await physics_frame
	C = load("res://scripts/controls.gd")
	_clean()
	await _blocks()
	await _hazard()
	await _quarantine()
	await _clue_and_door()
	await _spam()
	await _backups()
	await _exits()
	_binding_rules()
	await _binding_menu()
	_clean()
	print("REGION ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)


func _blocks() -> void:
	G.new_game()
	var s = await _room("c_drive", Vector2(328, 168))
	var block = null
	for b in s.blocks:
		if b.secret and (block == null or b.global_position.y > block.global_position.y):
			block = b
	_check("oculta nao existe sem farejar", not block.active and block.collision_layer == 0)
	await _hold("sniff", 12)
	_check("farejada de perto, materializa", block.active and block.collision_layer == 1)
	await _frames(60 * 7 + 20)
	_check("some sozinha depois de 7 s", not block.active)
	block.reveal()
	s.player.global_position = block.global_position + Vector2(0, -2)
	s.player.set_physics_process(false)
	await _frames(4)
	_check("nunca materializa por cima do cao", not block.active)

	s = await _room("temp", Vector2(40, 472))
	var temp = null
	for b in s.blocks:
		if not b.secret:
			temp = b
	var on := 0
	var off := 0
	for i in 210:
		await _frames(1)
		on += int(temp.active)
		off += int(not temp.active)
	_check("temporaria vai e volta", on > 100 and off > 40, "%d/%d" % [on, off])


func _hazard() -> void:
	G.new_game()
	var s = await _room("temp", Vector2(80, 472))  # longe do R, que curaria
	var firm: Vector2 = s.safe_pos
	s.player._iframes = 9.0
	s.player.global_position = Vector2(200, 488)
	await _frames(3)
	_check("setor ruim machuca, mesmo invulneravel", s.player.hp == 4, str(s.player.hp))
	_check("e devolve ao chao firme", s.player.global_position.distance_to(firm) < 24.0, str(s.player.global_position))
	s.player.hp = 1
	s.player.global_position = Vector2(200, 488)
	await _frames(5)
	_check("no ultimo ponto de vida, tela azul", s.banner.visible)


func _kill_waves(s: Node) -> void:
	for i in 60 * 12:
		await _frames(1)
		if not s.quarantine.locked():
			break
		s.player._iframes = 9.0
		for e in get_nodes_in_group("enemy"):
			e.hit(99, Vector2.RIGHT)


func _quarantine() -> void:
	G.new_game()
	var s = await _room("docs", Vector2(136, 168))
	var short = s.folders.filter(func(f): return f.to == "gallery")[0]
	_check("atalho comeca fechado", not s.folder_open(short))
	G.visited["gallery"] = true
	_check("so visitar nao abre o atalho", not s.folder_open(short))
	s.player.global_position = short.at
	await _frames(20)
	await _hold("down", 3)
	await _frames(8)
	_check("pasta fechada nao leva a lugar nenhum", G.room == "docs")

	s = await _room("gallery", Vector2(200, 168))
	_check("fora da zona, sem tranca", not s.quarantine.locked())
	s.player.global_position = Vector2(330, 168)
	await _frames(4)
	_check("dentro da zona, tranca", s.quarantine.locked() and s.is_solid(Vector2i(14, 10)) and s.is_solid(Vector2i(34, 10)))
	Input.action_press("left")
	s.player._iframes = 99.0
	await _frames(90)
	Input.action_release("left")
	_check("a grade segura o cao", s.player.global_position.x > 238.0, str(s.player.global_position))
	await _kill_waves(s)
	_check("limpas as ondas, abre", not s.quarantine.locked() and not s.is_solid(Vector2i(34, 10)))
	s = await _room("gallery", Vector2(330, 168))
	await _frames(4)
	_check("vencida, nao tranca de novo", not s.quarantine.locked())
	s = await _room("docs", Vector2(136, 168))
	short = s.folders.filter(func(f): return f.to == "gallery")[0]
	_check("quarentena vencida abre o atalho", s.folder_open(short))
	s.player.global_position = short.at
	await _frames(20)
	await _hold("down", 3)
	await _frames(8)
	_check("pasta leva do outro lado", G.room == "gallery" and current_scene.player.global_position.x > 700.0)


func _clue_and_door() -> void:
	G.new_game()
	var s = await _room("gallery", Vector2(680, 168))
	var at: Vector2 = s.clue_pos
	s.player.set_physics_process(false)
	s.player.global_position = at
	s.set_sniffing(true)
	await _frames(3)
	_check("pista espera a quarentena", not s._clue_dug() and G.clue_count() == 0)
	s.set_sniffing(false)
	G.taken["quarantine:gallery"] = true
	s = await _room("gallery", Vector2(680, 168))
	s.player.set_physics_process(false)
	s.player.global_position = at
	await _frames(4)
	_check("sem farejar nao se pega a pista", G.clue_count() == 0)
	s.set_sniffing(true)
	await _frames(4)
	s.set_sniffing(false)
	_check("farejada, desenterra e pega", G.clue_count() == 1)

	s = await _room("trash", Vector2(680, 168))
	s.player.global_position = s.door_pos
	await _frames(6)
	_check("uma pista nao abre a porta", current_scene == s and "3" in s.toast.text, s.toast.text)
	G.taken["arena_desktop"] = true
	_check("save de antes das pistas continua passando", s.door_unlocked())


func _spam() -> void:
	G.new_game()
	var s = await _room("docs", Vector2(120, 168))
	var bug = load("res://scripts/spam.gd").new()
	bug.position = Vector2(120, 110)
	s.add_child(bug)
	for e in get_nodes_in_group("enemy"):
		if e != bug:
			e.queue_free()
	s.player.global_position = Vector2(140, 168)
	var seen := []
	for i in 260:
		await _frames(1)
		s.player._iframes = 1.0
		if seen.is_empty() or seen[-1] != bug.state:
			seen.append(bug.state)
	var warn: int = seen.find(WARN)
	_check("Spam avisa antes de mergulhar", warn >= 0 and seen.find(DIVE) == warn + 1, str(seen))


func _backups() -> void:
	G.new_game()
	var s = await _room("c_drive", Vector2(60, 168))
	s.player.global_position = s.backup_pos
	await _frames(3)
	_check("backup alonga o faro", G.secret_count() == 1 and G.max_sniff() > 100.0)
	G.save_path = PATH
	G.save_game()
	G.new_game()
	G.load_game()
	_check("backup sobrevive ao save", G.secret_count() == 1 and G.sniff == G.max_sniff())
	G.save_path = ""
	s = await _room("c_drive", Vector2(60, 168))
	_check("backup pego nao volta", s.backup_pos == Vector2.ZERO)


func _exits() -> void:
	G.new_game()
	G.abilities.dash = true
	for case in [["downloads", Vector2(380, 168), "right", "temp"], ["images", Vector2(380, 56), "right", "gallery"], ["drivers", Vector2(4, 472), "left", "system32"]]:
		await _room(case[0], case[1])
		Input.action_press(case[2])
		for i in 40:
			await _frames(1)
			if G.room == case[3]:
				break
		Input.action_release(case[2])
		await _frames(10)
		var now = current_scene
		var at: Vector2 = now.player.global_position
		var ok: bool = G.room == case[3] and at.y > 0.0 and at.y < now.MAP.size() * 16 and not now.is_solid_at(at)
		_check("saida entre alturas: %s > %s" % [case[0], case[3]], ok, str(at))


# ---------------------------------------------------------------- controles

func _binding_rules() -> void:
	var b: Dictionary = C.defaults()
	var shoot: String = b.key.shoot[0]
	C.assign(b, "key", "jump", shoot)
	_check("tecla tomada sai de quem a tinha", b.key.jump == [shoot] and not shoot in b.key.shoot)
	b = C.defaults()
	C.assign(b, "pad", "jump", b.pad.dash[0])
	_check("botao unico: os dois trocam", b.pad.jump == ["b1"] and b.pad.dash == ["b0"])
	for code in ["b15", "a5+", "b3", "a0-"]:
		C.assign(b, "pad", "map", code)
	var empty := false
	for action in C.ACTIONS:
		empty = empty or b.pad[action].is_empty()
	_check("nenhuma acao fica sem botao", not empty)
	var fresh: Dictionary = C.defaults()
	for bad in [null, 7, {"key": {}}, {"key": {"left": ["rm"]}}, {"pad": "x"}]:
		if C.validated(bad) != fresh:
			_check("opcoes estragadas usam o padrao", false, str(bad))
	var twice: Dictionary = C.defaults()
	twice.key.jump = twice.key.shoot.duplicate()
	_check("tecla repetida no arquivo usa o padrao", C.validated(twice) == fresh)
	var good: Dictionary = C.defaults()
	C.assign(good, "key", "jump", "k%d" % KEY_P)
	_check("opcoes boas sao mantidas", C.validated(good) == good)
	for key in [KEY_ESCAPE, KEY_R, KEY_F11]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = true
		_check("reservada: " + OS.get_keycode_string(key), C.code_from(ev, "key") == "")


func _binding_menu() -> void:
	G.new_game()
	G.save_path = PATH
	var s = await _room("c_drive")
	await _key(KEY_ESCAPE)
	await _key(KEY_S)
	await _key(KEY_S)
	await _key(KEY_ENTER)
	for i in 5:
		await _key(KEY_S)
	await _key(KEY_ENTER)
	_check("opcoes levam aos controles", "TECLADO" in _focused(), _focused())
	for i in 5:
		await _key(KEY_S)
	_check("linha de pular", "Pular" in _focused(), _focused())
	await _key(KEY_ENTER)
	_check("pede a tecla", "aperte" in _focused(), _focused())
	await _key(KEY_P)
	await _frames(3)
	_check("tecla nova aparece na linha", "Pular" in _focused() and "P" in _focused().get_slice(":", 1), _focused())
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	await _frames(3)
	_check("Esc cancela sem fechar a pausa", paused and "Pular" in _focused() and "P" in _focused().get_slice(":", 1), _focused())
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	await _frames(3)
	_check("Enter vira tecla e nao reabre a escuta", "Enter" in _focused() and not "aperte" in _focused(), _focused())
	await _key(KEY_ENTER)
	await _key(KEY_P)
	await _frames(3)

	await _key(KEY_UP)
	_check("setas seguem no menu", "Baixo" in _focused(), _focused())
	await _key(KEY_DOWN)
	await _pad(JOY_BUTTON_B)
	await _frames(3)
	_check("B volta um nivel", paused and "CONTROLES" in _focused(), _focused())
	current_scene.pause_menu.close()
	await _frames(4)
	_check("dica usa a tecla nova", "P pula" in s.hud.hint, s.hud.hint)
	await _frames(20)
	var y: float = s.player.global_position.y
	await _key(KEY_P, 12)
	_check("tecla nova pula", s.player.global_position.y < y - 8.0)
	await _frames(50)
	y = s.player.global_position.y
	await _key(KEY_SPACE, 12)
	_check("tecla antiga nao pula mais", s.player.global_position.y > y - 2.0)

	await _pad(JOY_BUTTON_START)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	for i in 5:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("com controle, abre no gamepad", "GAMEPAD" in _focused(), _focused())
	for i in 5:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_Y)
	await _frames(3)
	_check("gamepad remapeia", "Y" in _focused(), _focused())
	_check("A continua confirmando no menu", InputMap.action_get_events("ui_accept").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A))

	O.bindings = C.defaults()
	O.load_options()
	_check("controles sobrevivem a reabrir", O.bindings.key.jump == ["k%d" % KEY_P] and O.bindings.pad.jump == ["b3"], str(O.bindings.key.jump))

	for i in 5:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	_check("linha de restaurar", "RESTAURAR" in _focused(), _focused())
	await _pad(JOY_BUTTON_A)
	await _frames(3)
	_check("restaura so o gamepad", O.bindings.pad.jump == ["b0"] and O.bindings.key.jump == ["k%d" % KEY_P])

	# os nomes mais compridos ainda cabem
	for pair in [["left", "k%d" % KEY_CAPSLOCK], ["right", "k%d" % KEY_BACKSPACE], ["jump", "k%d" % KEY_KP_SUBTRACT], ["shoot", "k%d" % KEY_PAGEDOWN], ["sniff", "m3"]]:
		C.assign(O.bindings, "key", pair[0], pair[1])
	O.pad = false
	var Hud_: GDScript = s.hud.get_script()
	for language in ["pt", "en"]:
		O.language = language
		var lines: PackedStringArray = Hud_.hint_lines(O.t("hint_side"))
		var wide := false
		for key in ["wall_smells", "clue_smells", "boss_need_sniff", "got_dash"]:
			for line in O.t(key).split("\n"):
				wide = wide or ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > 364.0
		for line in lines:
			wide = wide or ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > 376.0
		_check("nomes compridos cabem (%s)" % language, not wide and lines.size() <= 3, str(lines))
	O.language = "pt"
	paused = false
	G.save_path = ""
	O.load_options()
