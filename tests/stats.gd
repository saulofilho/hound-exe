extends SceneTree
## A contagem do playtest: relógio, mortes, desistências, marcas, save antigo,
## save estragado e a linha da tela de fim.
## Rodar (tempo real, sem --fixed-fps): godot --headless --path . -s tests/stats.gd

const PATH := "user://test_stats.json"

var G: Node
var O: Node
var Saves: GDScript
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	O = root.get_node("Options")
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	print("%-56s %-7s %s" % [what, "ok" if ok else "FALHOU", detail])
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _clean() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _run() -> void:
	await physics_frame
	Saves = load("res://scripts/save_file.gd")
	_clean()
	G.new_game()
	G.save_path = PATH
	G.enter("c_drive")
	await _frames(10)
	var s := current_scene

	var t: float = G.stats.seconds
	await _wait(1.0)
	_check("conta em tempo real", absf(G.stats.seconds - t - 1.0) < 0.2, str(G.stats.seconds - t))

	t = G.stats.seconds
	s.set_sniffing(true)
	Input.action_press("sniff")
	await _wait(1.0)
	Input.action_release("sniff")
	_check("o faro nao desacelera o relogio", absf(G.stats.seconds - t - 1.0) < 0.2, str(G.stats.seconds - t))
	await _frames(4)

	s.pause_menu.open()
	await _frames(2)
	t = G.stats.seconds
	await _wait(0.6)
	_check("pausa nao conta", G.stats.seconds - t < 0.05)
	s.pause_menu.close()
	await _frames(4)
	s._map_view.open()
	await _frames(2)
	t = G.stats.seconds
	await _wait(0.6)
	_check("olhar o Explorer conta", G.stats.seconds - t > 0.4)
	s._map_view.close()
	await _frames(4)

	s.player._iframes = 0.0
	s.player.hp = 1
	s.player.take_damage(1, s.player.global_position + Vector2(8, 0))
	await _frames(3)
	_check("morte conta, por sala", G.stats.deaths == 1 and G.stats.rooms.c_drive.deaths == 1)
	_check("morte grava na hora", int(Saves.read(PATH).stats.deaths) == 1)
	G.give_up()
	await _frames(8)
	_check("sair da tela azul nao e desistencia", G.stats.restarts == 0)
	G.give_up()
	await _frames(8)
	_check("reiniciar vivo e desistencia", G.stats.restarts == 1)

	G.enter_arena("trash", Vector2(720, 168))
	await _frames(8)
	var h = current_scene.hound
	h._iframes = 0.0
	h.hp = 1
	h.take_damage(1, h.global_position + Vector2(8, 0))
	await _frames(3)
	_check("sala de cima conta separado", G.stats.rooms.has("arena") and G.stats.rooms.arena.deaths == 1)

	G.stats.seconds = 1052.0
	G.taken["boss_desktop"] = true
	G.save_game()
	G.stats.seconds = 1300.0
	G.save_game()
	_check("o tempo do fim nao anda depois", G.stats.finish_time() == 1052, str(G.stats.finish_time()))
	var line: String = current_scene.pause_menu.ending_summary()
	_check("tela de fim mostra o tempo", "17:32" in line and "mortes 2" in line and "0/10" in line, line)
	var widest := 0.0
	for language in ["pt", "en"]:
		O.language = language
		var worst: String = O.t("ending_stats") % ["1:17:32", 188, 10, 10]
		widest = maxf(widest, ThemeDB.fallback_font.get_string_size(worst, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	O.language = "pt"
	_check("cabe na janela do fim", widest <= 254.0, str(widest))

	G.new_game()
	_check("jogo novo zera", G.stats.deaths == 0 and G.stats.seconds == 0.0)
	_check("continuar recupera e conta a sessao", G.load_game() and G.stats.deaths == 2 and G.stats.sessions == 2 and G.stats.finish_time() == 1052 and not G.stats.partial)

	var data: Dictionary = Saves.read(PATH)
	data.erase("stats")
	Saves.write(PATH, data)
	_check("save sem contagem carrega", G.load_game())
	_check("e nao finge um tempo", G.stats.partial and G.stats.finish_time() == -1)
	for bad in ["x", [1], {"seconds": "a"}, {"seconds": -5, "rooms": [1], "marks": 3}]:
		data["stats"] = bad
		Saves.write(PATH, data)
		_check("contagem estragada nao derruba o save: %s" % str(bad).left(18), G.load_game() and G.stats.partial)

	G.save_path = ""
	_clean()
	print("STATS ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)
