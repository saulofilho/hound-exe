extends SceneTree
## Da Lixeira até a tela de fim numa corrida só, com os controles: faro, parede,
## sala de cima, porta, chefe e saída. Sem teleporte e sem mexer em vida.
## Junto com route.gd, cobre o jogo inteiro.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/finish.gd

const ROUTE := [Vector2(52, 40), Vector2(332, 40), Vector2(332, 168), Vector2(52, 168)]
const ACTIONS := ["left", "right", "up", "down", "jump", "dash", "shoot", "sniff", "aim_left", "aim_right", "aim_up", "aim_down"]
const CHARGE := 4
const STUNNED := 5

var G: Node
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	_run()


func _check(what: String, ok: bool) -> void:
	print("%-44s %s" % [what, "ok" if ok else "FALHOU"])
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _release() -> void:
	for a in ACTIONS:
		Input.action_release(a)


## Anda para a direita pulando obstáculos e fareja quando a parede segura.
func _to_door() -> void:
	var hold := 0
	var sniff := 0
	for i in 60 * 50:
		var s = current_scene
		if s == null or s.get("player") == null or G.room != "trash":
			break
		var p = s.player
		if p.hp <= 0:
			break
		_release()
		Input.action_press("right")
		hold -= 1
		sniff -= 1
		if p.is_on_floor() and p.is_on_wall() and hold <= 0:
			hold = 22
		if p.global_position.x > 660.0 and not s.revealed and sniff <= -10:
			sniff = 14
		if hold > 1:
			Input.action_press("jump")
		if sniff > 1:
			Input.action_press("sniff")
		if p.global_position.x < 660.0:
			Input.action_press("shoot")
		await physics_frame
	_release()
	await _frames(8)


func _arena() -> void:
	var s = current_scene
	var h = s.hound
	var next := 0
	while not s._over and h.hp > 0:
		var to: Vector2 = ROUTE[next] - h.global_position
		if to.length() < 8.0:
			next = (next + 1) % ROUTE.size()
		var move := to.normalized()
		var near: Node2D = null
		for e in get_nodes_in_group("enemy"):
			if near == null or h.global_position.distance_to(e.global_position) < h.global_position.distance_to(near.global_position):
				near = e
		var aim := move
		if near != null:
			aim = (near.global_position - h.global_position).normalized()
		_release()
		for axis in [[move.x, "left", "right"], [move.y, "up", "down"], [aim.x, "aim_left", "aim_right"], [aim.y, "aim_up", "aim_down"]]:
			if absf(axis[0]) > 0.01:
				Input.action_press(axis[2] if axis[0] > 0.0 else axis[1], minf(absf(axis[0]), 1.0))
		Input.action_press("shoot")
		await physics_frame
	_release()
	for i in 400:
		await physics_frame
		if current_scene != null and current_scene.get("player") != null:
			break
	await _frames(6)


func _boss() -> void:
	var s = current_scene
	var b = s.boss
	var p = s.player
	var dash := 0
	for i in 60 * 120:
		if not is_instance_valid(b) or p.hp <= 0:
			break
		var d: float = b.global_position.x - p.global_position.x
		var toward := "right" if d > 0.0 else "left"
		var dodge: bool = b.state == CHARGE and absf(b.lane - p.global_position.y) < 18.0 and absf(d) < 55.0
		for c in s.get_children():
			if c.get("friendly") == false:
				var v: Vector2 = c.global_position - p.global_position
				if v.length() < 26.0 and v.dot(c.dir) < 0.0:
					dodge = true
		_release()
		if dodge:
			Input.action_press(toward)
		if b.state == STUNNED:
			if absf(d) > 100.0 or p.facing != signi(int(d)):
				Input.action_press(toward)
			Input.action_press("shoot")
			if b.second_phase():
				Input.action_press("sniff")
		dash -= 1
		if dodge and dash <= 0 and p._dash_cd == 0.0:
			dash = 4
		if dash > 1:
			Input.action_press("dash")
		await physics_frame
	_release()


func _to_exit() -> void:
	for i in 600:
		var s = current_scene
		if s == null or G.room != "ghost":
			break
		_release()
		var d: float = s.exit_pos.x - s.player.global_position.x
		Input.action_press("right" if d > 0.0 else "left")
		await physics_frame
	_release()
	await _frames(12)


func _run() -> void:
	await physics_frame
	seed(3)
	G.new_game()
	G.abilities.dash = true
	for id in ["gallery", "installers", "drivers"]:
		G.taken["clue:" + id] = true
	root.get_node("Options").show_ending = true
	G.enter("trash", Vector2(12, 168))
	await _frames(6)
	await _to_door()
	_check("fareja, passa a parede, entra na sala", current_scene.name == "Arena")
	if failures == 0:
		await _arena()
		_check("vence a sala de cima", G.taken.has("arena_desktop") and G.room == "trash")
	if failures == 0:
		_check("chega ao chefe de vida cheia", current_scene.player.hp == G.MAX_HP)
		await _to_door()
		_check("a porta leva ao chefe", G.room == "ghost")
	if failures == 0:
		await _boss()
		_check("derruba o chefe", G.taken.has("boss_desktop"))
	if failures == 0:
		await _to_exit()
		_check("sai e ve o fim", G.room == "trash" and paused and current_scene.pause_menu.page == 2)
	print("FINISH ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	_release()
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)
