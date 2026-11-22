extends SceneTree
## Percorre C:\ até a porta da Lixeira só com os controles, sem teleporte.
## Os bugs são removidos: aqui se testa a geometria das salas e o laser.
## Rodar: godot --headless --path . -s tests/route.gd

var G: Node
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _expect(what: String, ok: bool) -> void:
	var at := ""
	if current_scene != null and current_scene.get("player") != null:
		at = "%s %s hp=%d" % [G.room, current_scene.player.global_position.round(), current_scene.player.hp]
	print("%-46s %-7s %s" % [what, "ok" if ok else "FALHOU", at])
	if not ok:
		failures += 1


func _release() -> void:
	for a in ["left", "right", "jump", "dash"]:
		Input.action_release(a)


func _clear_bugs() -> void:
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await _frames(3)


## Anda até x; pula se encostar numa parede.
func _walk(x: float, limit := 500) -> bool:
	var room: String = G.room
	var p = current_scene.player
	var side := signf(x - p.global_position.x)
	var dir := "right" if side > 0 else "left"
	Input.action_press(dir)
	var hold := 0
	var done := false
	for i in limit:
		await physics_frame
		if G.room != room or not is_instance_valid(p):
			done = true
			break
		if (x - p.global_position.x) * side <= 0:
			done = true
			break
		hold -= 1
		if hold == 0:
			Input.action_release("jump")
		elif hold < 0 and p.is_on_floor() and p.is_on_wall():
			Input.action_press("jump")
			hold = 22
	_release()
	await _frames(14)
	return done


## Um pulo completo na direção de x; confere a altura em que pousou.
func _hop(x: float, floor_y: float) -> bool:
	var p = current_scene.player
	var dir := "right" if x > p.global_position.x else "left"
	Input.action_press("jump")
	Input.action_press(dir)
	for i in 70:
		await physics_frame
		if absf(x - p.global_position.x) < 4.0:
			Input.action_release(dir)
		if i > 8 and p.is_on_floor():
			break
	_release()
	await _frames(14)
	return absf(p.global_position.y - (floor_y - 8.0)) < 2.0


func _run() -> void:
	await physics_frame
	G.new_game()
	change_scene_to_file("res://main.tscn")
	await _frames(5)

	await _walk(400)
	_expect("C: -> Documentos", G.room == "docs")
	await _clear_bugs()
	await _walk(464)
	_expect("sobe 1", await _hop(500, 144))
	await _walk(534)
	_expect("sobe 2", await _hop(580, 112))
	await _walk(614)
	_expect("sobe 3", await _hop(660, 80))
	await _walk(688)
	_expect("sobe 4", await _hop(728, 64))
	await _walk(800)
	_expect("Documentos -> Downloads", G.room == "downloads")
	await _clear_bugs()
	await _walk(328)
	_expect("pega o chip", G.abilities.dash)

	await _walk(258)
	_expect("volta 1", await _hop(216, 144))
	await _walk(212)
	_expect("volta 2", await _hop(168, 112))
	await _walk(162)
	_expect("volta 3", await _hop(128, 80))
	await _walk(122)
	_expect("volta 4", await _hop(92, 64))
	await _walk(-20)
	_expect("Downloads -> Documentos", G.room == "docs")
	await _clear_bugs()
	await _walk(460)
	_expect("desce ao chao", current_scene.player.global_position.y > 160)

	# laser em x = 712: de qualquer distância, atravessa sem dano ou nem chega nele
	for side in [-1, 1]:
		for gap in [15, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62]:
			if side == 1 and gap > 42:
				continue  # não há espaço à direita
			G.hp = 5
			G.enter("docs", Vector2(600, 168))  # longe da torreta, até ela ser removida
			await _frames(5)
			await _clear_bugs()
			var p = current_scene.player
			p.global_position = Vector2(712 + side * gap, 168)
			await _frames(2)
			p.facing = -side
			await physics_frame
			Input.action_press("dash")
			await _frames(2)
			Input.action_release("dash")
			await _frames(20)
			var crossed: bool = G.room == "trash" or (p.global_position.x - 712) * side < 0
			_expect("laser lado %d, a %d px" % [side, gap], p.hp == 5 and (crossed or gap >= 58))

	# da Lixeira até a porta, passando pela parede falsa
	G.enter("docs", Vector2(684, 168))
	await _frames(5)
	await _clear_bugs()
	current_scene.player.facing = 1
	await physics_frame
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	await _frames(20)
	await _walk(800)
	_expect("Documentos -> Lixeira", G.room == "trash")
	await _clear_bugs()
	await _walk(740, 420)
	_expect("sem farejar, a parede segura", current_scene.name == "Main")
	Input.action_press("sniff")
	await _frames(12)
	Input.action_release("sniff")
	await _walk(740, 700)
	await _frames(10)
	_expect("porta da sala de cima", current_scene.name == "Arena")

	print("ROUTE ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)
