extends SceneTree
## Teste de fumaça: joga a região Área de trabalho sozinho e confere o básico.
## Rodar: godot --headless --path . -s tests/smoke.gd

const T := 16
var checks := {}
var G: Node  # autoload Game (não tem nome global em scripts -s)


func _initialize() -> void:
	G = root.get_node("Game")
	_run()


func _check(name: String, ok: bool) -> void:
	checks[name] = ok


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _p(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_p(action, true)
	await _frames(2)
	_p(action, false)


## Anda numa direção, pulando de tempos em tempos, até chegar à sala `room`.
func _walk_to_room(dir: String, room: String, max_frames := 900) -> bool:
	_p(dir, true)
	for i in max_frames:
		if i % 40 == 0:
			_p("jump", true)
		if i % 40 == 15:
			_p("jump", false)
		await physics_frame
		if G.room == room and current_scene != null and current_scene.get("player") != null:
			break
	_p(dir, false)
	_p("jump", false)
	await _frames(5)
	return G.room == room


func _teleport(room: String, pos: Vector2) -> void:
	G.enter(room, pos)
	await _frames(5)


func _run() -> void:
	await physics_frame  # a árvore ainda não aceita troca de cena no _initialize
	G.new_game()
	change_scene_to_file("res://main.tscn")
	await _frames(5)
	var s = current_scene
	var p = s.player

	# ---- C:\  movimento básico
	var y0: float = p.global_position.y
	_p("jump", true)
	await _frames(15)
	_check("pulo", y0 - p.global_position.y > 20)
	_p("jump", false)
	await _frames(40)
	var x0: float = p.global_position.x
	await _tap("dash")
	await _frames(10)
	_check("sem o chip não há dash", absf(p.global_position.x - x0) < 4.0)
	_check("sai de C:\\ para Documentos", await _walk_to_room("right", "docs"))

	# ---- Documentos: tiro e laser
	await _teleport("docs", Vector2(12 * T + 8, 168))
	s = current_scene
	p = s.player
	var bugs := get_nodes_in_group("enemy").size()
	_p("right", true)
	await _frames(2)
	_p("right", false)
	_p("shoot", true)
	await _frames(150)
	_p("shoot", false)
	_check("tiro mata bug", get_nodes_in_group("enemy").size() < bugs)

	await _teleport("docs", Vector2(42 * T + 8, 168))
	p = current_scene.player
	_p("right", true)
	await _frames(60)
	_p("right", false)
	_check("laser bloqueia sem dash", p.global_position.x < 44 * T)

	# ---- Instaladores: chip de dash
	await _teleport("installers", Vector2(41 * T + 8, 168))
	_p("right", true)
	await _frames(40)
	_p("right", false)
	_check("pega o chip de dash", G.abilities.dash)

	# ---- de volta ao laser, agora com dash
	await _teleport("docs", Vector2(42 * T + 8, 168))
	p = current_scene.player
	_p("right", true)
	await _frames(4)
	await _tap("dash")
	await _frames(20)
	_check("dash atravessa o laser", p.global_position.x > 44 * T + 8 or G.room == "trash")
	_check("chega à Lixeira", await _walk_to_room("right", "trash", 300))

	# ---- Lixeira: ponto de restauração, faro, morte e volta
	s = current_scene
	p = s.player
	_p("right", true)
	await _frames(30)
	_p("right", false)
	_check("cria ponto de restauração", G.restore.get("room", "") == "trash")

	_p("sniff", true)
	await _frames(30)
	_check("faro desacelera o tempo", s.sniffing and Engine.time_scale < 1.0)
	_check("parede falsa sólida de longe", s.is_solid_at(s.fake_walls[0]))
	_p("sniff", false)
	await _frames(5)
	_check("faro desliga", not s.sniffing and is_equal_approx(Engine.time_scale, 1.0))

	var before: Vector2 = p.global_position
	p.global_position = s.fake_walls[1] - Vector2(40, 0)
	_p("sniff", true)
	await _frames(10)
	_p("sniff", false)
	await _frames(5)
	_check("farejada de perto, abre", not s.is_solid_at(s.fake_walls[0]))
	p.global_position = before
	await _frames(5)

	p._iframes = 0.0  # a torreta ao lado da parede pode ter acertado o cão
	p.hp = 1
	p.take_damage(1, p.global_position + Vector2(10, 0))
	await _frames(10)
	_check("tela azul ao morrer", s.banner.visible and p.hp <= 0)
	await _tap("restart")
	await _frames(8)
	s = current_scene
	p = s.player
	_check("volta ao ponto de restauração", G.room == "trash" and p.hp == p.MAX_HP and p.global_position.distance_to(s.restore_pos) < 4.0)

	# ---- porta → sala de cima → de volta à Lixeira
	for id in ["gallery", "installers", "drivers"]:
		G.taken["clue:" + id] = true
	p.global_position = s.door_pos
	await _frames(8)
	s = current_scene
	_check("porta abre a sala de cima", _is_arena(s))
	if _is_arena(s):
		var t0: float = s.time_left
		_p("right", true)
		_p("shoot", true)
		await _frames(150)
		_p("right", false)
		_p("shoot", false)
		_check("ondas de bugs surgem", s._wave >= 1)
		_check("cronômetro anda", s.time_left < t0)
		s.time_left = 0.05
		await _frames(170)
		_check("vitória devolve à Lixeira", G.room == "trash" and G.taken.has("arena_desktop") and current_scene.get("player") != null)
		s = current_scene
		s.player.global_position = s.door_pos
		await _frames(8)
		_check("porta não reabre a sala vencida", not _is_arena(current_scene))
		_check("porta leva ao chefe", G.room == "ghost" and current_scene.boss != null)
		if G.room == "ghost":
			await _boss_flow()

	_check("Explorer conhece as 5 salas visitadas", G.visited.size() == 5)

	for k in checks:
		print("%-36s %s" % [k, "ok" if checks[k] else "FALHOU"])
	var ok := checks.values().all(func(v): return v)
	print("SMOKE ", "OK" if ok else "FALHOU")
	await root.get_node("Sound").shutdown()
	quit(0 if ok else 1)


func _is_arena(n: Node) -> bool:
	# sem citar a classe Arena: ela usa o autoload Game, que ainda não existe
	# quando este script é compilado
	return n != null and n.name == "Arena"


func _boss_flow() -> void:
	var s = current_scene
	var p = s.player
	var b = s.boss
	await _frames(100)  # fim da entrada do chefe
	b.set_physics_process(false)  # parado, na altura do tiro, para medir o dano
	b.global_position = Vector2(p.global_position.x + 70, 162)
	b.collision_layer = 0
	p.facing = 1
	_p("shoot", true)
	await _frames(3)
	_p("shoot", false)
	await _frames(30)
	_check("tiro atravessa o fantasma", b.hp == 64)
	b.set_physics_process(true)
	_p("sniff", true)
	await _frames(3)
	b.set_physics_process(false)
	b.global_position = Vector2(p.global_position.x + 70, 162)
	_p("shoot", true)
	await _frames(3)
	_p("shoot", false)
	await _frames(50)
	_check("faro: acerta com dano dobrado", b.hp == 62)
	_p("sniff", false)
	await _frames(3)

	p._iframes = 0.0
	p.hp = 1
	p.take_damage(1, p.global_position + Vector2(10, 0))
	await _frames(10)
	await _tap("restart")
	await _frames(8)
	_check("morrer no chefe volta à Lixeira", G.room == "trash" and not G.taken.has("boss_desktop"))

	s = current_scene
	s.player.global_position = s.door_pos
	await _frames(8)
	s = current_scene
	_check("revanche com o chefe inteiro", G.room == "ghost" and s.boss.hp == 64)
	s.player.global_position = s.exit_pos
	await _frames(5)
	_check("saída fechada até vencer", G.room == "ghost")
	s.player.global_position = Vector2(40, 168)
	await _frames(3)
	s.boss.hit(999, Vector2.RIGHT)
	await _frames(5)
	_check("vitória registrada", G.taken.has("boss_desktop"))
	s.player.global_position = s.exit_pos
	await _frames(15)
	_check("saída devolve à Lixeira", G.room == "trash")
	s = current_scene
	s.player.global_position = s.door_pos
	await _frames(8)
	_check("região limpa não repete o chefe", G.room == "trash")
