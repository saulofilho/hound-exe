extends SceneTree
## Roteiro do trailer de gameplay, em inglês, só com imagem do jogo.
## Chamado por tools/make_trailer.sh (--write-movie --fixed-fps 60).

const T := 16
const ACTIONS := ["left", "right", "up", "down", "jump", "shoot", "dash", "sniff", "aim_left", "aim_right", "aim_up", "aim_down"]
const CHARGE := 4
const STUNNED := 5

var G: Node


func _initialize() -> void:
	G = root.get_node("Game")
	# com a janela coberta o macOS não desenha, e o Movie Maker repete o quadro
	process_frame.connect(_draw_if_covered)
	_run()


func _draw_if_covered() -> void:
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _hold(action: String, on := true) -> void:
	if on != Input.is_action_pressed(action):
		if on:
			Input.action_press(action)
		else:
			Input.action_release(action)


func _release() -> void:
	for a in ACTIONS:
		_hold(a, false)


func _room(id: String, pos := Vector2.ZERO) -> void:
	_release()
	G.enter(id, pos)
	await _frames(4)


func _run() -> void:
	await process_frame
	root.get_node("Options").language = "en"
	G.new_game()

	# tiro em Documentos
	await _room("docs", Vector2(8 * T, 168))
	current_scene.player.facing = 1
	_hold("right")
	await _frames(45)
	_hold("right", false)
	_hold("shoot")
	await _frames(105)
	_hold("jump")
	await _frames(22)
	_release()
	await _frames(30)

	# o chip de dash
	await _room("downloads", Vector2(17 * T, 168))
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await _frames(20)
	_hold("right")
	await _frames(45)
	_release()
	await _frames(75)

	# o dash atravessa o laser
	await _room("docs", Vector2(38 * T, 168))
	for e in get_nodes_in_group("enemy"):
		if e.global_position.distance_to(Vector2(40 * T, 168)) < 40.0:
			e.queue_free()
	await _frames(30)
	_hold("right")
	for i in 100:
		await physics_frame
		if G.room != "docs" or not is_instance_valid(current_scene):
			break
		var gap: float = 712.0 - current_scene.player.global_position.x
		_hold("dash", gap < 34.0 and gap > 0.0)
	_release()
	await _frames(30)

	# o faro revela a parede falsa
	await _room("trash", Vector2(36 * T, 168))
	for e in get_nodes_in_group("enemy"):
		if e.global_position.y > 150.0:
			e.queue_free()
	await _frames(25)
	_hold("sniff")
	await _frames(40)
	_hold("right")
	await _frames(50)
	_release()
	await _frames(20)

	# sala de cima
	_release()
	seed(7)
	G.enter_arena("trash", Vector2(720, 168))
	await _frames(4)
	current_scene._wave = 2
	current_scene._wave_t = 0.2
	for i in 360:
		var h = current_scene.hound
		var near: Node2D = null
		for e in get_nodes_in_group("enemy"):
			if near == null or h.global_position.distance_to(e.global_position) < h.global_position.distance_to(near.global_position):
				near = e
		_release()
		_hold(["up", "right", "down", "left"][int(i / 70) % 4])
		if near != null:
			var aim: Vector2 = (near.global_position - h.global_position).normalized()
			if absf(aim.x) > 0.05:
				Input.action_press("aim_right" if aim.x > 0 else "aim_left", absf(aim.x))
			if absf(aim.y) > 0.05:
				Input.action_press("aim_down" if aim.y > 0 else "aim_up", absf(aim.y))
		_hold("shoot")
		await physics_frame

	# chefe
	await _room("ghost")
	var boss = current_scene.boss
	boss.hp = 34
	boss._left = 0.5
	var p = current_scene.player
	var dash_for := 0
	for i in 780:
		if not is_instance_valid(boss) or p.hp <= 0:
			break
		var d: float = boss.global_position.x - p.global_position.x
		var toward := "right" if d > 0.0 else "left"
		var close := false
		if boss.state == CHARGE and absf(boss.lane - p.global_position.y) < 18.0:
			close = absf(d) < 55.0
		_hold("left", (close or (boss.state == STUNNED and absf(d) > 90.0)) and toward == "left")
		_hold("right", (close or (boss.state == STUNNED and absf(d) > 90.0)) and toward == "right")
		if boss.state == STUNNED and p.facing != signi(int(d)):
			_hold(toward)
		_hold("shoot", boss.state == STUNNED)
		dash_for -= 1
		if close and dash_for < -20:
			dash_for = 4
		_hold("dash", dash_for > 1)
		await physics_frame
	_release()
	await _frames(80)

	# o nome
	G.save_path = "user://trailer_unused.json"  # o título só lê
	change_scene_to_file("res://title.tscn")
	await process_frame
	await process_frame
	root.get_node("Options").language = "en"  # o título recarrega as opções
	current_scene.show_main()
	await _frames(170)
	await root.get_node("Sound").shutdown()
	quit()
