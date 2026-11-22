extends SceneTree
## Sala de cima nos 45 segundos inteiros, só com os controles.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/arena.gd

const ROUTE := [Vector2(52, 40), Vector2(332, 40), Vector2(332, 168), Vector2(52, 168)]
const ACTIONS := ["left", "right", "up", "down", "aim_left", "aim_right", "aim_up", "aim_down", "shoot"]

var G: Node


func _initialize() -> void:
	G = root.get_node("Game")
	_run()


func _set_axis(v: float, neg: String, pos: String) -> void:
	Input.action_release(neg)
	Input.action_release(pos)
	if absf(v) > 0.01:
		Input.action_press(pos if v > 0 else neg, minf(absf(v), 1.0))


func _run() -> void:
	await physics_frame
	var wins := 0
	for game_seed in range(1, 11):
		seed(game_seed)
		G.new_game()
		G.enter_arena("trash", Vector2(720, 168))
		for i in 4:
			await physics_frame
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
			_set_axis(move.x, "left", "right")
			_set_axis(move.y, "up", "down")
			_set_axis(aim.x, "aim_left", "aim_right")
			_set_axis(aim.y, "aim_up", "aim_down")
			Input.action_press("shoot")
			await physics_frame
		for a in ACTIONS:
			Input.action_release(a)
		var won: bool = h.hp > 0
		wins += int(won)
		print("arena semente %-3d %s vida=%d faltavam=%ds" % [game_seed, "VENCEU" if won else "perdeu", h.hp, ceili(s.time_left)])
	print("ARENA ", "OK" if wins > 0 else "FALHOU", " (%d de 10)" % wins)
	await root.get_node("Sound").shutdown()
	quit(0 if wins > 0 else 1)
