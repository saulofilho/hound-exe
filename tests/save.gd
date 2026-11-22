extends SceneTree
## Salvamento, título e pausa, com processos de verdade: um joga e é morto à
## força, outro reabre e continua, um terceiro confere o fim da região.
## Só usa user://test_*; nunca o save do jogador.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/save.gd

const PATH := "user://test_save.json"
const MARK := "user://test_ready"

var G: Node
var Saves: GDScript
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	_run()


func _check(what: String, ok: bool) -> void:
	print("%-54s %s" % [what, "ok" if ok else "FALHOU"])
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _key(key: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = down
		_send(ev)
		await _frames(3)


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


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _open_title() -> void:
	G.save_path = PATH
	change_scene_to_file("res://title.tscn")
	await _frames(6)


func _run() -> void:
	await physics_frame
	Saves = load("res://scripts/save_file.gd")
	var args := OS.get_cmdline_user_args()
	match args[0] if not args.is_empty() else "":
		"play": await _child_play()
		"resume": await _child_resume()
		"finish": await _child_finish()
		_: await _parent()


# ---------------------------------------------------------------- processos

func _child_args(step: String) -> PackedStringArray:
	return PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "-s", "tests/save.gd", "--", step])


func _child(step: String) -> void:
	var out := []
	var code := OS.execute(OS.get_executable_path(), _child_args(step), out, true)
	var text: String = out[0]
	for line in text.split("\n"):
		if line.ends_with(" ok") or "FALHOU" in line or "ERROR" in line:
			print(line)
	_check("processo '%s' termina limpo" % step, code == 0 and not "ERROR" in text and not "FALHOU" in text)


func _clean() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp", MARK]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _parent() -> void:
	_clean()
	_check("disco desligado por padrao", G.save_path == "")
	G.new_game()
	G.save_game()
	_check("sem caminho, nao grava", not Saves.exists(PATH))

	var pid := OS.create_process(OS.get_executable_path(), _child_args("play"))
	var deadline := Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(MARK) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(100)
	_check("primeiro processo jogou e salvou", FileAccess.file_exists(MARK))
	OS.kill(pid)  # sem aviso, como uma queda de energia
	OS.delay_msec(500)
	var saved: Dictionary = Saves.read(PATH)
	_check("morto a forca: chip e ponto no disco", saved.get("dash") == true and saved.get("restore") == "c_drive")

	_child("resume")
	_child("finish")

	# arquivos estragados
	_clean()
	var good := {"restore": "trash", "dash": true, "visited": ["trash"], "taken": []}
	Saves.write(PATH, {"restore": "c_drive", "dash": false, "visited": ["c_drive"], "taken": []})
	Saves.write(PATH, good)
	var full := FileAccess.get_file_as_string(PATH)
	_put(PATH, full.substr(0, full.length() / 2))
	_check("principal cortado: usa a copia", Saves.read(PATH).get("restore") == "c_drive")
	Saves.write(PATH, good)
	_check("arquivo cortado nao vira copia", Saves._read_one(PATH + ".bak").get("restore") == "c_drive")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_check("sem principal: usa a copia", Saves.read(PATH).get("restore") == "c_drive")

	_clean()
	var bad := {
		"vazio": "",
		"lixo": "{{{",
		"lista": "[]",
		"nulo": "null",
		"versao texto": '{"version":"1","restore":"","dash":true,"visited":[],"taken":[]}',
		"versao futura": '{"version":2,"restore":"","dash":true,"visited":[],"taken":[]}',
		"sala inexistente": '{"version":1,"restore":"nada","dash":true,"visited":[],"taken":[]}',
		"sala sem ponto": '{"version":1,"restore":"docs","dash":true,"visited":[],"taken":[]}',
		"dash texto": '{"version":1,"restore":"","dash":"sim","visited":[],"taken":[]}',
		"visita invalida": '{"version":1,"restore":"","dash":true,"visited":["x"],"taken":[]}',
		"item numero": '{"version":1,"restore":"","dash":true,"visited":[],"taken":[7]}',
		"sem campos": '{"version":1}',
	}
	for label in bad:
		_put(PATH, bad[label])
		_check("recusa save: " + label, Saves.read(PATH).is_empty())
	await _open_title()
	_check("save ruim: titulo avisa, sem CONTINUAR", _focused() == "NOVO JOGO" and "lido" in current_scene.message.text)
	await _key(KEY_ENTER)
	_check("save ruim: pede confirmacao", _focused() == "CANCELAR")

	G.save_path = "user://pasta_que_nao_existe/test.json"
	G.new_game()
	G.enter("c_drive")
	await _frames(8)
	_check("falha de gravacao avisa na tela", "SALVAR" in current_scene.toast.text)

	_clean()
	print("SAVE ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _child_play() -> void:
	await _open_title()
	_check("sem save: foco em NOVO JOGO", _focused() == "NOVO JOGO")
	await _key(KEY_ENTER)
	await _frames(8)
	await _hold("right", 25)
	G.enter("downloads", Vector2(18 * 16 + 8, 168))
	await _frames(6)
	await _hold("right", 40)
	if failures == 0 and G.abilities.dash:
		_put(MARK, "ok")
	while true:
		await physics_frame  # espera ser morto


func _child_resume() -> void:
	await _open_title()
	_check("com save: foco em CONTINUAR", _focused() == "CONTINUAR")
	await _pad(JOY_BUTTON_A)
	await _frames(8)
	var s = current_scene
	_check("continua em C: no ponto, vida cheia", G.room == "c_drive" and s.player.global_position.distance_to(s.restore_pos) < 5.0 and s.player.hp == 5)
	_check("dash e salas visitadas voltam", G.abilities.dash and G.visited.has("downloads"))
	G.enter("downloads", Vector2(250, 168))
	await _frames(8)
	s = current_scene
	_check("chip pego nao reaparece", s.chips.is_empty())

	# pausa pelo teclado
	var bug = get_first_node_in_group("enemy")
	await _key(KEY_ESCAPE)
	var bug_at: Vector2 = bug.global_position
	var dog_at: Vector2 = s.player.global_position
	await _hold("right", 30)
	_check("Esc pausa e congela tudo", paused and bug.global_position == bug_at and s.player.global_position == dog_at)
	_check("foco inicial em CONTINUAR", _focused() == "CONTINUAR")
	await _key(KEY_S)
	_check("S desce no menu", _focused() == "VOLTAR AO PONTO DE RESTAURAÇÃO")
	await _key(KEY_UP)
	await _key(KEY_UP)
	_check("foco da a volta", _focused() == "SAIR DO JOGO")
	await _key(KEY_ESCAPE)
	await _frames(3)
	_check("Esc fecha e solta o foco", not paused and _focused() == "")
	await _key(KEY_SPACE)
	_check("Espaco depois da pausa nao aciona SAIR", current_scene == s and not paused)

	await _frames(45)
	await _pad(JOY_BUTTON_START)
	_check("Start pausa", paused)
	await _pad(JOY_BUTTON_B)
	await _frames(3)
	_check("B fecha sem dar dash", not paused and s.player._dash_t <= 0.0 and s.player._dash_cd == 0.0)
	await _pad(JOY_BUTTON_START)
	await _pad(JOY_BUTTON_A)
	await _frames(3)
	_check("A continua sem pular", not paused and s.player.velocity.y >= 0.0)

	await _key(KEY_ESCAPE)
	await _key(KEY_S)
	await _key(KEY_ENTER)
	await _frames(8)
	_check("pausa: volta ao ponto", G.room == "c_drive" and not paused)

	G.enter("trash", Vector2(30, 168))
	await _frames(8)
	s = current_scene
	await _hold("right", 30)
	_check("ponto da Lixeira salvo", Saves.read(PATH).get("restore") == "trash")
	s.player._iframes = 0.0
	s.player.hp = 1
	s.player.take_damage(1, s.player.global_position + Vector2(10, 0))
	await _frames(8)
	await _pad(JOY_BUTTON_START)
	await _frames(8)
	_check("Start na tela azul volta ao ponto", not paused and G.room == "trash" and current_scene.player.hp == 5)

	G.enter_arena("trash", Vector2(720, 168))
	await _frames(8)
	s = current_scene
	await _key(KEY_ESCAPE)
	var left: float = s.time_left
	await _frames(40)
	_check("pausa congela o cronometro", s.time_left == left)
	await _key(KEY_ESCAPE)
	await _frames(3)
	s.time_left = 0.02
	await _frames(5)
	_check("vitoria da sala salva na hora", "arena_desktop" in Saves.read(PATH).taken)
	await _key(KEY_ESCAPE)
	await _frames(160)
	_check("pausado na vitoria: nao troca de cena", paused and current_scene == s)
	await _key(KEY_ESCAPE)
	await _frames(140)
	_check("ao despausar, volta a Lixeira", G.room == "trash" and current_scene.get("player") != null)

	G.enter("ghost")
	await _frames(8)
	current_scene.boss.hit(999, Vector2.RIGHT)
	await _frames(8)
	_check("vitoria do chefe salva na hora", "boss_desktop" in Saves.read(PATH).taken)

	await _key(KEY_ESCAPE)
	await _key(KEY_S)
	await _key(KEY_S)
	await _key(KEY_ENTER)
	await _frames(10)
	_check("pausa: tela de titulo", current_scene.name == "Title" and not paused and _focused() == "CONTINUAR")
	quit(0 if failures == 0 else 1)


func _child_finish() -> void:
	await _open_title()
	_check("titulo mostra regiao limpa", "limpa" in current_scene.message.text)
	var before := FileAccess.get_file_as_string(PATH)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check("NOVO JOGO confirma, foco em CANCELAR", _focused() == "CANCELAR")
	await _key(KEY_ENTER)
	_check("Enter duplo nao apaga nada", _focused() == "CONTINUAR" and FileAccess.get_file_as_string(PATH) == before)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _pad(JOY_BUTTON_B)
	_check("B cancela a confirmacao", _focused() == "CONTINUAR")
	await _key(KEY_ENTER)
	await _frames(8)
	var s = current_scene
	_check("reabre na Lixeira", G.room == "trash")
	s.player.global_position = s.door_pos
	await _frames(8)
	_check("regiao continua limpa", G.room == "trash" and G.taken.has("boss_desktop"))

	await _open_title()
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(8)
	var fresh: Dictionary = Saves.read(PATH)
	_check("confirmar recomeca do zero", G.room == "c_drive" and not fresh.dash and fresh.taken.is_empty())
	_check("jogo anterior fica na copia", "boss_desktop" in Saves._read_one(PATH + ".bak").taken)

	await _open_title()
	await _key(KEY_UP)
	_check("SAIR selecionado", _focused() == "SAIR")
	if failures > 0:
		quit(1)
		return
	await _key(KEY_ENTER)
	await _frames(30)
	print("SAIR nao fechou o jogo FALHOU")
	quit(1)
